### Joomla 5 Web Services API structure as part of a Component Structure

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

### Component Key Files
- `/language` - Language files are installed within the component.