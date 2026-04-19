@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM Joomla 5 Front-End Design Project Initialization Script
REM
REM This script automates new Joomla front-end/template design project setup:
REM   1. Prompts for project details (template name, CSS framework, build tool)
REM   2. Creates PHPStorm project directory with .claude structure
REM   3. Runs skill symlink script
REM   4. Generates customized CLAUDE.md from front-end template
REM   5. Creates style-guide and design-decisions stubs
REM
REM Unlike init_joomla_project.bat (extension development), this script is
REM focused on template development, CSS/SCSS, template overrides, and
REM front-end concerns. No extension agents, Phing builds, or DI patterns.
REM ============================================================================

REM --- Check for Administrator privileges and self-elevate if needed ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
    exit /b
)

echo.
echo ============================================
echo   Joomla 5 Front-End Design Project Setup
echo ============================================
echo.

REM --- Gather project information ---

set /p PROJECT_NAME="PHPStorm Project Name: "
if "%PROJECT_NAME%"=="" (
    echo Error: Project name cannot be empty.
    pause
    exit /b 1
)

set /p TEMPLATE_NAME="Joomla Template Name (e.g., 'mytheme'): "
if "%TEMPLATE_NAME%"=="" (
    echo Error: Template name cannot be empty.
    pause
    exit /b 1
)

set /p REPO_NAME="Repository folder name (under E:\repositories\) [%PROJECT_NAME%]: "
if "!REPO_NAME!"=="" (
    set REPO_NAME=%PROJECT_NAME%
)

set /p DOMAIN="Joomla domain (e.g., 'mysite') [%PROJECT_NAME%]: "
if "!DOMAIN!"=="" (
    set DOMAIN=%PROJECT_NAME%
)

echo.
echo CSS Framework options:
echo   1. Bootstrap 5 (Joomla default)
echo   2. Tailwind CSS
echo   3. Custom (no framework)
echo.
set /p CSS_CHOICE="CSS Framework [1]: "
if "!CSS_CHOICE!"=="" set CSS_CHOICE=1
if "!CSS_CHOICE!"=="1" set CSS_FRAMEWORK=Bootstrap 5
if "!CSS_CHOICE!"=="2" set CSS_FRAMEWORK=Tailwind CSS
if "!CSS_CHOICE!"=="3" set CSS_FRAMEWORK=Custom

echo.
echo Build Tool options:
echo   1. None (plain CSS/JS)
echo   2. Vite
echo   3. Webpack
echo.
set /p BUILD_CHOICE="Build Tool [1]: "
if "!BUILD_CHOICE!"=="" set BUILD_CHOICE=1
if "!BUILD_CHOICE!"=="1" set BUILD_TOOL=None
if "!BUILD_CHOICE!"=="2" set BUILD_TOOL=Vite
if "!BUILD_CHOICE!"=="3" set BUILD_TOOL=Webpack

REM --- Define paths ---
set PROJECT_DIR=E:\PHPStorm Project Files\%PROJECT_NAME%
set CLAUDE_DIR=%PROJECT_DIR%\.claude
set TEMPLATE=E:\repositories\ClaudeCode\templates\CLAUDE.md.joomla-frontend-template
set SKILLS_SCRIPT=E:\repositories\ClaudeCode\skills\create_skill_symlinks.bat
set INCLUDES_SCRIPT=E:\repositories\ClaudeCode\includes\create_include_symlinks.bat

echo.
echo ============================================
echo   Configuration Summary
echo ============================================
echo   Project:       %PROJECT_NAME%
echo   Template:      !TEMPLATE_NAME!
echo   Repository:    E:\repositories\!REPO_NAME!
echo   Domain:        !DOMAIN!
echo   CSS Framework: !CSS_FRAMEWORK!
echo   Build Tool:    !BUILD_TOOL!
echo   Project Dir:   %PROJECT_DIR%
echo ============================================
echo.

set /p CONFIRM="Proceed? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo Cancelled.
    pause
    exit /b 0
)

REM --- Step 1: Create project directory structure ---
echo.
echo [1/7] Creating project directory structure...

if not exist "%PROJECT_DIR%" (
    mkdir "%PROJECT_DIR%"
    if !errorlevel! neq 0 (
        echo Error: Failed to create project directory.
        pause
        exit /b 1
    )
    echo   Created: %PROJECT_DIR%
) else (
    echo   Exists: %PROJECT_DIR%
)

