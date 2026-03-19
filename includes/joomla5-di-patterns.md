## Joomla 5 Dependency Injection Patterns

### Component Service Provider (`services/provider.php`)

```php
<?php

defined('_JEXEC') or die;

use Joomla\CMS\Dispatcher\ComponentDispatcherFactoryInterface;
use Joomla\CMS\Extension\ComponentInterface;
use Joomla\CMS\Extension\Service\Provider\CategoryFactory;
use Joomla\CMS\Extension\Service\Provider\ComponentDispatcherFactory;
use Joomla\CMS\Extension\Service\Provider\MVCFactory;
use Joomla\CMS\Extension\Service\Provider\RouterFactory;
use Joomla\CMS\HTML\Registry;
use Joomla\CMS\MVC\Factory\MVCFactoryInterface;
use Joomla\DI\Container;
use Joomla\DI\ServiceProviderInterface;
use Vendor\Component\Example\Administrator\Extension\ExampleComponent;

return new class () implements ServiceProviderInterface {
    public function register(Container $container): void
    {
        // Register core component factories
        $container->registerServiceProvider(new CategoryFactory('\\Vendor\\Component\\Example'));
        $container->registerServiceProvider(new ComponentDispatcherFactory('\\Vendor\\Component\\Example'));
        $container->registerServiceProvider(new MVCFactory('\\Vendor\\Component\\Example'));
        $container->registerServiceProvider(new RouterFactory('\\Vendor\\Component\\Example'));

        // Register the component extension
        $container->set(
            ComponentInterface::class,
            function (Container $container) {
                $component = new ExampleComponent($container->get(ComponentDispatcherFactoryInterface::class));
                $component->setMVCFactory($container->get(MVCFactoryInterface::class));
                $component->setRegistry($container->get(Registry::class));
                $component->setRouterFactory($container->get(RouterFactory::class));

                return $component;
            }
        );
    }
};
```

### Module Service Provider (`services/provider.php`)

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

### Plugin Service Provider (`services/provider.php`)

```php
<?php

defined('_JEXEC') or die;

use Joomla\CMS\Extension\PluginInterface;
use Joomla\CMS\Factory;
use Joomla\CMS\Plugin\PluginHelper;
use Joomla\DI\Container;
use Joomla\DI\ServiceProviderInterface;
use Joomla\Event\DispatcherInterface;
use Vendor\Plugin\System\Example\Extension\Example;

return new class () implements ServiceProviderInterface {
    public function register(Container $container): void
    {
        $container->set(
            PluginInterface::class,
            function (Container $container) {
                $dispatcher = $container->get(DispatcherInterface::class);
                $plugin = new Example(
                    $dispatcher,
                    (array) PluginHelper::getPlugin('system', 'example')
                );
                $plugin->setApplication(Factory::getApplication());

                return $plugin;
            }
        );
    }
};
```

### Constructor Injection Patterns

#### Service Injection in Controllers
```php
<?php

namespace Vendor\Component\Example\Administrator\Controller;

use Joomla\CMS\MVC\Controller\AdminController;
use Joomla\CMS\MVC\Factory\MVCFactoryInterface;
use Joomla\CMS\Application\CMSApplication;
use Joomla\Input\Input;

class ItemsController extends AdminController
{
    public function __construct(
        $config = [],
        MVCFactoryInterface $factory = null,
        ?CMSApplication $app = null,
        ?Input $input = null
    ) {
        parent::__construct($config, $factory, $app, $input);
    }
}
```

#### Service Injection in Models
```php
<?php

namespace Vendor\Component\Example\Administrator\Model;

use Joomla\CMS\MVC\Model\ListModel;
use Joomla\Database\DatabaseInterface;

class ItemsModel extends ListModel
{
    // Database is available via $this->getDatabase() (inherited)
    // Application is available via Factory::getApplication()
    // No need to inject DatabaseInterface manually in MVC models
}
```

### Common DI Service IDs

| Service Interface | Description |
|---|---|
| `Joomla\Database\DatabaseInterface` | Database connection |
| `Joomla\CMS\Application\CMSApplicationInterface` | Current application |
| `Joomla\CMS\User\UserFactoryInterface` | User factory |
| `Joomla\CMS\Mail\MailerFactoryInterface` | Mailer factory |
| `Joomla\CMS\Language\LanguageFactoryInterface` | Language factory |
| `Joomla\Event\DispatcherInterface` | Event dispatcher |
| `Joomla\CMS\Cache\CacheControllerFactoryInterface` | Cache factory |
| `Joomla\CMS\Session\SessionInterface` | Session |
| `Joomla\CMS\Document\DocumentInterface` | Document |
| `Joomla\CMS\Router\SiteRouter` | Site router |
| `Psr\Log\LoggerInterface` | PSR-3 logger |

