## Joomla Chunked Data Import / Migration Pattern

A reusable, battle-tested pattern for importing or migrating large external datasets into a
Joomla component's tables without hitting PHP/web-server timeouts, runnable identically from
the **admin UI (AJAX)**, the **Web Services API**, and the **CLI console**.

**Canonical reference implementation:** the `com_forum` migration feature in the SANE project
(`apps/joomla/extensions/admin/com_forum`), which imports boards, topics, messages, users,
kudos/supports and attachments from a legacy Khoros forum. Use it as the worked example when
building any similar bulk-import / data-migration capability.

This pattern is built from four independent, individually reusable techniques. Adopt them
together for a full importer, or cherry-pick whichever you need.

---

### Technique 1 — Migration options in `config.xml` (local/remote source switch + chunk size)

Store all import configuration in the component's `config.xml` under a dedicated `migration`
fieldset (its own tab). The key idea is a **source switch** that lets an operator toggle the
import between the **local** Joomla database and a **remote** database, with the remote
connection fields revealed conditionally via `showon`. The **chunk size** used by the AJAX/CLI
loop is also a config value, so it can be tuned per-environment without code changes.

```xml
<fieldset name="migration"
    label="COM_FORUM_CONFIG_MIGRATION_LABEL"
    description="COM_FORUM_CONFIG_MIGRATION_DESC"
>
    <!-- The source switch: local (default) vs remote -->
    <field name="migration_source" type="radio"
        label="COM_FORUM_CONFIG_MIGRATION_SOURCE"
        default="local"
        class="btn-group btn-group-yesno"
        layout="joomla.form.field.radio.switcher">
        <option value="local">COM_FORUM_CONFIG_MIGRATION_LOCAL</option>
        <option value="remote">COM_FORUM_CONFIG_MIGRATION_REMOTE</option>
    </field>

    <!-- Remote connection details — only shown when source = remote -->
    <field name="migration_host"     type="text"     showon="migration_source:remote" .../>
    <field name="migration_port"     type="text"     default="3306" showon="migration_source:remote" .../>
    <field name="migration_user"     type="text"     showon="migration_source:remote" .../>
    <field name="migration_password" type="password" showon="migration_source:remote" .../>
    <field name="migration_database" type="text"     showon="migration_source:remote" .../>
    <field name="migration_ssl"      type="radio"    default="0" showon="migration_source:remote"
        class="btn-group btn-group-yesno" layout="joomla.form.field.radio.switcher">
        <option value="0">JNO</option>
        <option value="1">JYES</option>
    </field>

    <!-- Import tuning -->
    <field name="migration_chunk_size" type="number"
        label="COM_FORUM_CONFIG_MIGRATION_CHUNK_SIZE"
        default="500" min="50" max="5000" />

    <!-- Domain-specific options (example: which user group migrated users join) -->
    <field name="migration_user_group" type="usergrouplist" default="2"
        layout="joomla.form.field.list-fancy-select" />
</fieldset>
```

**Reading the switch — lazy, cached source-DB resolver.** The service resolves the source
`DatabaseInterface` once. For `local` it returns Joomla's own driver; for `remote` it builds a
separate `mysqli` `DatabaseDriver` from the config. This keeps the *entire* importer source-agnostic
— every chunk method just calls `getSourceDb()`.

```php
private function getSourceDb(): DatabaseInterface
{
    if ($this->sourceDb !== null) {
        return $this->sourceDb;            // resolved once per service instance
    }

    $params = ComponentHelper::getParams('com_forum');

    if ($params->get('migration_source', 'local') === 'local') {
        return $this->sourceDb = $this->db;   // Joomla's own connection
    }

    $options = [
        'driver'   => 'mysqli',
        'host'     => $params->get('migration_host', ''),
        'port'     => (int) $params->get('migration_port', 3306),
        'user'     => $params->get('migration_user', ''),
        'password' => $params->get('migration_password', ''),
        'database' => $params->get('migration_database', ''),
        'prefix'   => '',
    ];

    if ((int) $params->get('migration_ssl', 0) === 1) {
        $options['ssl'] = ['enable' => true];
    }

    return $this->sourceDb = DatabaseDriver::getInstance($options);
}
```

**Rules**
- Migration settings live in `config.xml` (NOT the manifest) — see the Configuration Parameters
  rule in `joomla-coding-preferences.md`.
- The same `migration_chunk_size` param feeds **both** the JS batch size and the controller's
  default `limit`, so the front end and server agree by default.