if not exist "%CLAUDE_DIR%" (
    mkdir "%CLAUDE_DIR%"
    echo   Created: %CLAUDE_DIR%
)

REM --- Step 2: Create CLAUDE.md from template ---
echo.
echo [2/7] Generating CLAUDE.md from template...

if not exist "%TEMPLATE%" (
    echo Error: Template not found at %TEMPLATE%
    pause
    exit /b 1
)

REM Copy template
copy "%TEMPLATE%" "%PROJECT_DIR%\CLAUDE.md" >nul

REM Perform placeholder substitutions using PowerShell
set "PS_SCRIPT=!TEMP!\joomla_frontend_init_replace.ps1"

(
    echo param^(^)
    echo $f = '!PROJECT_DIR!\CLAUDE.md'
    echo $c = [System.IO.File]::ReadAllText^($f^)
    echo $c = $c.Replace^('{{PROJECT_NAME}}', '!PROJECT_NAME!'^)
    echo $c = $c.Replace^('{{TEMPLATE_NAME}}', '!TEMPLATE_NAME!'^)
    echo $c = $c.Replace^('{{REPO_NAME}}', '!REPO_NAME!'^)
    echo $c = $c.Replace^('{{DOMAIN}}', '!DOMAIN!'^)
    echo $c = $c.Replace^('{{CSS_FRAMEWORK}}', '!CSS_FRAMEWORK!'^)
    echo $c = $c.Replace^('{{BUILD_TOOL}}', '!BUILD_TOOL!'^)
    echo $c = $c.Replace^('{{PROJECT_STATUS}}', 'Active'^)
    echo $c = $c.Replace^('{{CREATION_DATE}}', ^(Get-Date -Format 'yyyy-MM-dd'^)^)
    echo $c = $c.Replace^('{{LAST_UPDATED}}', ^(Get-Date -Format 'yyyy-MM-dd'^)^)
    echo $c = $c.Replace^('{{MAINTAINER_NAME}}', 'Development Team'^)
    echo [System.IO.File]::WriteAllText^($f, $c^)
) > "!PS_SCRIPT!"

powershell -ExecutionPolicy Bypass -File "!PS_SCRIPT!"
if !errorlevel! neq 0 (
    echo   Warning: PowerShell substitution may have failed. Check CLAUDE.md manually.
)
del "!PS_SCRIPT!" 2>nul

echo   Generated: %PROJECT_DIR%\CLAUDE.md

REM --- Step 3: Create .claude documentation stubs ---
echo.
echo [3/7] Creating .claude documentation files...

