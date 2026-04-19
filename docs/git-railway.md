# The Railway Guide to Git

A beginner-friendly introduction to Git using the railway analogy — tracks, branch lines, sidings, and junctions instead of trees and branches hanging in mid-air.

This guide covers **local Git only**. Remote repositories and GitHub are covered in a follow-up document.

---

## Table of Contents

1. [Part 1: Why Version Control?](#part-1-why-version-control)
2. [Part 2: How Git Actually Works — The DAG](#part-2-how-git-actually-works--the-dag)
3. [Part 3: The Railway Analogy](#part-3-the-railway-analogy)
4. [Part 4: Your First Journey — Local Git Workflow](#part-4-your-first-journey--local-git-workflow)
5. [Part 5: Quick Reference](#part-5-quick-reference)

---

## Part 1: Why Version Control?

### The Problem

You've written something — code, a document, a configuration file. It works. Then you change it, and it breaks. You want to go back, but you saved over the original. Sound familiar?

The desperate solutions people reach for:

```
report.docx
report-v2.docx
report-v2-final.docx
report-v2-final-ACTUALLY-final.docx
report-v2-final-ACTUALLY-final-terry-edits.docx
```

This is version control by filename. It's ugly, it doesn't scale, and it tells you nothing about *what* changed between versions or *why*.

Now multiply that by a team. Five people editing the same project. Someone overwrites someone else's work. Nobody knows who changed what. Chaos.

Version control systems solve all of this. They track every change, who made it, when, and why. They let you rewind to any previous state. They let multiple people work on the same project without treading on each other's toes.

### A Brief History

**Manual copies** — The filename approach above. Better than nothing, barely.

**Centralised systems (CVS, SVN)** — One server holds the master copy. Everyone checks files out, edits them, checks them back in. Works until the server goes down, or you're on a train with no internet, or two people edit the same file at the same time.

**Distributed systems (Git, Mercurial)** — Every person has a complete copy of the entire project history. You can work offline, commit changes, create branches, review history — all without touching a server. When you're ready, you synchronise with others.

Git won this race. Created by Linus Torvalds in 2005 to manage the Linux kernel, it's now the de facto standard for version control across almost every programming language and project type.

### What Git Gives You

- **Full local history** — Every commit ever made, right on your machine
- **Branching** — Try out ideas in isolation, merge them back if they work, discard them if they don't
- **Offline work** — Commit, branch, merge, review history — all without a network connection
- **Safety net** — Almost nothing in Git is truly destructive; you can recover from nearly any mistake
- **Speed** — Operations are local, so they're fast

---

## Part 2: How Git Actually Works — The DAG

Before we get to commands, it helps to understand what Git is actually building under the hood. Skip this section if you just want to get started — but come back to it later, because understanding the data model makes everything else click.

### Commits Are Nodes

Every time you commit in Git, you create a **node**. That node contains:

- A snapshot of all your tracked files at that moment
- A message describing what changed
- A pointer to its **parent** (the commit that came before it)
- A unique identifier (a SHA-1 hash like `a1b2c3d`)

### The Graph

These nodes, connected by their parent pointers, form a **Directed Acyclic Graph** — a DAG. Let's unpack that:

- **Directed** — Each connection has a direction. A child commit points *back* to its parent. History flows backwards: from the newest commit, you follow parent pointers to reach older commits.
- **Acyclic** — There are no loops. You can never follow parent pointers and end up back where you started. History always reaches the root (the very first commit).
- **Graph** — It's not always a straight line. When you branch and merge, the graph forks and rejoins.

A simple linear history looks like this:

```
A ← B ← C ← D
                ↑
              main
```

Each letter is a commit. `D` points back to `C`, `C` points back to `B`, and so on. The label `main` is a pointer sitting on `D` — it tells Git "this is where the main line of development currently is."

### Branches Are Just Pointers

This is one of Git's most important insights. A branch is **not** a copy of your code. It's not a folder. It's a tiny label — a pointer — that sits on a commit and moves forward whenever you make a new commit on that branch.

```
A ← B ← C ← D          ← main
              ↑
              └── E ← F  ← feature
```

Here, `main` points to `D` and `feature` points to `F`. The commits `E` and `F` branched off from `C`. Both branches share the history `A ← B ← C`.

### Tags Are Immovable Pointers

A tag is like a branch pointer that never moves. You place it on a specific commit to mark it — usually for a release version.

```
A ← B ← C ← D ← E
         ↑        ↑
       v1.0     main
```

`v1.0` always points to `C`. Even as `main` moves forward, the tag stays put.

### HEAD — Where You Are Right Now

`HEAD` is a special pointer that tells Git which branch you're currently working on. Normally, `HEAD` points to a branch name, and the branch name points to a commit:

```
HEAD → main → D
```

When you make a new commit, the branch pointer moves forward and `HEAD` follows along (because it's attached to the branch).

### Merging in the Graph

When you merge two branches, Git creates a **merge commit** — a special node with *two* parents:

```
A ← B ← C ← D ←───── G    ← main
              ↑       ↗
              └ E ← F      ← feature
```

Commit `G` has two parents: `D` (from main) and `F` (from feature). The graph forked at `C` and rejoined at `G`.

That's the DAG. Every Git operation — branching, merging, rebasing, cherry-picking — is just manipulating nodes and pointers in this graph.

---

## Part 3: The Railway Analogy

The traditional way to explain Git uses tree metaphors — branches growing from a trunk. But trees grow upward and outward; they don't rejoin. Git branches split *and* merge, which is much more like a **railway network**.

Here's the complete mapping:

| Git Concept | Railway Equivalent | Why It Fits |
|---|---|---|
| `main` branch | **Main line** | The primary route that all other lines connect back to |
| Feature branch | **Branch line / siding** | A separate track diverging from the main line for specific work |
| `git switch` | **Points / switches** | The mechanism that moves you from one track to another |
| Commit | **Station stop** | A fixed point on the line — once a train has stopped there, the station exists forever |
| Tag / release | **Named station** | A significant station with a permanent name (e.g., "v2.0 Junction") |
| Merge | **Branch line rejoining the main line** | Two tracks converging at a junction |
| Merge commit | **The junction node** | The physical point where two incoming tracks become one |
| Fast-forward merge | **Extending the main line** | The branch line simply continues the main line — no junction needed because the main line hadn't moved |
| Rebase | **Relaying track** | Lifting the branch line's track and re-laying it from a more recent point on the main line |
| Conflict | **Incompatible track layouts** | Two tracks arrive at the junction with different gauges or signals — manual adjustment needed |
| Stash | **Shunting wagons into a temporary siding** | Moving your in-progress work off the active track so you can do something else |
| Cherry-pick | **Uncoupling a single carriage** | Detaching one carriage from a train on one line and attaching it to a train on another |
| Working directory | **The train on the track** | What's currently loaded and moving — the files you see and edit |
| Staging area | **The marshalling yard** | Where you assemble the next train (commit) — choosing which wagons (changes) to include |
| `git log` | **The logbook** | The record of every journey (commit) that's been made on the line |
| Detached HEAD | **A train stopped between stations** | You're at a specific point in history but not on any named line — anything you build here might be lost unless you name the line |

We'll use this analogy throughout the rest of the guide. When you see a railway term, you'll know exactly which Git concept it maps to.

---

## Part 4: Your First Journey — Local Git Workflow

Time to lay some track. Each section introduces a concept through the railway analogy, then shows you the Git command, then explains what's happening in the DAG.

### 4.1 Laying the First Track — `git init`

**The railway**: Before any trains can run, you need to establish a rail network. `git init` lays the first stretch of track and sets up the control office (the `.git` directory) that will manage all future operations.

**The command**:

```bash
mkdir my-project
cd my-project
git init
```

**What happened**: Git created a hidden `.git` directory inside `my-project`. This directory contains everything Git needs — the object database, configuration, and references. Your working directory (`my-project`) is now a Git repository.

At this point, the track is laid but no trains have run. There are no commits yet. The `main` branch exists in name only — it's waiting for its first station.

> **Note**: Modern Git defaults to naming the primary branch `main`. Older installations may use `master`. They work identically — only the name differs. You can set the default with:
> ```bash
> git config --global init.defaultBranch main
> ```

### 4.2 The Marshalling Yard — `git add`

**The railway**: You've got carriages (changed files) sitting in the depot. Before a train can depart the station, you need to shunt the right carriages into the **marshalling yard** — deciding exactly which carriages will form the next train.

This is Git's **staging area** (also called the **index**). It sits between your working directory and the repository, and it's where you assemble the next commit.

**Why a staging area?** Because you don't always want to commit everything at once. Maybe you fixed a bug *and* started a new feature. The staging area lets you commit the bug fix first, then the feature work separately — clean, logical history.

**The commands**:

```bash
# Create some files
echo "# My Project" > README.md
echo "first draft" > notes.txt

# Check what's in the depot (working directory)
git status
```

Git will show both files as **untracked** — they exist in the working directory, but Git isn't watching them yet.

```bash
# Move README.md into the marshalling yard
git add README.md

# Check status again
git status
```

Now `README.md` is listed under "Changes to be committed" (it's in the marshalling yard), while `notes.txt` is still untracked (still in the depot).

```bash
# Add everything at once
git add .
```

The `.` means "everything in the current directory." All files are now staged and ready for the train to depart.

**Useful variations**:

```bash
git add file1.txt file2.txt    # Add specific files
git add *.js                    # Add all JavaScript files
git add src/                    # Add everything in the src directory
git add -p                      # Interactive: choose individual chunks within files
```

The `-p` (patch) flag is particularly powerful. It lets you stage *part* of a file — like choosing specific wagons from a carriage rather than the whole carriage.

### 4.3 Departing the Station — `git commit`

**The railway**: The marshalling yard has assembled the train. It's time to depart the station. Once the train leaves, a permanent record is written in the logbook: what was on the train, when it departed, and where it was headed.

**The command**:

```bash
git commit -m "Initial commit: add README and notes"
```

**What happened**: Git took everything in the staging area, created a snapshot (the commit), recorded your message, and advanced the `main` pointer to this new commit.

```
A          ← main ← HEAD
"Initial commit: add README and notes"
```

The station now exists permanently. Even if you change these files later, this snapshot is preserved forever in the DAG.

**Writing good commit messages**:

The `-m` flag is fine for simple commits. For more complex changes, just run `git commit` without `-m` and Git will open your text editor for a multi-line message:

```
Short summary (50 chars or less)

Longer explanation of what changed and why. Wrap at 72 characters.
Explain the motivation for the change. What was wrong? What does this
fix? Are there side effects?
```

Convention: the first line is a brief summary in the **imperative mood** — "Add feature" not "Added feature" or "Adds feature." Think of it as completing the sentence "This commit will..."

**The shortcut** — `git commit -a`:

```bash
git commit -a -m "Update notes"
```

The `-a` flag automatically stages all **modified tracked files** before committing. It skips the marshalling yard for files Git already knows about. It will *not* add untracked (new) files — those still need an explicit `git add`.

### 4.4 Reading the Timetable — `git log`, `git status`, `git diff`

**The railway**: Any well-run railway keeps a timetable of past journeys, a display board showing current operations, and inspection reports comparing what's changed. Git has all three.

#### The Logbook — `git log`

```bash
git log
```

Shows the full history — every commit, newest first:

```
commit 7a3f2b1 (HEAD -> main)
Author: Your Name <you@example.com>
Date:   Tue Apr 8 10:30:00 2026 +0100

    Initial commit: add README and notes
```

Useful variations:

```bash
git log --oneline              # Compact: one line per commit
git log --oneline --graph      # ASCII graph of branches and merges
git log -5                     # Last 5 commits only
git log --stat                 # Show which files changed in each commit
git log -- README.md           # History of a specific file
```

The `--oneline --graph` combination is particularly useful once you start branching:

```
* 7a3f2b1 (HEAD -> main) Add search feature
*   c4d5e6f Merge branch 'feature/login'
|\
| * b2c3d4e Add login page
| * a1b2c3d Add auth module
|/
* 9f8e7d6 Initial commit
```

That's the DAG, rendered as ASCII art, right in your terminal.

#### The Departure Board — `git status`

```bash
git status
```

Shows you the current state of affairs:

- Which branch you're on (which track you're riding)
- What's staged (in the marshalling yard, ready for the next train)
- What's modified but not staged (carriages sitting in the depot)
- What's untracked (new carriages Git hasn't seen before)

Run `git status` often. It's your main orientation tool.

#### The Inspection Report — `git diff`

```bash
git diff                  # Changes in working directory vs staging area
git diff --staged         # Changes in staging area vs last commit
git diff HEAD             # All changes vs last commit (staged + unstaged)
git diff abc123 def456    # Changes between two specific commits
```

`git diff` shows you exactly what changed — line by line, with additions in green (prefixed `+`) and deletions in red (prefixed `-`).

### 4.5 Building a Branch Line — `git branch`, `git switch`

**The railway**: The main line is running smoothly. Now you want to build a branch line — a separate track where you can work on something new without disrupting mainline services. You throw the points (switches) to divert onto the new track.

**The commands**:

```bash
# See all branch lines
git branch

# Build a new branch line starting from where you are now
git branch feature/search

# Throw the points — switch to the new track
git switch feature/search
```

Or do both in one step:

```bash
git switch -c feature/search
```

The `-c` flag means "create and switch" — lay the new track and immediately divert onto it.

**What happened in the DAG**:

```
A ← B ← C     ← main
              ← feature/search ← HEAD
```

Both `main` and `feature/search` point to the same commit `C`. No files have changed. You've just created a new pointer and moved `HEAD` to follow it. This is why Git branching is so fast — it's just creating a 41-byte file containing a commit hash.

**Switching back**:

```bash
git switch main
```

This throws the points back to the main line. Your working directory updates to reflect the state of `main`. Any commits you made on `feature/search` are still there — you just can't see them right now because you're on a different track.

> **Older Git versions**: You may see `git checkout` in older tutorials. `git switch` (introduced in Git 2.23) does the same thing but is clearer in intent. `git checkout` was overloaded — it switched branches, restored files, and detached HEAD, which confused everyone. `git switch` only switches branches. Use `git switch`.

### 4.6 Working on the Branch — Commits on a Feature Branch

**The railway**: You're on the branch line now. Every station you build here is on *this* line — the main line isn't affected.

```bash
# You're on feature/search
echo "search function here" > search.js
git add search.js
git commit -m "Add search module skeleton"

echo "search tests here" > search.test.js
git add search.test.js
git commit -m "Add search tests"
```

**The DAG now**:

```
A ← B ← C               ← main
              ↖
               D ← E     ← feature/search ← HEAD
```

Commits `D` and `E` exist only on the `feature/search` line. If you `git switch main`, you're back at `C` — no `search.js`, no `search.test.js`. Switch back to `feature/search` and they reappear.

Meanwhile, someone (or future you) can make commits on `main` independently:

```bash
git switch main
echo "bug fix" >> README.md
git add README.md
git commit -m "Fix critical README bug"
```

```
A ← B ← C ← F           ← main ← HEAD
              ↖
               D ← E     ← feature/search
```

Two tracks, diverging from `C`, each with their own stations. This is the power of branching.

### 4.7 Rejoining the Main Line — `git merge`

**The railway**: The branch line work is complete. Time to lay a junction so the branch line rejoins the main line, bringing all its carriages (changes) with it.

There are two scenarios: **fast-forward** and **merge commit**.

#### Fast-Forward — No Junction Needed

If the main line hasn't moved since the branch diverged, Git can simply extend the main line pointer forward along the branch:

```bash
# Starting point:
# A ← B ← C          ← main
#              ↖
#               D ← E ← feature/search

git switch main
git merge feature/search
```

**Result**:

```
A ← B ← C ← D ← E   ← main ← HEAD
                       ← feature/search
```

No merge commit, no junction. The main line pointer simply moved forward to `E`. This is called a **fast-forward merge** — the branch line just *was* the next stretch of main line all along.

#### Merge Commit — Building a Junction

If the main line has moved since the branch diverged (both tracks have new stations), Git needs to create an actual junction — a merge commit with two parents:

```bash
# Starting point:
# A ← B ← C ← F          ← main
#              ↖
#               D ← E     ← feature/search

git switch main
git merge feature/search
```

Git combines the changes from both lines and creates a new commit:

```
A ← B ← C ← F ←── G     ← main ← HEAD
              ↖   ↗
               D ← E     ← feature/search
```

Commit `G` is the junction. It has two parents (`F` and `E`) and contains the combined result of both lines of work.

Git will open your editor to write a merge commit message. The default ("Merge branch 'feature/search'") is usually fine.

#### Cleaning Up Old Branch Lines

After merging, the branch pointer is still there but you probably don't need it:

```bash
git branch -d feature/search
```

This deletes the *pointer* only — the commits `D` and `E` are still in the graph, reachable through the merge commit `G`. No history is lost.

### 4.8 Resolving a Junction Conflict — Merge Conflicts

**The railway**: Sometimes two tracks arrive at the junction with incompatible layouts. Track A widened the gauge at a certain point; track B narrowed it. They can't both be right at the same spot. An engineer has to go to the junction site and decide how to reconcile the track layout.

A **merge conflict** happens when both branches changed the same part of the same file. Git can automatically merge changes to *different* files, or even *different parts* of the same file. But when both branches touched the same lines, Git stops and asks you to resolve it.

**What it looks like**:

```bash
git merge feature/search
# Auto-merging app.js
# CONFLICT (content): Merge conflict in app.js
# Automatic merge failed; fix conflicts and then commit the result.
```

Open `app.js` and you'll see conflict markers:

```
function init() {
<<<<<<< HEAD
    console.log("Welcome to the app");
=======
    console.log("Welcome! Try our new search.");
>>>>>>> feature/search
}
```

- Everything between `<<<<<<< HEAD` and `=======` is what's on the current branch (main)
- Everything between `=======` and `>>>>>>> feature/search` is what's on the incoming branch

**Resolving**: Edit the file to contain what you actually want. Remove the conflict markers entirely:

```
function init() {
    console.log("Welcome to the app! Try our new search.");
}
```

Then tell Git the conflict is resolved:

```bash
git add app.js
git commit
```

Git knows this is a merge commit and will pre-fill an appropriate message.

**Tips for conflicts**:

- `git status` during a conflict shows you exactly which files need attention
- `git diff` shows the conflict in detail
- `git merge --abort` cancels the merge entirely and returns to the state before you started — like abandoning the junction and going back to running two separate lines

### 4.9 Relaying the Track — `git rebase`

**The railway**: Your branch line diverged from the main line a while ago. Since then, the main line has built several new stations. Your branch line still works, but it's based on an older section of track. **Rebasing** lifts your branch line's track and re-lays it starting from the current end of the main line — as if you'd only just branched off.

**Before rebase**:

```
A ← B ← C ← F ← G       ← main
              ↖
               D ← E     ← feature/search ← HEAD
```

**The command**:

```bash
# While on feature/search:
git rebase main
```

**After rebase**:

```
A ← B ← C ← F ← G           ← main
                       ↖
                        D' ← E'  ← feature/search ← HEAD
```

Commits `D` and `E` have been recreated as `D'` and `E'` — same changes, but now they sit on top of `G` instead of `C`. The history is a clean straight line rather than a fork-and-merge.

**Why rebase?**

- **Cleaner history** — When you eventually merge, it can fast-forward, avoiding a merge commit
- **Easier to read** — A linear history is simpler to follow than a graph full of merge junctions
- **Up-to-date base** — Your branch includes the latest main-line changes, so you catch integration issues early

**The golden rule of rebasing**:

> **Never rebase commits that exist on a shared branch.**

Rebasing rewrites history — it creates *new* commits with different hashes. If someone else has based their work on the original commits, rebasing will cause confusion. Rebase your **own local feature branches** before merging. Never rebase `main` or any branch others are working on.

**Rebase conflicts** work exactly like merge conflicts. Git replays your commits one by one onto the new base. If any commit conflicts, Git pauses and asks you to resolve it:

```bash
# Fix the conflict, then:
git add conflicted-file.js
git rebase --continue

# Or abort the entire rebase:
git rebase --abort
```

### 4.10 Shunting Wagons — `git stash`

**The railway**: You're halfway through loading carriages on a branch line when an urgent signal comes in — you need to switch to the main line immediately. But the carriages aren't ready for a proper train (commit). You **shunt** them into a temporary siding so the track is clear, handle the emergency, then retrieve them later.

**The scenario**:

```bash
# You're working on feature/search, files are modified but not ready to commit
git status
# modified: search.js (not staged)

# Urgent: need to fix something on main
git stash
# Saved working directory and index state
```

Your working directory is now clean — the modifications are tucked away in the stash.

```bash
git switch main
# Fix the urgent issue...
git commit -a -m "Emergency hotfix"
git switch feature/search

# Retrieve your stashed work
git stash pop
```

`git stash pop` retrieves the most recent stash and removes it from the stash list. If you want to keep it in the stash (in case you need it again), use `git stash apply` instead.

**Multiple stashes**:

```bash
git stash list                   # See all stashed work
git stash push -m "search WIP"  # Stash with a description
git stash pop stash@{2}          # Pop a specific stash
git stash drop stash@{0}         # Delete a stash without applying
git stash clear                  # Delete all stashes
```

Think of the stash as a stack of temporary sidings, each holding a set of wagons you can retrieve later.

### 4.11 Naming a Station — `git tag`

**The railway**: Some stations are more important than others. They get proper names — "King's Cross", "Grand Central" — not just sequence numbers. In Git, these are **tags**: permanent markers on specific commits, usually used for release versions.

**The commands**:

```bash
# Lightweight tag — just a name
git tag v1.0

# Annotated tag — includes a message, author, and date (preferred for releases)
git tag -a v1.0 -m "First stable release"

# Tag a specific older commit
git tag -a v0.9 -m "Beta release" abc1234

# List all tags
git tag

# See tag details
git show v1.0

# Delete a tag
git tag -d v1.0
```

**Annotated vs lightweight**:

- **Lightweight** — Just a pointer, like a branch that never moves. Fine for personal bookmarks.
- **Annotated** — A full Git object with its own message, author, and timestamp. Use these for releases and anything you'd share with others.

In the DAG:

```
A ← B ← C ← D ← E ← F
         ↑        ↑    ↑
       v0.9     v1.0  main
```

Tags `v0.9` and `v1.0` are permanent markers. Even as `main` advances, the tags stay put — you can always return to exactly what was released.

---

## Part 5: Quick Reference

### Command Cheat Sheet

| Command | What It Does | Railway Analogy |
|---|---|---|
| `git init` | Create a new repository | Lay the first track and set up the control office |
| `git add <file>` | Stage changes | Shunt carriages into the marshalling yard |
| `git add .` | Stage all changes | Move everything in the depot to the marshalling yard |
| `git add -p` | Stage parts of files interactively | Pick specific wagons from carriages |
| `git commit -m "msg"` | Create a commit | Train departs the station; stop recorded in logbook |
| `git commit -a -m "msg"` | Stage tracked files and commit | Express departure — skip the marshalling yard for known carriages |
| `git status` | Show current state | Check the departure board |
| `git log` | Show commit history | Read the logbook |
| `git log --oneline --graph` | Show history as ASCII graph | View the network map |
| `git diff` | Show unstaged changes | Inspect carriages vs what's in the marshalling yard |
| `git diff --staged` | Show staged changes | Inspect the marshalling yard vs the last train |
| `git branch` | List branches | See all lines in the network |
| `git branch <name>` | Create a branch | Build a new branch line |
| `git switch <name>` | Switch to a branch | Throw the points to another track |
| `git switch -c <name>` | Create and switch to a branch | Lay new track and divert onto it immediately |
| `git merge <branch>` | Merge a branch into current | Build a junction to rejoin the main line |
| `git merge --abort` | Cancel an in-progress merge | Abandon the junction and restore original tracks |
| `git rebase <branch>` | Rebase current branch | Lift and re-lay track from a more recent point |
| `git rebase --continue` | Continue after resolving conflict | Resume track-laying after fixing a section |
| `git rebase --abort` | Cancel an in-progress rebase | Abandon re-laying and restore original track |
| `git stash` | Stash uncommitted changes | Shunt wagons into a temporary siding |
| `git stash pop` | Restore stashed changes | Retrieve wagons from the siding |
| `git stash list` | List all stashes | See all temporary sidings |
| `git tag <name>` | Create a lightweight tag | Put up a station name sign |
| `git tag -a <name> -m "msg"` | Create an annotated tag | Install a full station name plaque with dedication |
| `git branch -d <name>` | Delete a merged branch | Remove the branch line signpost (track history remains) |

### Common Workflows as Journey Plans

#### Journey 1: Basic Daily Workflow

```bash
# Morning: check the state of things
git status
git log --oneline -5

# Work on files...

# Stage and commit logical chunks
git add src/feature.js
git commit -m "Add feature X"

git add tests/feature.test.js
git commit -m "Add tests for feature X"
```

#### Journey 2: Feature Branch Workflow

```bash
# Start a new branch line
git switch -c feature/user-profiles

# Work, commit, repeat
git add .
git commit -m "Add user profile model"

git add .
git commit -m "Add profile view template"

# Bring in latest main-line changes
git rebase main

# Switch to main and merge
git switch main
git merge feature/user-profiles

# Clean up
git branch -d feature/user-profiles
```

#### Journey 3: Emergency Hotfix While Mid-Feature

```bash
# You're on feature/search with uncommitted work
git stash push -m "search: halfway through filter logic"

# Switch to main, fix the issue
git switch main
git switch -c hotfix/login-crash
# fix the bug...
git add .
git commit -m "Fix null pointer in login handler"

# Merge hotfix into main
git switch main
git merge hotfix/login-crash
git branch -d hotfix/login-crash

# Return to your feature and retrieve your work
git switch feature/search
git stash pop
```

#### Journey 4: Oops, I Committed to the Wrong Branch

```bash
# You accidentally committed to main instead of a feature branch
# The commit is at the tip of main

# Create the feature branch at the current point
git branch feature/oops

# Move main back one station
git reset HEAD~1

# Your working directory still has the changes
git switch feature/oops
git add .
git commit -m "Add feature that was on wrong branch"
```

> `HEAD~1` means "one commit before HEAD." `git reset` moves the branch pointer back but (by default) keeps your files unchanged. The commit still exists in the graph — you've just moved the `main` signpost back one station.

### Glossary: Git ↔ Railway

| Git Term | Railway Term | Definition |
|---|---|---|
| Repository | Rail network | The complete project including all history |
| Working directory | Train on the track | The current state of your files as you see them |
| Staging area / index | Marshalling yard | Where you assemble the next commit |
| Commit | Station stop | A recorded snapshot in history |
| Branch | Track line | A named pointer to a line of development |
| HEAD | Your current position | Which track and station you're at right now |
| Tag | Named station | A permanent marker on a specific commit |
| Merge | Junction | Where two track lines converge into one |
| Fast-forward | Track extension | Main line pointer slides forward — no junction needed |
| Merge commit | Junction node | A commit with two parents where tracks converge |
| Rebase | Track re-laying | Moving a branch line's starting point to a newer position |
| Conflict | Incompatible track layouts | Same section modified on both lines — manual resolution needed |
| Stash | Temporary siding | Parking uncommitted changes out of the way |
| Cherry-pick | Uncoupling a carriage | Copying a single commit from one branch to another |
| Detached HEAD | Stopped between stations | At a specific commit but not on any named branch |
| Reset | Moving a signpost back | Repositioning a branch pointer to an earlier commit |
| DAG | Network map | The directed acyclic graph of all commits and their connections |

---

**Next stop**: [Remote Repositories and GitHub](#) — pushing, pulling, cloning, pull requests, and collaborating with others across the network.