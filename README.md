giddy
=====

A git plugin for vim with shortcuts and commands for dealing with the most common operations.

* `Gstatus` Opens git status in a split window where files can be added, reset and checked out.
* `Gbranch` Show the current branch.
* `Gbranches` Show all branches and switch between them.
* `GcreateBranch` Show all branches and create a new one.
* `GdeleteBranch` Show all branches and delete one.
* `GdiffThis` Open a split window with the diff of the current file in the working tree.
* `GdiffAll` Open a split window with diffs of all files in working tree.
* `GdiffStaged` Open a split window with the diff of the current file in the staging area.
* `GdiffStagedAll` Open a split window with diffs of all files in the staging area.
* `Gcommit` Open a split window with the commit message. If the commit message is written commit the staging area. If no changes are staged for commit, open the status window.
* `GcommitAmend` Same as Gcommit but do a `git commit --amend`
* `GlogThis` Open a split window showing the `git log` of the current file.
* `GlogAll` Open a split window showing `git log` for all files.
* `Gpull` Run `git pull`
* `Gpush` Run `git push`
* `Greview` Do a commit against gerrit.
* `Gstash` Stash the current working tree and reopen any buffers showing files in the current repository.
* `GstashPop` Pop the top of the stash stack and reopen any buffers showing files in the current repository.


Shortcuts
---------

    gs              Gstatus                 
    gb              Gbranch                 
    gB              Gbranches               
    gc              GcreateBranch           
    gT              GdeleteBranch           
    gd              GdiffThis               
    gD              GdiffAll                
    gj              GdiffStaged             
    gJ              GdiffStagedAll          
    gC              Gcommit                 
    gA              GcommitAmend            
    gl              GlogThis                
    gL              GlogAll                 
    gp              Gpull                   
    gP              Gpush                   
    gR              Greview                 
    gk              Gstash                  
    gK              GstashPop               

The shortcuts aren't prefixed with <leader>. If you want to change this, they are listed at the bottom of the plugin source. Simply add <leader> to the shortcut if you prefer.