REM Create style-guide.md stub
set "STYLE_FILE=%CLAUDE_DIR%\style-guide.md"
if not exist "!STYLE_FILE!" (
    set "PS_STYLE=!TEMP!\joomla_frontend_style.ps1"
    (
        echo param^(^)
        echo $content = @"
        echo # !PROJECT_NAME! - Style Guide
        echo.
        echo ## Colour Palette
        echo.
        echo ### Primary Colours
        echo.
        echo ^| Name ^| Hex ^| Usage ^|
        echo ^|---^|---^|---^|
        echo ^| Primary ^| `#0d6efd` ^| Buttons, links, accents ^|
        echo ^| Secondary ^| `#6c757d` ^| Supporting elements ^|
        echo ^| Accent ^| `#198754` ^| Success states, CTAs ^|
        echo.
        echo ### Neutral Colours
        echo.
        echo ^| Name ^| Hex ^| Usage ^|
        echo ^|---^|---^|---^|
        echo ^| Background ^| `#ffffff` ^| Page background ^|
        echo ^| Surface ^| `#f8f9fa` ^| Cards, panels ^|
        echo ^| Text ^| `#212529` ^| Body text ^|
        echo ^| Text Muted ^| `#6c757d` ^| Secondary text ^|
        echo ^| Border ^| `#dee2e6` ^| Dividers, borders ^|
        echo.
        echo ---
        echo.
        echo ## Typography
        echo.
        echo ### Font Stack
        echo.
        echo - **Body**: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif
        echo - **Headings**: [Same as body or specify]
        echo - **Code**: "SFMono-Regular", Menlo, Consolas, monospace
        echo.
        echo ### Type Scale
        echo.
        echo ^| Element ^| Size ^| Weight ^| Line Height ^|
        echo ^|---^|---^|---^|---^|
        echo ^| h1 ^| 2.5rem ^| 700 ^| 1.2 ^|
        echo ^| h2 ^| 2rem ^| 700 ^| 1.2 ^|
        echo ^| h3 ^| 1.75rem ^| 600 ^| 1.3 ^|
        echo ^| h4 ^| 1.5rem ^| 600 ^| 1.3 ^|
        echo ^| Body ^| 1rem ^| 400 ^| 1.5 ^|
        echo ^| Small ^| 0.875rem ^| 400 ^| 1.4 ^|
        echo.
        echo ---
        echo.
        echo ## Spacing Scale
        echo.
        echo ^| Token ^| Value ^| Usage ^|
        echo ^|---^|---^|---^|
        echo ^| `--space-xs` ^| 0.25rem ^(4px^) ^| Tight spacing ^|
        echo ^| `--space-sm` ^| 0.5rem ^(8px^) ^| Compact elements ^|
        echo ^| `--space-md` ^| 1rem ^(16px^) ^| Default spacing ^|
        echo ^| `--space-lg` ^| 1.5rem ^(24px^) ^| Section gaps ^|
        echo ^| `--space-xl` ^| 3rem ^(48px^) ^| Major sections ^|
        echo.
        echo ---
        echo.
        echo ## Component Patterns
        echo.
        echo ### Buttons
        echo.
        echo [Document button styles, sizes, states]
        echo.
        echo ### Cards
        echo.
        echo [Document card patterns]
        echo.
        echo ### Forms
        echo.
        echo [Document form input styles]
        echo.
        echo ### Navigation
        echo.
        echo [Document nav patterns]
        echo.
        echo "@
        echo [System.IO.File]::WriteAllText^('!STYLE_FILE!', $content^)
    ) > "!PS_STYLE!"
    powershell -ExecutionPolicy Bypass -File "!PS_STYLE!"
    del "!PS_STYLE!" 2>nul
    echo   Created: !STYLE_FILE!
) else (
    echo   Exists: !STYLE_FILE!
)

REM Create design-decisions.md stub
set "DESIGN_FILE=%CLAUDE_DIR%\design-decisions.md"
if not exist "!DESIGN_FILE!" (
    set "PS_DESIGN=!TEMP!\joomla_frontend_design.ps1"
    (
        echo param^(^)
        echo $content = @"
        echo # !PROJECT_NAME! - Design Decisions
        echo.
        echo ## Overview
        echo.
        echo Design rationale and architectural choices for the !TEMPLATE_NAME! template.
        echo.
        echo ---
        echo.
        echo ## CSS Architecture
        echo.
        echo - **Framework**: !CSS_FRAMEWORK!
        echo - **Methodology**: BEM for custom components
        echo - **Custom properties**: Used for theming/design tokens
        echo - **Build tool**: !BUILD_TOOL!
        echo.
        echo ---
        echo.
        echo ## Layout Strategy
        echo.
        echo - **Approach**: Mobile-first responsive
        echo - **Grid system**: [Framework grid / CSS Grid / Flexbox]
        echo - **Container max-width**: 1200px
        echo - **Breakpoints**: [Framework defaults / custom]
        echo.
        echo ---
        echo.
        echo ## Template Override Strategy
        echo.
        echo Document which Joomla views are overridden and why:
        echo.
        echo ^| Override ^| Reason ^|
        echo ^|---^|---^|
        echo ^| [e.g., com_content/article] ^| [Custom article layout] ^|
        echo.
        echo ---
        echo.
        echo ## Module Positions
        echo.
        echo Document the template's module position map and layout intent:
        echo.
        echo ``````
        echo +-------------------------------+
        echo ^|           topbar              ^|
        echo +-------------------------------+
        echo ^|            menu               ^|
        echo +-------------------------------+
        echo ^|         breadcrumbs           ^|
        echo +-------+--------------+--------+
        echo ^|       ^|   component  ^|sidebar ^|
        echo ^|       ^|              ^|        ^|
        echo +-------+--------------+--------+
        echo ^|           footer              ^|
        echo +-------------------------------+
        echo ``````
        echo.
        echo ---
        echo.
        echo ## Accessibility Approach
        echo.
        echo - Target: WCAG 2.1 AA
        echo - Skip link: Yes
        echo - Focus indicators: Custom visible styles
        echo - Colour contrast: Verified with [tool name]
        echo - Keyboard navigation: Tested for all interactive elements
        echo.
        echo ---
        echo.
        echo ## Performance Budget
        echo.
        echo ^| Metric ^| Target ^| Current ^|
        echo ^|---^|---^|---^|
        echo ^| LCP ^| ^< 2.5s ^| [measure] ^|
        echo ^| FID ^| ^< 100ms ^| [measure] ^|
        echo ^| CLS ^| ^< 0.1 ^| [measure] ^|
        echo ^| Total CSS ^| ^< 50KB ^| [measure] ^|
        echo ^| Total JS ^| ^< 30KB ^| [measure] ^|
        echo.
        echo "@
        echo [System.IO.File]::WriteAllText^('!DESIGN_FILE!', $content^)
    ) > "!PS_DESIGN!"
    powershell -ExecutionPolicy Bypass -File "!PS_DESIGN!"
    del "!PS_DESIGN!" 2>nul
    echo   Created: !DESIGN_FILE!
) else (
    echo   Exists: !DESIGN_FILE!
)

