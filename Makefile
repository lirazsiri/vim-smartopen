prefix = /usr
PATH_INSTALL_VIMFILES = $(prefix)/share/vim/vimfiles

install:
	mkdir -p $(PATH_INSTALL_VIMFILES)
	cp -a vimfiles/* $(PATH_INSTALL_VIMFILES)
