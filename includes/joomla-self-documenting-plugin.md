## Self-Documenting Plugins — a Read-Only Reference in the Options Screen

### The rule

**Every plugin ships at least basic documentation inside itself, shown in its own options screen.**
All groups, no exceptions — a plugin is the one extension type with no front end, no menu item and
no visible UI, so unless it explains itself the only way to find out what it does is to read its
source.

At minimum that means: what the plugin does, when it fires, and what it adds. Plugins that register
things with the application — routes, commands, task types — document those too.

This is not a nicety. The administrator deciding whether it is safe to disable a plugin, and the
developer inheriting the site three years from now, are both looking at the same options screen.

### What to document

**Baseline — every plugin, every group:**

| Include | Because |
|---|---|
| What the plugin does, in a sentence or two | The manifest `<description>` is often the only other clue, and it is usually one line |
| The events it subscribes to, and when each fires | Read from `getSubscribedEvents()` — free, and it cannot drift. See below |
| Anything it changes that is not obvious | Writes a table, injects a header, rewrites output, calls a remote service |
| What stops happening when it is disabled | The question actually being asked when someone opens this screen |
| Its dependencies | A component that must be installed, a second plugin that must be enabled, an API key that must be set |

**On top of the baseline, per group:**

| Group | Also document | Pattern |
|---|---|---|
| `webservices` | Every registered route, auth, query parameters and how they fail | `joomla-structure-api.md` → *Self-Documenting Webservices Plugin* |
| `console` | Every registered command, its arguments and options | `joomla-structure-cli.md` → *Self-Documenting Console Plugin* |
| `task` | Each task type it registers and the parameters each accepts | Same mechanics; derive from the routine map the plugin exposes |
| `content`, `system`, `user`, `auth` | The context strings it acts on, and any ordering/priority sensitivity | Baseline is usually enough |

### Derive, don't transcribe

A hand-written list drifts from what the plugin actually does; the whole reference then quietly
becomes a lie. Read the data off the extension itself wherever it already exists as objects.

**The event list is free for every plugin.** `SubscriberInterface::getSubscribedEvents()` is
`static`, so the field can call it without instantiating anything:

```php
use Vendor\Plugin\Content\Example\Extension\ExamplePlugin;

/**
 * The events this plugin listens for, read from the plugin's own subscription map.
 *
 * getSubscribedEvents() returns ['eventName' => 'method'] or
 * ['eventName' => ['method', $priority]] — handle both shapes.
 */
private function events(): string
{
    $rows = '';

    foreach (ExamplePlugin::getSubscribedEvents() as $event => $handler) {
        $priority = \is_array($handler) ? (int) ($handler[1] ?? 0) : 0;

        $rows .= '<tr>'
            . '<td class="text-nowrap"><code>' . $this->e($event) . '</code></td>'
            . '<td>' . Text::_('PLG_CONTENT_EXAMPLE_DOCS_EVENT_' . strtoupper($event)) . '</td>'
            . '<td class="text-end">' . $priority . '</td>'
            . '</tr>';
    }

    return '<table class="table table-sm align-middle mb-0"><thead><tr>'
        . '<th scope="col">' . Text::_('PLG_CONTENT_EXAMPLE_DOCS_COL_EVENT') . '</th>'
        . '<th scope="col">' . Text::_('PLG_CONTENT_EXAMPLE_DOCS_COL_WHEN') . '</th>'
        . '<th scope="col" class="text-end">' . Text::_('PLG_CONTENT_EXAMPLE_DOCS_COL_PRIORITY') . '</th>'
        . '</tr></thead><tbody>' . $rows . '</tbody></table>';
}
```

The event *names* come from the plugin; only the prose describing when each fires is written by
hand, and it lives in the `.ini` keyed by event name — so adding a subscription without documenting
it shows up immediately as an untranslated key on the screen.

### The mechanics

#### 1. The field class

A `FormField` that **stores nothing**: `getInput()` renders, and the value is never saved. There is
no shared runtime library across plugins, so each plugin carries its own field in `src/Field/`; the
shape below is what gets copied.