### Accessing Services from the Container

```php
// From anywhere with access to the application
$db = Factory::getContainer()->get(DatabaseInterface::class);
$mailer = Factory::getContainer()->get(MailerFactoryInterface::class);

// From within a component extension class
$db = $this->getContainer()->get(DatabaseInterface::class);

// From controllers (via MVCFactory)
$db = $this->getModel()->getDatabase();

// From models (inherited method)
$db = $this->getDatabase();
```

### Accessing Component Services via bootComponent (Internal Pattern)

Joomla's `MVCComponent` does not natively expose its DI container. When code outside the component's own MVC stack needs to resolve component services (API controllers, plugins, other components, CLI commands), use the **bootComponent pattern**:

#### Step 1: Expose the container from the Extension class

The component's Extension class must implement `BootableExtensionInterface` and store the container passed to `boot()`:

```php
namespace Vendor\Component\Example\Administrator\Extension;

use Joomla\CMS\Extension\BootableExtensionInterface;
use Joomla\CMS\Extension\MVCComponent;
use Psr\Container\ContainerInterface;

class ExampleComponent extends MVCComponent implements BootableExtensionInterface
{
    private ?ContainerInterface $container = null;

    /**
     * @internal Used by controllers/plugins to resolve services.
     *           Joomla's MVCComponent does not expose the container natively.
     */
    public function getContainer(): ContainerInterface
    {
        if ($this->container === null) {
            throw new \RuntimeException('Component container not available. Has boot() been called?');
        }

        return $this->container;
    }

    #[\Override]
    public function boot(ContainerInterface $container): void
    {
        $this->container = $container;
        // Other boot logic...
    }
}
```

#### Step 2: Resolve services from anywhere

```php
use Vendor\Component\Example\Administrator\Service\SomeService;

// From any code with access to the application (controllers, plugins, CLI)
$service = $app->bootComponent('com_example')
    ->getContainer()
    ->get(SomeService::class);
```

#### When to use this pattern

| Context | How to get services |
|---------|-------------------|
| **Admin controllers** (within the component) | `$this->app->bootComponent('com_example')->getContainer()->get(Service::class)` |
| **API controllers** (within the component) | Same as admin — API controllers are in a separate namespace and don't have direct DI access |
| **Plugins** needing component services | `$this->getApplication()->bootComponent('com_example')->getContainer()->get(Service::class)` |
| **CLI commands** | `$this->getApplication()->bootComponent('com_example')->getContainer()->get(Service::class)` |
| **Other components** | `Factory::getApplication()->bootComponent('com_example')->getContainer()->get(Service::class)` |

#### Important notes

- This is an **internal convention**, not part of Joomla's public API — the same approach is used by Akeeba Backup and other major extensions
- `bootComponent()` triggers the component's `boot()` method if not already called, ensuring the container is populated
- Services resolved this way are the same singleton instances registered in `services/provider.php`
- The `@internal` docblock on `getContainer()` signals that this is a bridge method, not a public extension point
- **Never call `getContainer()` from within the component's own models or views** — those should use constructor injection via the service provider

### Anti-Patterns to Avoid

```php
// WRONG: Direct static factory calls (deprecated)
$db = JFactory::getDbo();
$user = JFactory::getUser();
$app = JFactory::getApplication();

// WRONG: Service locator in constructors
public function __construct()
{
    $this->db = Factory::getContainer()->get(DatabaseInterface::class);
}

// RIGHT: Constructor injection
public function __construct(
    private readonly DatabaseInterface $db
) {}

// WRONG: Using global state
global $mainframe;

// RIGHT: Inject the application
public function __construct(
    private readonly CMSApplicationInterface $app
) {}
```

### Extension Component Class Pattern

```php
<?php

namespace Vendor\Component\Example\Administrator\Extension;

use Joomla\CMS\Extension\BootableExtensionInterface;
use Joomla\CMS\Extension\MVCComponent;
use Joomla\CMS\HTML\HTMLRegistryAwareTrait;
use Psr\Container\ContainerInterface;

class ExampleComponent extends MVCComponent implements BootableExtensionInterface
{
    use HTMLRegistryAwareTrait;

    public function boot(ContainerInterface $container): void
    {
        // Register custom services, HTML helpers, etc.
    }
}
```

### Best Practices

1. **Prefer constructor injection** over service locator pattern
2. **Use interfaces** for type hints, not concrete classes
3. **Register services as shared** (singleton) when appropriate
4. **Use PHP 8.3+ constructor promotion** with `readonly` properties
5. **Avoid circular dependencies** - use lazy loading or factory patterns
6. **Keep service providers simple** - complex logic belongs in the services themselves
7. **Use `#[Override]`** attribute when overriding parent methods