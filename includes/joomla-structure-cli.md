## Joomla CLI Console Command Structure

### CLI Command Location Within a Component
```
/administrator/components/com_example/
└── src/
    └── Console/
        ├── ExampleImportCommand.php
        └── ExampleExportCommand.php
```

### Standalone CLI Plugin Structure
```
/plugins/console/example/
├── example.xml
├── language/en-GB/
│   ├── plg_console_example.ini
│   └── plg_console_example.sys.ini
├── services/
│   └── provider.php
└── src/
    ├── Console/
    │   ├── CommandRegistry.php      ← the one list of commands (see pattern below)
    │   └── ExampleCommand.php
    ├── Extension/
    │   └── ExampleConsolePlugin.php
    └── Field/
        └── CommandsField.php        ← command reference (see pattern below)
```

### CLI Command Key Files

#### Command Class (extends AbstractCommand)
```php
<?php

namespace Vendor\Component\Example\Administrator\Console;

defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\Console\Command\AbstractCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputArgument;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Console\Style\SymfonyStyle;

class ExampleImportCommand extends AbstractCommand
{
    protected static $defaultName = 'example:import';

    protected function configure(): void
    {
        $this->setDescription('Import example data from a CSV file');
        $this->setHelp('This command imports data from a specified CSV file into the example component.');

        $this->addArgument(
            'file',
            InputArgument::REQUIRED,
            'Path to the CSV file to import'
        );

        $this->addOption(
            'dry-run',
            null,
            InputOption::VALUE_NONE,
            'Simulate the import without making changes'
        );

        $this->addOption(
            'batch-size',
            'b',
            InputOption::VALUE_REQUIRED,
            'Number of records per batch',
            '100'
        );
    }

    protected function doExecute(InputInterface $input, OutputInterface $output): int
    {
        $io = new SymfonyStyle($input, $output);

        $file = $input->getArgument('file');
        $dryRun = $input->getOption('dry-run');
        $batchSize = (int) $input->getOption('batch-size');

        if (!file_exists($file)) {
            $io->error(sprintf('File not found: %s', $file));
            return Command::FAILURE;
        }

        $io->title('Example Data Import');

        if ($dryRun) {
            $io->warning('Running in dry-run mode. No changes will be made.');
        }

        // Processing with progress bar
        $io->progressStart($totalRecords);

        foreach ($batches as $batch) {
            // Process batch
            $io->progressAdvance($batchSize);
        }

        $io->progressFinish();

        $io->success(sprintf('Successfully imported %d records.', $count));

        return Command::SUCCESS;
    }
}
```

#### Registration via Component Service Provider
```php
// In services/provider.php, register commands in the boot() method
public function boot(ContainerInterface $container): void
{
    // Register CLI commands
    if ($container->has(ConsoleApplication::class)) {
        $app = $container->get(ConsoleApplication::class);
        $app->addCommand(new ExampleImportCommand());
        $app->addCommand(new ExampleExportCommand());
    }
}
```

#### Registration via Console Plugin
```php
<?php

namespace Vendor\Plugin\Console\Example\Extension;

defined('_JEXEC') or die;

use Joomla\Application\ApplicationEvents;
use Joomla\CMS\Plugin\CMSPlugin;
use Joomla\Event\SubscriberInterface;
use Vendor\Plugin\Console\Example\Console\CommandRegistry;

final class ExampleConsolePlugin extends CMSPlugin implements SubscriberInterface
{
    protected $autoloadLanguage = true;

    public static function getSubscribedEvents(): array
    {
        return [
            ApplicationEvents::BEFORE_EXECUTE => 'registerCommands',
        ];
    }

    public function registerCommands(): void
    {
        // The commands come from CommandRegistry, never an inline list here — the
        // options screen documents that same registry. See the pattern below.
        foreach (CommandRegistry::commands() as $command) {
            $this->getApplication()->addCommand($command);
        }
    }
}
```

### Self-Documenting Console Plugin (command reference in the plugin options)

**Required for every console plugin, new or revised.** A plugin that registers CLI commands must
publish those commands in its own options screen. Commands declared only inside
`registerCommands()` are discoverable by running `php cli/joomla.php list` — which needs shell
access the administrator reading the Plugins manager may not have, and which still will not explain
what a command's arguments mean.

