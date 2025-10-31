## Coding Standards for Joomla projects

### Namespacing Guidelines
- All namespacing at the top of each file should be in alphabetical order for any Joomla task/project

- ### Code Standards
- PHP 8.2+ language features
- Modern PSR-4 autoloading with Joomla namespaced classes
- Joomla 4.x/5.x conventions and security practices
- All files include `defined('_JEXEC') or die;` protection
- Uses container-based dependency injection

### Reference Libraries
- Always consult https://context7.com/context7/developer_joomla-coding-standards library for additional coding standards reference
- Refer to additional context7 libraries located in @.claude/includes/context7.json before starting any tasks
- Always use the latest version of the context7 libraries

### Database Schema
- Standard Joomla audit fields (created, modified, published state)
- MySQL8+ and Maria 10+ support
- Changes to the database schema to be updated in /sql/updates/mysql/ with version numbers.