```php
<?php

namespace Vendor\Plugin\Content\Example\Field;

\defined('_JEXEC') or die;

use Joomla\CMS\Form\FormField;
use Joomla\CMS\Language\Text;

final class DocsField extends FormField
{
    protected $type = 'Docs';

    protected function getInput(): string
    {
        try {
            return '<div class="alert alert-info">' . Text::_('PLG_CONTENT_EXAMPLE_DOCS_SUMMARY') . '</div>'
                . '<p class="mt-3 mb-1"><strong>' . Text::_('PLG_CONTENT_EXAMPLE_DOCS_EVENTS_HEADING') . '</strong></p>'
                . $this->events()
                . '<p class="mt-3 mb-1"><strong>' . Text::_('PLG_CONTENT_EXAMPLE_DOCS_EFFECTS_HEADING') . '</strong></p>'
                . '<p class="mb-0">' . Text::_('PLG_CONTENT_EXAMPLE_DOCS_EFFECTS') . '</p>';
        } catch (\Throwable) {
            // See "Degrade, never fatal" below.
            return '<div class="alert alert-warning">'
                . Text::_('PLG_CONTENT_EXAMPLE_DOCS_UNAVAILABLE') . '</div>';
        }
    }

    /** Escape every *dynamic* value. Text::_() output is deliberately not escaped. */
    private function e(string $value): string
    {
        return htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
    }
}
```

#### 2. Manifest config block

`addfieldprefix` is what makes the custom type resolvable — see Trap 1.

```xml
<config>
    <fields name="params">
        <fieldset name="basic"
                  addfieldprefix="Vendor\Plugin\Content\Example\Field">
            <field name="docs"
                   type="docs"
                   label="PLG_CONTENT_EXAMPLE_DOCS_LABEL"
                   description="PLG_CONTENT_EXAMPLE_DOCS_DESC"
            />
        </fieldset>
    </fields>
</config>
```

An existing `<files><folder>src</folder></files>` already ships `src/Field/` — no file-list change
is needed beyond the `<config>` block.

#### 3. Plugins that *do* have settings

The reference does not compete with real settings: give it its own fieldset so it renders as a
separate tab, and leave `basic` to the things an administrator actually changes.

```xml
<fieldset name="documentation"
          label="PLG_CONTENT_EXAMPLE_DOCS_FIELDSET"
          addfieldprefix="Vendor\Plugin\Content\Example\Field">
```

Where a setting has a non-obvious effect, document it in the reference rather than stretching the
field's own `description` attribute into a paragraph.

#### 4. Language strings

All prose belongs in the `.ini`, never in the PHP. `Text::_()` output is **not escaped** by the
field, so simple markup (`<code>`, `&rarr;`, `&lt;`) renders — which is what you want for inline
examples. Escape only the *dynamic* values, via the `e()` helper.

The `.sys.ini` description is static and cannot enumerate anything, so give it a one-line summary —
that is what the Plugins manager list and the install screen show. The dynamic detail belongs in
the options field.

### Degrade, never fatal

A plugin routinely outlives the thing it documents: the component is uninstalled, part-installed,
or disabled while the plugin remains. Wrap anything that reaches outside the plugin —
`bootComponent()`, a database query, a container lookup — and return a warning rather than letting
the options screen fatal:

```php
catch (\Throwable) {
    return '<div class="alert alert-warning">' . Text::_('..._UNAVAILABLE') . '</div>';
}
```

An options screen that white-screens is a worse outcome than one admitting it cannot build its
list, and it is far harder to diagnose — the administrator sees a broken Plugins manager, not a
missing component.

### Trap 1 — a custom field type that does not resolve falls back to a text input, silently

If `addfieldprefix` is missing or the namespace is wrong, Joomla does **not** error. It resolves
`type="docs"` to `Joomla\CMS\Form\Field\TextField` and renders a stray text box on the options
screen. Nothing in a lint, a syntax check, or an install will tell you — the form builds
successfully, it just builds the wrong field.