The plugin has no settings of its own, so its options tab is free real estate. Fill it with a
read-only reference rendered against **this installation**: the real console entry-point path, and
each command's real arguments and options.

Unlike the webservices equivalent (`joomla-structure-api.md` → *Self-Documenting Webservices
Plugin*), **nothing here is transcribed by hand**. A route table has to be mirrored from
`onBeforeApiRoute()` and can drift from it; a command is an object that already knows its own name,
description, arguments and options. Read them off the command and drift becomes impossible.

#### 1. One registry, two consumers (`src/Console/CommandRegistry.php`)

The registry is what makes the screen trustworthy: the listener and the field walk the same list,
so the options screen cannot document a command the plugin does not actually register.

```php
<?php

namespace Vendor\Plugin\Console\Example\Console;

\defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\Console\Command\AbstractCommand;

/**
 * The commands this plugin owns — the single list.
 *
 * Consumed by the plugin's BEFORE_EXECUTE listener (which registers them) and by
 * CommandsField (which documents them).
 */
final class CommandRegistry
{
    /** @return AbstractCommand[] */
    public static function commands(): array
    {
        // Dependency-free commands construct directly. Commands with injected models or
        // services come from the component container: ConsoleApplication and
        // AdministratorApplication both use ExtensionManagerTrait, so bootComponent()
        // resolves identically whether this runs under the CLI or the options screen.
        $container = Factory::getApplication()->bootComponent('com_example')->getContainer();

        return [
            new ExampleClearcacheCommand(),
            $container->get(ExampleImportCommand::class),
        ];
    }
}
```

#### 2. The listener consumes it (`src/Extension/ExampleConsolePlugin.php`)

```php
public function registerCommands(): void
{
    foreach (CommandRegistry::commands() as $command) {
        $this->getApplication()->addCommand($command);
    }
}
```

#### 3. The field class (`src/Field/CommandsField.php`)

