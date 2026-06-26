**Deprecated Pattern Avoidance**:
   ```php

   // Deprecated toolbar singleton
   Toolbar::getInstance('toolbar'); // WRONG

   // Correct approach
   $toolbar = Factory::getApplication()->getDocument()->getToolbar();

   // Deprecated JFactory
   JFactory::getDbo(); // WRONG

   // Correct approach
   Factory::getContainer()->get(DatabaseInterface::class);
   ```

### ToolbarHelper Static Button Methods (Deprecated in Joomla 5.0)
**Pattern**: Using `ToolbarHelper::` static methods to add toolbar buttons
**Deprecation Version**: 5.0
**Removal Version**: 7.0
**Note**: `ToolbarHelper::title()` is **NOT deprecated** — continue using it for page titles and icons.

#### Detection Pattern
Look for code like:
```php
// WRONG — static button methods are deprecated
ToolbarHelper::addNew('{entity}.add');
ToolbarHelper::editList('{entities}.edit');
ToolbarHelper::publish('{entities}.publish');
ToolbarHelper::unpublish('{entities}.unpublish');
ToolbarHelper::archive('{entities}.archive');
ToolbarHelper::trash('{entities}.trash');
ToolbarHelper::deleteList('JGLOBAL_CONFIRM_DELETE', '{entities}.delete');
ToolbarHelper::apply('{entity}.apply');
ToolbarHelper::save('{entity}.save');
ToolbarHelper::save2new('{entity}.save2new');
ToolbarHelper::save2copy('{entity}.save2copy');
ToolbarHelper::cancel('{entity}.cancel');
ToolbarHelper::preferences('com_{name}');
```

#### Recommended Migration
Get the Toolbar object from the document and call instance methods:
```php
$toolbar = $this->getDocument()->getToolbar();

// Then call methods on the toolbar object
$toolbar->addNew('{entity}.add');
$toolbar->publish('{entities}.publish')->listCheck(true);
$toolbar->unpublish('{entities}.unpublish')->listCheck(true);
$toolbar->delete('{entities}.delete')
    ->message('JGLOBAL_CONFIRM_DELETE')
    ->listCheck(true);
$toolbar->apply('{entity}.apply');
$toolbar->save('{entity}.save');
$toolbar->save2new('{entity}.save2new');
$toolbar->cancel('{entity}.cancel', 'JTOOLBAR_CLOSE');
$toolbar->preferences('com_{name}');
```

#### Full Before/After Example — ListView `addToolbar()`

```php
// ❌ BEFORE (deprecated)
protected function addToolbar(): void
{
    $canDo = ContentHelper::getActions('com_example');

    ToolbarHelper::title(Text::_('COM_EXAMPLE_ITEMS'), 'generic');

    if ($canDo->get('core.create')) {
        ToolbarHelper::addNew('item.add');
    }

    if ($canDo->get('core.edit.state')) {
        ToolbarHelper::publish('items.publish');
        ToolbarHelper::unpublish('items.unpublish');
        ToolbarHelper::archive('items.archive');
        ToolbarHelper::trash('items.trash');
    }

    if ($canDo->get('core.delete')) {
        ToolbarHelper::deleteList('JGLOBAL_CONFIRM_DELETE', 'items.delete');
    }

    if ($canDo->get('core.admin')) {
        ToolbarHelper::preferences('com_example');
    }
}

// ✅ AFTER (modern Joomla 5+ Toolbar object API)
protected function addToolbar(): void
{
    $canDo   = ContentHelper::getActions('com_example');
    $toolbar = $this->getDocument()->getToolbar();

    ToolbarHelper::title(Text::_('COM_EXAMPLE_ITEMS'), 'generic');

    if ($canDo->get('core.create')) {
        $toolbar->addNew('item.add');
    }

    if ($canDo->get('core.edit.state')) {
        $dropdown = $toolbar->dropdownButton('status-group', 'JTOOLBAR_CHANGE_STATUS');
        $childBar = $dropdown->getChildToolbar();
        $childBar->publish('items.publish')->listCheck(true);
        $childBar->unpublish('items.unpublish')->listCheck(true);
        $childBar->archive('items.archive')->listCheck(true);
        $childBar->trash('items.trash')->listCheck(true);
    }

    if ($canDo->get('core.delete')) {
        $toolbar->delete('items.delete')
            ->message('JGLOBAL_CONFIRM_DELETE')
            ->listCheck(true);
    }

    if ($canDo->get('core.admin')) {
        $toolbar->preferences('com_example');
    }
}
```