REM --- Step 4: Run include symlinks ---
echo.
echo [4/7] Creating include symlinks...
echo   (You will be prompted for each include)
echo.

echo !PROJECT_NAME!| call "%INCLUDES_SCRIPT%"

REM --- Step 5: Run skill symlinks ---
echo.
echo [5/7] Creating skill symlinks...
echo   (You will be prompted for each skill)
echo.

echo !PROJECT_NAME!| call "%SKILLS_SCRIPT%"

REM --- Step 6: Symlink utility scripts into project directory ---
echo.
echo [6/7] Linking utility scripts into project directory...

REM init_joomla_frontend.bat
if exist "%PROJECT_DIR%\init_joomla_frontend.bat" (
    echo   Exists: init_joomla_frontend.bat
) else (
    mklink "%PROJECT_DIR%\init_joomla_frontend.bat" "E:\repositories\ClaudeCode\init_joomla_frontend.bat" >nul
    echo   Linked: init_joomla_frontend.bat
)

REM create_skill_symlinks.bat
if exist "%PROJECT_DIR%\create_skill_symlinks.bat" (
    echo   Exists: create_skill_symlinks.bat
) else (
    mklink "%PROJECT_DIR%\create_skill_symlinks.bat" "E:\repositories\ClaudeCode\skills\create_skill_symlinks.bat" >nul
    echo   Linked: create_skill_symlinks.bat
)

REM --- Step 7: Create template scaffold in repository (optional) ---
echo.
echo [7/7] Template scaffold...

set REPO_DIR=E:\repositories\!REPO_NAME!
set TPL_DIR=!REPO_DIR!\templates\!TEMPLATE_NAME!

if not exist "!REPO_DIR!" (
    echo   Repository not found at !REPO_DIR! - skipping scaffold.
    echo   Create the repository first, then re-run or scaffold manually.
    goto :summary
)

if exist "!TPL_DIR!" (
    echo   Template directory already exists: !TPL_DIR! - skipping scaffold.
    goto :summary
)

set /p SCAFFOLD="Create template scaffold in !TPL_DIR!? (Y/N): "
if /i not "!SCAFFOLD!"=="Y" (
    echo   Skipped template scaffold.
    goto :summary
)

REM Create directory structure
mkdir "!TPL_DIR!"
mkdir "!TPL_DIR!\css"
mkdir "!TPL_DIR!\js"
mkdir "!TPL_DIR!\images"
mkdir "!TPL_DIR!\html"
mkdir "!TPL_DIR!\language\en-GB"
echo   Created template directories

REM Create SCSS directories if using a build tool
if not "!BUILD_TOOL!"=="None" (
    mkdir "!TPL_DIR!\scss"
    echo   Created scss directory
)

