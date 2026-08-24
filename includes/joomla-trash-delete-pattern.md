## Trash, Delete and Empty Trash — List View Toolbar Pattern

### Purpose

Joomla deletes records in **two steps**: a record is trashed (`state = -2`), then purged
from the Trashed filter. A list view that offers **Delete** without first offering
**Trash** ships a button that can never succeed. Pressing it returns Joomla's core string
`JLIB_APPLICATION_ERROR_DELETE_NOT_PERMITTED` — *"Delete not permitted."* — which reads as
an ACL failure and is not one. Administrators reasonably conclude their permissions are
broken and go hunting through the ACL matrix.

This was a real defect in `com_mapper` up to 2.5.1: the toolbar offered `publish`,
`unpublish`, `checkin` and `delete`, and no `trash` button existed anywhere in the
component. Nothing could reach `state = -2` from the list, so Delete was permanently
inoperative there. A Super User hit "Delete not permitted" on every record.

### The mechanism you are working with

`AdminModel::delete()` calls `canDelete($record)` once per record and skips any record that
returns false, enqueueing the core message. Components override `canDelete()` to enforce
the trashed-first rule:

```php
protected function canDelete($record): bool
{
    if (empty($record->id) || $record->state != -2) {
        return false;                     // <- short-circuits BEFORE any ACL check
    }

    return parent::canDelete($record);    // <- core.delete on the component
}
```

Two consequences that drive everything below:

1. **The state gate runs before the ACL gate.** No permission level, Super User included,
   can delete a record that is not trashed. Never diagnose this as an ACL problem.
2. **`AdminModel::canDelete()` checks only `core.delete` on the component.** Whatever the
   toolbar shows or hides, that is the real gate unless you override it.

### The rule

| View state | Buttons |
|---|---|
| Showing records that are not trashed | **Trash** |
| Showing trashed records | **Empty Trash** (a `delete` button relabelled) |

```php
$toolbar->trash('{entities}.trash')->listCheck(true);

$toolbar->delete('{entities}.delete', 'JTOOLBAR_EMPTY_TRASH')
    ->message('JGLOBAL_CONFIRM_DELETE')
    ->listCheck(true);
```

**No controller work is required for the trash task.** `AdminController::__construct()`
already does `registerTask('trash', 'publish')`, and `publish()` maps
`['publish' => 1, 'unpublish' => 0, 'archive' => 2, 'trash' => -2]`. Adding the button is
the whole change.

`JTOOLBAR_TRASH`, `JTOOLBAR_EMPTY_TRASH` and `JGLOBAL_CONFIRM_DELETE` are all core strings —
do not add component copies.

### Decide which variant you need — this is the step that gets skipped

**How the Empty Trash button is gated depends on whether your list hides trashed records
by default.** Copying core's condition into a list that behaves differently reintroduces
the bug in a subtler form: the button is simply never there when it is wanted.

#### Variant A — the list hides trashed records unless asked (core behaviour)

Standard for core components. The Status filter is the only way to see a trashed record, so
the filter alone is a sound gate and the two buttons swap:

```php
$trashed = (string) $this->state->get('filter.published') === '-2';

if (!$trashed) {
    $toolbar->trash('{entities}.trash')->listCheck(true);
} elseif ($user->authorise('core.admin', 'com_{name}')) {
    $toolbar->delete('{entities}.delete', 'JTOOLBAR_EMPTY_TRASH')
        ->message('JGLOBAL_CONFIRM_DELETE')
        ->listCheck(true);
}
```

#### Variant B — the list shows every state by default

Common in internally-built admin components whose list model applies a `state` WHERE only
when the filter holds a number:

```php
// Typical: an empty filter means no WHERE at all, so trashed rows stay visible.
if ($published !== '*' && is_numeric($published)) {
    $query->where($db->quoteName('state') . ' = :state')->bind(':state', (int) $published);
}
```

Here a filter-only gate fails the obvious case: the administrator trashes a record, the row
stays on screen with a trash icon, and the button that would purge it is nowhere. Gate on
the filter **or** the presence of a trashed row in the current page:

