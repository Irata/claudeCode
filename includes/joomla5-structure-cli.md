## Joomla 5 CLI Console Command Structure

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
    └── Extension/
        └── ExampleConsolePlugin.php
    └── Console/
        └── ExampleCommand.php
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
use Vendor\Plugin\Console\Example\Console\ExampleCommand;

final class ExampleConsolePlugin extends CMSPlugin implements SubscriberInterface
{
    public static function getSubscribedEvents(): array
    {
        return [
            ApplicationEvents::BEFORE_EXECUTE => 'registerCommands',
        ];
    }

    public function registerCommands(): void
    {
        $this->getApplication()->addCommand(new ExampleCommand());
    }
}
```

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