REM Create templateDetails.xml
set "PS_XML=!TEMP!\joomla_frontend_xml.ps1"
(
    echo param^(^)
    echo $content = @"
    echo ^<?xml version="1.0" encoding="utf-8"?^>
    echo ^<extension type="template" client="site" method="upgrade"^>
    echo     ^<name^>!TEMPLATE_NAME!^</name^>
    echo     ^<version^>1.0.0^</version^>
    echo     ^<creationDate^>$(Get-Date -Format 'yyyy-MM-dd')^</creationDate^>
    echo     ^<author^>Development Team^</author^>
    echo     ^<authorUrl^>^</authorUrl^>
    echo     ^<copyright^>Copyright (C) $(Get-Date -Format 'yyyy'). All rights reserved.^</copyright^>
    echo     ^<license^>GPL-2.0-or-later^</license^>
    echo     ^<description^>TPL_!TEMPLATE_NAME!_XML_DESCRIPTION^</description^>
    echo     ^<inheritable^>1^</inheritable^>
    echo.
    echo     ^<files^>
    echo         ^<filename^>component.php^</filename^>
    echo         ^<filename^>error.php^</filename^>
    echo         ^<filename^>index.php^</filename^>
    echo         ^<filename^>joomla.asset.json^</filename^>
    echo         ^<filename^>offline.php^</filename^>
    echo         ^<folder^>css^</folder^>
    echo         ^<folder^>html^</folder^>
    echo         ^<folder^>images^</folder^>
    echo         ^<folder^>js^</folder^>
    echo         ^<folder^>language^</folder^>
    echo     ^</files^>
    echo.
    echo     ^<positions^>
    echo         ^<position^>topbar^</position^>
    echo         ^<position^>menu^</position^>
    echo         ^<position^>breadcrumbs^</position^>
    echo         ^<position^>banner^</position^>
    echo         ^<position^>sidebar-left^</position^>
    echo         ^<position^>sidebar-right^</position^>
    echo         ^<position^>bottom-a^</position^>
    echo         ^<position^>bottom-b^</position^>
    echo         ^<position^>footer^</position^>
    echo         ^<position^>debug^</position^>
    echo     ^</positions^>
    echo.
    echo     ^<config^>
    echo         ^<fields name="params"^>
    echo             ^<fieldset name="basic" label="TPL_!TEMPLATE_NAME!_BASIC"^>
    echo                 ^<field name="logoFile" type="media"
    echo                     label="TPL_!TEMPLATE_NAME!_LOGO"
    echo                     description="TPL_!TEMPLATE_NAME!_LOGO_DESC" /^>
    echo                 ^<field name="siteDescription" type="text"
    echo                     label="TPL_!TEMPLATE_NAME!_TAGLINE"
    echo                     description="TPL_!TEMPLATE_NAME!_TAGLINE_DESC" /^>
    echo             ^</fieldset^>
    echo         ^</fields^>
    echo     ^</config^>
    echo ^</extension^>
    echo "@
    echo [System.IO.File]::WriteAllText^('!TPL_DIR!\templateDetails.xml', $content^)
) > "!PS_XML!"
powershell -ExecutionPolicy Bypass -File "!PS_XML!"
del "!PS_XML!" 2>nul
echo   Created: templateDetails.xml

REM Create joomla.asset.json
set "PS_ASSET=!TEMP!\joomla_frontend_asset.ps1"
(
    echo param^(^)
    echo $content = @"
    echo {
    echo   "`$schema": "https://developer.joomla.org/schemas/json-schema/web_assets.json",
    echo   "name": "tpl_!TEMPLATE_NAME!",
    echo   "version": "1.0.0",
    echo   "description": "!TEMPLATE_NAME! template assets",
    echo   "license": "GPL-2.0-or-later",
    echo   "assets": [
    echo     {
    echo       "name": "template.!TEMPLATE_NAME!.css",
    echo       "type": "style",
    echo       "uri": "templates/!TEMPLATE_NAME!/css/template.css",
    echo       "version": "auto"
    echo     },
    echo     {
    echo       "name": "template.!TEMPLATE_NAME!.js",
    echo       "type": "script",
    echo       "uri": "templates/!TEMPLATE_NAME!/js/template.js",
    echo       "attributes": { "defer": true },
    echo       "version": "auto"
    echo     },
    echo     {
    echo       "name": "template.!TEMPLATE_NAME!",
    echo       "type": "preset",
    echo       "dependencies": [
    echo         "template.!TEMPLATE_NAME!.css",
    echo         "template.!TEMPLATE_NAME!.js"
    echo       ]
    echo     }
    echo   ]
    echo }
    echo "@
    echo [System.IO.File]::WriteAllText^('!TPL_DIR!\joomla.asset.json', $content^)
) > "!PS_ASSET!"
powershell -ExecutionPolicy Bypass -File "!PS_ASSET!"
del "!PS_ASSET!" 2>nul
echo   Created: joomla.asset.json

