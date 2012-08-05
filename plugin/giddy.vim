" giddy - a vim git plugin
"
" Author: louisadunne@gmail.com
" License: GPLv2
" Home: http://github.com/lad/giddy/
" Version: 1.0
" Options:
"   GiddyTrackingBranch     - If set this will be used when creating branches
"                             as the name of the remote tracking branch.
"   GiddyScaleWindow        - If set the value will be multiple by the number
"                             of lines in the current window to calculate the
"                             size of the git split window.
"                           - The maximum value is 1 which cause Giddy now to
"                             split the window but use the entire current
"                             window.
"                           - By default the value is 0.5.


if exists('g:giddy_loaded')
    finish
endif
"let g:giddy_loaded=1

if exists('g:GiddyScaleWindow')
    if g:GiddyScaleWindow > 1
        call Error('Invalid value for GiddyScaleWindow (' .
                   \ printf('%.2f', GiddyScaleWindow) . 
                   \ '). Maximum allowable value is 1.')
        "call Error(printf('%s (%.2f)%s', 'Invalid value for GiddyScaleWindow',
        "           \ GiddyScaleWindow, '. Maximum allowable value is 1.'))
    endif
else
    let g:GiddyScaleWindow=0.5
endif

if !exists('g:added_runtimepath')
    let &runtimepath = expand(&runtimepath) . ',.'
    let g:added_runtimepath = 1
endif

let s:ALL=1
let s:FILE=2
let s:NEW=3
let s:AMEND=4
let s:IGNORE_EXIT_CODE=5
let s:RED = 'red'
let s:GREEN = 'green'

let s:MatchAdd = 'use "git add\(/rm\)\? <file>..."'
let s:MatchReset = 'use "git reset HEAD <file>..."'
let s:MatchModified = '#\tmodified:   \zs\(.*\)'
let s:MatchNew = '#\tnew file:   \zs\(.*\)'
let s:MatchDeleted = '#\tdeleted:    \zs\(.*\)'
let s:MatchUntracked = '#\t\zs\(.*\)'
let s:NothingToCommit = 'nothing to commit (working directory clean)'
let s:MatchCheckout = 'use "git checkout -- <file>..."'
let s:NoChanges = 'no changes added to commit'


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
command! Gcommit            call Gcommit(s:NEW)
command! GcommitAmend       call Gcommit(s:AMEND)
command! Gpush              call Gpush()
command! Greview            call Greview()
command! GlogThis           call Glog(expand('%:p'))
command! GlogAll            call Glog(s:ALL)

nnoremap gs                 :Gstatus<CR>
nnoremap gb                 :Gbranch<CR>
nnoremap gB                 :Gbranches<CR>
nnoremap gc                 :GcreateBranch<CR>
nnoremap gR                 :GdeleteBranch<CR>
nnoremap gd                 :GdiffThis<CR>
nnoremap gD                 :GdiffAll<CR>
nnoremap gl                 :GlogThis<CR>
nnoremap gC                 :Gcommit<CR>

highlight GoodHL            ctermbg=green ctermfg=white cterm=bold
highlight ErrorHL           ctermbg=red ctermfg=white cterm=bold
highlight RedHL             ctermfg=red cterm=bold
highlight GreenHL           ctermfg=green cterm=bold


function! Error(text)
    redraw
    echohl ErrorHL | echom a:text | echohl None
endfunction


function! Echo(text)
    echohl GoodHL | echo a:text | echohl None
endfunction


function! EchoWait(args)
    echo a:args
    call input('>')
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


function! Git(args, ...) abort
    " Run git from the repo's top-level dir
    let l:output = system('cd ' . b:top_level . '; git ' . a:args)
    if v:shell_error
        echo b:top_level
        call input(':')
        if a:0 == 1 && a:1 == s:IGNORE_EXIT_CODE
            return l:output
        endif

        if strlen(l:output)
            call Error(l:output)
        else
            call Error('Error running git command')
        endif
        return -1
    endif

    return l:output
endfunction


function! SetTopLevel() abort
    if !exists('b:top_level')
        let l:dir = fnamemodify(resolve(expand('%:p')), ":h")
        let b:top_level = system('cd ' . l:dir . '; git rev-parse --show-toplevel')
        if v:shell_error
            return -1
        endif
        let b:top_level = substitute(b:top_level, '\n', "", "")
    endif
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
                call EchoHL(l:line, s:GREEN)
                let l:current = substitute(l:line, '^\* \(.*\)', '\1', '')
            elseif l:line =~? 'remotes/'
                call EchoHL(l:line, s:RED)
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
    let l:max_win_size = max([float2nr(&lines * g:GiddyScaleWindow), a:min_lines])
    return min([len(a:lines), l:max_win_size])
