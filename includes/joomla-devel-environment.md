## Development Environment
PHPStorm project configured with:
- PHP 8.3 language level
- Joomla framework include paths
- Code style enforcement
- Source mapping between project and repository directories
- Git integration
- XDebug integration
- PHP_CodeSniffer integration
- LESS file Watcher

### Development Structure
- **Source Code**: `E:\repositories\_name_`
- **PHPStorm Project**: `E:\PHPStorm Project Files\_name_` (working directory)
- **Build Files**: `E:\repositories\_name_\Phing\` directory contains XML build configurations for each extension.
- **Joomla Instances**: `E:\www\_domain_`     
- **Databases**: `E:\www\Databases`
- **SQL**: Maria on port 3306
- **WSL Symbolic Links** are used to link the source files to the directory containing the Joomla installation.
- **Website URLs** `https\\:_domain_.local` are used to link the source files to the directory containing the Joomla installation.

### Repository Folder Structure

The standard folder structure for Joomla projects in their `E:\repositories\{REPO_NAME}` directory:

```
E:\repositories\{REPO_NAME}\
├── admin/com_example/          — Administrator backend code
├── api/com_example/            — REST API code (same level as admin/site)
├── media/com_example/          — CSS, JS, joomla.asset.json
├── site/com_example/           — Public frontend code
├── plugins/
│   ├── console/            — CLI console plugins
│   ├── webservices/        — API routing plugins
│   └── system/             — System plugins
├── Files/                  — Non-extension files (scripts, configs, etc.)
└── Phing/                  — Build configuration (build.xml, build.properties)
```

Key conventions:
- `/tmpl` is at the same level as `/src` within each component layer — NOT a subdirectory of `/View`.

**Development Setup** (Windows):
Run `symlink.bat` to create junction link for live development in Joomla installation.

### Xdebug Path Mappings for Symlinked Extensions

When extensions are symlinked from a repository into a Joomla instance, Xdebug has **dual path behavior**:

- **Breakpoint matching**: uses the **symlink path** (`E:/www/{domain}/components/com_example/...`)
- **Breakpoint reporting**: uses the **resolved real path** (`E:/repositories/{repo}/site/com_example/...`)

Each symlinked extension therefore requires **two `remote-root` entries** in PHPStorm's server path mappings (`.idea/workspace.xml` → `<component name="PhpServers">`), both pointing to the same `local-root`:

| local-root (repository source) | remote-root 1 (symlink — for matching) | remote-root 2 (resolved — for reporting) |
|---|---|---|
| `{repo}/admin/com_example` | `{domain}/administrator/components/com_example` | `{repo}/admin/com_example` |
| `{repo}/site/com_example` | `{domain}/components/com_example` | `{repo}/site/com_example` |
| `{repo}/api/com_example` | `{domain}/api/components/com_example` | `{repo}/api/com_example` |
| `{repo}/media/com_example` | `{domain}/media/com_example` | `{repo}/media/com_example` |
| `{repo}/plugins/{group}/{name}` | `{domain}/plugins/{group}/{name}` | `{repo}/plugins/{group}/{name}` |

Joomla core (not symlinked) needs only a single mapping: `remote-root = E:/www/{domain}`.

If two server entries exist (e.g. port 443 and default), both need the same dual mappings.

**Diagnostics**: Enable `xdebug.log = "E:/tmp/xdebug.log"` and `xdebug.log_level = 7` in php.ini. Ensure `E:\tmp` exists. Look for `breakpoint_set` (what PHPStorm sends) and `breakpoint_resolved` (what Xdebug reports back) to verify paths match.
