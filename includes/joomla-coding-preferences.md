## Coding Standards for Joomla projects

### Namespacing Guidelines
- All namespacing at the top of each file should be in alphabetical order for any Joomla task/project
- All component Classes namespaced under _vendor_\_name_ 
- 
- ### Code Standards
- PHP 8.3+ language features (constructor promotion, readonly properties, enums, match expressions, typed class constants, `#[Override]` attribute)
- Modern PSR-4 autoloading with Joomla namespaced classes
- Joomla 4.x/5.x conventions and security practices
- All files include `defined('_JEXEC') or die;` protection
- Uses container-based dependency injection
- PHPDoc comments for all public methods and properties
### Reference Libraries
- Always consult https://context7.com/context7/developer_joomla-coding-standards library for additional coding standards reference
- Refer to additional context7 libraries located in @.claude/includes/context7.json before starting any tasks
- Always use the latest version of the context7 libraries

### Design Patterns
- Do NOT use the Repository design pattern in Joomla extensions. Use Joomla's native Model pattern (`ListModel`, `FormModel`, `AdminModel`, `BaseDatabaseModel`) for all data access.
- Models handle database queries, state management, and business logic — there is no need for a separate Repository layer.

### Configuration Parameters
- Extension configuration parameters MUST be defined in a separate `config.xml` file, NOT embedded as `<config>` blocks inside the extension's manifest XML file (`extensionname.xml`).
- The manifest XML is for extension metadata, installation instructions, namespace, and file declarations only.
- This applies to all extension types: components, modules, and plugins.

### Database Schema
- Standard Joomla audit fields (created, modified, published state)
- MySQL8+ and Maria 10+ support
- Changes to the database schema to be updated in /sql/updates/mysql/ with version numbers.