endfunction


function! CreateScratchBuffer(name, size)
    " Get the buffer number using the given name to check if already exists
    let l:winnr = bufwinnr('^' . a:name . '$')
    if l:winnr >= 0
        " Change to that buffer and clear its contents
        execute l:winnr . 'wincmd w'
        setlocal modifiable
        silent! execute 'normal ggdG'
    else
        " Set the value of top_level of the repository so we can set it in the new buffer
        let l:top_level = b:top_level

        " Create the buffer of that name and set it up as a scratch buffer
        execute 'silent ' . a:size . 'new ' . a:name
        setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
        setlocal modifiable
        let b:top_level = l:top_level
    endif
endfunction


function! FindStatusFile()
    let l:linenr = line('.')
    let l:filename = matchstr(getline(l:linenr), s:MatchModified)
    if strlen(l:filename) == 0
        let l:filename = matchstr(getline(l:linenr), s:MatchDeleted)
    endif
    if strlen(l:filename) == 0
        let l:filename = matchstr(getline(l:linenr), s:MatchUntracked)
    endif
    return l:filename
endfunction


function! Edit()
    let l:filename = FindStatusFile()
    bunload
    execute 'edit ' . b:top_level . '/' . l:filename
endfunction


function! Checkout()
    " Get the filename on the current line
    let l:filename = FindStatusFile()
    " Check we have a filename and that "use git checkout" appears on a line
    " somewhere above the current line
    if strlen(l:filename) && MatchAbove(s:MatchCheckout) != -1
        " Confirm this since it wipes out any changes made in that file.
        let l:yn = UserInput('Checkout ' . l:filename . ' [y/n]')
        if l:yn ==? 'y'
            wincmd p
            let l:output = Git('checkout ' . l:filename)
            if l:output == -1
                return
            endif
            redraw  "clear the status line
            echo 'Checked out ' . l:filename
            return Gstatus()
        else
            redraw  "clear the status line
            echo 'Checkout cancelled'
        endif
    endif
endfunction


function! MatchAbove(text) abort
    " Matches the given text anywhere above the current line.
    " Returns the line number of the match or -1
    for l:n in range(line('.'), 1, -1)
        let l:line = getline(l:n)
        if match(l:line, a:text) != -1
            return l:n
        endif
    endfor
    return -1
endfunction


function! StatusAdd(arg) abort
    " Add the file on the current line to git's staging area, or add all files is arg is s:ALL
    if a:arg == s:FILE
        let l:filename = FindStatusFile()

        if strlen(l:filename) != 0
            if MatchAbove(s:MatchAdd) != -1
                wincmd p
                let l:output = Git('add -A ' . l:filename)
                if l:output == -1
                    return
                endif
                call Gstatus()
                call search(l:filename . '$')
                execute 'normal ^'
            endif
        else
            let l:filename = ''
        endif
    elseif a:arg == s:ALL
        let l:output = Git('add -A')
        if l:output == -1
            return
        endif
        call Gstatus()
        call cursor(0, 0)
    else
        call Error('Script Error: invalid argument')
    endif
endfunction


function! StatusReset() abort
    let l:filename = FindStatusFile()

    if strlen(l:filename)
        if MatchAbove(s:MatchReset) != -1
            wincmd p
            " Need -q for reset otherwise it will exit with a non-zero exit
            " code in some cases
            let l:output = Git('reset -q -- ' . l:filename)
            if l:output == -1
                return
            endif
            call Gstatus()
            call search(l:filename . '$')
            execute 'normal ^'
        endif
    endif
endfunction


function! NextDiff() abort
    call search('^@@')
    " If there's less than 5 lines viewable from the diff reposition it to the
    " center of the window
    if winheight(winnr()) - winline() < 5
        execute 'normal z.'
    endif
endfunction


function! CommitBufferPreCmd() abort
    " Delete all comment lines
    silent! execute 'g/^#/d'

    " Delete any blank lines at the end of the message
    silent! execute 'normal G'
    " b = search backwards, c = match current line if present
    let l:line_num = search('^[^\s]', 'bc')
    if l:line_num != -1 && l:line_num != line('$')
        let l:line_num += 1
        silent! execute l:line_num . ',$delete _'
    endif