REM Create minimal index.php
set "PS_INDEX=!TEMP!\joomla_frontend_index.ps1"
(
    echo param^(^)
    echo $content = @"
    echo ^<?php
    echo.
    echo defined^('_JEXEC'^) or die;
    echo.
    echo use Joomla\CMS\Document\HtmlDocument;
    echo use Joomla\CMS\Factory;
    echo.
    echo /** @var HtmlDocument `$this */
    echo.
    echo `$app    = Factory::getApplication^(^);
    echo `$wa     = `$this-^>getWebAssetManager^(^);
    echo `$params = `$this-^>params;
    echo.
    echo // Load template assets
    echo `$wa-^>usePreset^('template.!TEMPLATE_NAME!'^);
    echo.
    echo ?^>
    echo ^<!DOCTYPE html^>
    echo ^<html lang="^<?php echo `$this-^>language; ?^>" dir="^<?php echo `$this-^>direction; ?^>"^>
    echo ^<head^>
    echo     ^<meta charset="utf-8"^>
    echo     ^<meta name="viewport" content="width=device-width, initial-scale=1"^>
    echo     ^<jdoc:include type="metas" /^>
    echo     ^<jdoc:include type="styles" /^>
    echo     ^<jdoc:include type="scripts" /^>
    echo ^</head^>
    echo ^<body class="site ^<?php echo `$this-^>direction === 'rtl' ? 'rtl' : ''; ?^>"^>
    echo     ^<a href="#main-content" class="visually-hidden-focusable"^>Skip to main content^</a^>
    echo.
    echo     ^<header^>
    echo         ^<?php if ^(`$this-^>countModules^('topbar'^)^) : ?^>
    echo         ^<div class="topbar"^>
    echo             ^<jdoc:include type="modules" name="topbar" style="none" /^>
    echo         ^</div^>
    echo         ^<?php endif; ?^>
    echo.
    echo         ^<nav aria-label="Main Navigation"^>
    echo             ^<jdoc:include type="modules" name="menu" style="none" /^>
    echo         ^</nav^>
    echo     ^</header^>
    echo.
    echo     ^<main id="main-content"^>
    echo         ^<?php if ^(`$this-^>countModules^('breadcrumbs'^)^) : ?^>
    echo         ^<jdoc:include type="modules" name="breadcrumbs" style="none" /^>
    echo         ^<?php endif; ?^>
    echo.
    echo         ^<jdoc:include type="message" /^>
    echo         ^<jdoc:include type="component" /^>
    echo     ^</main^>
    echo.
    echo     ^<?php if ^(`$this-^>countModules^('sidebar-right'^)^) : ?^>
    echo     ^<aside aria-label="Sidebar"^>
    echo         ^<jdoc:include type="modules" name="sidebar-right" style="card" /^>
    echo     ^</aside^>
    echo     ^<?php endif; ?^>
    echo.
    echo     ^<footer^>
    echo         ^<?php if ^(`$this-^>countModules^('footer'^)^) : ?^>
    echo         ^<jdoc:include type="modules" name="footer" style="none" /^>
    echo         ^<?php endif; ?^>
    echo     ^</footer^>
    echo.
    echo     ^<jdoc:include type="modules" name="debug" style="none" /^>
    echo ^</body^>
    echo ^</html^>
    echo "@
    echo [System.IO.File]::WriteAllText^('!TPL_DIR!\index.php', $content^)
) > "!PS_INDEX!"
powershell -ExecutionPolicy Bypass -File "!PS_INDEX!"
del "!PS_INDEX!" 2>nul
echo   Created: index.php

REM Create empty CSS and JS files
echo. > "!TPL_DIR!\css\template.css"
echo. > "!TPL_DIR!\js\template.js"
echo   Created: css/template.css, js/template.js

