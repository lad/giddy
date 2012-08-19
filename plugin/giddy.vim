" giddy - a vim git plugin
"
" Author: louisadunne@gmail.com
" License: GPLv2
" Home: http://github.com/lad/giddy/
" Version: 1.0
" Options:
"   GiddyTrackingBranch     - If set this will be used when creating branches
"                             as the name of the remote tracking branch.
"   GiddyScaleWindow        - If set this value will be multiplied by the number
"                             of lines in the current window to calculate the
"                             size of the git split window.
"                           - The default the value is 0.5 (max: 1)

if exists('g:giddy_loaded') && !exists('g:giddy_dev')
    finish
endif
let g:giddy_loaded = 1

if exists('g:GiddyScaleWindow')
    if g:GiddyScaleWindow > 1
        call s:Error('Invalid value for GiddyScaleWindow (' .
                   \ printf('%.2f', GiddyScaleWindow) .
                   \ '). Maximum allowable value is 1.')
    endif
else
    let g:GiddyScaleWindow = 0.5
endif

" This is used so we can use runtime to load the files in the syntax directory
if !exists('g:added_runtimepath')
    let &runtimepath = expand(&runtimepath) . ',.'
    let g:added_runtimepath = 1
endif

let s:ALL = 1
let s:FILE = 2
let s:NEW = 3
let s:AMEND = 4
let s:IGNORE_ERROR = 5
let s:AGAIN = 6
let s:NOECHO = 7
let s:TOGGLE = 8
let s:STAGED = 9
let s:RED = 'red'
let s:GREEN = 'green'

let s:ModifiedFile = '#\t.*modified:   \zs\(.*\)'
let s:NewFile = '#\tnew file:   \zs\(.*\)'
let s:DeletedFile = '#\tdeleted:    \zs\(.*\)'
let s:UntrackedFile = '#\t\zs\(.*\)'

let s:MatchAdd = 'use "git add\(/rm\)\? <file>..."'
let s:MatchReset = 'use "git reset HEAD <file>..."'
let s:MatchCheckout = 'use "git checkout -- <file>..."'

let s:NothingToCommit = 'nothing to commit (working directory clean)'
let s:NoChanges = 'no changes added to commit'
let s:EverythingUpToDate = 'Everything up-to-date'
let s:AlreadyUpToDate = 'Already up-to-date'

let s:NoLocalChangesToSave = 'No local changes to save'

let s:GLOG_BUFFER = '_git_log'
let s:GCOMMIT_BUFFER = '_git_commit'
let s:GSTATUS_BUFFER = '_git_status'
let s:GDIFF_BUFFER = '_git_diff'

let s:STATUS_HELP = ['# Keys: <F1> (toggle help), a (add), A (add all), r (reset), e (edit)',
                   \ '#       c (checkout), Q (quit)']

let s:DIFF_HELP = ['# Keys: <F1> (toggle help), zj (next diff), zk (previous diff)',
                  \ '#       zf (first diff, next file) zF (first diff, previous file)']

command! Git                call Git()
command! Gstatus            call Gstatus()
command! Gbranch            call Gbranch()
command! Gbranches          call Gbranches()
command! GcreateBranch      call GcreateBranch()
command! GdeleteBranch      call GdeleteBranch()
command! GdiffThis          call Gdiff(expand('%:p'))
command! GdiffAll           call Gdiff(s:ALL)
command! GdiffStaged        call Gdiff(expand('%:p'), s:STAGED)
command! GdiffStagedAll     call Gdiff(s:ALL, s:STAGED)
command! GlogThis           call Glog(expand('%:p'))
command! GlogAll            call Glog(s:ALL)
command! Gcommit            call Gcommit(s:NEW)
command! GcommitAmend       call Gcommit(s:AMEND)
command! Gpull              call Gpull()
command! Gpush              call Gpush()
command! Greview            call Greview()
command! Gstash             call Gstash()
command! GstashPop          call GstashPop()

