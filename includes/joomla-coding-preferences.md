## Coding Standards for Joomla projects

### Namespacing Guidelines
- All namespacing at the top of each file should be in alphabetical order for any Joomla task/project
- All component Classes namespaced under _vendor_\_name_ 
- 
- ### Code Standards
- PHP 8.3+ language features (constructor promotion, readonly properties, enums, match expressions, typed class constants, `#[Override]` attribute)
- Modern PSR-4 autoloading with Joomla namespaced classes
- Joomla 4.x/5.x conventions and security practices
- All files include `defined('_JEXEC') or die;` protection
- Uses container-based dependency injection
- PHPDoc comments for all public methods and properties
### Reference Libraries
- Always consult https://context7.com/context7/developer_joomla-coding-standards library for additional coding standards reference
- Refer to additional context7 libraries located in @.claude/includes/context7.json before starting any tasks
- Always use the latest version of the context7 libraries

### Input Handling
- NEVER access PHP superglobals (`$_REQUEST`, `$_GET`, `$_POST`, `$_COOKIE`) directly. Always use Joomla's `InputInterface` via `$this->app->getInput()` or `Factory::getApplication()->getInput()`.
- Use typed getter methods: `$input->getInt()`, `$input->getString()`, `$input->getCmd()`, etc.
- For HikaShop legacy plugins, use `$this->app->getInput()` (available via the parent class) — NOT `hikaInput::get()` or raw superglobals.
- Filter and validate all input at the point of retrieval. Never trust client-supplied values for security-sensitive decisions (e.g., payment status).

### Design Patterns
- Do NOT use the Repository design pattern in Joomla extensions. Use Joomla's native Model pattern (`ListModel`, `FormModel`, `AdminModel`, `BaseDatabaseModel`) for all data access.
- Models handle database queries, state management, and business logic — there is no need for a separate Repository layer.
- Services MUST NOT access the database directly. All data access flows through DataModel methods.

### Manifest XML Naming
- Component manifest files MUST be named `{name}.xml` (e.g. `forum.xml`, `community.xml`), **NOT** `com_{name}.xml`.
- The manifest lives inside the admin folder: `admin/com_{name}/{name}.xml`.
- This matches Joomla's convention where the manifest filename is the extension name without the `com_` prefix.

### Configuration Parameters
- Extension configuration parameters MUST be defined in a separate `config.xml` file, NOT embedded as `<config>` blocks inside the extension's manifest XML file (`{name}.xml`).
- The manifest XML is for extension metadata, installation instructions, namespace, and file declarations only.
- This applies to all extension types: components, modules, and plugins.

### Repository Folder Structure
- Components are stored in `Components/com_{name}/` with `admin/`, `api/`, `media/`, and `site/` as peer subdirectories.
- The `/api` folder is a subfolder of the component — NOT a top-level directory.
- The `/src` folder belongs inside each component layer (e.g., `admin/src/`), NOT at the repository root.
- The `/tmpl` folder is at the same level as `/src` within each layer — NOT a subdirectory of `/View`.
- Plugins are stored in `Plugins/{group}/{name}/`.
- Build configuration goes in the `Phing/` directory.
- See `includes/joomla-devel-environment.md` for the full repository structure reference.

### Version Synchronisation (V.R.M)
- The extension version follows **V.R.M** (Version.Release.Modification) format (e.g. `0.0.5`)
- **Reset rules when incrementing**:
  - Incrementing **V** (version) resets both **R** and **M** to `0` (e.g. `1.2.3` → `2.0.0`)
  - Incrementing **R** (release) resets **M** to `0` (e.g. `1.2.3` → `1.3.0`)
  - Incrementing **M** (modification) changes only **M** (e.g. `1.2.3` → `1.2.4`)
- **Three files MUST stay in sync**:
  1. **SQL update file**: `sql/updates/mysql/{V.R.M}.sql`
  2. **Manifest XML**: `<version>` element in `admin/com_{name}/{name}.xml`
  3. **Phing build file**: `version` property in `Phing/com_{name}.xml`