- Expose the chunk size to JavaScript with `Document::addScriptOptions('com_forum.migration_chunk_size', ...)`
  so the browser reads it via `Joomla.getOptions(...)`.

---

### Technique 2 — AJAX + chunking to defeat timeouts (one engine, two drivers)

Long imports die on `max_execution_time`. The fix: process the source set in **bounded chunks**
addressed by `offset` / `limit`, and drive the loop from outside a single PHP request. The same
service method is driven two ways:

1. **Browser (admin):** JavaScript runs a `count → loop(chunk) → rebuild` sequence, one AJAX
   request per chunk, updating a progress bar. Each request is a fresh PHP execution, so no
   single request ever approaches the timeout.
2. **CLI console:** a `while ($offset < $total)` loop calls the identical service method with a
   Symfony `ProgressBar`.

**JavaScript driver (admin)** — `media/com_forum/js/migration-import.js`:

```js
const BATCH_SIZE = Joomla.getOptions('com_forum.migration_chunk_size', 500);

// Step 1: how many source rows?
const { total } = await request(buildUrl(config.countTask));

// Step 2: walk the set one chunk per request
let offset = 0;
while (offset < total) {
    const chunkData = await request(buildUrl(config.chunkTask), 'POST', {
        offset: offset.toString(),
        limit:  BATCH_SIZE.toString(),
    });
    totalImported += chunkData.imported;
    totalSkipped  += chunkData.skipped;
    totalErrors   += chunkData.errors;

    const percent = Math.round((Math.min(offset + BATCH_SIZE, total) / total) * 100);
    updateProgress(barEl, percent, `${percent}%`);
    offset += BATCH_SIZE;
}

// Step 3: rebuild derived data (counts, nested-set trees, statistics) once at the end
await request(buildUrl(config.rebuildTask), 'POST');
```

**CLI driver** — identical loop, same service method:

```php
$total  = $this->migrationService->countSourceMessages();
$offset = 0;

while ($offset < $total) {
    $result = $this->migrationService->importMessageChunk($userId, $offset, $batchSize, true);
    $totalImported += $result->imported;
    $totalSkipped  += $result->skipped;
    $totalErrors   += $result->errors;
    $progressBar->advance(min($batchSize, $total - $offset));
    $offset += $batchSize;
}
```

**Inside one chunk** (`importMessageChunk(int $userId, int $offset, int $limit): MigrationResult`):
- Call `@set_time_limit(0)` at the top — belt-and-braces; the chunk boundary is the real safety net.
- Fetch exactly this chunk from the source: `$sourceDb->setQuery($query, $offset, $limit)`.
- Wrap the chunk in a transaction and **commit periodically** (e.g. every 50–100 rows) to bound
  memory and lock duration.
- Make the chunk **idempotent**: pre-load which source IDs already exist and skip them, so a
  re-run (or a retried chunk after a browser refresh) never double-inserts. Track an ID map
  (`#__{name}_migration_id_map`: `source_type`, `source_id`, `target_table`, `target_id`) so
  later passes can resolve foreign keys.
- Batch-preload lookups for the whole chunk (e.g. user-ID maps) — 2 queries per chunk, not 2×N.
- Catch `\Throwable` **per row**: increment an error counter, log via a durable error-log
  service, and continue — one bad row must not abort the chunk.
- Return a small **result value object** with the counts (see `MigrationResult` below). Never
  return rendered HTML or echo from the service.
- Defer expensive derived-data work (nested-set tree rebuild, aggregate counters) to a final
  `rebuild` step run once after all chunks — don't recompute per row.

> **Note any deliberate caps.** If a chunk silently truncates, samples, or skips, surface it in
> the returned `messages[]` — a silent cap reads as "imported everything" when it didn't.

---

### Technique 3 — One Service funnels admin + API + CLI into a single DataModel

All three entry points are thin adapters. They authenticate/authorise, read `offset`/`limit`,
call **one** service method, and format the return. The service owns the logic and delegates all
DB access to purpose-built **DataModels** (`BaseDatabaseModel` subclasses). This is the
service-layer convention: *Service → ServiceModel(s) → Table*.

```
   Admin AJAX Controller ┐
   API Controller        ├─→  MigrationService  ─→  XxxDataModel(s)  ─→  Xxx Table(s)
   Console Command        ┘     (all logic)          (all DB access)      (validate + write)
```

**The service** declares its dependencies via constructor promotion and is registered in DI:

