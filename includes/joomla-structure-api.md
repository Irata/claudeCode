### Joomla Web Services API structure as part of a Component Structure

### Directory and File Structure for Web Services API application of a component.
```
/
└── api/
    └── components/com_example/
        ├── language/en-GB/
        └── src/
            ├── Controller
            ├── Serializer/
            └── View/
```

### Webservices Plugin Directory and File Structure
```
/plugins/
└── webservices/example/
    ├── example.xml
    ├── language/en-GB/
    ├── services/
    │   └── provider.php
    └── src/
       ├── Extension/
       │   └── Example.php
       └── Field/
           └── EndpointsField.php   ← endpoint reference (see pattern below)
```
### JsonApiView Property Types

The base class `Joomla\CMS\MVC\View\JsonApiView` declares `$fieldsToRenderItem` and
`$fieldsToRenderList` **without** a type declaration. Child classes **MUST NOT** add
the `array` type — PHP forbids adding a type to an untyped parent property.

```php
// CORRECT — no type declaration
protected $fieldsToRenderItem = ['id', 'title', 'state'];
protected $fieldsToRenderList = ['id', 'title'];

// WRONG — will cause a fatal error
protected array $fieldsToRenderItem = ['id', 'title', 'state'];
```

### JSON:API Error Responses (Exceptions → HTTP status & message)

In the API application, a thrown exception is rendered by a **type-specific** JSON:API
error handler (`libraries/src/Error/JsonApi/*`). Each handler decides the HTTP status
and **whether the exception message is shown**. This matters: several 404/403 handlers
**hardcode a generic title and discard your message**, and any exception type with no
registered handler falls through to a **generic 500** (the message appears only in
debug mode). So the exception you throw determines both the status code and whether the
caller sees *why*.

| Exception (throw this) | HTTP status | Error title | Your message shown? |
|---|---|---|---|
| `Joomla\CMS\Router\Exception\RouteNotFoundException` | 404 | "Resource not found" (hardcoded) | **No** |
| `Joomla\CMS\MVC\Controller\Exception\ResourceNotFound` | 404 | "Resource not found" (hardcoded) | **No** |
| `Joomla\CMS\Access\Exception\NotAllowed` | 403 | "Access Denied" (hardcoded) | **No** |
| `Joomla\CMS\MVC\Controller\Exception\Save` | **`getCode()`** (default 400) | **your message** | **Yes** |
| `Tobscure\JsonApi\Exception\InvalidParameterException` | 400 | **your message** | **Yes** |
| `...Controller\Exception\CheckinCheckout` / `SendEmail` | `getCode()` | **your message** | **Yes** |
| `AuthenticationFailed` / `NotAcceptable` | 401 / 406 | hardcoded | No |
| anything else (e.g. `\InvalidArgumentException`, `\RuntimeException`) | **500 generic** | "Internal server error" | only in debug |

**Practical recipes:**
- **404 with a custom message** → `throw new Save('No matching records found.', 404);`
  (the only core handler that yields a `getCode()`-driven status **and** surfaces the
  message — `RouteNotFoundException` would discard the message).
- **Plain 404** (generic title acceptable) → `RouteNotFoundException`.
- **403 forbidden** → `NotAllowed(..., 403)`.
- **400 with a message** → `InvalidParameterException(...)` or `Save($message, 400)`.
- **Never** throw a bare `\InvalidArgumentException` / `\RuntimeException` from an API
  controller expecting a specific status — it renders as a generic 500 regardless of the
  code you pass.

> The `Save` class name implies a write failure; when using it purely to carry a
> 404 + message on a read endpoint, add a short comment explaining why, so the choice
> isn't mistaken for a copy-paste error.

### Purpose-Built List Endpoint Pattern (custom action → state → parent displayList → slim view)

A clean, flexible way to add a specialised list/search endpoint (e.g. an @mention
type-ahead, an autocomplete, a constrained sub-list) **without** new models or
duplicated query logic. The custom controller action only sets model state and
selects the view; the heavy lifting is reused from the existing list model and the
core `parent::displayList()`.

**The pattern:**
1. Add a custom action method on the existing API controller (e.g. `profilesByDisplayname()`).
2. Validate/normalise the route input; on failure throw a core exception (see below).
3. Build/seed the model state — reuse the same state builder the normal `displayList()`
   uses (pagination, sorting, base filters), then set the endpoint-specific filter(s).
4. Point the response at a **purpose-built JSON:API view** by setting
   `$this->default_view` to a slim view, while **keeping `$this->contentType` unchanged**.
5. Call `parent::displayList()` (the core `ApiController::displayList`).