- **When a schema change is needed**, ASK the user whether to:
  - **Append** to the current (latest) SQL update file, OR
  - **Create a new** SQL update file with the next version number
- Only when a **new** SQL update file is created should the manifest and Phing versions be bumped to match
- Appending to the current file requires no version changes — this supports iterative development before deployment
- **When bumping the version**, also review the `<creationDate>` element in the manifest XML and update it to the current month and year (e.g. `<creationDate>March 2026</creationDate>`) if it does not reflect the current date

### Git Commit Message Convention — Conventional Commits
- All projects MUST use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) syntax
- Format: `<type>(<scope>): <description> [<version>]`
- **type** (required): `feat`, `fix`, `refactor`, `docs`, `chore`, `build`, `perf`, `test`, `style`, `ci`
- **scope** (required): extension name (e.g. `com_forum`, `plg_webservices_forum`) or `project` for cross-cutting changes
- **description** (required): imperative mood, lowercase, no trailing period
- **version** (when applicable): `[V.R.M]` appended to subject when the manifest version has changed
- The version number is read from the `<version>` element in the extension's manifest XML
- Examples:
  - `feat(com_forum): add hits column to boards, topics, and messages [0.1.1]`
  - `fix(com_forum): prevent null column errors with CheckDefaultsTrait`
  - `refactor(com_forum): delegate all database access to DataModels [0.1.0]`
  - `docs(com_community): update language files for space entity`
  - `build(plg_webservices_forum): update Phing build for new API routes [1.0.0]`
  - `chore(project): update shared documentation files`
- For commits touching multiple extensions, create separate commits per extension
- A `commit-msg` git hook SHOULD be used to enforce the format in each repository

### DatabaseQuery `bind()` — By-Reference Gotcha
- `DatabaseQuery::bind()` accepts its value parameter **by reference** (`&$value`)
- **Never reuse a loop variable** across multiple `bind()` calls — all bindings will point to the final value of the variable
- Store each value in a separate array element so each binding has a stable reference:
  ```php
  // WRONG — $value is overwritten each iteration, all binds point to last value
  foreach (['scope', 'affiliation'] as $field) {
      $value = $this->getState('filter.' . $field);
      if ($value !== '') {
          $query->where($db->quoteName($field) . ' = :' . $field)
              ->bind(':' . $field, $value);
      }
  }

  // CORRECT — each array element is a distinct reference
  $filterValues = [];
  foreach (['scope', 'affiliation'] as $field) {
      $filterValues[$field] = $this->getState('filter.' . $field);
      if ($filterValues[$field] !== null && $filterValues[$field] !== '') {
          $query->where($db->quoteName($field) . ' = :' . $field)
              ->bind(':' . $field, $filterValues[$field]);
      }
  }
  ```

### SQL Filter Fields — Exclude NULL Values
- SQL-type filter fields in form XML (`type="sql"`) that use `SELECT DISTINCT` can return `NULL` values from the database
- On PHP 8.1+, passing `NULL` to Joomla's `Select` helper triggers deprecation warnings in `trim()` and `explode()`
- Always add `WHERE column IS NOT NULL AND column != ''` and `ORDER BY column` to filter field queries:
  ```xml
  <field name="scope" type="sql"
         query="SELECT DISTINCT scope AS value, scope AS scope FROM #__example_items WHERE scope IS NOT NULL AND scope != '' ORDER BY scope"
         label="FILTER_SCOPE" onchange="this.form.submit();">
      <option value="">FILTER_SCOPE</option>
  </field>
  ```

### Do Not Remove `$query->dump()`
- `DatabaseQuery::dump()` is marked deprecated since Joomla 3 but **must not be removed** from existing code
- It is actively used for debugging SQL statements during development
- Agents and code reviewers must leave existing `dump()` calls in place

### Database Schema
- MySQL8+ and MariaDB 10+ support
- Changes to the database schema to be updated in /sql/updates/mysql/ with version numbers
- Use `DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci` for all tables
- Use `ENGINE=InnoDB` for all tables

