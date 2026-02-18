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