```php
$filterTrashed  = (string) $this->state->get('filter.published') === '-2';
$pageHasTrashed = false;

foreach ((array) $this->items as $item) {
    if ((string) ($item->state ?? '') === '-2') {
        $pageHasTrashed = true;
        break;
    }
}

if (!$filterTrashed) {
    $toolbar->trash('{entities}.trash')->listCheck(true);
}

if (($filterTrashed || $pageHasTrashed) && $user->authorise('core.admin', 'com_{name}')) {
    $toolbar->delete('{entities}.delete', 'JTOOLBAR_EMPTY_TRASH')
        ->message('JGLOBAL_CONFIRM_DELETE')
        ->listCheck(true);
}
```

Requirements for the row scan:

- `display()` must assign `$this->items` **before** calling `addToolbar()`. It normally
  does; confirm rather than assume.
- The list query must select the `state` column. Many hand-written `getListQuery()`
  implementations select an explicit column list and omit it.
- Compare as a string. `state` arrives from the database as `'-2'`, and from the filter bar
  as request input, so `(string)` on both sides avoids a type-juggling surprise.
- **The scan sees the current page only.** That is sufficient for the case it serves — a
  record just trashed and still on screen. Anything beyond it is what the Status filter is
  for. Say so in a comment rather than letting the next reader assume it is exhaustive.

### Restricting Empty Trash to a higher permission

Purging is irreversible, so gating it above `core.delete` is often right —
`core.admin` is `JACTION_ADMIN`, *"Configure ACL & Options"*. Users without it keep read
access to the Trashed filter, so records stay visible and restorable; they simply cannot be
purged.

**Hiding the button is not the enforcement.** `AdminModel::delete()` is reachable by any
POST naming the task, so the check must live at the record level where every path passes
through it:

```php
protected function canDelete($record): bool
{
    if (empty($record->id) || $record->state != -2) {
        return false;
    }

    // Irreversible, so gated above the core.delete that AdminModel would settle for.
    // The toolbar hides Empty Trash to match; this is what makes it real.
    if (!$this->getCurrentUser()->authorise('core.admin', 'com_{name}')) {
        return false;
    }

    return parent::canDelete($record);
}
```

Add the matching action to `access.xml` if it is not already present:

```xml
<action name="core.admin" title="JACTION_ADMIN" description="JACTION_ADMIN_COMPONENT_DESC" />
```

`getCurrentUser()` is available on models via `BaseDatabaseModel`'s `CurrentUserTrait`, and
on views via `HtmlView`'s.

### Verifying it

`canDelete()` is protected, so exercise it by reflection against a real record rather than
reasoning about it. All three cases matter:

| Identity | Record state | Expected |
|---|---|---|
| Privileged user | not trashed | `false` — trashed-first rule |
| Privileged user | trashed `-2` | `true` |
| User without the gating permission | trashed `-2` | `false` |

A CLI harness must `loadIdentity()` a real user — with no identity the current user is a
guest and every case returns false, which looks like a broken gate.

Booting a component from a CLI script may need the namespace registered by hand, since the
console application does not always populate the extension namespace map:

```php
\JLoader::registerNamespace('{Vendor}\\Component\\{Name}\\Administrator',
    JPATH_ADMINISTRATOR . '/components/com_{name}/src');
```

Finish in the browser. Toolbar rendering and the filter bar are not exercised by a CLI
harness — see `joomla-devel-environment.md` on verifying admin views over HTTP.

### Checklist

- [ ] A `trash` button exists. Without one, `Delete` is unreachable and the component is broken.
- [ ] `Delete` is labelled `JTOOLBAR_EMPTY_TRASH` and appears only where trashed records are visible.
- [ ] The gate matches the list's default behaviour — Variant A or Variant B, chosen deliberately.
- [ ] The list query selects `state` if Variant B's row scan is used.
- [ ] Any permission above `core.delete` is enforced in `canDelete()`, not only in the toolbar.
- [ ] `access.xml` declares the action being checked.
- [ ] No component-local copies of `JTOOLBAR_TRASH`, `JTOOLBAR_EMPTY_TRASH` or `JGLOBAL_CONFIRM_DELETE`.
- [ ] Verified in the browser, not only by reading the code.

### Reference implementation

`com_mapper` 2.5.2 (Mapper2 project) — `admin/com_mapper/src/View/Maps/HtmlView.php`
(Variant B) and `admin/com_mapper/src/Model/MapModel.php` (`core.admin` enforcement).

### Related

- `joomla-coding-preferences.md` → **Standard Toolbar Buttons**
- `joomla-depreciated.md` → list view `addToolbar()` before/after example
- `joomla-authorisation-service-pattern.md` — for components centralising ACL decisions