highlight GoodHL            ctermbg=green ctermfg=white cterm=bold
highlight ErrorHL           ctermbg=red ctermfg=white cterm=bold
highlight RedHL             ctermfg=red cterm=bold
highlight GreenHL           ctermfg=green cterm=bold


" ---------------- Private functions first ----------------------

function! s:EchoLines(lines)
    for l:line in split(a:lines, '\n')
        echo l:line
    endfor
endfunction

function! s:Error(text, ...)
    redraw
    echohl ErrorHL
    call s:EchoLines(a:text)
    echohl None
endfunction

function! s:Echo(text, ...)
    echohl GoodHL
    call s:EchoLines(a:text)
    echohl None
endfunction

function! s:EchoDebug(text)
    call s:EchoLines(a:text)
    call input('>')
endfunction

function! s:EchoHL(text, hl)
    if a:hl == 'red'
        echohl RedHL
    elseif a:hl == 'green'
        echohl GreenHL
    endif

    call s:EchoLines(a:text)
    echohl None
endfunction

" Set b:top_level to the path of the repository containing the current file
function! s:SetTopLevel() abort
    if !exists('b:top_level')
        " git rev-parse can determine the top level
        let l:dir = fnamemodify(resolve(expand('%:p')), ":h")
        let l:output = system('cd ' . l:dir . '; git rev-parse --show-toplevel')
        if !v:shell_error && l:output !~? '^fatal'
            " No errors
            let b:top_level = substitute(l:output, '\n', "", "")
        else
            " Probably not a git dir
            if strlen(l:output)
                call s:Error(l:output)
            endif
            return -1
        endif
    endif
    return 0
endfunction

