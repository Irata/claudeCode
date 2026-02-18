# ClaudeCode - Joomla 5 Development Toolkit for Claude Code

A collection of specialised agents, reference includes, and project templates designed to streamline Joomla 5 extension development with [Claude Code](https://claude.ai/code). These files are maintained in a single repository and symlinked into individual PHPStorm project directories, ensuring consistent conventions and tooling across all Joomla projects.

## Repository Structure

```
ClaudeCode/
├── agents/
│   ├── data-model-architect.md
│   ├── create_agent_symlinks.bat
│   └── joomla/
│       ├── joomla-admin-builder.md
│       ├── joomla-api-builder.md
│       ├── joomla-architect.md
│       ├── joomla-build-agent.md
│       ├── joomla-cli-builder.md
│       ├── joomla-code-reviewer.md
│       ├── joomla-debugger.md
│       ├── joomla-language-manager.md
│       ├── joomla-migration-agent.md
│       ├── joomla-module-builder.md
│       ├── joomla-orchestrator.md
│       ├── joomla-performance-agent.md
│       ├── joomla-plugin-builder.md
│       ├── joomla-prd-writer.md
│       ├── joomla-security-auditor.md
│       ├── joomla-site-builder.md
│       └── joomla-test-engineer.md
├── includes/
│   ├── create_include_symlinks.bat
│   ├── .mcp.json
│   ├── context7.json
│   ├── joomla-coding-preferences.md
│   ├── joomla-devel-environment.md
│   ├── joomla5-depreciated.md
│   ├── joomla5-di-patterns.md
│   ├── joomla5-events-system.md
│   ├── joomla5-structure-api.md
│   ├── joomla5-structure-cli.md
│   ├── joomla5-structure-component.md
│   ├── joomla5-structure-module.md
│   └── joomla5-structure-plugin.md
├── templates/
│   ├── CLAUDE.md.joomla-template
│   ├── project-ecosystem.accountdata-template.md
│   ├── project-ecosystem.entitydata-template.md
│   └── project-ecosystem.inventorydata-template.md
├── docs/
│   ├── agent-usage-guide.md
│   ├── INTERPROJECT-REFERENCES.md
│   └── PROJECT-ECOSYSTEM.md
├── init_joomla_project.bat
└── README.md
```

## Agents

Agent files live in `.claude/agents/` within each project and provide Claude Code with specialised knowledge and instructions for specific development tasks. Each agent is a markdown file containing role definitions, coding patterns, and domain-specific guidance.

### Joomla Agents

| Agent | Purpose |
|-------|---------|
| **joomla-orchestrator** | Primary coordinator that delegates work across other agents for full extension builds |
| **joomla-architect** | Designs extension structure, namespace maps, DI wiring, database schemas, and ACL matrices |
| **joomla-prd-writer** | Produces Product Requirements Documents for complex features |
| **joomla-admin-builder** | Builds the administrator/backend side — controllers, models, views, tables, forms, toolbar, ACL, and service providers |
| **joomla-site-builder** | Builds the public-facing frontend — controllers, models, views, router, and menu integration |
| **joomla-api-builder** | Creates REST API endpoints with JSON views and webservices plugin registration |
| **joomla-cli-builder** | Creates Symfony Console CLI commands for Joomla's `cli/joomla.php` |
| **joomla-module-builder** | Builds modules using the Joomla 5 dispatcher pattern with helper factory DI |
| **joomla-plugin-builder** | Creates plugins for any event group using the subscriber/dispatcher pattern |
| **joomla-build-agent** | Manages Phing build files, extension packaging, version management, and update server XML |
| **joomla-code-reviewer** | Reviews code for PHP 8.3+ standards, Joomla conventions, and architectural patterns |
| **joomla-security-auditor** | Audits for SQL injection, XSS, CSRF, ACL gaps, and file upload vulnerabilities |
| **joomla-performance-agent** | Analyses N+1 queries, caching opportunities, and asset loading optimisation |
| **joomla-test-engineer** | Creates PHPUnit tests for services, integration tests for controllers, and coverage targets |
| **joomla-debugger** | Systematic bug diagnosis with root cause analysis via logs and pattern search |
| **joomla-language-manager** | Audits hardcoded strings, manages `Text::_()` coverage, and maintains translation files |
| **joomla-migration-agent** | Assists with upgrading extensions from Joomla 4 to Joomla 5 |

### General Agents

| Agent | Purpose |
|-------|---------|
| **data-model-architect** | Designs database schemas, analyses data sources, and establishes field naming conventions |

## Includes

Include files live in `.claude/includes/` within each project. They are referenced from `CLAUDE.md` using the `@includes/filename.md` directive, which causes Claude Code to load their contents as part of the project context.

This means every agent and conversation in the project automatically has access to the coding standards, structural references, and environment details defined in these files — without duplicating content across projects.

### Include Files

| File | Purpose |
|------|---------|
| **joomla-coding-preferences.md** | Coding standards — namespacing, PHP 8.3+ conventions, design patterns, configuration rules, and database schema conventions |
| **joomla-devel-environment.md** | Development environment setup — directory paths, source mapping, and local server configuration |
| **joomla5-structure-component.md** | Reference directory and file structure for Joomla 5 components (administrator and site) |
| **joomla5-structure-module.md** | Reference directory and file structure for Joomla 5 modules |
| **joomla5-structure-plugin.md** | Reference directory and file structure for Joomla 5 plugins |
| **joomla5-structure-api.md** | Reference directory and file structure for Joomla 5 REST API extensions |
| **joomla5-structure-cli.md** | Reference directory and file structure for Joomla 5 CLI commands |
| **joomla5-di-patterns.md** | Dependency injection patterns — service providers, container registration, and factory patterns |
| **joomla5-events-system.md** | Joomla 5 event system — dispatching, subscribing, and event class conventions |
| **joomla5-depreciated.md** | Deprecated Joomla patterns to avoid — legacy APIs, removed features, and migration paths |
| **context7.json** | Context7 library references for enhanced development context |
| **.mcp.json** | MCP server configuration |

## Templates

Templates provide starting points for new projects and extensions. They contain placeholder variables (e.g. `{{PROJECT_NAME}}`, `{{VENDOR_NAMESPACE}}`) that are replaced with project-specific values during initialisation.

| Template | Purpose |
|----------|---------|
| **CLAUDE.md.joomla-template** | Main project CLAUDE.md template — includes project configuration, namespace conventions, agent orchestration workflow, and all `@includes/` references |
| **project-ecosystem.accountdata-template.md** | Data model template for accounting/financial extensions |
| **project-ecosystem.entitydata-template.md** | Data model template for entity management extensions (customers, suppliers, contacts) |
| **project-ecosystem.inventorydata-template.md** | Data model template for inventory management extensions |

## Batch Files

### `init_joomla_project.bat`

The main project initialisation script. Run this when starting a new Joomla extension project. It:

1. Prompts for project details (name, vendor namespace, repository name, domain, database connection)
2. Creates the PHPStorm project directory with the `.claude/` structure
3. Generates a customised `CLAUDE.md` from the template with all placeholders replaced
4. Creates stub files for `project-ecosystem.md` and `architecture.md`
5. Runs the agent and include symlink scripts (see below)
6. Displays a summary with next steps

**Requires Administrator privileges** (for symlink creation on Windows).

### `agents/create_agent_symlinks.bat`

Creates symbolic links from the agent files in this repository into a target project's `.claude/agents/` directory. Prompts for the PHPStorm project name and confirms each agent individually before linking.

### `includes/create_include_symlinks.bat`

Creates symbolic links from the include files in this repository into a target project's `.claude/includes/` directory. Works the same way as the agent symlink script.

## How Symlinks Work

All agent and include files are maintained in this single repository. Rather than copying these files into each Joomla project, **symbolic links** are created that point back to the originals.

```
E:\PHPStorm Project Files\MyProject\
└── .claude\
    ├── agents\
    │   └── joomla\
    │       ├── joomla-architect.md  →  E:\repositories\ClaudeCode\agents\joomla\joomla-architect.md
    │       ├── joomla-admin-builder.md  →  E:\repositories\ClaudeCode\agents\joomla\joomla-admin-builder.md
    │       └── ...
    └── includes\
        ├── joomla-coding-preferences.md  →  E:\repositories\ClaudeCode\includes\joomla-coding-preferences.md
        ├── joomla5-structure-component.md  →  E:\repositories\ClaudeCode\includes\joomla5-structure-component.md
        └── ...
```

This approach provides:

- **Single source of truth** — edit an agent or include file once in this repository and the change is immediately reflected in every project that links to it.
- **Consistency** — all projects share the same coding standards, structural references, and agent instructions.
- **Selective linking** — the batch scripts prompt for confirmation on each file, so projects can include only the agents and includes they need.
- **No duplication** — avoids maintaining separate copies of the same files across dozens of projects.

## Docs

Supporting documentation for the agent ecosystem and multi-extension architecture.

| File | Purpose |
|------|---------|
| **agent-usage-guide.md** | Comprehensive guide to using the agent system, including the service layer architecture pattern |
| **PROJECT-ECOSYSTEM.md** | Overview of the multi-extension project ecosystem and how data layer extensions interact |
| **INTERPROJECT-REFERENCES.md** | Patterns and examples for cross-extension dependency injection and service consumption |

## Getting Started

1. Clone this repository to `E:\repositories\ClaudeCode`
2. Run `init_joomla_project.bat` to set up a new project
3. Open the project in PHPStorm
4. Start Claude Code in the project directory
5. Use `joomla-architect` to design your extension
6. Use the appropriate builder agent(s) for implementation