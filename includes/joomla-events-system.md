## Joomla 5 Events System Reference

### SubscriberInterface Implementation

All modern Joomla 5 plugins must implement `SubscriberInterface`:

```php
<?php

namespace Vendor\Plugin\Content\Example\Extension;

defined('_JEXEC') or die;

use Joomla\CMS\Event\Content\AfterSaveEvent;
use Joomla\CMS\Event\Content\BeforeDisplayEvent;
use Joomla\CMS\Plugin\CMSPlugin;
use Joomla\Event\SubscriberInterface;

final class Example extends CMSPlugin implements SubscriberInterface
{
    public static function getSubscribedEvents(): array
    {
        return [
            'onContentAfterSave'    => 'handleAfterSave',
            'onContentBeforeDisplay' => 'handleBeforeDisplay',
        ];
    }

    public function handleAfterSave(AfterSaveEvent $event): void
    {
        $context = $event->getContext();
        $item    = $event->getItem();
        $isNew   = $event->getIsNew();

        // Handle the event
    }

    public function handleBeforeDisplay(BeforeDisplayEvent $event): void
    {
        $context = $event->getContext();
        $item    = $event->getItem();
        $params  = $event->getParams();

        // Modify content before display
    }
}
```

### Core Event Names by Group

#### Content Events
| Event Name | Event Class | Triggered When |
|---|---|---|
| `onContentPrepare` | `ContentPrepareEvent` | Content is being prepared for display |
| `onContentAfterTitle` | `AfterTitleEvent` | After content title is rendered |
| `onContentBeforeDisplay` | `BeforeDisplayEvent` | Before content is displayed |
| `onContentAfterDisplay` | `AfterDisplayEvent` | After content is displayed |
| `onContentBeforeSave` | `BeforeSaveEvent` | Before content is saved |
| `onContentAfterSave` | `AfterSaveEvent` | After content is saved |
| `onContentBeforeDelete` | `BeforeDeleteEvent` | Before content is deleted |
| `onContentAfterDelete` | `AfterDeleteEvent` | After content is deleted |
| `onContentChangeState` | `ChangeStateEvent` | When content state changes (publish/unpublish) |
| `onContentBeforeChangeState` | `BeforeChangeStateEvent` | Before content state changes |

#### User Events
| Event Name | Event Class | Triggered When |
|---|---|---|
| `onUserLogin` | `LoginEvent` | User logs in |
| `onUserLogout` | `LogoutEvent` | User logs out |
| `onUserAfterSave` | `AfterSaveEvent` | After user profile is saved |
| `onUserBeforeSave` | `BeforeSaveEvent` | Before user profile is saved |
| `onUserAfterDelete` | `AfterDeleteEvent` | After user is deleted |
| `onUserBeforeDelete` | `BeforeDeleteEvent` | Before user is deleted |
| `onUserAuthorisation` | `AuthorisationEvent` | During authorisation check |

#### System Events
| Event Name | Event Class | Triggered When |
|---|---|---|
| `onAfterInitialise` | `AfterInitialiseEvent` | After application initialisation |
| `onAfterRoute` | `AfterRouteEvent` | After routing is complete |
| `onBeforeRender` | `BeforeRenderEvent` | Before page rendering |
| `onAfterRender` | `AfterRenderEvent` | After page rendering |
| `onBeforeCompileHead` | `BeforeCompileHeadEvent` | Before head section is compiled |
| `onAfterRespond` | `AfterRespondEvent` | After response is sent |

#### Installer Events
| Event Name | Triggered When |
|---|---|
| `onExtensionBeforeInstall` | Before extension installation |
| `onExtensionAfterInstall` | After extension installation |
| `onExtensionBeforeUpdate` | Before extension update |
| `onExtensionAfterUpdate` | After extension update |
| `onExtensionBeforeUninstall` | Before extension uninstallation |
| `onExtensionAfterUninstall` | After extension uninstallation |

### Custom Event Creation