#### Full Before/After Example — FormView `addToolbar()`

```php
// ❌ BEFORE (deprecated)
protected function addToolbar(): void
{
    Factory::getApplication()->getInput()->set('hidemainmenu', true);

    $isNew = ($this->item->id == 0);
    $canDo = ContentHelper::getActions('com_example');

    ToolbarHelper::title(
        Text::_('COM_EXAMPLE_ITEM_' . ($isNew ? 'NEW' : 'EDIT')),
        'pencil-alt'
    );

    if ($canDo->get('core.edit') || $canDo->get('core.create')) {
        ToolbarHelper::apply('item.apply');
        ToolbarHelper::save('item.save');
        ToolbarHelper::save2new('item.save2new');
    }

    ToolbarHelper::cancel('item.cancel', $isNew ? 'JTOOLBAR_CANCEL' : 'JTOOLBAR_CLOSE');
}

// ✅ AFTER (modern Joomla 5+ Toolbar object API)
protected function addToolbar(): void
{
    Factory::getApplication()->getInput()->set('hidemainmenu', true);

    $isNew   = ($this->item->id == 0);
    $canDo   = ContentHelper::getActions('com_example');
    $toolbar = $this->getDocument()->getToolbar();

    ToolbarHelper::title(
        Text::_('COM_EXAMPLE_ITEM_' . ($isNew ? 'NEW' : 'EDIT')),
        'pencil-alt'
    );

    if ($canDo->get('core.edit') || $canDo->get('core.create')) {
        $toolbar->apply('item.apply');
        $toolbar->save('item.save');
        $toolbar->save2new('item.save2new');
    }

    $toolbar->cancel('item.cancel', $isNew ? 'JTOOLBAR_CANCEL' : 'JTOOLBAR_CLOSE');
}
```

#### Why This Change
- `ToolbarHelper::` static methods internally call `Toolbar::getInstance()` which is itself deprecated
- The modern API returns a `Toolbar` object with a fluent interface supporting method chaining (e.g., `->listCheck(true)`, `->message(...)`)
- `ToolbarHelper::title()` is exempt — it remains the correct way to set the page title and icon

### `$response->code` on HTTP Responses (Does Not Exist)
**Pattern**: Accessing `->code` property on the response from `HttpFactory::getHttp()`
**Risk**: Fatal — property does not exist, causes an undefined property warning/error
**Note**: `Joomla\Http\Response` extends `Laminas\Diactoros\Response` which implements PSR-7 `ResponseInterface`. PSR-7 has no public `$code` property — only the `getStatusCode()` method.

#### Detection Pattern
```php
// WRONG — no public $code property on PSR-7 Response
$http = HttpFactory::getHttp();
$response = $http->post($url, $body, $headers);
$code = $response->code;
```

#### Recommended Migration
```php
// CORRECT — use the PSR-7 getStatusCode() method
$http = HttpFactory::getHttp();
$response = $http->post($url, $body, $headers);
$code = $response->getStatusCode();
```

#### Why This Matters
- Older Joomla HTTP libraries (Joomla 3.x era) exposed `$response->code` as a public property
- Since Joomla 4.0+, the HTTP layer uses `Laminas\Diactoros\Response` (PSR-7 compliant)
- PSR-7 `ResponseInterface` defines `getStatusCode(): int` — there is no `$code` property
- Similarly, the response body is accessed via `$response->getBody()->__toString()` or `(string) $response->getBody()`, not `$response->body`

