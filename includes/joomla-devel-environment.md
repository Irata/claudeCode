## Development Environment
PHPStorm project configured with:
- PHP 8.2 language level
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

**Development Setup** (Windows):
Run `symlink.bat` to create junction link for live development in Joomla installation.
