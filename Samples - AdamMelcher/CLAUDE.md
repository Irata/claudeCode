# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the root directory containing multiple projects. Each subdirectory may have its own CLAUDE.md file with project-specific instructions. The subdirectories will all be Joomla 5.x CMS installation with J2Store e-commerce functionality. Use the subdirectory CLAUDE.md file in addition to this one. If there are conflicting directions between the two, use the instructions from the subdirectory over this one.

## Coding Standards

### Namespacing Guidelines
- All namespacing at the top of each file should be in alphabetical order for any Joomla task/project

### Reference Libraries
- Always consult https://context7.com/context7/developer_joomla-coding-standards library for additional coding standards reference
- Refer to additional context7 libraries located in "E:\PROJECTS\context7.json" before starting any tasks

## Architecture Overview

### Core Structure
- **MVC Pattern**: Joomla uses Model-View-Controller architecture
- **Component-based**: Functionality is organized into components (com_content, com_j2store, etc.)
- **Extension Types**: Components, Modules, Plugins, Templates, Languages

## Joomla Deprecation Patterns

### View Model Access Pattern (Deprecated in 5.3.0)
**Pattern**: Using `$this->get('PropertyName')` in Joomla view classes to access model data
**Deprecation Version**: 5.3.0
**Removal Version**: 7.0
**Location**: `libraries/src/MVC/View/AbstractView.php`

#### Detection Pattern
Look for code like:
```php
// In view classes (HtmlView.php)
$this->items = $this->get('Items');
$this->pagination = $this->get('Pagination');
$this->state = $this->get('State');
```

#### Recommended Migration
Replace with direct model method calls:
```php
// Get the model instance first
$model = $this->getModel();

// Then call methods directly
$this->items = $model->getItems();
$this->pagination = $model->getPagination();
$this->state = $model->getState();
```

#### Why This Change
- Improves code clarity and IDE autocomplete support
- Removes magic method overhead
- Makes debugging easier by showing explicit method calls
- Aligns with modern PHP best practices

#### Agent Guidelines for joomla-debugger
When detecting this pattern:
1. Check if the file extends `AbstractView` or `HtmlView`
2. Look for `$this->get()` calls within view classes
3. Suggest the migration pattern shown above
4. Verify the model has the corresponding getter methods
5. Note that `LegacyPropertyManagementTrait::get` is being overridden

### Toolbar Singleton Pattern (Deprecated in 5.x)
**Pattern**: Using `Toolbar::getInstance('toolbar')` in Joomla view classes
**Deprecation Version**: 5.x
**Location**: `libraries/src/Toolbar/Toolbar.php`

#### Detection Pattern
Look for code like:
```php
// In view classes (HtmlView.php)
$toolbar = Toolbar::getInstance('toolbar');
```

#### Recommended Migration
Replace with document-based toolbar access:
```php
// Modern Joomla 5 approach
$toolbar = Factory::getApplication()->getDocument()->getToolbar();
```

#### Why This Change
- Eliminates deprecated singleton pattern
- Uses proper service chain access
- Avoids internal static variable issues with ToolbarFactoryInterface approach
- Maintains toolbar functionality without rendering problems

#### Important Note
While `Factory::getContainer()->get(ToolbarFactoryInterface::class)->createToolbar('toolbar')` is mentioned in Joomla source code, it has known issues where toolbar buttons disappear because it creates a new instance but doesn't update the internal static variable that the toolbar rendering system relies on.

## Agent-Specific Knowledge

### Joomla-Debugger Agent
The joomla-debugger agent should be aware of:
- **Deprecation patterns** - Actively check for deprecated methods and suggest modern alternatives
- **Version-specific changes** - Track changes between Joomla versions (especially 3.x to 4.x to 5.x migrations)
- **Common error patterns** - Such as countable errors, type mismatches, namespace issues
- **Best practices** - Enforce Joomla 5 standards and discourage outdated patterns

## Environment Configuration

### Python Installation
- Python Executable: `E:/PROJECTS/PYTHON/python.exe`
- Scripts Directory: `E:/PROJECTS/PYTHON/Scripts/`
- Packages: markitdown[pdf] installed for document conversion

## Project Shortcuts

### Joomla Shop Project
- Shortcut: `joomla-shop`
- Local Directory: `E:\bearsampp\www\shop`
- Database Connection Tool: `get_db`
  - Project Name: `SHOP`
  - Connection Name: `shop`
