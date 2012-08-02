syntax match gitLogCommit +^commit \x\++
syntax match gitLogAuthor +^Author: .*+
syntax match gitLogDate +^Date: .*+

highlight gitLogCommit ctermfg=3 cterm=bold
highlight gitLogAuthor ctermfg=2 cterm=bold
highlight gitLogDate ctermfg=7 cterm=bold