```php
<?php

namespace Vendor\Plugin\Console\Example\Field;

\defined('_JEXEC') or die;

use Joomla\CMS\Form\FormField;
use Joomla\CMS\Language\Text;
use Joomla\Console\Command\AbstractCommand;
use Symfony\Component\Console\Input\InputOption;
use Vendor\Plugin\Console\Example\Console\CommandRegistry;

/**
 * Read-only documentation of the CLI commands this plugin registers.
 *
 * Stores nothing: getInput() renders and the value is never saved. Every argument and
 * option is read off the command's own InputDefinition, so this screen cannot drift
 * from what configure() declares.
 */
final class CommandsField extends FormField
{
    protected $type = 'Commands';

    protected function getInput(): string
    {
        try {
            $commands = CommandRegistry::commands();
        } catch (\Throwable) {
            // A console plugin can legitimately outlive its component (part-installed, or
            // the component removed). An options screen that fatals is a worse outcome
            // than one admitting it cannot list the commands.
            return '<div class="alert alert-warning">'
                . Text::_('PLG_CONSOLE_EXAMPLE_COMMANDS_UNAVAILABLE') . '</div>';
        }

        $base = $this->cliBase();
        $html = '<div class="alert alert-info">'
            . Text::sprintf('PLG_CONSOLE_EXAMPLE_COMMANDS_INTRO', $this->e($base)) . '</div>';

        foreach ($commands as $command) {
            if ($command->isHidden()) {
                continue;
            }

            $html .= $this->commandBlock($command, $base);
        }

        return $html;
    }

    /**
     * The console entry point for this site, e.g. php /var/www/example/cli/joomla.php.
     *
     * A filesystem path, NOT a URL — Uri::root() has no place here (Trap 3). Backslashes
     * are normalised so the line pastes cleanly into a shell on Windows too.
     */
    private function cliBase(): string
    {
        return 'php ' . str_replace('\\', '/', JPATH_ROOT) . '/cli/joomla.php';
    }

    private function commandBlock(AbstractCommand $command, string $base): string
    {
        // getSynopsis() yields e.g. "example:items:import [--dry-run] [--] <file>".
        $synopsis = $base . ' ' . $command->getSynopsis();

        return '<div class="card mb-3">'
            . '<div class="card-header"><code>' . $this->e((string) $command->getName()) . '</code></div>'
            . '<div class="card-body">'
            . '<p class="mb-2">' . $this->e($command->getDescription()) . '</p>'
            . '<p class="text-break mb-2"><code>' . $this->e($synopsis) . '</code></p>'
            . $this->help($command, $base)
            . $this->arguments($command)
            . $this->options($command)
            . '</div></div>';
    }

    /**
     * getHelp(), never getProcessedHelp() — see Trap 2. The placeholders are substituted
     * here against the real console entry point instead.
     */
    private function help(AbstractCommand $command, string $base): string
    {
        $help = trim($command->getHelp());

        if ($help === '') {
            return '';
        }

        $help = str_replace(
            ['%command.name%', '%command.full_name%'],
            [(string) $command->getName(), $base . ' ' . $command->getName()],
            $help
        );

        return '<p class="text-muted mb-2">' . nl2br($this->e($help)) . '</p>';
    }

    private function arguments(AbstractCommand $command): string
    {
        $rows = '';

        foreach ($command->getDefinition()->getArguments() as $argument) {
            $rows .= '<tr>'
                . '<td class="text-nowrap"><code>' . $this->e($argument->getName()) . '</code></td>'
                . '<td>' . Text::_($argument->isRequired()
                    ? 'PLG_CONSOLE_EXAMPLE_COMMANDS_REQUIRED'
                    : 'PLG_CONSOLE_EXAMPLE_COMMANDS_OPTIONAL') . '</td>'
                . '<td>' . $this->e($argument->getDescription()) . '</td>'
                . '<td>' . $this->defaultValue($argument->getDefault()) . '</td>'
                . '</tr>';
        }

        return $rows === '' ? '' : $this->table(
            'PLG_CONSOLE_EXAMPLE_COMMANDS_ARGUMENTS',
            'PLG_CONSOLE_EXAMPLE_COMMANDS_COL_ARGUMENT',
            'PLG_CONSOLE_EXAMPLE_COMMANDS_COL_REQUIRED',
            $rows
        );
    }

    private function options(AbstractCommand $command): string
    {
        $rows = '';

        foreach ($command->getDefinition()->getOptions() as $option) {
            $name = '--' . $option->getName();

            if ($option->getShortcut()) {
                $name .= ', -' . $option->getShortcut();
            }

            $rows .= '<tr>'
                . '<td class="text-nowrap"><code>' . $this->e($name) . '</code></td>'
                . '<td>' . Text::_($this->valueModeKey($option)) . '</td>'
                . '<td>' . $this->e($option->getDescription()) . '</td>'
                . '<td>' . $this->defaultValue($option->getDefault()) . '</td>'
                . '</tr>';
        }

        return $rows === '' ? '' : $this->table(
            'PLG_CONSOLE_EXAMPLE_COMMANDS_OPTIONS',
            'PLG_CONSOLE_EXAMPLE_COMMANDS_COL_OPTION',
            'PLG_CONSOLE_EXAMPLE_COMMANDS_COL_VALUE',
            $rows
        );
    }

    private function valueModeKey(InputOption $option): string
    {
        if (!$option->acceptValue()) {
            return 'PLG_CONSOLE_EXAMPLE_COMMANDS_VALUE_NONE';       // a flag
        }

        return $option->isValueRequired()
            ? 'PLG_CONSOLE_EXAMPLE_COMMANDS_VALUE_REQUIRED'
            : 'PLG_CONSOLE_EXAMPLE_COMMANDS_VALUE_OPTIONAL';
    }

    /** A VALUE_NONE option defaults to false; render that as "no default", not as "false". */
    private function defaultValue(mixed $value): string
    {
        if ($value === null || $value === false || $value === [] || $value === '') {
            return '<span class="text-muted">&mdash;</span>';
        }

        return '<code>' . $this->e(\is_array($value) ? implode(', ', $value) : (string) $value) . '</code>';
    }

    private function table(string $headingKey, string $firstColKey, string $secondColKey, string $rows): string
    {
        return '<p class="mt-3 mb-1"><strong>' . Text::_($headingKey) . '</strong></p>'
            . '<table class="table table-sm align-middle mb-0"><thead><tr>'
            . '<th scope="col">' . Text::_($firstColKey) . '</th>'
            . '<th scope="col">' . Text::_($secondColKey) . '</th>'
            . '<th scope="col">' . Text::_('PLG_CONSOLE_EXAMPLE_COMMANDS_COL_PURPOSE') . '</th>'
            . '<th scope="col">' . Text::_('PLG_CONSOLE_EXAMPLE_COMMANDS_COL_DEFAULT') . '</th>'
            . '</tr></thead><tbody>' . $rows . '</tbody></table>';
    }

    private function e(string $value): string
    {
        return htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
    }
}
```