function! s:EnterBranchName(prompt)
    return substitute(s:UserInput(prompt), '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

" Return the name of the current branch
function! s:GetCurrentBranch() abort
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

" Echos all branches in the current repository
function! s:EchoExistingBranches() abort
    let l:output = Git('branch -a')
    if l:output != -1
        echo 'Existing branches:'
        let l:current = ''
        for l:line in split(l:output, '\n')
            if l:line[0] == '*'
                call s:EchoHL(l:line, s:GREEN)
                let l:current = substitute(l:line, '^\* \(.*\)', '\1', '')
            elseif l:line =~? 'remotes/'
                call s:EchoHL(l:line, s:RED)
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

" Read and return input
function! s:UserInput(prompt) abort
    call inputsave()
    let l:in = input(a:prompt . ": ")
    call inputrestore()
    return l:in
endfunction

" Calculate the size of scratch windows (uses g:GiddyScaleWindow option)
function! s:CalcWinSize(lines, min_lines) abort
    let l:max_win_size = max([float2nr(winheight(0) * g:GiddyScaleWindow), a:min_lines])
    return min([len(a:lines), l:max_win_size])
endfunction

" Create the buffer used to display output from various git commands (diff, status, log, etc)
function! s:CreateScratchBuffer(name, size)
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

function! s:FindStatusFile()
    " TODO: Modify s:FindStatusFile so that we don't pickup Untracked as allowing checkout
    " Check for '^# \a'

    let l:linenr = line('.')
    let l:filename = matchstr(getline(l:linenr), s:ModifiedFile)
    if strlen(l:filename) == 0
        let l:filename = matchstr(getline(l:linenr), s:DeletedFile)
    endif
    if strlen(l:filename) == 0
        let l:filename = matchstr(getline(l:linenr), s:UntrackedFile)
    endif
    return l:filename
endfunction

function! s:Edit()
    let l:filename = s:FindStatusFile()
    bunload
    execute 'edit ' . b:top_level . '/' . l:filename
endfunction

function! s:Checkout()

    " TODO: Modify s:FindStatusFile so that we don't pickup Untracked as allowing checkout
    " Check for '^# \a'

    " Get the filename on the current line
    let l:filename = s:FindStatusFile()
    " Check we have a filename and that "use git checkout" appears on a line
    " somewhere above the current line
    if strlen(l:filename) && s:MatchAbove(s:MatchCheckout) != -1
        " Confirm this since it wipes out any changes made in that file.
        let l:yn = s:UserInput('s:Checkout ' . l:filename . ' [y/n]')
        if l:yn ==? 'y'
            wincmd p
            if s:SetTopLevel() != 0
                return
            endif
            let l:output = Git('checkout ' . l:filename)
            if l:output == -1
                return
            endif
            redraw  "clear the status line
            call s:Echo('Checked out ' . l:filename)
            call ReloadRepoWindows()
            return Gstatus(s:NOECHO)
        else
            redraw  "clear the status line
            call s:Error('s:Checkout cancelled')
        endif
    endif
endfunction

function! s:MatchAbove(text) abort
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

function! s:StatusAdd(arg) abort
    " Add the file on the current line to git's staging area, or add all files is arg is s:ALL
    if a:arg == s:FILE
        let l:filename = s:FindStatusFile()

        if strlen(l:filename) != 0
            if s:MatchAbove(s:MatchAdd) != -1
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
        call s:Error('Script Error: invalid argument')
    endif
endfunction

function! s:StatusReset() abort
    let l:filename = s:FindStatusFile()

    if strlen(l:filename)
        if s:MatchAbove(s:MatchReset) != -1
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

function! s:NextDiff() abort
    " Find the next diff section in a diff scratch buffer.  If there's less
    " than 5 lines viewable from the diff reposition it to the center of the
    " window
    call search('^@@')
    if winheight(winnr()) - winline() < 5
        execute 'normal z.'
    endif
endfunction

function! s:NextDiffFile() abort
    " Find the first diff section for the next file in a diff scratch buffer.
    " If there's less than 5 lines viewable from the diff reposition it to the
    " center of the window
    if search('^diff --git', 'c') != 0
        call search('^@@')
        if winheight(winnr()) - winline() < 5
            execute 'normal z.'
        endif
    endif
endfunction

function! s:PrevDiffFile() abort
    " Find the first diff section for the previous file in a diff scratch buffer.
    let l:line = search('^diff --git', 'bn')
    if l:line != 0
        " TODO ...
        call cursor(l:line, 0)
        if search('^diff --git', 'b') != 0
            call search('^@@')
        else
            execute "silent ''"
        endif
    endif
endfunction

function! s:CommitBufferAuBufWrite() abort
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
        call s:Error('No commit messages present')
        echo ' '
        return -1
    elseif strlen(l:lines[0]) == 0
        call s:Error('The first line must contain a commit message')
        echo ' '
        return -1
    endif

    " b:tmpfile will is used in CommitBufferAuBufUnload() below
    let b:tmpfile = tempname())
    call writefile(l:lines, b:tmpfile)
endfunction

function! s:CommitBufferAuBufUnload() abort
    if exists('b:tmpfile')
        if b:giddy_commit_type == s:NEW
            let l:output = Git('commit --file=' . b:tmpfile)
        elseif b:giddy_commit_type == s:AMEND
            let l:output = Git('commit --amend --file=' . b:tmpfile)
        else
            call s:Error('Script Error: invalid argument')
        endif

        if l:output != -1
            call s:Echo('Committed')
        endif
    else
        call s:Error('No files committed')
    endif

    silent! execute bufnr(bufname('%')) . 'bdelete'
endfunction

function! s:ShowHelp(...) abort
    " args are help-text-list and optional s:TOGGLE
    let l:text = a:1
    let l:do_toggle = a:0 == 2 && a:2 == s:TOGGLE

    setlocal modifiable
    if (!exists('b:has_help') && do_toggle) || (exists('b:has_help') && !do_toggle)
        for n in range(0, len(l:text) - 1)
            call append(n, l:text[n])
        endfor
        execute 'silent normal gg'
        let b:has_help = 1
    elseif (exists('b:has_help') && do_toggle)
        let l:max = len(l:text)
        execute 'silent 1,' . l:max . 'delete'
        " Check if there's a previous position and move there
        if line("''") != 0
            execute "silent ''"
        endif
        unlet b:has_help
    endif
    setlocal nomodifiable
