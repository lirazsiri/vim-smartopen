" common utility functions
" vim: set hlsearch tw=0 fdm=marker:

pyfile <sfile>:p:h/common.py

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

