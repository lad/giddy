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
let s:AGAIN=6
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
let s:EverythingUpToDate = 'Everything up-to-date'

let s:GLOG_BUFFER = '_git_log'
let s:GCOMMIT_BUFFER = '_git_commit'
let s:GSTATUS_BUFFER = '_git_status'
let s:GDIFF_BUFFER = '_git_diff'

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
nnoremap gL                 :GlogAll<CR>
nnoremap gC                 :Gcommit<CR>
nnoremap gA                 :GcommitAmend<CR>
nnoremap gP                 :Gpush<CR>

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

function! EchoDebug(args)
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

function! EchoExistingBranches() abort
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

function! CalcWinSize(lines, min_lines) abort
    let l:max_win_size = max([float2nr(winheight(0) * g:GiddyScaleWindow), a:min_lines])
    return min([len(a:lines), l:max_win_size])
endfunction

function! CreateScratchBuffer(name, size)
    " Get the buffer number using the given name to check if already exists
    let l:winnr = bufwinnr('^' . a:name . '$')
    if l:winnr >= 0
        " Change to that buffer and clear its contents
        silent execute l:winnr . 'wincmd w'
        setlocal modifiable
        silent! execute '1,' . line('$') . 'delete _'
    else
        " Set the value of top_level of the repository so we can set it in the new buffer
        let l:top_level = b:top_level

        " Create the buffer of that name and set it up as a scratch buffer
        silent! execute a:size . 'new ' . a:name
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
            call Echo('Checked out ' . l:filename)
            return Gstatus()
        else
            redraw  "clear the status line
            call Error('Checkout cancelled')
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
                call Gstatus(s:AGAIN)
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
        call Gstatus(s:AGAIN)
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
            call Gstatus(s:AGAIN)
            call search(l:filename . '$')
            execute 'normal ^'
        endif
    endif
endfunction

function! NextDiff() abort
    " Find the next diff section in a diff scratch buffer.  If there's less
    " than 5 lines viewable from the diff reposition it to the center of the
    " window
    call search('^@@')
    if winheight(winnr()) - winline() < 5
        execute 'normal z.'
    endif
endfunction

function! CommitBufferAuBufWrite() abort
    " get all lines
    let l:num_lines = line('$')
    let l:lines = getline(1, l:num_lines)

    " First remove comments
    let l:i = l:num_lines - 1
    while l:i >= 0
        if strlen(l:lines[l:i]) > 0 && l:lines[l:i][0] == '#'
            unlet l:lines[l:i]
        endif
        let l:i -= 1
    endwhile

    " Remove blank lines at the end
    let l:num_lines = len(l:lines)
    let l:i = l:num_lines - 1
    while l:i >= 0
        if strlen(l:lines[l:i]) == 0
            unlet l:lines[l:i]
        else
            " break on the last non-blank line
            break
        endif
        let l:i -= 1
    endwhile

    let l:num_lines = len(l:lines)
    if l:num_lines == 0
        call Error('No commit messages present')
        echo ' '
        return -1
    elseif strlen(l:lines[0]) == 0
        call Error('The first line must contain a commit message')
        echo ' '
        return -1
    endif

    let b:tmpfile = tempname()
    call writefile(l:lines, b:tmpfile)
endfunction

function! CommitBufferAuBufUnload() abort
    if exists('b:tmpfile')
        if b:giddy_commit_type == s:NEW
            let l:output = Git('commit --file=' . b:tmpfile)
        elseif b:giddy_commit_type == s:AMEND
            let l:output = Git('commit --amend --file=' . b:tmpfile)
        else
            call Error('Script Error: invalid argument')
        endif

        if l:output != -1
            call Echo('Committed')
        endif
    else
        call Error('No files committed')
    endif

    silent! execute bufnr(bufname('%')) . 'bdelete'
endfunction

" ---------------- Callable git functions from here ------------------

