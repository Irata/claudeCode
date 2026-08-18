## Joomla Plugin Structure

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

### Every Plugin Documents Itself

A plugin has no front end, no menu item and no visible UI, so unless it explains itself the only
way to find out what it does is to read its source. **Every plugin therefore ships at least basic
documentation in its own options screen** — what it does, the events it listens for, what it
changes, and what stops happening when it is disabled.

Plugins that register things with the application document those on top of the baseline: API routes
(`webservices`), CLI commands (`console`), task types (`task`).

Implement it as a `FormField` that stores nothing, declared in a `<config><fields name="params">`
block whose `<fieldset>` carries `addfieldprefix`. Derive the content from the extension itself
wherever the data already exists as objects — the event list is free, because
`getSubscribedEvents()` is static — since a hand-transcribed list drifts from what the plugin
actually does.

- Mechanics, baseline and verification: `includes/joomla-self-documenting-plugin.md`
- Webservices routes: `includes/joomla-structure-api.md` → *Self-Documenting Webservices Plugin*
- Console commands: `includes/joomla-structure-cli.md` → *Self-Documenting Console Plugin*
