### Joomla 5 Component Structure

### Component Directory and File Structure - Administrator and Site
```
/
├── administrator/
│   ├── components/com_example/
│   │   ├── example.xml            ← Component manifest (NOT com_example.xml)
│   │   ├── config.xml
│   │   ├── access.xml
│   │   ├── forms
│   │   ├── language/en-GB/
│   │   ├── services/
│   │   │   └── provider.php
│   │   ├── sql/
│   │   ├── src/
│   │   │   ├── Controller/
│   │   │   ├── Event/
│   │   │   ├── Extension/
│   │   │   ├── Model/
│   │   │   ├── View/
│   │   │   ├── Service/
│   │   │   ├── Table/
│   │   │   └── Helper
│   │   └── tmpl/
├── components/com_example/
│   ├── forms
│   ├── language/en-GB/
│   ├── src/
│   │   ├── Controller/
│   │   ├── Helper/
│   │   ├── Layouts/
│   │   ├── Model/├
│   │   ├── Service/
│   │   │   └── Router.php
│   │   └── View/
│   └── tmpl/
└── media/com_example/
    ├── joomla.asset.json 
    ├── css/ 
    └── js/
```

### Component Directory and File Structure - Administrator Only
```
/
└── administrator/
    └── components/com_example/
        ├── example.xml            ← Component manifest (NOT com_example.xml)
        ├── config.xml
        ├── access.xml
        ├── forms
        ├── language/en-GB/
        ├── services/
        │   └── provider.php
        ├── sql/
        ├── src/
        │   ├── Controller
        │   ├── Event
        │   ├── Extension
        │   ├── Model
        │   ├── View/
        │   ├── Table
        │   └── Helper
        └── tmpl/
```

### Component Key Files
- `/extension_name.xml` - Component manifest (e.g. `forum.xml` for `com_forum`, **NOT** `com_forum.xml`). Defines version, namespace, file declarations only.
- `/config.xml` - Configuration parameters (NOT in the manifest XML)
- `/access.xml` - ACL action definitions
- `/services/provider.php` - Service provider for dependency injection
- `/src/Extension/extension_nameComponent.php` - Main extension class (must expose `getContainer()` for service resolution — see `joomla5-di-patterns.md`)
- `/language` - Language files are installed within the component.
- `/tmpl` - Template files are at the same level as `/src` — **NOT** a subdirectory of `/View`.

### View Conventions (Administrator and Site)
Views extend `HtmlView`. **CRITICAL**: Use direct model calls, NOT the deprecated `$this->get()` magic method (deprecated 5.3.0, removed 7.0):
```php
// WRONG (deprecated)
$this->items = $this->get('Items');
$this->pagination = $this->get('Pagination');
$this->state = $this->get('State');
$this->form = $this->get('Form');

// CORRECT — get model instance, call methods directly
$model = $this->getModel();
$this->items = $model->getItems();
$this->pagination = $model->getPagination();
$this->state = $model->getState();
$this->form = $model->getForm();
```

### Hierarchical List Views (Nested/Tree Display)

For entities with parent-child relationships (e.g., categories, boards), the admin list view should display items in tree order with indentation. This requires:

**ListModel** — Order by `lft` and select `level`:
```php
protected function populateState($ordering = 'a.lft', $direction = 'asc')
{
    parent::populateState($ordering, $direction);
}

// In getListQuery(), include level and lft in the SELECT:
$db->quoteName('a.level'),
$db->quoteName('a.lft'),

// Fallback ordering:
$orderCol = $this->state->get('list.ordering', 'a.lft');
```

**Template** — Render indentation before the title using the `level` property:
```php
<td>
    <?php echo str_repeat('<span class="gi">&mdash;</span>', (int) $item->level); ?>
    <a href="<?php echo Route::_('index.php?option=com_example&task=item.edit&id=' . (int) $item->id); ?>">
        <?php echo $this->escape($item->title); ?>
    </a>
</td>
```

**AdminModel** — Trigger nested set rebuild on save:
```php
public function save($data): bool
{
    if (!parent::save($data)) {
        return false;
    }

    // Rebuild the nested set tree so lft/rgt/level stay current.
    $container = Factory::getContainer();
    if ($container->has(EntityService::class)) {
        $container->get(EntityService::class)->rebuildNestedSet();
    }

    return true;
}
```

**Form XML** — The parent field must use `type="sql"` to dynamically populate:
```xml
<field
    name="parent_id"
    type="sql"
    label="COM_EXAMPLE_FIELD_PARENT_LABEL"
    query="SELECT id AS value, title AS text FROM #__example_items WHERE state = 1 ORDER BY title ASC"
    key_field="value"
    value_field="text"
>
    <option value="0">COM_EXAMPLE_FIELD_PARENT_ROOT</option>
</field>
```

**Edit/Form views MUST load the form validator** via Web Asset Manager. Without this, toolbar Save/Apply buttons fail with JS error `document.formvalidator is undefined`:
```php
public function display($tpl = null): void
{
    $model       = $this->getModel();
    $this->form  = $model->getForm();
    $this->item  = $model->getItem();
    $this->state = $model->getState();

    $this->addToolbar();

    // REQUIRED when template <form> has class="form-validate"
    $this->document->getWebAssetManager()->useScript('form.validate');

    parent::display($tpl);
}
```