**Why it works — view vs. model resolution in `ApiController::displayList()`:**
- The **view** is resolved from `$this->default_view`.
- The **model** (and the JSON:API resource `type`) is resolved from `$this->contentType`.
- So setting only `default_view` swaps the rendered field set while the existing
  list model, its filters/pagination, and the resource type are all reused unchanged —
  no new model or content type required.

**Why a dedicated view (not the request `fields` param):** core
`JsonApiView::displayList()` forces output to its own `$fieldsToRenderList` (via the
`onApiGetFields` event) and **ignores** the request's `fields[type]` sparse fieldset.
A purpose-built view with a slim `$fieldsToRenderList` is therefore the reliable way
to limit the payload — important for **not leaking PII** (email, phone, etc.) on a
public-ish search endpoint.

**Error handling:** validate input and throw a core exception that maps to the status
and message you want — see "JSON:API Error Responses" above. For the too-short-input
case use `Save($message, 404)` to return a 404 whose body carries the reason.

```php
// Controller (api/src/Controller/ExamplesController.php) — reuses ExamplesModel + 'examples' type
public function byPrefix()
{
    $term = trim((string) $this->input->get('string', '', 'STRING'));

    if (mb_strlen($term) < 2) {
        throw new \Joomla\CMS\MVC\Controller\Exception\Save('No matching records found.', 404);
    }

    foreach ($this->getService()->buildApiListState(
        $this->input->get('page', [], 'array'),
        $this->input->get('list', [], 'array')
    ) as $key => $value) {
        $this->modelState->set($key, $value);
    }

    $this->modelState->set('filter.name', $term);   // endpoint-specific filter
    $this->modelState->set('filter.state', 1);      // constrain to active records

    $this->default_view = 'examplesslim';           // slim view; contentType stays 'examples'

    return parent::displayList();
}
```
```php
// Slim view (api/src/View/Examplesslim/JsonApiView.php) — extends the full view, slim fields only
class JsonApiView extends \Vendor\Component\Example\Api\View\Examples\JsonApiView
{
    protected $fieldsToRenderItem = ['id', 'name', 'avatar'];
    protected $fieldsToRenderList = ['id', 'name', 'avatar'];
}
```

The endpoint-specific filter must exist in the list model's `getListQuery()`
(prefer an index-friendly prefix `LIKE 'term%'` over `%term%` for type-ahead). Add a
supporting column index when searching a large table.

### Self-Documenting Webservices Plugin (endpoint reference in the plugin options)

**Required for every webservices plugin, new or revised.** A plugin that registers API routes
must publish those routes in its own options screen. Routes declared only inside
`onBeforeApiRoute()` are discoverable only by reading the source, which is the wrong place
to send an integrator — and the wrong place for the site administrator who has to answer "what
can this token call?".

The plugin has no settings of its own, so its options tab is free real estate. Fill it with a
read-only reference rendered against **the site being looked at**: this site's base URL, and
worked examples naming resources that actually exist here. Placeholder text (`https://yoursite/…`)
is worth far less — the point is that an integrator can copy a line and have it work.

The read-only-field mechanics, the baseline every plugin documents, and the generic verification
harness live in `includes/joomla-self-documenting-plugin.md`. This section covers only what is
specific to routes.

#### 1. The field class (`src/Field/EndpointsField.php`)