Where a command takes a record id, add worked examples naming records that actually exist on this
site — query them exactly as `EndpointsField::liveResources()` does in `joomla-structure-api.md`,
with the same `catch (\Throwable) { return []; }` degradation.

#### 4. Manifest config block (`example.xml`)

`addfieldprefix` is what makes the custom type resolvable — see Trap 1.

```xml
<config>
    <fields name="params">
        <!-- Documentation only; this plugin stores no settings. -->
        <fieldset name="basic"
                  addfieldprefix="Vendor\Plugin\Console\Example\Field">
            <field name="commands"
                   type="commands"
                   label="PLG_CONSOLE_EXAMPLE_COMMANDS_LABEL"
                   description="PLG_CONSOLE_EXAMPLE_COMMANDS_DESC"
            />
        </fieldset>
    </fields>
</config>
```

#### 5. Language strings

All prose belongs in the `.ini`, never in the PHP. `Text::_()` output is **not** escaped by the
field, so simple markup renders; escape only the *dynamic* values, via the `e()` helper.

The `.sys.ini` description is static and cannot enumerate arguments, so give it a one-line summary
naming the commands — that is what the Plugins manager list and the install screen show.

```ini
PLG_CONSOLE_EXAMPLE_COMMANDS_LABEL="Available Commands"
PLG_CONSOLE_EXAMPLE_COMMANDS_DESC="Reference only — this plugin has no settings to change. The commands below are read from the plugin itself, so they always match what is installed."
PLG_CONSOLE_EXAMPLE_COMMANDS_INTRO="Run these from the site root as the web-server user. Commands are registered only while this plugin is <strong>enabled</strong>; disable it and they disappear from <code>%s list</code>."
PLG_CONSOLE_EXAMPLE_COMMANDS_UNAVAILABLE="The commands cannot be listed — the com_example component appears to be missing or disabled. Reinstall it, or disable this plugin."
```

#### What the reference must cover

| Include | Because |
|---|---|
| Every registered command, read from the registry | The whole point; a hand-written list drifts |
| The full console entry-point path | `php cli/joomla.php` alone fails from the wrong working directory |
| Each argument, and whether it is required | The synopsis shows shape, not meaning |
| Each option, its shortcut, and whether it takes a value | `--batch-size 100` and `--dry-run` are used differently |
| Defaults | Saves reading the source to find out what happens when it is omitted |
| That commands exist only while the plugin is enabled | The options screen is reachable for a disabled plugin |
| Worked examples using real record ids, where a command takes one | Turns the screen into something copy-pasteable |

#### Trap 1 — a custom field type that does not resolve falls back to a text input, silently

Identical to the webservices case: a missing or wrong `addfieldprefix` resolves `type="commands"`
to `Joomla\CMS\Form\Field\TextField` and renders a stray text box, with no error from a lint, a
syntax check, or an install. Full explanation in `joomla-structure-api.md` → *Trap 1*. Always
render the field once and assert the resolved class.

#### Trap 2 — `getProcessedHelp()` builds its example from `$_SERVER['PHP_SELF']`

`AbstractCommand::getProcessedHelp()` substitutes `%command.full_name%` with
`$_SERVER['PHP_SELF'] . ' ' . $name`. Under CLI that gives the intended `cli/joomla.php …`. On the
plugin options screen — an administrator **web** request — it becomes
`/administrator/index.php example:import`: a copy-pasteable instruction that cannot work.

