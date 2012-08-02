" giddy - a vim git plugin
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
command! GdiffThis          call Gdiff(expand('%:p'))
command! GdiffAll           call Gdiff(s:ALL)
command! GdiffStaged        call GdiffStaged(expand('%:p'))
command! GdiffStagedAll     call GdiffStaged(s:ALL)
command! GaddThis           call Gadd(expand('%:p')
command! GaddAll            call Gadd(s:ALL)
command! GaddInteractive    call Gadd(s:INTERACTIVE)
command! Gcommit            call Gcommit()
command! GcommitAmend       call Gcommit(s:AMEND)
command! Gpush              call Gpush()
command! Greview            call Greview()
command! GlogThis           call Glog(expand('%:p'))
command! GlogAll            call Glog(s:ALL)

nnoremap gs                 :Gstatus<CR>
nnoremap gb                 :Gbranch<CR>
nnoremap gB                 :Gbranches<CR>
nnoremap gC                 :GcreateBranch<CR>
nnoremap gR                 :GdeleteBranch<CR>
nnoremap gd                 :GdiffThis<CR>
nnoremap gD                 :GdiffAll<CR>
nnoremap gl                 :GlogThis<CR>

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

    "if strlen(l:output) == 0
        "call Error('No output from "git ' . a:args . '"')
        "return -1
    "endif

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


function! CalcStatusWinSize(lines, scale, min_lines) abort
    let l:max_win_size = max([float2nr(winheight(winnr()) * a:scale), a:min_lines])
    return min([len(a:lines), l:max_win_size])
endfunction


function! CreateScratchBuffer(name, size)
    let l:winnr = bufwinnr('^' . a:name . '$')
    if l:winnr >= 0
        execute l:winnr . 'wincmd w'
        setlocal modifiable
        silent! execute 'normal ggdG'
    else
        execute a:size . 'new ' . a:name
        setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
        setlocal modifiable
    endif
endfunction

let s:NothingToCommit = 'nothing to commit (working directory clean)'

function! Gstatus() abort
    let l:output = Git('status')
    if l:output != -1
        let l:lines = split(l:output, '\n')
        if len(l:lines) == 2 && l:lines[1] == s:NothingToCommit
            echo s:NothingToCommit
        else
            call CreateScratchBuffer('_git_status', CalcStatusWinSize(l:lines, 0.3, 5))
            call append(line('$'), l:lines)
            runtime syntax/git-status.vim
            setlocal cursorline
            " delete without saving to a register
            execute 'delete _'
            setlocal nomodified
            setlocal nomodifiable

            " Local mappings for the status buffer
            nnoremap <buffer> q :bwipe<CR>
            nnoremap <buffer> <silent> a :call GstatusAdd()<CR>
        endif
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


function! Gdiff(arg) abort
    if a:arg == s:ALL
        let l:filename = ''
    else
        let l:filename = a:arg
    endif
    let l:output = Git('diff ' . l:filename)
    if l:output != -1
        if l:output == ''
            echo 'No changes'
        else
            let l:lines = split(l:output, '\n')
            call CreateScratchBuffer('_git_diff', CalcStatusWinSize(l:lines, 0.5, 5))
            call append(line('$'), l:lines)
            runtime syntax/git-diff.vim
            " delete without saving to a register
            execute 'delete _'
            setlocal nomodified
            setlocal nomodifiable

            " Local mappings for the status buffer
            nnoremap <buffer> q :bwipe!<CR>
        endif
    endif
endfunction

let s:MatchAdd = 'use "git add <file>..."'
let s:MatchModified = '#[\t ]\+modified:   \zs\(.*\)'

function! GstatusAdd() abort
    let l:linenr = line('.')
    let l:filename = matchstr(getline(l:linenr), s:MatchModified)
    if strlen(l:filename)
        for l:n in range(l:linenr - 1, 1, -1)
            let l:line = getline(l:n)
            if match(getline(n), s:MatchAdd) != -1
                wincmd p
                let l:output = Git('add ' . l:filename)
                if l:output == -1
                    return
                endif
                call Gstatus()
                break
            endif
        endfor
    endif
endfunction


function! Gadd(filename) abort
    let l:output = Git(a:filename)
    if l:output != -1
        echo l:output
    endif
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


function! Glog(arg) abort
    if a:arg == s:ALL
        let l:filename = ''
    else
        let l:filename = a:arg
    endif
    let l:output = Git('log ' . l:filename)
    if l:output != -1
        let l:lines = split(l:output, '\n')
        call CreateScratchBuffer('_git_log', CalcStatusWinSize(l:lines, 0.5, 5))
        call append(line('$'), l:lines)
        runtime syntax/git-log.vim
        " delete without saving to a register
        execute 'delete _'
        setlocal nomodified
        setlocal nomodifiable

        " Local mappings for the status buffer
        nnoremap <buffer> q :bwipe!<CR>
    endif
endfunction
