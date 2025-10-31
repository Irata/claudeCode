### Joomla 5 Component Structure

### Component Directory and File Structure - Administrator and Site
```
/components/com_example/
├── administrator/
│   ├── components/com_example/
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
├── language/en-GB/
└── media/com_example/
    ├── joomla.asset.json 
    ├── css/ 
    └── js/
```

### Component Directory and File Structure - Administrator Only
```
/components/com_example/
└── administrator/
    └── components/com_example/
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
- `/extension_name.xml` - Component manifest (defines version, namespace, installation)
- `/services/provider.php` - Service provider for dependency injection
- `/src/Extension/extension_nameComponent.php` - Main extension class
- `/language` - Language files are installed within the component.