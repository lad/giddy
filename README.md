giddy
=====

A git plugin for vim with shortcuts and commands for dealing with the most common operations.

The main functionality can be summarized as:

* status - Opens git status in a split window where files can be added, reset and checked out.
* branch - Shows the current branch, switch to an existing branch, create a new branch, delete a branch.
* diff   - Diffs the current file or all files in the working tree or staging area. Diffs
           are opened in a split window.
* commit - Opens the commit message in a split window. Also supports commit amend.
* log    - Opens git log in a split window.
* push   - Push to remote.
* pull   - Pull from remote.
* stash  - Stash push and pop. Also reloads any open files in the repository.

The following vim commands and shortcuts are defined.

    Command                 Shortcut

    Gstatus                 gs
    Gbranch                 gb
    Gbranches               gB
    GcreateBranch           gc
    GdeleteBranch           gT
    GdiffThis               gd
    GdiffAll                gD
    GdiffStaged             gj
    GdiffStagedAll          gJ
    Gcommit                 gC
    GcommitAmend            gA
    GlogThis                gl
    GlogAll                 gL
    Gpull                   gp
    Gpush                   gP
    Greview                 gR
    Gstash                  gk
    GstashPop               gK
