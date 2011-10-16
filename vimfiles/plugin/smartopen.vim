" vim: set hlsearch tw=0 fdm=marker:

pyfile <sfile>:p:h/smartopen.py

" PathComplete() 
function! PathComplete(lead, path)
    py import vim

    if empty(a:path)
        py paths = vim.eval("&path").split(',')
        py if '' in paths: paths.remove('')
    else
        py paths = [ vim.eval("a:path") ]
    endif

    py lead = vim.eval("expand(a:lead)")
    py matches = paths_complete(paths, lead)

    py vim.command("let matches = " + `matches`)

    return matches
endfunction
" 

" MakeRelative() 
function! MakeRelative(base, path)
    py import paths
    py base = vim.eval("a:base")
    py path = vim.eval("a:path")

    py vim.command("let relpath = " + `paths.make_relative(base, path)`)
    return relpath
endfunction
"

" SwitchIfLoaded() 
function! SwitchIfLoaded(path)
    if bufnr(a:path) > 0 && bufloaded(a:path)
        let switchbuf_orig = &switchbuf 
        let &switchbuf = "useopen,usetab"

        exe "sb " . a:path

        let &switchbuf = switchbuf_orig

        return 1
    else
        return 0
    endif
endfunction
" 

" place stack functions (I.e., history)"
let s:PlaceStack= []

function! PlacePush()
    let place = [ fnamemodify(bufname("%"), ":p"), getpos('.'), winnr() ]
    call add(s:PlaceStack, place)
endfunction

function! PlacePop()
    if empty(s:PlaceStack)
        return
    endif

    let place = s:PlaceStack[-1]
    unlet s:PlaceStack[-1]

    let place_path = place[0]
    let place_pos = place[1]
    let place_window = place[2]

    if !SwitchIfLoaded(place_path)
        exe "e " . place_path
    else
        " special case for split windows:
        " switch windows if the window has the right buffer in it
        let window_path = fnamemodify(bufname(winbufnr(place_window)), ":p")
        if winnr() != place_window && window_path == place_path
            exe place_window . "wincmd w"
        endif
    endif
    call setpos('.', place_pos)
endfunction
"

" path completion function 
function! OpenComplete(ArgLead, CmdLine, CursorPos)
    return PathComplete(a:ArgLead, "")
endfunction

" user defined complete function (C-X C-U)
function! CompleteFunc(findstart, base)
    if a:findstart
        " locate the start of the word
        let line = getline('.')
        let start = col('.') - 1
        while start > 0 && line[start - 1] =~ '[A-Za-z0-9/_\.\-]'
            let start -= 1
        endwhile
        return start
    else
        return PathComplete(a:base, "")
    endif
endfunction

set completefunc=CompleteFunc

" functions
function! s:FindPathForNewFile(arg)
    let dirname = fnamemodify(a:arg, ":h")
    if dirname == "."
        return a:arg
    else
        let basename = fnamemodify(a:arg, ":t")

        let path = finddir(dirname)
        if empty(path)
            throw printf("no such file or directory (%s)", a:arg)
        endif

        return path . "/" . basename
    endif
endfunction

" handle url -> returns 1 if arg is an url
function! s:OpenUri(arg)
    let match = matchlist(a:arg, '^\(\a\+\)://')
    if empty(match)
        return 0
    endif

    let proto = match[1]
    if has_key(g:UriHandlers, proto)
        let cmd = printf("%s %s &", g:UriHandlers[proto], a:arg)
        call system(cmd)
    endif

    return 1
endfunction

" open in external program -> return True if we found an external handler
function! s:OpenExternalFiletypes(arg)
    let match = matchlist(a:arg, '\.\(\a\+\)$')
    if empty(match)
        return 0
    endif

    let suffix = match[1]
    if has_key(g:ExternalFiletypes, suffix)
        let handler = g:ExternalFiletypes[suffix]
        if handler != ""
            let cmd = printf("%s %s &", handler, a:arg)
            echo cmd
            call system(cmd)
        endif

        return 1
    endif
    return 0
endfunction

function! s:Open(cmd, arg)
    let arg = a:arg
    if empty(arg)
        let arg = expand("<cfile>")
        let implicit = 1
    else
        let implicit = 0
    endif
    if s:OpenUri(arg)
        return
    endif

    let cmd = a:cmd
    
    " special handling for nofiles because we can't get back if we leave
    " so split the window instead
    if &buftype == "nofile" && cmd =~ "^e"
        let cmd = "sp"
    endif

    let path = findfile(arg)
    if empty(path)
        " if its not a file, maybe its a tag?
        let tags = taglist('^'.arg.'$')
        if !empty(tags)
            call PlacePush()

            if cmd == "e"
                exe "tag " . arg
            else
                exe cmd . " +tag\\ " . arg
            endif

            return
        endif

        if implicit
            let pat = exists("b:ImplicitCreateFilter") ?
                            \ b:ImplicitCreateFilter : g:ImplicitCreateFilter
            if (pat == "" || arg !~ pat)
                return
            endif
        endif

        " if its not a tag, assume its a new file
        try
            let path = s:FindPathForNewFile(arg)
        catch
            if !implicit
                throw v:exception
            endif
            return 
        endtry
    else
        if s:OpenExternalFiletypes(path)
            return
        endif
    endif

    call PlacePush()
    if !SwitchIfLoaded(path)
        exe cmd . " " . escape(path, " ")
    endif
endfunction

function! Open(bang, arg)
    call s:Open('e'.a:bang, a:arg)
endfunction

function! SplitOpen(arg)
    call s:Open('split', a:arg)
endfunction

function! TabOpen(arg)
    call s:Open('tabnew', a:arg)
endfunction
"

" commands"
command! -bang -complete=customlist,OpenComplete -nargs=? 
    \ Open call Open('<bang>', '<args>')

command! -complete=customlist,OpenComplete -nargs=? 
    \ TabOpen call TabOpen('<args>')

command! -complete=customlist,OpenComplete -nargs=? 
    \ SplitOpen call SplitOpen('<args>')
"

" keyboard bindings"
map <silent>gf              :O<CR>
map <silent><C-W>f          :SplitOpen<CR>
map <silent><C-]>           :O<CR>
map <silent><C-T>           :call PlacePop()<CR>
"

" mouse bindings"
map <S-LeftMouse>           <LeftMouse>
map <silent><2-LeftMouse>   :Open<CR>
map <silent><S-2-LeftMouse> :SplitOpen<CR>

noremap <C-LeftMouse>       <LeftMouse>
map <silent><C-2-LeftMouse> :TabOpen<CR>

map <silent><C-RightMouse>  :call PlacePop()<CR>
"

"

