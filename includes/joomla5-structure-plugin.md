## Joomla 5 Plugin Structure

## Plugin Structure

```
plugins/{group}/{name}/
├── {name}.xml                    — Manifest (metadata, namespace, files only)
├── language/en-GB/
│   ├── plg_{group}_{name}.ini    — Language strings
│   └── plg_{group}_{name}.sys.ini — System language strings
├── services/
│   └── provider.php              — DI service provider
└── src/
    └── Extension/
        └── {Name}.php            — Main plugin class
```

### Plugin Manifest `<files>` Element

The `<files>` block **MUST** include the `plugin="..."` attribute on the `src` folder
entry. This attribute tells the installer the plugin's `element` name for the
`#__extensions` table. Without it, installation fails with
`"Field 'element' doesn't have a default value"`.

```xml
<files>
    <folder plugin="{name}">src</folder>
    <folder>services</folder>
    <folder>language</folder>
</files>
```

### Plugin Key Files
- `/extension_name.xml` - Plugin manifest (defines version, namespace, file declarations, configuration)
- `/services/provider.php` - Service provider for dependency injection
- `/src/Extension/extension_name.php` - Main extension class
- `/language` - Language files are installed within the plugin.

### Language Loading
- **Always** set `protected $autoloadLanguage = true;` in the Extension class
- This tells Joomla to load the plugin's `.ini` language file when the plugin is instantiated
- Without this, `Text::_()` calls within the plugin will return untranslated language keys

### Plugin Preferences
- For smaller code bases keep everything in a single file in the extension_name.php
- For larger more complex code bases, separate the code in several classes in /src
