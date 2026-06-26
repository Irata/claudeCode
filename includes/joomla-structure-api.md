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
       └── Extension
           └── Example.php
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

### Component Key Files
- `/language` - Language files are installed within the component.