---
name: pr-summary
description: Summarise the commits on the current branch and write a markdown file suitable for pasting into a Pull Request description
when_to_use: Use when the user wants to generate a PR summary, pull request description, or changelog from the current branch commits
argument-hint: "[base-branch]"
arguments: [base]
disable-model-invocation: true
user-invocable: true
allowed-tools: Bash(git *) Read Write
model: inherit
shell: bash
---

# Pull Request Summary

Analyse the commits unique to the current branch and write a structured markdown summary suitable for pasting into a Pull Request description.

## Arguments

`$base` is optional:
- If provided, use it as the base branch to compare against (e.g. `main`, `develop`)
- If not provided, detect the default branch automatically (see step 2)

## Core Principles

1. **Only current-branch commits** — use `git merge-base` to find the exact fork point; never include commits from the parent branch
2. **Exclude merge commits** — always pass `--no-merges` to `git log`
3. **Never fabricate** — only report changes you can verify from the git history
4. **Summarise, don't parrot** — describe the *purpose* of each change, don't just repeat the commit message verbatim
5. **Be concise** — the summary should be readable in under a minute

## Steps

### 1. Discover Project Context

Read the project's `CLAUDE.md` (it is auto-loaded into context). Extract:
- **Project Name** — from the `## Project Configuration` section
- **Repository** — from the `## Directory Paths` section

If these values cannot be found, use the current working directory as the repository and the directory name as the project name.

### 2. Determine Base Branch

If `$base` was provided and is non-empty, use it as the base branch.

Otherwise, detect the default branch:
```bash
git -C "{Repository}" remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}'
```
If that fails, fall back to `main`.

### 3. Verify Current Branch

Get the current branch name:
```bash
git -C "{Repository}" branch --show-current
```

If the current branch IS the base branch, report that there is nothing to summarise and stop.

### 4. Find the Fork Point

Use `git merge-base` to find the exact commit where the current branch diverged from the base branch. This is critical for isolating only the current branch's commits:
```bash
git -C "{Repository}" merge-base {base-branch} HEAD
```

Store this commit hash as `FORK_POINT`. All subsequent git commands use `FORK_POINT..HEAD` as the range — not `{base-branch}..HEAD` — to ensure that only commits introduced on the current branch are included, even if the base branch has moved forward or been merged in.

### 5. Gather Commit Data

Run these commands using the `FORK_POINT..HEAD` range:

1. **Commit list** — only commits on this branch, excluding merge commits:
   ```bash
   git -C "{Repository}" log FORK_POINT..HEAD --no-merges --first-parent --pretty=format:"%h %s (%an, %ad)" --date=short
   ```

2. **Detailed commit messages** — for deeper analysis of each commit's purpose:
   ```bash
   git -C "{Repository}" log FORK_POINT..HEAD --no-merges --first-parent --pretty=format:"%h%n%s%n%b%n---"
   ```

3. **Diff stats** — summary of files changed:
   ```bash
   git -C "{Repository}" diff --stat FORK_POINT..HEAD
   ```

4. **Changed file list**:
   ```bash
   git -C "{Repository}" diff --name-only FORK_POINT..HEAD
   ```

If the commit list is empty, report that the current branch has no unique commits and stop.

### 6. Identify Affected Extensions and Versions

From the changed file list (step 5), determine which extension(s) the PR touches and read each one's current version:

- Map each changed file to the extension that owns it by walking up its path to the nearest extension **manifest XML** (the file containing an `<extension ...>` root with a `<version>` tag).
- For each unique extension, record:
  - **Name** — the conventional extension identifier, NOT the manifest `<name>` value (which is often a language constant like `COM_FORUM`). Derive it from the install/folder convention: components → `com_{name}`, plugins → `plg_{group}_{name}`, modules → `mod_{name}`, templates → `tpl_{name}`.
  - **Version** — the `<version>` value from that extension's manifest XML, read from the **working tree** (current state) so it matches what the PR ships.
- A single PR may touch more than one extension (e.g. a component plus its plugins) — list every affected extension.
- If a changed file cannot be mapped to a manifest, omit it from this section (it is not part of a versioned extension). If no extension can be determined at all, write `_None_` in the Extensions section.

### 7. Analyse and Group Changes

Review every commit message and the diff stats. Group related commits by area of change. Common categories include:
- **Feature** — new functionality
- **Fix** — bug fixes
- **Refactor** — code restructuring without behaviour change
- **Tests** — test additions or updates
- **Docs** — documentation changes
- **Config** — build, CI, or configuration changes

If all commits fall into a single logical group, skip the category subheadings.

### 8. Write the Summary File

The summary file is written to `{Repository}/Files/PR_SUMMARY.md`.

- If the `Files/` directory does not exist, create it

Write the file using this structure:

```markdown
# PR Summary: {branch-name}

**Base branch:** {base-branch}
**Commits:** {count}

## Summary

<!-- One or two sentences describing the overall purpose of this branch -->

## Extensions

- {extension-name} {version}

## Changes

### <Category>
- Description of change (`hash`)

## Files Changed

```
<!-- git diff --stat output -->
```
```

**Format rules:**
- Use imperative mood in bullet points (e.g. "Add user validation" not "Added user validation")
- Include the short commit hash in backtick-wrapped parentheses after each bullet for traceability
- Each bullet describes the *purpose* of the change, not a verbatim repeat of the commit message
- If there is only one logical group of changes, omit the category subheadings and use a flat bullet list under `## Changes`
- The `## Extensions` section lists each extension the PR touches as `- {name} {version}` (e.g. `- com_forum 1.0.4`), one per line, using the version from each extension's manifest XML
- The `## Files Changed` section contains the raw `git diff --stat` output in a fenced code block
- Always end the file with a newline

### 9. Report Results

After writing the file:
1. Display the full contents of `PR_SUMMARY.md` to the user
2. Report the file path where it was saved
3. Note the number of commits summarised and the branch range

## Edge Cases

- **No unique commits**: If `FORK_POINT..HEAD` yields zero commits, report that the branch has no changes to summarise and stop. Do not create an empty file.
- **Base branch not found**: If the specified base branch does not exist locally, try `origin/{base-branch}`. If that also fails, report the error and stop.
- **Detached HEAD**: If `git branch --show-current` returns empty, report that a branch checkout is required and stop.
- **Very large branches** (50+ commits): Group more aggressively. Focus on functional areas rather than individual commits. Note the total commit count.
- **Existing PR_SUMMARY.md**: Overwrite it — this file is always regenerated fresh.