endfunction


" ---------------- Callable git functions from here ------------------


function! Git(args, ...) abort
    " Run git from the repo's top-level dir
    let l:output = system('cd ' . b:top_level . '; git ' . a:args)
    if v:shell_error
        if a:0 == 1 && a:1 == s:IGNORE_ERROR
            return l:output
        endif

        if strlen(l:output)
            call s:Error(l:output)
        else
            call s:Error('Error running git command')
        endif
        return -1
    endif

    return l:output
endfunction

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

    if s:SetTopLevel() != 0
        return
    endif
    let l:output = Git('status')
    if l:output != -1
        let l:lines = split(l:output, '\n')
        let l:num_lines = len(l:lines)
        if l:num_lines > 0 && l:lines[l:num_lines - 1] == s:NothingToCommit
            let l:nr = bufnr(s:GSTATUS_BUFFER)
            if l:nr != -1
                execute l:nr . "bwipe"
            endif
            if ! (a:0 > 0 && a:1 == s:NOECHO)
                call s:Error('No changes')
            endif
        else
            let l:size = s:CalcWinSize(l:lines, 5)
            call s:CreateScratchBuffer(s:GSTATUS_BUFFER, l:size)
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
            command! -buffer StatusAddFile      call s:StatusAdd(s:FILE)
            command! -buffer StatusAddAll       call s:StatusAdd(s:ALL)
            command! -buffer StatusReset        call s:StatusReset()
            command! -buffer ToggleHelp         call s:ShowHelp(s:STATUS_HELP, s:TOGGLE)
            command! -buffer Edit               call s:Edit()
            command! -buffer Checkout           call s:Checkout()

            nnoremap <buffer> <silent> <F1>     :ToggleHelp<CR>
            nnoremap <buffer> <silent> a        :StatusAddFile<CR>
            nnoremap <buffer> <silent> A        :StatusAddAll<CR>
            nnoremap <buffer> <silent> r        :StatusReset<CR>
            nnoremap <buffer> <silent> e        :Edit<CR>
            nnoremap <buffer> <silent> c        :Checkout<CR>
            nnoremap <buffer> <silent> q        :bwipe<CR>

            call s:ShowHelp(s:STATUS_HELP)
        endif
    endif
endfunction

function! Gbranch() abort
    if s:SetTopLevel() != 0
        return
    endif
    let l:output = Git('branch')
    if l:output != -1
        let l:o = matchstr(split(l:output, '\n'), '\*\ze .*')
        let l:o = substitute(l:o, '^* ', '', '')
        call s:Echo(l:o)
    endif
endfunction

function! Gbranches() abort
    if s:SetTopLevel() != 0
        return
    endif
    let l:current = s:EchoExistingBranches()
    if l:current != -1
        let l:br = s:EnterBranchName('Switch branch [' . l:current . ']')
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
    if s:SetTopLevel() != 0
        return
    endif
    let l:current = s:EchoExistingBranches()
    if l:current != -1
        let l:br = s:EnterBranchName('Create branch')
        if strlen(l:br)
            echo ' '
            let cmd = 'checkout -b ' . l:br
            if exists('g:GiddyTrackingBranch')
                let cmd = cmd . ' ' . g:GiddyTrackingBranch
            endif

            let l:output = Git(cmd)
            if l:output != -1
                call s:EchoLines(l:output)
            endif
        endif
    endif
endfunction

function! GdeleteBranch() abort
    if s:SetTopLevel() != 0
        return
    endif
    let current = s:EchoExistingBranches()
    if current != -1
        let br = s:EnterBranchName('Delete branch')
        if strlen(br)
            echo ' '
            let l:output = Git('branch -d ' . br)
            if l:output != -1
                call s:EchoLines(l:output)
            endif
        endif
    endif