```php
<?php

namespace Vendor\Plugin\WebServices\Example\Field;

\defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Form\FormField;
use Joomla\CMS\Language\Text;
use Joomla\CMS\Uri\Uri;
use Joomla\Database\DatabaseInterface;

/**
 * Read-only documentation of the API routes this plugin registers.
 *
 * Stores nothing: getInput() renders and the value is never saved.
 */
final class EndpointsField extends FormField
{
    protected $type = 'Endpoints';

    /** How many live resources to list before summarising the remainder. */
    private const SAMPLE_LIMIT = 10;

    protected function getInput(): string
    {
        $base = $this->apiBase();

        return '<div class="alert alert-info">' . Text::_('PLG_WEBSERVICES_EXAMPLE_ENDPOINTS_AUTH') . '</div>'
            . $this->routesTable($base)
            . '<p class="mt-3 mb-1"><strong>' . Text::_('PLG_WEBSERVICES_EXAMPLE_ENDPOINTS_QUERY_HEADING') . '</strong></p>'
            . $this->queryList()
            . '<p class="mt-3 mb-1"><strong>' . Text::_('PLG_WEBSERVICES_EXAMPLE_ENDPOINTS_EXAMPLES_HEADING') . '</strong></p>'
            . $this->examples($base);
    }

    /**
     * The API entry point for this site, e.g. https://example.com/api/index.php.
     *
     * Uri::root() is safe here in a way it is not everywhere: this field only ever renders on
     * the plugin options screen, which is an administrator web request. There is always a real
     * host to derive, and AdministratorApplication::doExecute() has already reset the URI root
     * back to the SITE root, so no '/administrator' segment leaks into the addresses.
     */
    private function apiBase(): string
    {
        return Uri::root() . 'api/index.php';
    }

    private function routesTable(string $base): string
    {
        $routes = [
            ['GET',  '/v1/example/items',      'PLG_WEBSERVICES_EXAMPLE_ENDPOINTS_ROUTE_LIST'],
            ['GET',  '/v1/example/items/{id}', 'PLG_WEBSERVICES_EXAMPLE_ENDPOINTS_ROUTE_ITEM'],
            ['POST', '/v1/example/items',      'PLG_WEBSERVICES_EXAMPLE_ENDPOINTS_ROUTE_CREATE'],
        ];

        $rows = '';

        foreach ($routes as [$method, $path, $key]) {
            $rows .= '<tr>'
                . '<td class="text-nowrap"><span class="badge bg-success">' . $this->e($method) . '</span></td>'
                . '<td class="text-break"><code>' . $this->e($base . $path) . '</code></td>'
                . '<td>' . Text::_($key) . '</td>'
                . '</tr>';
        }

        return '<table class="table table-sm align-middle mb-0">'
            . '<thead><tr>'
            . '<th scope="col">' . Text::_('PLG_WEBSERVICES_EXAMPLE_ENDPOINTS_COL_METHOD') . '</th>'
            . '<th scope="col">' . Text::_('PLG_WEBSERVICES_EXAMPLE_ENDPOINTS_COL_ENDPOINT') . '</th>'
            . '<th scope="col">' . Text::_('PLG_WEBSERVICES_EXAMPLE_ENDPOINTS_COL_PURPOSE') . '</th>'
            . '</tr></thead><tbody>' . $rows . '</tbody></table>';
    }

    private function queryList(): string
    {
        $params = [
            'page[limit]=20'  => 'PLG_WEBSERVICES_EXAMPLE_ENDPOINTS_QUERY_LIMIT',
            'page[offset]=0'  => 'PLG_WEBSERVICES_EXAMPLE_ENDPOINTS_QUERY_OFFSET',
            'filter[state]=1' => 'PLG_WEBSERVICES_EXAMPLE_ENDPOINTS_QUERY_FILTER',
        ];

        $items = '';

        foreach ($params as $example => $key) {
            $items .= '<li class="text-break"><code>?' . $this->e($example) . '</code> — ' . Text::_($key) . '</li>';
        }

        return '<ul class="mb-0">' . $items . '</ul>';
    }

    /** Worked examples naming this site's own records where there are any. */
    private function examples(string $base): string
    {
        $records = $this->liveResources();

        if (!$records) {
            return '<p class="text-muted mb-1">' . Text::_('PLG_WEBSERVICES_EXAMPLE_ENDPOINTS_NO_RESOURCES') . '</p>'
                . '<ul class="mb-0"><li class="text-break"><code>'
                . $this->e($base . '/v1/example/items/1') . '</code></li></ul>';
        }

        $items = '';

        foreach (\array_slice($records, 0, self::SAMPLE_LIMIT) as $record) {
            $items .= '<li class="text-break"><code>'
                . $this->e($base . '/v1/example/items/' . $record->id) . '</code>'
                . ' — ' . $this->e($record->title) . '</li>';
        }

        $more = \count($records) > self::SAMPLE_LIMIT
            ? '<p class="text-muted mt-1 mb-0">'
                . Text::sprintf('PLG_WEBSERVICES_EXAMPLE_ENDPOINTS_MORE', \count($records) - self::SAMPLE_LIMIT)
                . '</p>'
            : '';

        return '<ul class="mb-0">' . $items . '</ul>' . $more;
    }

    /**
     * Returns an empty array rather than throwing when the component is absent: a webservices
     * plugin can legitimately outlive its component (part-installed, or the component removed),
     * and an options screen that fatals is a worse outcome than one missing its examples.
     */
    private function liveResources(): array
    {
        try {
            $db    = Factory::getContainer()->get(DatabaseInterface::class);
            $query = $db->getQuery(true)
                ->select($db->quoteName(['id', 'title']))
                ->from($db->quoteName('#__example_items'))
                ->where($db->quoteName('state') . ' = 1')
                ->order($db->quoteName('modified') . ' DESC');

            return (array) $db->setQuery($query)->loadObjectList();
        } catch (\Throwable) {
            return [];
        }
    }

    private function e(string $value): string
    {
        return htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
    }
}
```

#### 2. Manifest config block (`example.xml`)

`addfieldprefix` is what makes the custom type resolvable — see the trap below.