endfunction


" ---------------- Callable git functions from here ------------------


function! Gstatus() abort
    call SetTopLevel()
    let l:output = Git('status')
    if l:output != -1
        let l:lines = split(l:output, '\n')
        if len(l:lines) == 2 && l:lines[1] == s:NothingToCommit
            silent! bwipe '_git_status'
            echo s:NothingToCommit
        else
            let l:size = CalcStatusWinSize(l:lines, 5)
            call CreateScratchBuffer('_git_status', l:size)
            call append(line('$'), l:lines)
            runtime syntax/git-status.vim
            setlocal cursorline
            " delete without saving to a register
            execute 'delete _'
            setlocal nomodified
            setlocal nomodifiable
            " resize doesn't work so well, this expands but doesn't shrink a window height
            let &winheight = l:size

            " Local commands and their mappings for the status buffer
            command! -buffer StatusAddFile      call StatusAdd(s:FILE)
            command! -buffer StatusAddAll       call StatusAdd(s:ALL)
            command! -buffer StatusReset        call StatusReset()

            nnoremap <buffer> <silent> a        :StatusAddFile<CR>
            nnoremap <buffer> <silent> A        :StatusAddAll<CR>
            nnoremap <buffer> <silent> r        :StatusReset<CR>
            nnoremap <buffer> <silent> e        :call Edit()<CR>
            nnoremap <buffer> <silent> c        :call Checkout()<CR>
            nnoremap <buffer> <silent> q        :bwipe<CR>
        endif
    endif
endfunction


function! Gbranch() abort
    call SetTopLevel()
    let l:output = Git('branch')
    if l:output != -1
        let l:o = matchstr(split(l:output, '\n'), '\*\ze .*')
        let l:o = substitute(l:o, '^* ', '', '')
        call Echo(l:o)
    endif
endfunction


function! Gbranches() abort
    call SetTopLevel()
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
    call SetTopLevel()
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
    call SetTopLevel()
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
    call SetTopLevel()
    call Error('Not implemented yet.')
endfunction


function! Gdiff(arg) abort
    call SetTopLevel()
    if a:arg == s:ALL
        let l:filename = ''
    else
        let l:filename = a:arg
    endif
    let l:output = Git('diff ' . l:filename)
    if l:output != -1
        if l:output == ''
            echo 'no changes'
        else
            let l:lines = split(l:output, '\n')
            call CreateScratchBuffer('_git_diff', CalcStatusWinSize(l:lines, 5))
            call append(line('$'), l:lines)
            runtime syntax/git-diff.vim
            " delete without saving to a register
            execute 'delete _'
            setlocal nomodified
            setlocal nomodifiable

            " Local mappings for the status buffer
            nnoremap <buffer> q :bwipe!<CR>
            nnoremap <buffer> <silent> zj :call NextDiff()<CR>
            nnoremap <buffer> <silent> zk ?^@@<CR>
        endif
    endif
endfunction

" Use --porcelain
function! Gcommit(arg) abort
    call SetTopLevel()
    if a:arg == s:NEW
        let l:tmpfile = tempname()
        let l:commit_msg = Git('commit --dry-run', s:IGNORE_EXIT_CODE)
        let l:lines = split(l:commit_msg, '\n')
        let l:len = len(l:lines)
        if l:lines[l:len - 1] =~ s:NoChanges
            call Error(s:NoChanges)
            return Gstatus()
        endif
        execute 'silent ' . 'split ' . l:tmpfile
        call append(line('$'), l:lines)
        set filetype=gitcommit
    elseif a:arg == s:AMEND
        call Error('Not implemented yet.')
    endif
endfunction


function! Glog(arg) abort
    call SetTopLevel()
    if a:arg == s:ALL
        let l:filename = ''
    else
        let l:filename = a:arg
    endif
    let l:output = Git('log ' . l:filename)
    if l:output != -1
        let l:lines = split(l:output, '\n')
        call CreateScratchBuffer('_git_log', CalcStatusWinSize(l:lines, 5))
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


function! Gpush() abort
    call SetTopLevel()
    call Error('Not implemented yet.')
endfunction


function! Greview() abort
    call SetTopLevel()
    call Error('Not implemented yet.')
endfunction