```php
class MigrationService
{
    public function __construct(
        private readonly DatabaseInterface     $db,
        private readonly ErrorLogService       $errorLogService,
        private readonly MessageDataModel       $messageDataModel,
        private readonly MigrationMapDataModel  $migrationMapDataModel,
        // ...one DataModel per target entity
    ) {}

    public function importMessageChunk(int $userId, int $offset, int $limit): MigrationResult { /* ... */ }
    public function countSourceMessages(): int { /* ... */ }
}
```

**DI registration** — `services/provider.php`. DataModels are built via the MVC factory with
`ignore_request => true` (they are service collaborators, not request-bound MVC models):

```php
$container->set(
    MessageDataModel::class,
    fn(Container $c) => $c->get(MVCFactoryInterface::class)
        ->createModel('MessageData', 'Administrator', ['ignore_request' => true])
);

$container->set(
    MigrationService::class,
    fn(Container $c) => new MigrationService(
        $c->get(DatabaseInterface::class),
        $c->get(ErrorLogService::class),
        $c->get(MessageDataModel::class),
        $c->get(MigrationMapDataModel::class),
        // ...
    )
);

// CLI commands receive the SAME service
$container->set(
    MigrationCommand::class,
    fn(Container $c) => new MigrationCommand($c->get(MigrationService::class))
);
```

**Admin controller** (AJAX, returns JSON). Resolve the service from the booted component
container — never `new` it:

```php
public function chunk(): void
{
    if (!$this->checkAdminAccess() || !Session::checkToken()) {
        echo new JsonResponse(null, 'Invalid token', true);
        return;
    }

    $chunkSize = (int) ComponentHelper::getParams('com_forum')->get('migration_chunk_size', 500);
    $offset    = $this->input->getInt('offset', 0);
    $limit     = $this->input->getInt('limit', $chunkSize);
    $userId    = Factory::getApplication()->getIdentity()->id;

    try {
        $result = $this->getMigrationService()->importMessageChunk($userId, $offset, $limit, true);
        echo new JsonResponse([
            'imported' => $result->imported,
            'skipped'  => $result->skipped,
            'errors'   => $result->errors,
            'messages' => $result->messages,
        ]);
    } catch (\Throwable $e) {
        echo new JsonResponse(null, $e->getMessage(), true);
    }
}

private function getMigrationService(): MigrationService
{
    return Factory::getApplication()
        ->bootComponent('com_forum')
        ->getContainer()
        ->get(MigrationService::class);
}
```

**Console command** — same service, injected via DI (see Technique 2 for the loop). The API
controller follows the identical adapter shape, returning a JSON:API document instead of a raw
`JsonResponse`.

**Return value object** — keep the service framework-agnostic by returning a readonly DTO each
driver formats for its own channel:

```php
final readonly class MigrationResult
{
    public function __construct(
        public int   $imported = 0,
        public int   $skipped  = 0,
        public int   $errors   = 0,
        public array $messages = [],
    ) {}

    public function isSuccess(): bool { return $this->errors === 0; }
}
```

---

### Technique 4 — Validate through the Table, write with direct SQL (controlled exception)

The standard rule is **all writes go through `Table::store()`** (see `joomla-coding-preferences.md`).
Bulk import has two cases where that single rule needs a deliberate, *documented* exception — but
**validation always still flows through the Table** so no malformed row ever reaches the database.

#### 4a. Explicit primary key on a *new* record (preserve source IDs)

Migrations usually need to keep the source system's IDs as the new primary keys (so cross-table
references resolve). Joomla's `Table::store()` decides INSERT vs UPDATE from `hasPrimaryKey()`:
if a PK is set it assumes UPDATE — which silently affects **0 rows** for a brand-new record with
a pre-assigned ID. The fix is to **override `store()`** in the Table subclass: it still runs the
full `bind()` + `check()` validation pipeline, but when an explicit PK is present and no such row
exists yet, it writes via `$db->insertObject()` directly instead of letting `parent::store()`
mis-route to UPDATE.

```php
// In the Table subclass (e.g. MessageTable / TopicTable)
#[\Override]
public function store($updateNulls = true): bool
{
    // bind() + check() have already validated & defaulted every column at this point.

    // Explicit PK on a new row (migration with source ID as PK):
    // parent::store() would try UPDATE and affect 0 rows. Detect and INSERT instead.
    if ($this->hasPrimaryKey()) {
        $pk = (int) $this->{$this->getKeyName()};

        if ($pk > 0) {
            $db     = $this->getDbo();
            $exists = $db->setQuery(
                $db->getQuery(true)
                    ->select('1')
                    ->from($db->quoteName($this->getTableName()))
                    ->where($db->quoteName($this->getKeyName()) . ' = ' . $pk)
            )->loadResult();

            if (!$exists) {
                return $db->insertObject($this->getTableName(), $this, $this->getKeyName());
            }
        }
    }

    return parent::store($updateNulls);   // normal path for everything else
}
```

