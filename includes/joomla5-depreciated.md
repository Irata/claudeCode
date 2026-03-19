**Deprecated Pattern Avoidance**:
   ```php
   
   // Deprecated toolbar
   Toolbar::getInstance('toolbar'); // WRONG
   
   // Correct approach
   $toolbar = Factory::getApplication()->getDocument()->getToolbar();
   
   // Deprecated JFactory
   JFactory::getDbo(); // WRONG
   
   // Correct approach
   Factory::getContainer()->get(DatabaseInterface::class);
   ```

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

### `$query->dump()` — Do NOT Remove
**Pattern**: `$query->dump()` marked deprecated since Joomla 3
**Status**: Despite the deprecation marker, this method **must not be removed** from existing code. It is actively used for debugging SQL statements during development. Agents and code reviewers must leave existing `dump()` calls in place.