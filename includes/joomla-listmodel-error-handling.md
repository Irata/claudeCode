## ListModel Swallows Query Failures — Surface Them in the View

### Purpose

`ListModel` catches a failed list query, stores the message where nothing reads it, and
returns `false`. The list renders empty. No error is enqueued, no exception escapes, and
the log stays clean. A schema fault therefore presents as *"No matching results"* — the
same thing an over-tight filter produces — and gets diagnosed as a data problem for as long
as it takes someone to run the query by hand.

This is core behaviour, not a component bug. Every list view has to defend against it.

### The mechanism

Two methods swallow, independently:

```php
// libraries/src/MVC/Model/ListModel.php
public function getItems()                              // ~271
{
    try {
        $this->cache[$store] = $this->_getList($this->_getListQuery(), $this->getStart(), ...);
    } catch (\RuntimeException $e) {
        $this->setError($e->getMessage());              // 285 — goes nowhere on its own
        return false;                                   // <- view assigns false to $this->items
    }
    ...
}

public function getTotal()                              // ~360
{
    try {
        $this->cache[$store] = (int) $this->_getListCount($this->_getListQuery());
    } catch (\RuntimeException $e) {
        $this->setError($e->getMessage());              // 375
        return false;
    }
    ...
}
```

`setError()` appends to `$_errors` (`LegacyErrorHandlingTrait`) and does nothing else. Unless
the view asks for it, the message is discarded when the request ends.

### The fingerprint — empty rows beside a working pagination count

The tell that separates this from a genuinely empty result set:

> **The table shows nothing while the pagination footer reports a real, non-zero total.**

That split is possible because the two numbers come from two *different* queries.
`BaseDatabaseModel::_getListCount()` (line ~181) does not run the list query — it clones it
and strips it back:

```php
$query = clone $query;
$query->clear('select')->clear('order')->clear('limit')->clear('offset')->select('COUNT(*)');
```

So the count query can succeed on a query the list version cannot. Anything the count clears
is invisible to it:

| Cleared by the count | A fault here breaks rows but not the total |
|---|---|
| `select` | A column that does not exist, or is misspelled, or was added by an update file the site never ran |
| `order` | An `ORDER BY` on a column that is not in the table |
| `limit` / `offset` | — |

Anything the count *keeps* — `FROM`, every `WHERE`, the bound parameters — fails both, and the
pagination reads zero. **A zero total means the fault is in the FROM/WHERE half; a non-zero
total means it is in the SELECT or ORDER BY half.** That is a free bisection before you read
any code.

> Caveat: the stripping shortcut is conditional. `_getListCount()` takes the fast path only
> when the query has no `GROUP BY`, `HAVING`, `UNION` or query set. A grouped query falls
> through to the slow path, which keeps the SELECT list, so both queries fail and the split
> symptom does not appear.

### The rule

> **Every list view's `display()` MUST read the model's errors and throw before it touches
> `$this->items`.**

```php
use Joomla\CMS\MVC\View\GenericDataException;

$this->items         = $model->getItems();
$this->pagination    = $model->getPagination();
$this->state         = $model->getState();
$this->filterForm    = $model->getFilterForm();
$this->activeFilters = $model->getActiveFilters();

$errors = $model->getErrors();

if (\count($errors)) {
    throw new GenericDataException(implode("\n", $errors), 500);
}

$this->addToolbar();
```

This is the idiom core list views use, and the one edit/form views in these projects already
use. Three points that are easy to get wrong:

- **Placement is not cosmetic.** It must come before `addToolbar()` and before anything else
  that walks `$this->items`. On failure that property is boolean `false`, and `(array) false`
  is `[false]` — a toolbar loop reading `$item->state` off it raises *"Attempt to read
  property on bool"*, burying the real message under a second, misleading one.
- **Collect after every model call, not after `getItems()` alone.** `getTotal()` fails
  separately, and a filter or ordering fault can break the count while the rows survive.
- **`getErrors()` is deprecated (removal in 7.0) and is still the only retrieval path**,
  because `ListModel` itself still calls `setError()`. When core stops swallowing, this check
  becomes dead code and can go. Until then it is required, and `setUseExceptions(true)`
  (Joomla 5.4+) is not a portable substitute on a 5.2 baseline.

### This does not replace `DebugErrorAwareTrait`

`DebugErrorAwareTrait` enqueues `setError()` messages as warnings **when `JDEBUG` is
active**. That covers a developer's own session and nothing else — on a production site with
debug off, the message is still discarded. The two are complementary:

| | Debug session | Debug off |
|---|---|---|
| `DebugErrorAwareTrait` | warning in the message queue | nothing |
| `getErrors()` check in the view | error page with the driver message | error page with the driver message |

Use both. Neither is sufficient alone.

### Verifying the guard

A throwaway `ListModel` proves the behaviour without touching a schema — worth running once
against a real database so the fingerprint is recognisable later:

```php
class ProbeModel extends \Joomla\CMS\MVC\Model\ListModel {
    public $badColumn = true;
    protected function getListQuery() {
        $db = $this->getDatabase();
        return $db->getQuery(true)
            ->from($db->quoteName('#__example'))
            ->select($db->quoteName($this->badColumn ? 'no_such_column' : 'id'));
    }
    protected function populateState($o = null, $d = null) {
        $this->setState('list.limit', 20);
        $this->setState('list.start', 0);
    }
}
```

```
BAD  column: getItems()=false  getTotal()=271  getErrors()=1
             Unknown column 'no_such_column' in 'SELECT'
GOOD column: getItems()=20     getTotal()=271  getErrors()=0
```

### Checklist

- [ ] `use Joomla\CMS\MVC\View\GenericDataException;` imported in the list view
- [ ] `getErrors()` checked in `display()` after the model calls, before `addToolbar()`
- [ ] Model uses `DebugErrorAwareTrait` as well (see *Model Error Surfacing*)
- [ ] Nothing between the model calls and the check dereferences `$this->items`
- [ ] When a list reports rows-empty-but-count-populated, suspect the SELECT/ORDER BY half
      of the query — and check the table actually has every column the model selects

### Related

- `includes/joomla-coding-preferences.md` — *Model Error Surfacing*, and the `#__schemas` /
  Database Checker sections: a site whose update files never ran is the most common way a
  model ends up selecting a column that is not there
