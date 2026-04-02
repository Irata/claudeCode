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

## Steps

1. **Read project configuration** from the project's `CLAUDE.md` to discover:
   - The **Phing build file** path (look for "Phing Configuration" or "Phing file" references)
   - The **manifest XML** file (the extension's `.xml` manifest, e.g. `mapper.xml`)
   - The **SQL updates directory** (typically `sql/updates/mysql/`)

2. **Read the current version** from the manifest XML `<version>` tag.

3. **Calculate the new version** based on `$ARGUMENTS`:
   - `modification` → keep V and R, increment M
   - `release` → keep V, increment R, set M to 0
   - `version` → increment V, set R and M to 0
   - If `$ARGUMENTS` matches an `X.Y.Z` pattern, use it as-is
   - Validate that the new version is greater than the current version

4. **Update these files** (all three must stay in sync):
   - **Phing build file** — update the `<property name="version" value="..."/>` line
   - **Manifest XML** — update the `<version>` tag
   - **SQL update file** — create an empty file named `{new-version}.sql` in the SQL updates directory. If the file already exists, leave it as-is and note this to the user.

5. **Report** the result:
   - Old version → New version
   - List all files created or modified
   - Remind the user to add any required ALTER TABLE statements to the new SQL file if database changes are included in this release