**Always render the field once and assert the resolved class** (harness below).

### Trap 2 — know which application renders the field

The options screen always renders inside `AdministratorApplication`. Two consequences that bite in
opposite directions:

- **`Uri::root()` is safe here** — `AdministratorApplication::doExecute()` has already reset the URI
  root back to the site root, so no `/administrator` segment leaks into generated addresses. It is
  **not** safe anywhere else: copied into a console, task or CLI context it yields
  `https://joomla.invalid/set/by/console/application/` unless the site sets `$live_site`.
- **Anything invoked by path rather than by URL wants `JPATH_ROOT`**, not `Uri`. A console command
  is run as `php <JPATH_ROOT>/cli/joomla.php …`; deriving that from `Uri::root()` produces a line
  that cannot work.

Group specifics: `joomla-structure-api.md` → *Trap 2* (the root reset, and reproducing it in a
harness); `joomla-structure-cli.md` → *Trap 3* (filesystem path, not URL).

### Verifying it (build the form from the real manifest)

Rendering programmatically is the only thing that catches Trap 1. Run from the Joomla root:

```php
// Pretend to be an administrator web request.
$_SERVER['HTTP_HOST']   = 'example.local';
$_SERVER['SCRIPT_NAME'] = '/administrator/index.php';
$_SERVER['REQUEST_URI'] = '/administrator/';   // the DIRECTORY — see the API include's note
$_SERVER['HTTPS']       = 'on';

\define('_JEXEC', 1);
\define('JPATH_BASE', 'E:/www/example');
require_once JPATH_BASE . '/includes/defines.php';
require_once JPATH_BASE . '/includes/framework.php';

$container = \Joomla\CMS\Factory::getContainer();
$container->alias('session', 'session.cli')
    ->alias(\Joomla\Session\SessionInterface::class, 'session.cli');

$app = $container->get(\Joomla\CMS\Application\ConsoleApplication::class);
\Joomla\CMS\Factory::$application = $app;

// A real application registers extension namespaces during execute(); without this every
// extension class silently fails to autoload and the field falls back to TextField.
\JLoader::register('JNamespacePsr4Map', JPATH_LIBRARIES . '/namespacemap.php');
(new \JNamespacePsr4Map())->load();

$app->getLanguage()->load('plg_content_example', JPATH_BASE . '/plugins/content/example');

$manifest = simplexml_load_file(JPATH_BASE . '/plugins/content/example/example.xml');
$xml      = '<?xml version="1.0"?><form>' . $manifest->config->fields->asXML() . '</form>';
$form     = \Joomla\CMS\Form\Form::getInstance('t' . mt_rand(), $xml, ['control' => 'jform']);

$field = $form->getField('docs', 'params');
echo $field ? 'resolved as ' . $field::class . "\n" : "FAIL: did not resolve\n";   // Trap 1

$html = $form->renderField('docs', 'params');
preg_match_all('/PLG_[A-Z_]+/', $html, $m);
echo $m[0] ? "FAIL untranslated: " . implode(', ', array_unique($m[0])) . "\n" : "all keys resolved\n";
```

**Pass criteria, every group:** the field resolves to your own class (not `TextField`), and no
`PLG_…` constant survives in the rendered output.

**Add the group-specific assertions on top:**

- `webservices` — the emitted URLs carry no `/administrator` segment, and the harness reproduces
  the admin root reset first (`joomla-structure-api.md` → *Verifying it*)
- `console` — every command in `CommandRegistry::commands()` appears in the rendered HTML, and no
  rendered path contains `/administrator` (`joomla-structure-cli.md` → *Verifying it*)
- any group — every event in `getSubscribedEvents()` appears in the rendered HTML

### Keeping it honest

The reference lives next to the thing it documents, but only introspected content is enforced by
construction. For everything written by hand, treat the prose and the behaviour as one unit: when
the subscription map, the routes, or the commands change, the `.ini` changes in the same commit.

Where a project also keeps a `.http` request file or a `README`, prefer the options screen as the
source of truth and let the other file hold only what it uniquely needs.