#### Defining a Custom Event Class
```php
<?php

namespace Vendor\Component\Example\Administrator\Event;

defined('_JEXEC') or die;

use Joomla\CMS\Event\AbstractEvent;
use Joomla\CMS\Event\Result\ResultAware;
use Joomla\CMS\Event\Result\ResultAwareInterface;
use Joomla\CMS\Event\Result\ResultTypeStringAware;

class ItemProcessedEvent extends AbstractEvent implements ResultAwareInterface
{
    use ResultAware;
    use ResultTypeStringAware;

    public function __construct(
        string $name,
        array $arguments = []
    ) {
        parent::__construct($name, $arguments);

        // Validate required arguments
        if (!isset($arguments['item'])) {
            throw new \BadMethodCallException("Argument 'item' is required.");
        }
    }

    // Typed getter for the item
    public function getItem(): object
    {
        return $this->arguments['item'];
    }

    // Typed getter for context
    public function getContext(): string
    {
        return $this->arguments['context'] ?? '';
    }
}
```

#### Dispatching Custom Events from Components
```php
<?php

use Joomla\CMS\Event\AbstractEvent;
use Joomla\CMS\Factory;
use Vendor\Component\Example\Administrator\Event\ItemProcessedEvent;

// Create the event
$event = new ItemProcessedEvent('onExampleItemProcessed', [
    'item'    => $item,
    'context' => 'com_example.item',
]);

// Dispatch via the application's event dispatcher
Factory::getApplication()->getDispatcher()->dispatch(
    'onExampleItemProcessed',
    $event
);

// Read results from plugins
$results = $event->getResult();
```

#### Alternative: Using AbstractEvent Factory Method
```php
$event = AbstractEvent::create('onExampleItemProcessed', [
    'subject' => $item,
    'context' => 'com_example.item',
]);

$this->getDispatcher()->dispatch($event->getName(), $event);
```

### Event Result Handling

```php
// In plugin - adding results
public function handleItemProcessed(ItemProcessedEvent $event): void
{
    // Add result using ResultAware trait
    $event->addResult('processed-by-example-plugin');
}

// In component - reading results
$event = new ItemProcessedEvent('onExampleItemProcessed', ['item' => $item]);
Factory::getApplication()->getDispatcher()->dispatch('onExampleItemProcessed', $event);

$results = $event->getResult();
foreach ($results as $result) {
    // Handle each plugin's result
}
```

### Event Naming Conventions

- **Prefix with `on`**: All event names start with `on`
- **Component events**: `on{ComponentName}{Entity}{Action}` (e.g., `onExampleItemProcessed`)
- **Use PascalCase**: `onContentAfterSave`, not `on_content_after_save`
- **Before/After pairs**: Provide both for operations that can be intercepted

### Plugin Group Registration

Plugins must be registered in the correct group in their manifest XML:
```xml
<extension type="plugin" group="content" method="upgrade">
```

Common groups: `content`, `system`, `user`, `authentication`, `webservices`, `console`, `task`, `editors`, `editors-xtd`, `fields`, `finder`, `installer`, `media-action`, `quickicon`, `workflow`

### Migration from Legacy Event Handling

```php
// WRONG: Legacy onContentAfterSave (Joomla 3/4 style)
public function onContentAfterSave($context, $item, $isNew): void

// RIGHT: Modern typed event (Joomla 5 style)
public function handleAfterSave(AfterSaveEvent $event): void
{
    $context = $event->getContext();
    $item    = $event->getItem();
    $isNew   = $event->getIsNew();
}
```

### Best Practices

1. **Always use typed event classes** instead of generic argument arrays
2. **Implement SubscriberInterface** - never use legacy `onEventName` method naming as sole registration
3. **Use `final` class** for plugin extensions to prevent unintended inheritance
4. **Keep event handlers focused** - one handler per concern
5. **Don't throw exceptions** in event handlers unless the operation must be blocked
6. **Use ResultAwareInterface** when plugins need to return data to the dispatcher
7. **Document custom events** with PHPDoc for discoverability