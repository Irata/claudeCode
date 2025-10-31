## Joomla 5 Plugin Structure

### Plugin Directory and File Structure
```
/plugins/
└── type/plg_type_name/
    ├── plugin_name.xml
    ├── language/en-GB/
    ├── services/
    │   └── provider.php
    └── src/
       └── Extension
```

### Plugin Key Files
- `/extension_name.xml` - Plugin manifest (defines version, namespace, installation)
- `/services/provider.php` - Service provider for dependency injection
- `/src/Extension/extension_name.php` - Main extension class
- `/language` - Language files are installed within the plugin.

### Plugin Preferences
- For smaller code bases keep everything in a single file in the extension_name.php
- For larger more complex code bases, separate the code in several classes in /src