### `getInstance()` on Joomla Framework Classes (Does Not Exist)
**Pattern**: Calling `getInstance()` on Joomla Framework classes (under `Joomla\Filter\`, `Joomla\Input\`, etc.)
**Risk**: Fatal — method does not exist on the framework class, causing a runtime error
**Note**: The old CMS wrapper classes (e.g., `Joomla\CMS\Filter\InputFilter`) had `getInstance()`, but the framework-level classes never did. When using the framework `InputFilter` import (`use Joomla\Filter\InputFilter`), `getInstance()` will fail.

#### Detection Pattern
```php
// WRONG — getInstance() does not exist on Joomla\Filter\InputFilter
use Joomla\Filter\InputFilter;

$filter = InputFilter::getInstance($allowedTags, $allowedAttributes, InputFilter::ONLY_ALLOW_DEFINED_TAGS, InputFilter::ONLY_ALLOW_DEFINED_ATTRIBUTES);
```

#### Recommended Migration
```php
// CORRECT — use the constructor directly
use Joomla\Filter\InputFilter;

$filter = new InputFilter($allowedTags, $allowedAttributes, InputFilter::ONLY_ALLOW_DEFINED_TAGS, InputFilter::ONLY_ALLOW_DEFINED_ATTRIBUTES);
```

#### Why This Matters
- `Joomla\Filter\InputFilter` (the framework class) has a public constructor but no static `getInstance()` factory
- Code that imports the framework class and calls `::getInstance()` will fail at runtime with "Call to undefined method"
- This applies broadly: Joomla Framework 2.0+ classes use constructors, not static factories
- Always check which `InputFilter` is imported — `Joomla\Filter\InputFilter` (framework) vs `Joomla\CMS\Filter\InputFilter` (CMS wrapper)

### View Model Access Pattern (Deprecated in 5.3.0)
**Pattern**: Using `$this->get('PropertyName')` in Joomla view classes to access model data
**Deprecation Version**: 5.3.0
**Removal Version**: 7.0
**Location**: `libraries/src/MVC/View/AbstractView.php`

#### Detection Pattern
Look for code like:
```php
// In view classes (HtmlView.php)
$this->items = $this->get('Items');
$this->pagination = $this->get('Pagination');
$this->state = $this->get('State');
```

#### Recommended Migration
Replace with direct model method calls:
```php
// Get the model instance first
$model = $this->getModel();

// Then call methods directly
$this->items = $model->getItems();
$this->pagination = $model->getPagination();
$this->state = $model->getState();
```

#### Detection Pattern
Look for code like:
```php
Factory::getUser()->get('id')
```

#### Recommended Migration
Replace with call to DI Container:
```php
Factory::getApplication()->getIdentity()->id;
```



#### Why This Change
- Improves code clarity and IDE autocomplete support
- Removes magic method overhead
- Makes debugging easier by showing explicit method calls
- Aligns with modern PHP best practices

### `jexit()` (Deprecated since 4.0)
**Pattern**: Using `jexit()` for token validation exit
**Removal Version**: 6.0

#### Detection Pattern
```php
// WRONG — jexit() is deprecated
Session::checkToken() || jexit(Text::_('JINVALID_TOKEN'));
```

#### Recommended Migration
```php
// CORRECT — use BaseController's built-in method
$this->checkToken();
```

`BaseController::checkToken()` handles token validation and throws the appropriate exception. No manual `Session::checkToken()` or `jexit()` calls needed.

### `$this->app` in MVC Controllers
**Note**: `$this->app` is a protected property on `BaseController` that is always initialized in the constructor (with `Factory::getApplication()` fallback). It is safe to use `$this->app` directly in MVC controllers. `getApplication()` does NOT exist on MVC controller classes — do not use it there.

### Bootstrap Modals (Deprecated in Joomla 5)
**Pattern**: Using Bootstrap modals (`data-bs-toggle="modal"`, `bootstrap.modal` script, `new bootstrap.Modal()`)
**Issue**: Joomla 5 provides its own `<joomla-dialog>` web component. Bootstrap modals are deprecated and will be removed in Joomla 6.

#### Detection Patterns
```javascript
// WRONG — bootstrap is not a global in Joomla 5
new bootstrap.Modal(element).show();
```
```html
<!-- WRONG — Bootstrap modal markup -->
<div class="modal fade" id="myModal" data-bs-toggle="modal">
```
```php
// WRONG — Bootstrap modal asset loading
HTMLHelper::_('bootstrap.modal', '#myModalId');
$wa->useScript('bootstrap.modal');
```

#### Recommended Migration
Use Joomla's `<joomla-dialog>` web component with `data-joomla-dialog` attribute:
```php
// Load the dialog autocreate script
$wa->useScript('joomla.dialog-autocreate');
```
```html
<!-- Trigger button -->
<button type="button"
        data-joomla-dialog='{"popupType": "inline", "src": "#myDialogContent", "textHeader": "Title", "width": "500px", "height": "fit-content"}'>
    Open Dialog
</button>

<!-- Dialog content in a template element -->
<template id="myDialogContent">
    <div class="p-3">Dialog body here</div>
</template>
```

Reference: https://manual.joomla.org/docs/4.4/general-concepts/javascript/js-library/joomla-dialog/

### Application `->input` Property Access (Deprecated, removal targeted for Joomla 6)
**Pattern**: Accessing `->input` directly on the Application object
**Risk**: High — property will be removed

#### Detection Pattern
```php
// WRONG — direct property access
$input = Factory::getApplication()->input;
Factory::getApplication()->input->get('return', null, 'base64');
Factory::getApplication()->input->set('hidemainmenu', true);
$this->app->input->get('filter', [], 'array');
```

#### Recommended Migration
```php
// CORRECT — use getter method
$input = Factory::getApplication()->getInput();
Factory::getApplication()->getInput()->get('return', null, 'base64');
Factory::getApplication()->getInput()->set('hidemainmenu', true);
$this->app->getInput()->get('filter', [], 'array');
```

**Note**: In MVC controllers, `$this->input` is a separate property initialized from the application input during construction and is safe to use directly. The deprecation applies to `$app->input`, not `$controller->input`.

### Application `->scope` Property Access (Deprecated, removal targeted for Joomla 6)
**Pattern**: Accessing `->scope` directly on the Application object
**Risk**: High — property will be removed

#### Detection Pattern
```php
// WRONG — direct property access
$component_name = Factory::getApplication()->scope;
```

#### Recommended Migration
```php
// CORRECT — use the input option or pass explicitly
$component_name = Factory::getApplication()->getInput()->getCmd('option');
```

### Application `->getName()` Method (Deprecated, removal targeted for Joomla 6)
**Pattern**: Calling `->getName()` on the Application object to get the client prefix
**Risk**: Medium — method will be removed

#### Detection Pattern
```php
// WRONG — deprecated method
$prefix = Factory::getApplication()->getName();
```

#### Recommended Migration
```php
// CORRECT — use client name from the application identity
$prefix = Factory::getApplication()->isClient('administrator') ? 'Administrator' : 'Site';
// Or pass the prefix explicitly via method parameters / DI config
```

### `Factory::getDate()` Static Method (Service Locator Anti-Pattern)
**Pattern**: Using `Factory::getDate()` to create Date objects
**Risk**: Medium — static service locator pattern being phased out

#### Detection Pattern
```php
// WRONG — static service locator
$date = Factory::getDate();
$this->created = Factory::getDate()->toSql();
```

#### Recommended Migration
```php
// CORRECT — instantiate directly
use Joomla\CMS\Date\Date;

$date = new Date();
$this->created = (new Date())->toSql();
```

### `Factory::getApplication()` in Models and Views (Service Locator Anti-Pattern)
**Pattern**: Using `Factory::getApplication()` inside models and views instead of DI
**Risk**: Low — unlikely to be removed soon, but is an anti-pattern

#### Detection Pattern
```php
// WRONG — static call in a model or view
$data = Factory::getApplication()->getUserState('com_example.edit.item.data', []);
```

#### Recommended Migration
Models and views that extend Joomla base classes have `ApplicationAwareTrait` available:
```php
// CORRECT in AdminModel / ListModel — already has the application injected
// No change needed if the base class provides getApplication()
// For custom models extending BaseDatabaseModel, use ApplicationAwareTrait:
use Joomla\CMS\Application\ApplicationAwareTrait;

class MyModel extends BaseDatabaseModel
{
    use ApplicationAwareTrait;

    public function doSomething(): void
    {
        $app = $this->getApplication();
    }
}
```

### `HTMLHelper::_('behavior.multiselect')` (Redundant Legacy Pattern)
**Pattern**: Loading multiselect via the legacy `behavior` helper group
**Risk**: Medium — `behavior.*` helpers are legacy and may be removed

#### Detection Pattern
```php
// WRONG — legacy behavior helper (often redundant)
HTMLHelper::_('behavior.multiselect');
```

#### Recommended Migration
```php
// CORRECT — use WebAssetManager
$wa = $this->getDocument()->getWebAssetManager();
$wa->useScript('multiselect');
```

### `HTMLHelper::_('bootstrap.tooltip', ...)` — NOT Deprecated (Do NOT Replace)
**Pattern**: Initializing Bootstrap tooltips via HTMLHelper
**Status**: This is **still the correct Joomla 5/6 approach**. Do not replace it.

#### Why It Cannot Be Replaced with WebAssetManager
`HTMLHelper::_('bootstrap.tooltip', '.hasTooltip')` both loads the Bootstrap tooltip script **and** generates the inline JavaScript that initializes tooltips on elements matching the CSS selector. There is no registered `bootstrap.tooltip` script asset in Joomla's WebAssetManager — using `$wa->useScript('bootstrap.tooltip')` will throw:

> There is no "bootstrap.tooltip" asset of a "script" type in the registry.

#### Correct Usage
```php
// CORRECT — keep using the HTMLHelper
HTMLHelper::_('bootstrap.tooltip', '.hasTooltip');
```

### `defined('JPATH_PLATFORM') or die` (Joomla 3 Guard Constant)
**Pattern**: Using `JPATH_PLATFORM` as the entry guard constant
**Risk**: Medium — `JPATH_PLATFORM` is a legacy constant from the Joomla Platform era

#### Detection Pattern
```php
// WRONG — legacy guard constant
defined('JPATH_PLATFORM') or die;
```

#### Recommended Migration
```php
// CORRECT — use the standard Joomla execution guard
\defined('_JEXEC') or die;
```

### `defined()` vs `\defined()` (Namespace Best Practice)
**Pattern**: Using `defined()` without leading backslash in namespaced files
**Risk**: Cosmetic / best practice — works but not optimal

#### Detection Pattern
```php
// SUBOPTIMAL — requires PHP namespace resolution lookup
defined('_JEXEC') or die;
```

#### Recommended Migration
```php
// CORRECT — explicit global function call, avoids namespace resolution
\defined('_JEXEC') or die;
```

### `$query->dump()` — Do NOT Remove
**Pattern**: `$query->dump()` marked deprecated since Joomla 3
**Status**: Despite the deprecation marker, this method **must not be removed** from existing code. It is actively used for debugging SQL statements during development. Agents and code reviewers must leave existing `dump()` calls in place.