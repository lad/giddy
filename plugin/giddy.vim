" giddy - a simple git plugin
"
" Author: louisadunne@gmail.com
" License: GPLv2
" Home: http://github.com/lad/giddy/
" Version: 1.0
" NOTE: This is intentionally a simple plugin. If you need a more fully
"       featured Git plugin see Tim Pope's fugitive or motemen's git-vim


" Options
"   GiddyTrackingBranch     - if set it will be used when creating branches as
"                             the name of the remote tracking branch


if exists('g:giddy_loaded')
    finish
endif
"let g:giddy_loaded=1

if !exists('g:added_runtimepath')
    let &runtimepath = expand(&runtimepath) . ',.'
    let g:added_runtimepath = 1
endif

let s:ALL=1
let s:INTERACTIVE=2
let s:AMEND=3

" set cursorline

command! Gstatus            call Gstatus()
command! Gbranch            call Gbranch()
command! Gbranches          call Gbranches()
command! GcreateBranch      call GcreateBranch()
command! GdeleteBranch      call GdeleteBranch()
command! GwipeBranch        call GwipeBranch()
command! Gdiff              call Gdiff(expand('%:p'))
command! GdiffAll           call Gdiff(s:ALL)
command! GdiffStaged        call GdiffStaged(expand('%:p'))
command! GdiffStagedAll     call GdiffStaged(s:ALL)
command! Gadd               call Gadd(expand('%:p')
command! GaddAll            call Gadd(s:ALL)
command! GaddInteractive    call Gadd(s:INTERACTIVE)
command! Gcommit            call Gcommit()
command! GcommitAmend       call Gcommit(s:AMEND)
command! Gpush              call Gpush()
command! Greview            call Greview()
command! Glog               call Glog(expand('%:p'))
command! GlogAll            call Glog(s:ALL)

nnoremap gs                 :Gstatus<CR>
nnoremap gb                 :Gbranch<CR>
nnoremap gB                 :Gbranches<CR>
nnoremap gC                 :GcreateBranch<CR>
nnoremap gD                 :GdeleteBranch<CR>

highlight GoodHL            ctermbg=green ctermfg=white cterm=bold
highlight ErrorHL           ctermbg=red ctermfg=white cterm=bold
highlight RedHL             ctermfg=red cterm=bold
highlight GreenHL           ctermfg=green cterm=bold


function! Error(args)
    echohl ErrorHL | echo a:args | echohl None
endfunction


function! Echo(args)
    echohl GoodHL | echo a:args | echohl None
endfunction


function! EchoHL(args, hl)
    if a:hl == 'red'
        echohl RedHL | echo a:args  | echohl None
    elseif a:hl == 'green'
        echohl GreenHL | echo a:args  | echohl None
    endif
endfunction


function! Strip(str)
    return substitute(a:str, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction


function! Git(args) abort
    if SetTopLevel() == -1
        call Error("Couldn't determine git dir")
        return -1
    endif

    " Run git from the repo's top-level dir
    let l:output = system('cd ' . b:top_level . '; git ' . a:args)
    if v:shell_error
        if strlen(l:output)
            call Error(l:output)
        else
            call Error('Error running git command')
        endif
        return -1
    endif

    if strlen(l:output) == 0
        call Error('No output from "git ' . a:args . '"')
        return -1
    endif

    return l:output
endfunction


function! SetTopLevel() abort
"   if !exists('b:top_level')
        let l:dir = fnamemodify(resolve(expand('%:p')), ":h")
        let b:top_level = system('cd ' . l:dir . '; git rev-parse --show-toplevel')
        if v:shell_error
            return -1
        endif
        let b:top_level = substitute(b:top_level, '\n', "", "")
"   endif
    return 0
endfunction


function! GetCurrentBranch() abort
    let l:output = Git('branch -a')
    if l:output != -1
        let l:current = ''
        for line in split(l:output, '\n')
            if line[0] == '*'
                let l:current = substitute(line, '^\* \(.*\)', '\1', '')
                break
            endif
        endfor

        if strlen(l:current)
            return l:current
        else
            return -1
        endif
    endif
endfunction


function! ExistingBranches() abort
    let l:output = Git('branch -a')
    if l:output != -1
        echo 'Existing branches:'
        let l:current = ''
        for l:line in split(l:output, '\n')
            if l:line[0] == '*'
                call EchoHL(l:line, 'green')
                let l:current = substitute(l:line, '^\* \(.*\)', '\1', '')
            elseif l:line =~? 'remotes/'
                call EchoHL(l:line, 'red')
            else
                echo l:line
            endif
        endfor

        if strlen(l:current)
            return l:current
        else
            return -1
        endif
    else
        return -1
    endif
endfunction


function! UserInput(prompt) abort
    call inputsave()
    let l:in = input(a:prompt . ": ")
    call inputrestore()
    return l:in
endfunction


function! CalcStatusWinSize(lines, min_lines) abort
    let l:max_win_size = max([float2nr(winheight(winnr()) * 0.3), a:min_lines])
    return min([len(a:lines), l:max_win_size])
endfunction


function! Gstatus() abort
    let l:output = Git('status')
    if l:output != -1
        let l:lines = split(l:output, '\n')
        let l:winsize = CalcStatusWinSize(l:lines, 5)
        execute l:winsize . 'new'
        set modifiable
        call append(line('$'), l:lines)
        runtime syntax/git-status.vim
        set cursorline
        execute 'delete _'
        set nomodified
        set nomodifiable
        wincmd p
    endif
endfunction


function! Gbranch() abort
    let l:output = Git('branch')
    if l:output != -1
        let l:o = matchstr(split(l:output, '\n'), '\*\ze .*')
        let l:o = substitute(l:o, '^* ', '', '')
        call Echo(l:o)
    endif
endfunction


function! Gbranches() abort
    let l:current = ExistingBranches()
    if l:current != -1
        let l:br = Strip(UserInput('Switch branch [' . l:current . ']'))
        if strlen(l:br)
            echo ' '
            let l:output = Git('checkout ' . l:br)
            if l:output != -1
                echo l:output
            endif
        endif
    endif
endfunction


function! GcreateBranch() abort
    let l:current = ExistingBranches()
    if l:current != -1
        let l:br = Strip(UserInput('Create branch'))
        if strlen(l:br)
            echo ' '
            let cmd = 'checkout -b ' . l:br
            if exists('g:GiddyTrackingBranch')
                let cmd = cmd . ' ' . g:GiddyTrackingBranch
            endif

            let l:output = Git(cmd)
            if l:output != -1
                echo l:output
            endif
        endif
    endif
endfunction


function! GdeleteBranch() abort
    let current = ExistingBranches()
    if current != -1
        let br = Strip(UserInput('Delete branch'))
        if strlen(br)
            echo ' '
            let l:output = Git('branch -d ' . br)
            if l:output != -1
                echo l:output
            endif
        endif
    endif
endfunction


function! GwipeBranch() abort
    call Error('Not implemented yet.')
endfunction


function! Gdiff(args) abort
    if a:args != 1
        " ALL
        let dargs = a:args
    else
        let dargs = ''
    endif
    let output = Git('diff ' . dargs)
    if output != -1
        echo output
    endif
endfunction



function! Gadd() abort
    call Error('Not implemented yet.')
endfunction


function! GaddInteractive() abort
    call Error('Not implemented yet.')
endfunction


function! Gcommit() abort
    call Error('Not implemented yet.')
endfunction


function! Gpush() abort
    call Error('Not implemented yet.')
endfunction


function! Greview() abort
    call Error('Not implemented yet.')
endfunction


function! Glog(args) abort
    if a:args != 1
        let l:args = a:args
    else
        let l:args = ''
    endif
    let l:output = Git('log ' . l:args)
    if l:output != -1
        echo l:output
    endif
endfunction