#### Standard Joomla System Fields for Core/CRUD Tables

Main entity tables where users create, edit, and manage records through CRUD interfaces MUST include these standard Joomla system fields:

```sql
-- Publication & workflow
state TINYINT(1) NOT NULL DEFAULT 0,           -- 1=published, 0=unpublished, 2=archived, -2=trashed
ordering INT NOT NULL DEFAULT 0,                -- Display order within lists
access INT UNSIGNED NOT NULL DEFAULT 1,         -- Joomla access level (1=Public, 2=Registered, etc.)

-- Ownership & audit trail
created DATETIME NOT NULL,                      -- Record creation timestamp
created_by INT UNSIGNED NOT NULL DEFAULT 0,     -- Joomla user ID of creator
modified DATETIME,                              -- Last modification timestamp
modified_by INT UNSIGNED NOT NULL DEFAULT 0,    -- Joomla user ID of last modifier

-- Edit locking
checked_out INT UNSIGNED,                       -- User ID who has record checked out for editing
checked_out_time DATETIME,                      -- When the checkout occurred

-- Optional but common on content-like entities
asset_id INT UNSIGNED NOT NULL DEFAULT 0,       -- Joomla ACL asset reference (for per-item permissions)
alias VARCHAR(400) NOT NULL DEFAULT '',         -- URL-safe slug (for SEF routing)
publish_up DATETIME,                            -- Scheduled publish start
publish_down DATETIME,                          -- Scheduled publish end
language CHAR(7) NOT NULL DEFAULT '*',          -- Language code ('*' = all languages)
note VARCHAR(255) NOT NULL DEFAULT '',          -- Admin-only notes
```

**Required indexes for system fields:**
```sql
KEY idx_state (state),
KEY idx_created_by (created_by),
KEY idx_access (access),
KEY idx_checked_out (checked_out),
KEY idx_language (language)
```

#### When to Include System Fields

| Table Type | System Fields Required | Examples |
|---|---|---|
| **Core entity tables** (user-managed CRUD) | Full set: state, ordering, access, created, created_by, modified, modified_by, checked_out, checked_out_time | Items, Categories, Customers, Orders, Invoices |
| **Secondary entity tables** (admin-managed) | Minimum: state, created, created_by, modified, modified_by | Addresses, Contacts, Tax Rates, Pricing Rules |
| **Link/join tables** (cross-references) | NOT required — keep minimal | item_tag_map, category_item, user_role |
| **System/log tables** (auto-generated) | Only created (timestamp) | Audit logs, Stock movements, Payment transactions |