endfunction

function! Gdiff(arg, ...) abort
    " Check if we're already in a giddy buffer
    if exists('b:giddy_buffer')
        if b:giddy_buffer ==# s:GDIFF_BUFFER
            return
        else
            " We can't do a git diff on the current file (since the current file is the giddy
            " scratch buffer). We can only do a git diff all.
            if a:arg != s:ALL
                call s:Error("Can't diff a giddy buffer. Did you mean :GdiffAll?")
                return
            endif
            silent! bwipe
        endif
    endif

    if s:SetTopLevel() != 0
        return
    endif

    " First arg (required) is S:ALL or a filename
    if a:arg == s:ALL
        let l:filename = ''
    else
        let l:filename = a:arg
    endif

    " Second arg is optional
    if a:0 == 1 && a:1 == s:STAGED
        let l:staged = '--staged '
    else
        let l:staged = ''
    endif

    let l:output = Git('diff ' . l:staged . l:filename)
    if l:output != -1
        if l:output == ''
            call s:Error('No changes')
        else
            let l:lines = split(l:output, '\n')
            call s:CreateScratchBuffer(s:GDIFF_BUFFER, s:CalcWinSize(l:lines, 5))
            let b:giddy_buffer = s:GDIFF_BUFFER
            call append(line('$'), l:lines)
            runtime syntax/git-diff.vim
            " delete without saving to a register
            silent! execute 'delete _'
            setlocal nomodified
            setlocal nomodifiable

            " Local mappings for the scratch buffer
            command! -buffer ToggleHelp     call s:ShowHelp(s:DIFF_HELP, s:TOGGLE)
            command! -buffer NextDiff       call s:NextDiff()
            command! -buffer NextDiffFile   call s:NextDiffFile()
            command! -buffer PrevDiffFile   call s:PrevDiffFile()

            nnoremap <buffer> <silent> <F1> :ToggleHelp<CR>
            nnoremap <buffer> <silent> zj   :NextDiff<CR>
            nnoremap <buffer> <silent> zk   ?^@@<CR>
            nnoremap <buffer> <silent> zf   :NextDiffFile<CR>
            nnoremap <buffer> <silent> zF   :PrevDiffFile<CR>
            nnoremap <buffer> <silent> q    :bwipe<CR>
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

    if s:SetTopLevel() != 0
        return
    endif
    let l:tmpfile = tempname()
    let l:commit_msg = Git('commit --dry-run', s:IGNORE_ERROR)
    if l:commit_msg == -1
        return
    endif
    let l:lines = split(l:commit_msg, '\n')
    let l:len = len(l:lines)
    if l:lines[l:len - 1] =~# s:NoChanges
        call s:Error('No changes staged for commit, opening git status')
        return Gstatus()
    elseif l:lines[l:len - 1] =~# s:NothingToCommit
        call s:Error(s:NothingToCommit)
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

    command! -buffer CommitBufferAuBufWrite call s:CommitBufferAuBufWrite()
    command! -buffer CommitBufferAuBufUnload call s:CommitBufferAuBufUnload ()

    au! BufWrite   <buffer> CommitBufferAuBufWrite
    au! BufUnload  <buffer> CommitBufferAuBufUnload
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
                call s:Error("Can't log a giddy buffer. Did you mean :GlogAll?")
                return
            endif
            silent! bwipe
        endif
    endif

    if s:SetTopLevel() != 0
        return
    endif
    if a:arg == s:ALL
        let l:filename = ''
    else
        let l:filename = a:arg
    endif
    let l:output = Git('log ' . l:filename)
    if l:output != -1
        let l:lines = split(l:output, '\n')
        call s:CreateScratchBuffer(s:GLOG_BUFFER, s:CalcWinSize(l:lines, 5))
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
    if s:SetTopLevel() != 0
        return
    endif
    echo 'Pushing...'
    let l:output = Git('push')
    if l:output != -1
        " clear status line (Pushing...)
        redraw
        if split(l:output, '\n')[0] =~# s:EverythingUpToDate
            call s:Echo(s:EverythingUpToDate)
        else
            call s:EchoLines(l:output)
            call s:Echo('Pushed')
        endif
    endif
