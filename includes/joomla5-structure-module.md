## Joomla 5 Module Structure

### Module Directory and File Structure
```
/modules/
└── mod_example/
    ├── mod_example.xml
    ├── config.xml
    ├── language/en-GB/
    │   ├── mod_example.ini
    │   └── mod_example.sys.ini
    ├── services/
    │   └── provider.php
    ├── src/
    │   ├── Dispatcher/
    │   │   └── Dispatcher.php
    │   └── Helper/
    │       └── ExampleHelper.php
    ├── tmpl/
    │   └── default.php
    └── media/mod_example/
        ├── joomla.asset.json
        ├── css/
        └── js/
```

### Administrator Module Structure
```
/administrator/modules/
└── mod_example/
    ├── mod_example.xml
    ├── config.xml
    ├── language/en-GB/
    ├── services/
    │   └── provider.php
    ├── src/
    │   ├── Dispatcher/
    │   │   └── Dispatcher.php
    │   └── Helper/
    │       └── ExampleHelper.php
    └── tmpl/
        └── default.php
```

### Module Key Files

#### Manifest (`mod_example.xml`)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<extension type="module" client="site" method="upgrade">
    <name>mod_example</name>
    <author>Vendor</author>
    <version>1.0.0</version>
    <description>MOD_EXAMPLE_DESCRIPTION</description>
    <namespace path="src">Vendor\Module\Example</namespace>
    <files>
        <folder>language</folder>
        <folder>services</folder>
        <folder>src</folder>
        <folder>tmpl</folder>
    </files>
    <media destination="mod_example" folder="media">
        <folder>css</folder>
        <folder>js</folder>
        <filename>joomla.asset.json</filename>
    </media>
</extension>
```

> **IMPORTANT:** Configuration parameters are defined in a separate `config.xml` file, NOT in the manifest XML.

#### Config (`config.xml`)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<config>
    <fields name="params">
        <fieldset name="basic">
        </fieldset>
    </fields>
</config>
```

#### Service Provider (`services/provider.php`)
```php
<?php

defined('_JEXEC') or die;

use Joomla\CMS\Extension\Service\Provider\HelperFactory;
use Joomla\CMS\Extension\Service\Provider\Module;
use Joomla\CMS\Extension\Service\Provider\ModuleDispatcherFactory;
use Joomla\DI\Container;
use Joomla\DI\ServiceProviderInterface;

return new class () implements ServiceProviderInterface {
    public function register(Container $container): void
    {
        $container->registerServiceProvider(new ModuleDispatcherFactory('\\Vendor\\Module\\Example'));
        $container->registerServiceProvider(new HelperFactory('\\Vendor\\Module\\Example\\Site\\Helper'));
        $container->registerServiceProvider(new Module());
    }
};
```

#### Dispatcher (`src/Dispatcher/Dispatcher.php`)
```php
<?php

namespace Vendor\Module\Example\Dispatcher;

defined('_JEXEC') or die;

use Joomla\CMS\Dispatcher\AbstractModuleDispatcher;
use Joomla\CMS\Helper\HelperFactoryAwareInterface;
use Joomla\CMS\Helper\HelperFactoryAwareTrait;

class Dispatcher extends AbstractModuleDispatcher implements HelperFactoryAwareInterface
{
    use HelperFactoryAwareTrait;

    protected function getLayoutData(): array
    {
        $data = parent::getLayoutData();
        $helper = $this->getHelperFactory()->getHelper('ExampleHelper');

        $data['items'] = $helper->getItems($data['params'], $this->getApplication());

        return $data;
    }
}
```

#### Helper (`src/Helper/ExampleHelper.php`)
```php
<?php

namespace Vendor\Module\Example\Helper;

defined('_JEXEC') or die;

use Joomla\CMS\Application\CMSApplicationInterface;
use Joomla\Registry\Registry;

class ExampleHelper
{
    public function getItems(Registry $params, CMSApplicationInterface $app): array
    {
        // Business logic here
        return [];
    }
}
```

### Module Design Patterns

1. **Dispatcher Pattern**: All business logic is delegated through the Dispatcher, which calls Helper classes
2. **Helper Factory**: Helpers are instantiated via HelperFactory DI, not static calls
3. **No direct database access in Dispatcher**: Database queries belong in Helper classes
4. **Template data**: Pass data to templates via `getLayoutData()` return array
5. **Parameters**: Access module params via `$data['params']` in templates, `$params` argument in helpers
6. **Application access**: Use `$this->getApplication()` in Dispatcher, pass as argument to helpers

### Module Preferences
- Keep helper methods focused and testable
- Use the module's media folder for assets with Web Asset Manager
- Language constants follow `MOD_EXAMPLE_` prefix convention
- For admin modules, use `client="administrator"` in manifest