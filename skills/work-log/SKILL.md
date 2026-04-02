---
name: work-log
description: Scan the repository for file modifications and append structured daily entries to the project work log
disable-model-invocation: true
argument-hint: include today
---

# Work Log

Scan the project repository for file modifications since the last logged date and append structured daily entries to the work log.

## Arguments

`$ARGUMENTS` is optional:
- **`include today`** — include today's date in the scan range (default stops at yesterday)
- If no argument is provided, scan up to yesterday only

## Core Principles

1. **Never fabricate** — only report changes you can verify from file timestamps and content
2. **Verify day-of-week** — ALWAYS use `date -d "YYYY-MM-DD" +%A` before writing any date heading; never guess
3. **Skip empty days** — if no files were modified on a date, do not create an entry for it
4. **Append only** — never modify existing entries; only add new ones at the end of the file
5. **Be concise but informative** — group related changes by functional area, explain *what* and *why*

## Steps

### 1. Discover Project Context

Read the project's `CLAUDE.md` (it is auto-loaded into context). Extract:
- **Project Name** — from the `## Project Configuration` section (e.g. `SANE`)
- **Repository** — from the `## Directory Paths` section (e.g. `E:\repositories\Sane`)

If these values cannot be found, report the error and stop.

### 2. Locate or Initialise Work Log

The work log lives at `{Repository}/Files/work-log.md`.

- If the `Files/` directory does not exist, create it
- If `work-log.md` does not exist, create it with the initialisation template (see below)
- If it exists, read it to find the last entry date

**Initialisation template** (only used for new files):
```markdown
# {Project Name} Project — Work Log

> Daily record of development activity on the {Project Name} project.

---
```

### 3. Determine Date Range

Find the last `## YYYY-MM-DD` heading in the existing work log. The scan range is:
- **Start**: last entry date + 1 day
- **End**: yesterday's date (unless `$ARGUMENTS` includes "include today", in which case end = today)

If the work log has no entries yet, scan from 30 days ago (or a reasonable lookback).

If there are no dates to scan (last entry = yesterday, or last entry = today when "include today"), report that the work log is up to date and stop.

### 4. Scan for Modifications

For each date in the range, scan the repository for modified files:

```bash
find "{Repository}" \
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/vendor/*" \
  -not -path "*/build/*" \
  -not -path "*/.idea/*" \
  -newermt "YYYY-MM-DD 00:00:00" \
  -not -newermt "YYYY-MM-DD+1 00:00:00" \
  -type f \
  -printf "%T@ %p\n" 2>/dev/null | sort
```

Group all dates with modifications. Skip dates with zero modified files.

For efficiency, you may scan the entire range at once and then group by date:
```bash
find "{Repository}" \
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/vendor/*" \
  -not -path "*/build/*" \
  -not -path "*/.idea/*" \
  -newermt "{start_date} 00:00:00" \
  -not -newermt "{end_date+1} 00:00:00" \
  -type f \
  -printf "%TY-%Tm-%Td %p\n" 2>/dev/null | sort
```

### 5. Analyse Changes

For each date with modifications:

1. **Read the modified files** (or at least examine their paths and key content) to understand what changed
2. **Group by functional area** — e.g. "Admin UI", "API Layer", "Schema Updates", "Documentation", "Build/Packaging"
3. **Determine the focus** — write a one-line summary of the day's primary focus
4. **List files changed** — compile a summary file list (not every single file, but the key ones)
5. **Write the "In short" summary** — 1-2 sentences capturing the essence of the day

### 6. Verify Day Names

Before writing any entry, verify the day-of-week:
```bash
date -d "YYYY-MM-DD" +%A
```

This is critical. Never assume or calculate the day name yourself.

### 7. Generate and Append Entries

Append new entries to the end of `work-log.md` following this exact format:

```markdown

---

## YYYY-MM-DD (DayName)

### Focus: [one-line summary of the day's primary activity]

### 1. [First area of work]
[Description of what changed and why — be specific about files, features, fixes]

### 2. [Second area of work]
[Description]

**Files changed:** [comma-separated list of key files or "N files across X, Y, Z"]

**In short:** [1-2 sentence summary of the entire day's work]
```

**Format rules:**
- Each entry starts with `---` separator on a blank line before the heading
- Use `### Focus:` (not bold, not a different heading level)
- Number the work areas: `### 1.`, `### 2.`, etc.
- End each entry with `**Files changed:**` and `**In short:**`
- If only one area of work, still use `### 1.` numbering
- Keep descriptions factual — describe what was done, not speculation about intent

### 8. Report Results

After appending, report:
- How many new entries were added
- Which dates were covered
- A brief note if any dates were skipped (no modifications found)

## Edge Cases

- **Binary files** (PDF, XLSX, images): Note their presence but don't try to read content. Describe based on filename.
- **Very large change sets** (50+ files): Group broadly rather than listing every file. Focus on the functional areas.
- **Only .git changes**: Skip the date entirely — these are not project work.
- **Symlinks**: Include them if they point to project-relevant files.

## Important Reminders

- The work log uses `## YYYY-MM-DD (DayName)` headings — TWO hashes, not three
- Day names are English full names: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday
- Always end the file with a newline
- Do NOT modify any existing content in the work log — only append