endfunction

" Gerrit push for review
function! Greview() abort
    if s:SetTopLevel() != 0
        return
    endif
    echo 'Pushing for review...'
    if exists('g:GiddyGerritBranch')
        let l:review_branch = g:GiddyGerritBranch
    else
        let l:review_branch = 'develop'
    endif

    let l:output = Git('review ' . l:review_branch . ' ' . s:GetCurrentBranch())
    if l:output != -1
        redraw
        call s:EchoLines(l:output)
    endif
endfunction

function! Gpull() abort
    if s:SetTopLevel() != 0
        return
    endif
    echo 'Pulling...'
    let l:output = Git('pull')
    if l:output != -1
        " clear status line (Pulling...)
        redraw
        if split(l:output, '\n')[0] =~# s:AlreadyUpToDate
            call s:Echo(s:AlreadyUpToDate)
        else
            call s:EchoLines(l:output)
            call s:Echo('Pulled')
        endif
    endif
endfunction

function! Gstash() abort
    if s:SetTopLevel() != 0
        return
    endif
    let l:output = Git('stash')
    if l:output != -1
        if split(l:output, '\n')[0] == s:NoLocalChangesToSave
            call s:Error(l:output)
        else
            call s:EchoLines(l:output)
            call s:Echo('File(s) stashed')
            call ReloadRepoWindows()
        endif
    endif
endfunction

function! GstashPop() abort
    if s:SetTopLevel() != 0
        return
    endif
    let l:output = Git('stash pop')
    if l:output != -1
        call s:EchoLines(l:output)
        call s:Echo('File(s) popped')
        call ReloadRepoWindows()
    endif
endfunction

function! ReloadRepoWindows() abort
    "Save the current window number so we end up back where we started
    let l:winnr = winnr()

    " Reload all windows which have files in the current repository
    let l:top_level = b:top_level
    windo call ReloadWindows(l:top_level)

    " Move back to the window we started in
    execute l:winnr . 'wincmd w'
endfunction

function! ReloadWindows(top_level) abort
    " This is run on each open window. If b:top_level matches the value
    " passed in then this window contains a file in the current repository,
    " so reload it (checking for any unsaved modifications)
    if s:SetTopLevel() == 0 && a:top_level == b:top_level
        call ReloadCurrentBuffer()
    endif
endfunction

function! ReloadCurrentBuffer() abort
    " Reload if unmodified otherwise get confirmation first
    if &modified == 1
        let l:filenamae = expand('%')
        if s:UserInput(l:filename . ' is modified. Reload [y/n]') !=? 'y'
            return
        endif
    endif

    execute 'silent edit! +' . line('.')

    if exists('l:filename')
        call s:Echo('Reloaded ' . l:filename)
    endif
endfunction


" -------------- SHORTCUTS ------------------


nnoremap gs                 :Gstatus<CR>
nnoremap gb                 :Gbranch<CR>
nnoremap gB                 :Gbranches<CR>
nnoremap gc                 :GcreateBranch<CR>
nnoremap gT                 :GdeleteBranch<CR>
nnoremap gd                 :GdiffThis<CR>
nnoremap gD                 :GdiffAll<CR>
nnoremap gj                 :GdiffStaged<CR>
nnoremap gJ                 :GdiffStagedAll<CR>
nnoremap gl                 :GlogThis<CR>
nnoremap gL                 :GlogAll<CR>
nnoremap gC                 :Gcommit<CR>
nnoremap gA                 :GcommitAmend<CR>
nnoremap gp                 :Gpull<CR>
nnoremap gP                 :Gpush<CR>
nnoremap gR                 :Greview<CR>
nnoremap gk                 :Gstash<CR>
nnoremap gK                 :GstashPop<CR>