The DataModel still drives the **validate-first** sequence — `bind()` to load+coerce, `check()`
to validate/default/normalise — and only then calls `store()`. The override above keeps that
guarantee while controlling the actual INSERT:

```php
public function createMessage(array $data): object
{
    $table = $this->getTable();

    if (!$table->bind($data))  { throw new \RuntimeException($table->getError()); }
    if (!$table->check())      { throw new \RuntimeException($table->getError()); } // structure + validate
    if (!$table->store())      { throw new \RuntimeException($table->getError()); } // store() routes the write

    return $this->getMessage((int) $table->id);
}
```

**Why this is the "handy technique":** the record is guaranteed structurally valid by the Table's
own `check()` (required fields, aliases, NOT-NULL defaults, timestamps, nested-set positioning),
yet the write is performed by an explicit SQL `insertObject()`/`updateObject()` — bypassing
`store()`'s INSERT-vs-UPDATE heuristic that breaks on pre-assigned primary keys.

#### 4b. Bulk / atomic writes that cannot be expressed row-by-row

Set-based operations during import and the post-import rebuild — moving every message in a topic,
atomic counter increments, aggregate recomputes, FK realignment with a JOIN — are written as raw
query-builder `->update()` statements in the DataModel. These do **not** round-trip through a
Table (there is no single row to validate), so mark each one with a `Direct SQL exception:`
comment stating *why*.

```php
/**
 * Increments the support count atomically.
 *
 * Direct SQL exception: an atomic increment cannot be expressed via Table::store().
 */
public function incrementTopicSupportCount(int $topicId): void
{
    $db    = $this->getDatabase();
    $query = $db->getQuery(true)
        ->update($db->quoteName('#__forum_topics'))
        ->set($db->quoteName('support_count') . ' = ' . $db->quoteName('support_count') . ' + 1')
        ->where($db->quoteName('id') . ' = :id')
        ->bind(':id', $topicId, ParameterType::INTEGER);

    $db->setQuery($query)->execute();
}
```

**Discipline for Technique 4**
- Per-record CRUD: **always** `bind()` → `check()` → write. Never skip `check()`.
- Only use direct SQL for: (a) explicit-PK inserts in a Table `store()` override, (b) genuine
  set-based/atomic/aggregate operations that have no single owning row.
- Always annotate a direct-SQL write with `Direct SQL exception: <reason>`.
- Always parameter-bind (`:name` + `->bind(...)` / `ParameterType::*`). Never concatenate
  untrusted values.
- This is an **exception**, not a license to abandon Tables for ordinary writes.

---

### Checklist for a new chunked importer

1. **config.xml** — add a `migration` fieldset: source switch (`local`/`remote`), remote
   connection fields (`showon`), `*_chunk_size`, and any domain options.
2. **DataModel(s)** — one `BaseDatabaseModel` per target entity, with `createX()`/`updateX()`
   doing `bind()`/`check()`/`store()`, plus `countSourceX()`, idempotency lookups, and an ID-map
   helper. Register in `services/provider.php` with `ignore_request => true`.
3. **Table subclass(es)** — override `check()` for validation/defaults; override `store()` to
   handle explicit-PK inserts (Technique 4a).
4. **Service** — `importXChunk($userId, $offset, $limit)` returning a `MigrationResult`; `getSourceDb()`
   for the local/remote switch; `countSourceX()`; a final `rebuildX()` for derived data.
5. **Three drivers** — admin AJAX controller (JSON), API controller (JSON:API), console command
   (Symfony `ProgressBar`), all calling the same service. Register the command in DI.
6. **JS** — `count → while(chunk) → rebuild` loop reading `migration_chunk_size` via
   `Joomla.getOptions`, with a progress bar and per-chunk error logging.
7. **Idempotency + durability** — pre-existence checks, per-chunk transactions with periodic
   commits, per-row `try/catch` with durable error logging, `@set_time_limit(0)`.

See also: `joomla-coding-preferences.md` (Model→Table rule, service-layer conventions),
`joomla-di-patterns.md` (service providers, `bootComponent`), `joomla-structure-cli.md`
(console command structure), `joomla-structure-api.md` (API controllers).