function! Gstatus(...) abort
    " Gstatus can be called again from a giddy status window when we add or reset files
    if ! (a:0 > 0 && a:1 == s:AGAIN)
        " Check if we're already in a giddy buffer
        if exists('b:giddy_buffer')
            if b:giddy_buffer ==# s:GSTATUS_BUFFER
                return
            else
                silent! bwipe
            endif
        endif
    endif

    call SetTopLevel()
    let l:output = Git('status')
    if l:output != -1
        let l:lines = split(l:output, '\n')
        let l:num_lines = len(l:lines)
        if l:num_lines > 0 && l:lines[l:num_lines - 1] == s:NothingToCommit
            silent! bwipe s:GSTATUS_BUFFER
            call Error('No changes')
        else
            let l:size = CalcWinSize(l:lines, 5)
            call CreateScratchBuffer(s:GSTATUS_BUFFER, l:size)
            let b:giddy_buffer = s:GSTATUS_BUFFER
            call append(line('$'), l:lines)
            runtime syntax/git-status.vim
            setlocal cursorline
            " delete without saving to a register
            silent! execute 'delete _'
            setlocal nomodified
            setlocal nomodifiable
            " resize doesn't work so well, this expands but doesn't shrink a window height
            let &winheight = l:size

            " Local commands and their mappings for the scratch buffer
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
    let l:current = EchoExistingBranches()
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
    let l:current = EchoExistingBranches()
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
    let current = EchoExistingBranches()
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
    " Check if we're already in a giddy buffer
    if exists('b:giddy_buffer')
        if b:giddy_buffer ==# s:GDIFF_BUFFER
            return
        else
            " We can't do a git diff on the current file (since the current file is the giddy
            " scratch buffer). We can only do a git diff all.
            if a:arg != s:ALL
                call Error("Can't diff a giddy buffer. Did you mean :GlogAll?")
                return
            endif
            silent! bwipe
        endif
    endif

    call SetTopLevel()
    if a:arg == s:ALL
        let l:filename = ''
    else
        let l:filename = a:arg
    endif

    let l:output = Git('diff ' . l:filename)
    if l:output != -1
        if l:output == ''
            call Error('No changes')
        else
            let l:lines = split(l:output, '\n')
            call CreateScratchBuffer(s:GDIFF_BUFFER, CalcWinSize(l:lines, 5))
            let b:giddy_buffer = s:GDIFF_BUFFER
            call append(line('$'), l:lines)
            runtime syntax/git-diff.vim
            " delete without saving to a register
            silent! execute 'delete _'
            setlocal nomodified
            setlocal nomodifiable

            " Local mappings for the scratch buffer
            nnoremap <buffer> <silent> zj :call NextDiff()<CR>
            nnoremap <buffer> <silent> zk ?^@@<CR>
            nnoremap <buffer> <silent> q :bwipe<CR>
        endif
    endif
endfunction

" Use --porcelain?
function! Gcommit(arg) abort
    " Check if we're already in a giddy buffer
    if exists('b:giddy_buffer')
        if b:giddy_buffer ==# s:GCOMMIT_BUFFER
            return
        else
            silent! bwipe
        endif
    endif

    call SetTopLevel()
    let l:tmpfile = tempname()
    let l:commit_msg = Git('commit --dry-run', s:IGNORE_EXIT_CODE)
    if l:commit_msg == -1
        return
    endif
    let l:lines = split(l:commit_msg, '\n')
    let l:len = len(l:lines)
    if l:lines[l:len - 1] =~# s:NoChanges
        call Error('No changes staged for commit, opening git status')
        return Gstatus()
    elseif l:lines[l:len - 1] =~# s:NothingToCommit
        call Error(s:NothingToCommit)
        return
    endif

    let l:top_level = b:top_level
    silent! execute 'split ' . l:top_level . '/.git/COMMIT_MSG'
    setlocal modifiable
    setlocal filetype=gitcommit
    let b:top_level = l:top_level
    let b:giddy_buffer = s:GCOMMIT_BUFFER
    let b:giddy_commit_type = a:arg

    if a:arg == s:AMEND
        let l:amend_msg = Git('log -1 --pretty=%B')
        if l:amend_msg == -1
            return
        endif
        let l:lines = split(l:amend_msg, '\n') + l:lines
    endif

    silent! execute '1,' . line('$') . 'delete _'
    call append(line('$'), l:lines)
    " delete blank first line without saving to a register
    silent! execute 'delete _'

    au! BufWrite <buffer> call CommitBufferAuBufWrite()
    au! BufUnload  <buffer> call CommitBufferAuBufUnload()
endfunction

function! Glog(arg) abort
    " Check if we're already in a giddy scratch buffer
    if exists('b:giddy_buffer')
        if b:giddy_buffer ==# s:GLOG_BUFFER
            return
        else
            " We can't do a git log on the current file (since the current file is the giddy
            " scratch buffer). We can only do a git log all.
            if a:arg != s:ALL
                call Error("Can't log a giddy buffer. Did you mean :GlogAll?")
                return
            endif
            silent! bwipe
        endif
    endif

    call SetTopLevel()
    if a:arg == s:ALL
        let l:filename = ''
    else
        let l:filename = a:arg
    endif
    let l:output = Git('log ' . l:filename)
    if l:output != -1
        let l:lines = split(l:output, '\n')
        call CreateScratchBuffer(s:GLOG_BUFFER, CalcWinSize(l:lines, 5))
        let b:giddy_buffer = s:GLOG_BUFFER
        call append(line('$'), l:lines)
        runtime syntax/git-log.vim
        " delete without saving to a register
        execute 'delete _'
        setlocal nomodified
        setlocal nomodifiable

        " Local mappings for the scratch buffer
        nnoremap <buffer> q :bwipe<CR>
    endif
endfunction

function! Gpush() abort
    call SetTopLevel()
    echo 'Pushing...'
    let l:output = Git('push')
    if l:output != -1
        echo l:output
        if l:output !~# s:EverythingUpToDate 
            call Echo('Pushed')
        endif
    endif
endfunction

function! Greview() abort
    call SetTopLevel()
    call Error('Not implemented yet.')
endfunction