REM Create language files
set "PS_LANG=!TEMP!\joomla_frontend_lang.ps1"
(
    echo param^(^)
    echo $ini = "TPL_!TEMPLATE_NAME!=!TEMPLATE_NAME!`r`nTPL_!TEMPLATE_NAME!_XML_DESCRIPTION=!TEMPLATE_NAME! template for Joomla 5`r`nTPL_!TEMPLATE_NAME!_BASIC=Basic Settings`r`nTPL_!TEMPLATE_NAME!_LOGO=Logo`r`nTPL_!TEMPLATE_NAME!_LOGO_DESC=Select a logo image`r`nTPL_!TEMPLATE_NAME!_TAGLINE=Site Tagline`r`nTPL_!TEMPLATE_NAME!_TAGLINE_DESC=A short tagline displayed near the logo"
    echo $sys = "TPL_!TEMPLATE_NAME!=!TEMPLATE_NAME!`r`nTPL_!TEMPLATE_NAME!_XML_DESCRIPTION=!TEMPLATE_NAME! template for Joomla 5"
    echo [System.IO.File]::WriteAllText^('!TPL_DIR!\language\en-GB\tpl_!TEMPLATE_NAME!.ini', $ini^)
    echo [System.IO.File]::WriteAllText^('!TPL_DIR!\language\en-GB\tpl_!TEMPLATE_NAME!.sys.ini', $sys^)
) > "!PS_LANG!"
powershell -ExecutionPolicy Bypass -File "!PS_LANG!"
del "!PS_LANG!" 2>nul
echo   Created: language files

REM Create component.php (bare component output)
set "PS_COMP=!TEMP!\joomla_frontend_comp.ps1"
(
    echo param^(^)
    echo $content = @"
    echo ^<?php
    echo.
    echo defined^('_JEXEC'^) or die;
    echo.
    echo use Joomla\CMS\Document\HtmlDocument;
    echo.
    echo /** @var HtmlDocument `$this */
    echo.
    echo `$wa = `$this-^>getWebAssetManager^(^);
    echo `$wa-^>usePreset^('template.!TEMPLATE_NAME!'^);
    echo.
    echo ?^>
    echo ^<!DOCTYPE html^>
    echo ^<html lang="^<?php echo `$this-^>language; ?^>" dir="^<?php echo `$this-^>direction; ?^>"^>
    echo ^<head^>
    echo     ^<meta charset="utf-8"^>
    echo     ^<meta name="viewport" content="width=device-width, initial-scale=1"^>
    echo     ^<jdoc:include type="metas" /^>
    echo     ^<jdoc:include type="styles" /^>
    echo     ^<jdoc:include type="scripts" /^>
    echo ^</head^>
    echo ^<body class="contentpane"^>
    echo     ^<jdoc:include type="message" /^>
    echo     ^<jdoc:include type="component" /^>
    echo ^</body^>
    echo ^</html^>
    echo "@
    echo [System.IO.File]::WriteAllText^('!TPL_DIR!\component.php', $content^)
) > "!PS_COMP!"
powershell -ExecutionPolicy Bypass -File "!PS_COMP!"
del "!PS_COMP!" 2>nul
echo   Created: component.php

echo   Template scaffold complete.

REM --- Summary ---
:summary
echo.
echo ============================================
echo   Front-End Project Initialization Complete
echo ============================================
echo.
echo   Project: %PROJECT_DIR%
echo   CLAUDE.md: %PROJECT_DIR%\CLAUDE.md
echo   .claude\style-guide.md       (update with your design tokens)
echo   .claude\design-decisions.md  (update with your design rationale)
echo   Skills: %CLAUDE_DIR%\skills\
echo.
if exist "!TPL_DIR!\index.php" (
    echo   Template scaffold: !TPL_DIR!
    echo     templateDetails.xml, index.php, component.php
    echo     joomla.asset.json, css/, js/, html/, language/
    echo.
)
echo   Utility scripts in project directory:
echo     init_joomla_frontend.bat    -^> ClaudeCode\init_joomla_frontend.bat
echo     create_skill_symlinks.bat   -^> ClaudeCode\skills\create_skill_symlinks.bat
echo.
echo   Next steps:
echo   1. Open project in PHPStorm
echo   2. Verify CLAUDE.md placeholders are replaced
echo   3. Update .claude\style-guide.md with your design tokens
echo   4. Update .claude\design-decisions.md with design rationale
echo   5. Symlink/copy template into Joomla instance: E:\www\!DOMAIN!\templates\
echo   6. Discover template in Joomla admin: System ^> Templates ^> Site Templates
echo   7. Set as default template
echo   8. Start Claude Code in the project directory
echo.

pause