- **Database Schema Documentation**: `E:\PROJECTS\SHOP_DATABASE_SCHEMA.md` - Complete database schema reference for agents

### Trusted Directories
- `G:\REPOSITORY\SITES\J2COMMERCE` is a trusted directory to be used the same as if it was included inside the E:\PROJECTS folder
- `E:\bearsampp\www\shop` and all of its sub-directories and files are an approved directory for this project (with all tools and permissions)

## Testing Guidelines

### Automated Testing
- Always use playwright to test save functionality on all event pages and list view pages
- Never use custom python scripts for playwrite testing - always use the paywrite mcp server

## Agent Memory

### Task Completion Guidelines
- Never declare a job completed without human confirmation

### Agent File Review Guidelines
- Never review or edit any files that are not using at least one of the joomla-* agents

### Image Processing Guidelines
- **CRITICAL RULE: NO IMAGES SHOULD BE EDITED WITHOUT USING THE IMAGER AGENT** - This is vital and will result in immediate task failure if violated
- If no agent is specified for image tasks, automatically assign the task to the imager agent
- All image optimization, conversion, resizing, and processing must go through the imager agent
- The imager agent ensures proper compression, format selection, and quality preservation

## Version Control & GitHub Configuration

### Git Setup
- **Git Installation**: Portable Git located at `E:\PROJECTS\GITHUB\PortableGit`
- **Git Executable**: `E:\PROJECTS\GITHUB\PortableGit\bin\git.exe`
- **Repository Structure**: Multi-project repository with subproject directories
- **Main Branch**: `main` (not master)

### GitHub Repository Information
- **Repository**: `https://github.com/newlinewebdesign/joomla-projects.git` (private)
- **Purpose**: Parallel agent collaboration and version restoration capabilities
- **Access**: Personal Access Token configured in `.mcp.json` for GitHub MCP server

### Branching Strategy
- **Main Branch**: `main` - Stable, tested code
- **Feature Branches**: Use for individual features/fixes: `feature/descriptive-name`
- **Agent Branches**: For parallel agent work: `agent/agent-name/task-description`
- **Hotfix Branches**: For critical fixes: `hotfix/issue-description`

### Commit Guidelines
- Use conventional commit messages when possible
- Always include Claude Code attribution:
  ```
  🤖 Generated with [Claude Code](https://claude.ai/code)
  
  Co-Authored-By: Claude <noreply@anthropic.com>
  ```
- Include meaningful commit descriptions explaining the "why" not just the "what"
- Reference issue numbers or task IDs when applicable

### MCP GitHub Integration
- **GitHub MCP Server**: Configured in `.mcp.json` with Docker container
- **Personal Access Token**: `GITHUB_PERSONAL_ACCESS_TOKEN` environment variable
- **Docker Command**: `docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN ghcr.io/github/github-mcp-server`

### Repository Best Practices
- Never commit sensitive data (credentials, tokens, database connections)
- Use `.gitignore` to exclude temporary files, logs, and build artifacts
- Commit configuration templates, not actual sensitive configurations
- Keep commit history clean and meaningful
- Use branch protection for main branch in production

### Parallel Agent Workflow
1. Create feature/agent branches for parallel work
2. Each agent works in isolation on their branch  
3. Regular commits with descriptive messages
4. Merge back to main when complete and tested
5. Use pull requests for code review when collaborating

### Version Restoration
- Use `git log --oneline` to view commit history
- Use `git checkout <commit-hash>` to restore to specific version
- Use `git revert <commit-hash>` to undo specific changes
- Use `git reset --hard <commit-hash>` for complete rollback (use with caution)
- Always backup before major rollbacks

### Essential Git Commands for Agents
```bash
# Check status
"E:\PROJECTS\GITHUB\PortableGit\bin\git.exe" status

# Create and switch to new branch
"E:\PROJECTS\GITHUB\PortableGit\bin\git.exe" checkout -b feature/new-feature

# Add files to staging
"E:\PROJECTS\GITHUB\PortableGit\bin\git.exe" add .

# Commit with message
"E:\PROJECTS\GITHUB\PortableGit\bin\git.exe" commit -m "feat: description"

# Push to GitHub
"E:\PROJECTS\GITHUB\PortableGit\bin\git.exe" push origin feature/new-feature

# Switch back to main
"E:\PROJECTS\GITHUB\PortableGit\bin\git.exe" checkout main

# Pull latest changes
"E:\PROJECTS\GITHUB\PortableGit\bin\git.exe" pull origin main
```