#### Reference: Complete Core Table Template
```sql
CREATE TABLE IF NOT EXISTS `#__example_items` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `asset_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `title` VARCHAR(255) NOT NULL DEFAULT '',
    `alias` VARCHAR(400) NOT NULL DEFAULT '',
    -- ... entity-specific fields here ...
    `state` TINYINT(1) NOT NULL DEFAULT 0,
    `ordering` INT NOT NULL DEFAULT 0,
    `access` INT UNSIGNED NOT NULL DEFAULT 1,
    `created` DATETIME NOT NULL,
    `created_by` INT UNSIGNED NOT NULL DEFAULT 0,
    `modified` DATETIME,
    `modified_by` INT UNSIGNED NOT NULL DEFAULT 0,
    `checked_out` INT UNSIGNED,
    `checked_out_time` DATETIME,
    `publish_up` DATETIME,
    `publish_down` DATETIME,
    `language` CHAR(7) NOT NULL DEFAULT '*',
    `note` VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (`id`),
    KEY `idx_state` (`state`),
    KEY `idx_created_by` (`created_by`),
    KEY `idx_access` (`access`),
    KEY `idx_checked_out` (`checked_out`),
    KEY `idx_language` (`language`),
    KEY `idx_alias` (`alias`(191))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```


#### Hierarchical/Nested Tables (Parent-Child Relationships)

Tables with a `parent_id` column (adjacency list pattern) MUST also include **nested set columns** to enable efficient tree ordering and depth display in admin list views:

```sql
-- Required nested set fields (add after entity-specific fields, before Joomla system fields)
`level` INT UNSIGNED NOT NULL DEFAULT 0,    -- Depth in tree (0=root, 1=child, 2=grandchild)
`lft` INT NOT NULL DEFAULT 0,               -- Left boundary of nested set range
`rgt` INT NOT NULL DEFAULT 0,               -- Right boundary of nested set range
```

**Required index:**
```sql
KEY `idx_lft` (`lft`)
```

**Implementation requirements:**
- A `rebuildNestedSet()` method in the entity's **Service class** walks the adjacency list (`parent_id`) and computes `lft`, `rgt`, and `level` for every row
- The entity's **AdminModel** (`save()`) must call `rebuildNestedSet()` after every save so tree values stay current
- The entity's **ListModel** must default to `ORDER BY a.lft ASC` (set in both `populateState()` and the `getListQuery()` fallback)
- The entity's **ListModel** must include `level`, `lft` in both the SELECT column list and the `filter_fields` array
- The **list view template** renders indentation with: `<?php echo str_repeat('<span class="gi">&mdash;</span>', (int) $item->level); ?>`
- The **edit form** parent field must use `type="sql"` (not `type="list"`) to dynamically populate from the database

### Popups and Modals
- **Always use Joomla's `<joomla-dialog>` web component** — never use Bootstrap modals directly
- Reference: https://manual.joomla.org/docs/4.4/general-concepts/javascript/js-library/joomla-dialog/
- Load via Web Asset Manager: `$wa->useScript('joomla.dialog-autocreate');`
- Trigger with the `data-joomla-dialog` attribute on buttons/links:
  ```html
  <button type="button"
          data-joomla-dialog='{"popupType": "inline", "src": "#myTemplateId", "textHeader": "Dialog Title", "width": "500px", "height": "fit-content"}'>
      Open Dialog
  </button>
  ```
- Place dialog content in a `<template id="myTemplateId">` element — the web component clones it into the dialog body when opened
- Supports four popup types: `inline`, `iframe`, `image`, `ajax`
- For toolbar popups, use `$toolbar->popupButton()` with `->popupType('inline')` pointing to a `<template>` element
- Bootstrap modals (`data-bs-toggle="modal"`, `bootstrap.modal` script) are **deprecated** in Joomla 5 and must not be used

### View HtmlView Preferences
- Use the direct model call pattern, not deprecated `$this->get()` magic method
- **Edit/Form views MUST load the form validator** via Web Asset Manager: `$this->document->getWebAssetManager()->useScript('form.validate');`
- Place the `useScript` call in `display()` after `addToolbar()` and before `parent::display($tpl)`
- Without this, the `form-validate` CSS class on the `<form>` element causes a JS error: `document.formvalidator is undefined`

### Filter Form XML Preferences
- **Do NOT include a `fullordering` field** in filter XML files — users sort via clickable column headings (`HTMLHelper::_('searchtools.sort', ...)`)
- The `<fields name="list">` section should only contain the `limit` (limitbox) field
- Filter dropdowns go in `<fields name="filter">`

### Model Error Surfacing
- All ListModel and AdminModel subclasses MUST use the `DebugErrorAwareTrait`
- The trait overrides `setError()` to enqueue errors as warnings when `JDEBUG` is active
- The trait file exists in each component's `Model` namespace (same namespace, no import needed)
- Add `use DebugErrorAwareTrait;` as the first statement inside the class body
- BaseDatabaseModel subclasses (DataModels, DashboardModel) do NOT need the trait

### DataModel Pattern
- DataModels extend `BaseDatabaseModel`, named `{Entity}DataModel.php`
- DataModels are the **sole database access layer** for Service classes
- Service classes MUST NOT access the database directly — all data via DataModels
- DataModels use Table classes internally for CUD operations (bind/check/store/delete)
- Documented exceptions for bulk/atomic operations stay as direct SQL in DataModels
- DataModels are registered in `services/provider.php` via `MVCFactoryInterface::createModel()`