```xml
<config>
    <fields name="params">
        <!-- Documentation only; this plugin stores no settings. -->
        <fieldset name="basic"
                  addfieldprefix="Vendor\Plugin\WebServices\Example\Field">
            <field name="endpoints"
                   type="endpoints"
                   label="PLG_WEBSERVICES_EXAMPLE_ENDPOINTS_LABEL"
                   description="PLG_WEBSERVICES_EXAMPLE_ENDPOINTS_DESC"
            />
        </fieldset>
    </fields>
</config>
```

The existing `<files><folder>src</folder></files>` already ships `src/Field/` — no manifest file
list change is needed beyond the `<config>` block.

#### 3. Language strings

Prose in the `.ini`, dynamic values escaped through `e()` — see
`joomla-self-documenting-plugin.md` → *Language strings*. The route-specific keys:

```ini
PLG_WEBSERVICES_EXAMPLE_ENDPOINTS_LABEL="Available Endpoints"
PLG_WEBSERVICES_EXAMPLE_ENDPOINTS_DESC="Reference only — this plugin has no settings to change. The addresses below are this site's own and can be copied as they stand."
PLG_WEBSERVICES_EXAMPLE_ENDPOINTS_AUTH="Every route requires a Joomla API token sent as an <code>Authorization: Bearer &lt;token&gt;</code> header. A token only reaches the records its user's access level permits, so two callers can be given the same endpoint and see different data. Create tokens under Users &rarr; Manage &rarr; API Tokens."
```

#### What the reference must cover

| Include | Because |
|---|---|
| Every registered route, with method and full URL | The whole point; mirror `onBeforeApiRoute()` exactly |
| Authentication, and that access is per-record | Administrators consistently assume a token sees everything |
| Each query parameter, **and how it fails** | "rejected with 400" saves a support round-trip |
| Content-negotiation traps | e.g. a bare `Accept: text/csv` is refused with 406 upstream, before the component sees it |
| Live example URLs | Turns the screen from documentation into something copy-pasteable |

#### Trap 1 — a custom field type that does not resolve falls back to a text input, silently

Generic to every documentation field: a missing or wrong `addfieldprefix` resolves
`type="endpoints"` to `Joomla\CMS\Form\Field\TextField` and renders a stray text box, with no
error from a lint, a syntax check, or an install. Full explanation and why it cannot be caught
statically: `joomla-self-documenting-plugin.md` → *Trap 1*.

#### Trap 2 — `Uri::root()` and the administrator root reset

`Uri::root()` is the correct API for the site root here, but understand *why* it is safe:
`AdministratorApplication::doExecute()` resets the URI root back to the site root, stripping
`/administrator`. Options screens always render inside that application, so the reset has always
run. Two consequences:

- Do **not** copy this `apiBase()` into a console, task, or CLI context. There, `Uri::root()`
  yields `https://joomla.invalid/set/by/console/application/` unless the site sets `$live_site`.
- A CLI **test harness** must reproduce the reset, or it measures a state that never occurs.

#### Verifying it (build the form from the real manifest)

Use the generic harness in `joomla-self-documenting-plugin.md` → *Verifying it* for the bootstrap,
the field-resolution check and the untranslated-key check. Two additions are specific to this
field, because it is the only one that emits URLs:

**Reproduce the administrator root reset** before rendering, or the harness measures a state that
never occurs (Trap 2):

```php
// Reproduce AdministratorApplication::doExecute()'s root reset.
\Joomla\CMS\Uri\Uri::root(null, rtrim(\dirname(\Joomla\CMS\Uri\Uri::base(true)), '/\\'));
```

**Assert the emitted URLs**:

```php
preg_match_all('#https?://[^<\s"]+#', $html, $u);
print_r(array_unique($u[0]));   // must have no '/administrator' segment
```

> **`REQUEST_URI` must point at the admin *directory*.** Under CLI, `Uri::base()` derives its
> path from `REQUEST_URI`; under a web SAPI it uses `dirname(SCRIPT_NAME)`. Passing
> `/administrator/index.php` makes the two branches disagree and every URL gains a segment —
> a harness artefact that looks exactly like a code bug.

**Pass criteria:** the generic ones (field resolves to your own class, no surviving `PLG_…`
constants) plus — specific to this field — the emitted URLs match what a client actually calls and
carry no `/administrator` segment.

#### Keeping it honest

The reference lives next to the routes it documents, but nothing enforces agreement. When
`onBeforeApiRoute()` changes, the field changes in the same commit — treat them as one unit.
Where a project also keeps a `.http` request file, prefer the field as the source of truth and
let the `.http` file hold only the requests.

### Component Key Files
- `/language` - Language files are installed within the component.