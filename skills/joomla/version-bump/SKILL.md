---
name: version-bump
description: Bump the V.R.M version across manifest XML, Phing build file, and SQL update file for any Joomla extension project
disable-model-invocation: true
argument-hint: modification|release|version|X.Y.Z
---

# Version Bump

Bump the project version following the **V.R.M** (Version.Release.Modification) convention.

## Arguments

`$ARGUMENTS` must be one of:
- **`modification`** — increment M only (e.g. 2.4.0 → 2.4.1)
- **`release`** — increment R, reset M to 0 (e.g. 2.4.1 → 2.5.0)
- **`version`** — increment V, reset R and M to 0 (e.g. 2.4.1 → 3.0.0)
- **`X.Y.Z`** — an explicit version number to set directly

If no argument is provided, ask the user which level to bump.

## Context: SQL Update File Management

This skill works in tandem with the **SQL Update File Management** convention documented in `joomla-coding-preferences.md`. During development, agents create and append to an unstaged SQL update file whenever schema changes are needed. By the time this skill runs, one of two situations exists:

1. **An unstaged SQL file already exists** in `sql/updates/mysql/` — created during development when schema changes were written. This file needs to be reconciled with the final version number.
2. **No unstaged SQL file exists** — no schema changes were made during this development cycle. A new SQL file is created as a version marker, containing basic placeholder comment content (never left truly empty — a zero-byte SQL file can cause problems for tooling and is ambiguous in review).

## Steps

1. **Read project configuration** from the project's `CLAUDE.md` to discover:
   - The **Phing build file** path (look for "Phing Configuration" or "Phing file" references)
   - The **manifest XML** file (the extension's `.xml` manifest, e.g. `mapper.xml`)
   - The **SQL updates directory** (typically `sql/updates/mysql/`)
   - The **repository root** (for git commands)

2. **Read the current version** from the manifest XML `<version>` tag.

3. **Calculate the new version** based on `$ARGUMENTS`:
   - `modification` → keep V and R, increment M
   - `release` → keep V, increment R, set M to 0
   - `version` → increment V, set R and M to 0
   - If `$ARGUMENTS` matches an `X.Y.Z` pattern, use it as-is
   - Validate that the new version is greater than the current version

4. **Check for an existing unstaged SQL file** in the SQL updates directory:
   - Run `git status --porcelain` on the SQL updates directory
   - Look for any untracked (`??`) or modified (`M`/`A`) `.sql` files
   - If an unstaged SQL file is found, this is the work-in-progress file from development

5. **Handle the SQL update file** based on what was found:

   **If an unstaged SQL file exists:**
   - Compare its filename version with the calculated new version
   - If they match → no action needed, the file already has the correct name
   - If they differ → **rename** the file to `{new-version}.sql`
   - Preserve all content in the file (it contains schema changes written during development)
   - Report the rename to the user (e.g. "Renamed 2.4.3.sql → 2.5.0.sql")

   **If no unstaged SQL file exists:**
   - Create a file named `{new-version}.sql` in the SQL updates directory containing basic placeholder comment content — **do not create a zero-byte/empty file**. Use two SQL comment lines: one identifying the extension and version, one stating there are no schema changes. For example:
     ```sql
     -- com_forum schema update {new-version}
     -- No schema changes in this release.
     ```
   - If a file with this name already exists and is committed, warn the user — this version has already been released

6. **Update the remaining files** (must stay in sync with the SQL file):
   - **Manifest XML** — update the `<version>` tag to the new version
   - **Manifest XML** — update the `<creationDate>` to today's date in `YYYY-MM-DD` format (e.g. `<creationDate>2026-04-08</creationDate>`)

7. **Check the Phing build file** — do **not** edit a version number into it.

   The manifest XML is the single source of truth. Current Phing build files read the version at build time:

   ```xml
   <xmlproperty file="${sourcedir}/admin/${extension}/${ext_name}.xml" prefix="mf" keepRoot="true" />
   <property name="version" value="${mf.extension.version}" override="true" />
   ```

   - **If the build file already uses this pattern** — no change is needed; the manifest bump is sufficient. Say so in the report.
   - **If the build file still has a hardcoded `<property name="version" value="X.Y.Z" .../>`** — this is a legacy build file. Convert it to the manifest-read pattern above (including the fail-fast guard below), rather than updating the literal. Report the conversion to the user.

   The guard belongs at the top of the `build` target, because Phing leaves unresolved properties as their literal token and would otherwise produce a zip named `com_example..zip`:

   ```xml
   <fail message="Could not read &lt;version&gt; from ${ext_name}.xml - check the manifest path.">
       <condition>
           <contains string="${version}" substring="mf.extension" />
       </condition>
   </fail>
   ```

   Plugin build files use the plugin manifest path instead: `${sourcedir}/${ext_name}/${ext_name}.xml`.

8. **Report** the result:
   - Old version → New version
   - List all files created, renamed, or modified
   - State whether the Phing build file already read the version from the manifest, or was converted
   - If the SQL file was renamed, show the old and new filenames
   - If the SQL file contains schema changes, remind the user to review it
   - If the SQL file is just the placeholder marker, remind the user to add any required ALTER TABLE statements if database changes are included in this release