runtime syntax/diff.vim

" removed == red, added == green
highlight diffRemoved ctermfg=1 cterm=bold
highlight diffAdded ctermfg=2 cterm=bold
highlight WhitespaceEOL ctermbg=1 cterm=bold

match WhitespaceEOL "[ ]\+$"