Call `getHelp()` and substitute the placeholders yourself against `cliBase()`, as above.

#### Trap 3 — the address here is a filesystem path, not a URL

The webservices field derives `Uri::root()`. Do not carry that across: a console command is invoked
by path, and `JPATH_ROOT` is the correct source. (`Uri::root()` would also mislead anyone who then
copied `apiBase()` into a real console context, where it yields `https://joomla.invalid/…` unless
the site sets `$live_site`.)

#### Trap 4 — commands with dependencies cannot be `new`'d inside a form field

This is what forces the registry rather than letting the field build its own list. A command taking
an injected model or service cannot be constructed with a bare `new` on the options screen, and a
field that quietly maintains a second, simpler list reintroduces exactly the drift the
introspection was meant to eliminate. Note that `CommandRegistry::commands()` boots the component
during an administrator request — harmless, but it is why the whole call is wrapped in `try`.

#### Trap 5 — `getDefinition()` is command-only until the application merges its own

Do not call `mergeApplicationDefinition()` to "complete" the definition. It folds in the
application-wide options (`--verbose`, `--quiet`, `--no-interaction` …), which belong to
`php cli/joomla.php` rather than to this command, and listing them per command buries the two or
three options that are actually the command's own. Read the definition as it comes.

#### Verifying it (build the form from the real manifest)

Use the harness in `joomla-structure-api.md` → *Verifying it*, with two changes:

- **Drop the URL assertions and the `Uri::root()` reset.** This field never touches `Uri`, so the
  administrator root-reset dance that harness performs is irrelevant here.
- **Add the drift assertion** — the check the webservices version cannot make:

```php
$html = $form->renderField('commands', 'params');

foreach (\Vendor\Plugin\Console\Example\Console\CommandRegistry::commands() as $command) {
    echo str_contains($html, (string) $command->getName())
        ? "ok {$command->getName()}\n"
        : "FAIL missing: {$command->getName()}\n";
}
```

**Pass criteria:** the field resolves to your own class (not `TextField`), no `PLG_…` constants
survive in the output, every command in the registry appears in the rendered HTML, and no rendered
path contains `/administrator` (which would mean Trap 2 had slipped back in via
`getProcessedHelp()`).

#### Keeping it honest

Adding a command means adding it to `CommandRegistry::commands()` — the listener and the options
screen both follow from that. Nothing else needs touching, and nothing else *should* be touched: a
second list anywhere is a drift source.

### CLI Command Conventions

#### Command Naming
- Use colon-separated namespaces: `component:action` (e.g., `example:import`, `example:export`)
- Group related commands under the same prefix
- Use lowercase with hyphens for multi-word actions: `example:clear-cache`

#### Exit Codes
- `Command::SUCCESS` (0) - Command completed successfully
- `Command::FAILURE` (1) - Command failed with an error
- `Command::INVALID` (2) - Invalid input/arguments

#### Output Levels
- Normal output: Always shown
- Verbose (`-v`): Additional details
- Very verbose (`-vv`): Debug-level information
- Debug (`-vvv`): Full trace information

```php
if ($output->isVerbose()) {
    $io->info(sprintf('Processing record %d of %d', $current, $total));
}

if ($output->isVeryVerbose()) {
    $io->writeln(sprintf('  Record data: %s', json_encode($record)));
}
```

#### Progress Indicators
- Use `SymfonyStyle::progressStart/Advance/Finish` for batch operations
- Use `SymfonyStyle::createTable()` for tabular output
- Use `$io->section()` to break up long output

### Task Scheduler Integration
```php
// Register as a Joomla Task Scheduler task type via a task plugin
// Plugin group: task
// Allows CLI commands to be scheduled through Joomla's built-in scheduler
```

### Best Practices
- Always validate input arguments and options early
- Provide meaningful error messages with `$io->error()`
- Support `--dry-run` for destructive operations
- Use progress bars for long-running operations
- Return appropriate exit codes
- Access Joomla services via `Factory::getContainer()->get()`
- Never use `echo` directly; always use Symfony Console output methods