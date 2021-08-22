# WipFinder

Find uncommitted or unpushed WIP code in git repos.

I made this to help when determining what I needed to clean up before blowing away my `~/code` dir in preparation for an OS reinstall.

This has been tested through trial-and-error of running it on a collection of 110 git projects on my machine.

Checks for thes

## Usage

```
gem install wipfinder

wipfinder ~/code
```

```
Found 2 repos with potential sync issues
Git repo at /home/horace/code/foo is dirty
untracked files: 0
changed files: 0
deleted files: 1
unpushed branches:
Git repo at /home/horace/code/bar is dirty
untracked files: 0
changed files: 0
deleted files: 0
unpushed branches:
    feature/baz - 6 commits
```

### Known issues

There's a lot of screwy ways git projects can be configured so it's hard to capture them all with a trial and error script like this. Here are a few I know may not generalize well:

* Currently assumes 'origin' is the default remote to check for identifying the 'base' branch
* Does not handle git subprojects very well
