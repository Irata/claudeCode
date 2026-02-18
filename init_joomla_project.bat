@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM Joomla 5 Project Initialization Script
REM
REM This script automates new Joomla project setup:
REM   1. Prompts for project details
REM   2. Creates PHPStorm project directory with .claude structure
REM   3. Runs agent and include symlink scripts
REM   4. Generates customized CLAUDE.md from template
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
echo   Joomla 5 Project Initialization
echo ============================================
echo.

REM --- Gather project information ---

set /p PROJECT_NAME="PHPStorm Project Name: "
if "%PROJECT_NAME%"=="" (
    echo Error: Project name cannot be empty.
    pause
    exit /b 1
)

set /p VENDOR_NS="Vendor Namespace (e.g., 'Acme'): "
if "%VENDOR_NS%"=="" (
    echo Error: Vendor namespace cannot be empty.
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

set /p DB_CONN="Database connection name [%PROJECT_NAME%_dev]: "
if "!DB_CONN!"=="" (
    set DB_CONN=%PROJECT_NAME%_dev
)

REM --- Define paths ---
set PROJECT_DIR=E:\PHPStorm Project Files\%PROJECT_NAME%
set CLAUDE_DIR=%PROJECT_DIR%\.claude
set TEMPLATE=E:\repositories\ClaudeCode\templates\CLAUDE.md.joomla-template
set AGENTS_SCRIPT=E:\repositories\ClaudeCode\agents\create_agent_symlinks.bat
set INCLUDES_SCRIPT=E:\repositories\ClaudeCode\includes\create_include_symlinks.bat

echo.
echo ============================================
echo   Configuration Summary
echo ============================================
echo   Project:     %PROJECT_NAME%
echo   Vendor:      !VENDOR_NS!
echo   Repository:  E:\repositories\!REPO_NAME!
echo   Domain:      !DOMAIN!
echo   DB Conn:     !DB_CONN!
echo   Project Dir: %PROJECT_DIR%
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
echo [1/6] Creating project directory structure...

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
echo [2/6] Generating CLAUDE.md from template...

if not exist "%TEMPLATE%" (
    echo Error: Template not found at %TEMPLATE%
    pause
    exit /b 1
)

REM Copy template
copy "%TEMPLATE%" "%PROJECT_DIR%\CLAUDE.md" >nul

REM Perform placeholder substitutions using PowerShell
REM Write a temporary .ps1 script to avoid CMD parsing issues with $ and ^
set "PS_SCRIPT=!TEMP!\joomla_init_replace.ps1"

(
    echo param^(^)
    echo $f = '!PROJECT_DIR!\CLAUDE.md'
    echo $c = [System.IO.File]::ReadAllText^($f^)
    echo $c = $c.Replace^('{{VENDOR_NAMESPACE}}', '!VENDOR_NS!'^)
    echo $c = $c.Replace^('{{REPO_NAME}}', '!REPO_NAME!'^)
    echo $c = $c.Replace^('{{PROJECT_NAME}}', '!PROJECT_NAME!'^)
    echo $c = $c.Replace^('{{COMPONENT_NAME}}', '!PROJECT_NAME!'^)
    echo $c = $c.Replace^('{{DOMAIN}}', '!DOMAIN!'^)
    echo $c = $c.Replace^('{{DB_CONNECTION_NAME}}', '!DB_CONN!'^)
    echo $c = $c.Replace^('{{DATABASE_NAME}}', '!PROJECT_NAME!'^)
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
echo [3/6] Creating .claude documentation files...

REM Create project-ecosystem.md stub
set "ECOSYSTEM_FILE=%CLAUDE_DIR%\project-ecosystem.md"
if not exist "!ECOSYSTEM_FILE!" (
    set "PS_ECO=!TEMP!\joomla_init_ecosystem.ps1"
    (
        echo param^(^)
        echo $content = @"
        echo # !PROJECT_NAME! - Project Ecosystem
        echo.
        echo ## Extension Overview
        echo.
        echo - **Name**: !PROJECT_NAME!
        echo - **Namespace**: !VENDOR_NS!\!PROJECT_NAME!
        echo - **Status**: In Development
        echo.
        echo ---
        echo.
        echo ## Services Provided
        echo.
        echo Public services and repositories this extension registers in the DI container.
        echo.
        echo ### Repositories
        echo.
        echo ``````php
        echo // TODO: Document repositories this extension provides
        echo // Example:
        echo // namespace !VENDOR_NS!\!PROJECT_NAME!\Repository;
        echo // interface ItemRepository { ... }
        echo ``````
        echo.
        echo ### Services
        echo.
        echo ``````php
        echo // TODO: Document services this extension provides
        echo // Example:
        echo // namespace !VENDOR_NS!\!PROJECT_NAME!\Administrator\Service;
        echo // class MyService { ... }
        echo ``````
        echo.
        echo ---
        echo.
        echo ## Services Consumed
        echo.
        echo External services this extension depends on ^(injected via DI^).
        echo.
        echo ### From com_inventorydata
        echo.
        echo - [Remove this section if not applicable]
        echo.
        echo ### From com_entitydata
        echo.
        echo - [Remove this section if not applicable]
        echo.
        echo ### From com_accountdata
        echo.
        echo - [Remove this section if not applicable]
        echo.
        echo ---
        echo.
        echo ## Events Emitted
        echo.
        echo Events this extension broadcasts for other extensions to listen to.
        echo.
        echo - [Add events emitted by this extension]
        echo.
        echo ---
        echo.
        echo ## Events Consumed
        echo.
        echo Events from other extensions that this extension listens to.
        echo.
        echo - [Add events listened to by this extension]
        echo.
        echo ---
        echo.
        echo ## Extensions That Consume This
        echo.
        echo Other extensions that depend on this extension's services.
        echo.
        echo - [Add consumers here]
        echo.
        echo "@
        echo [System.IO.File]::WriteAllText^('!ECOSYSTEM_FILE!', $content^)
    ) > "!PS_ECO!"
    powershell -ExecutionPolicy Bypass -File "!PS_ECO!"
    del "!PS_ECO!" 2>nul
    echo   Created: !ECOSYSTEM_FILE!
) else (
    echo   Exists: !ECOSYSTEM_FILE!
)

REM Create architecture.md stub
set "ARCH_FILE=%CLAUDE_DIR%\architecture.md"
if not exist "!ARCH_FILE!" (
    set "PS_ARCH=!TEMP!\joomla_init_architecture.ps1"
    (
        echo param^(^)
        echo $content = @"
        echo # !PROJECT_NAME! - Architecture Decisions
        echo.
        echo ## Overview
        echo.
        echo Architectural decisions and patterns for !PROJECT_NAME!.
        echo.
        echo ---
        echo.
        echo ## Service Layer
        echo.
        echo - `Administrator\Service\` contains canonical business logic
        echo - All controllers delegate to services
        echo - Site, API, and CLI layers reuse Administrator services unchanged
        echo - Services registered in `services/provider.php` via DI
        echo.
        echo ---
        echo.
        echo ## Namespace Map
        echo.
        echo ``````
        echo !VENDOR_NS!\Component\!PROJECT_NAME!\
        echo +-- Administrator\
        echo ^|   +-- Controller\
        echo ^|   +-- Model\
        echo ^|   +-- View\
        echo ^|   +-- Service\          ^(business logic^)
        echo ^|   +-- Table\
        echo ^|   +-- Form\
        echo +-- Site\
        echo ^|   +-- Controller\
        echo ^|   +-- Model\
        echo ^|   +-- View\
        echo +-- Api\
        echo ^|   +-- Controller\
        echo ^|   +-- View\
        echo +-- Entity\
        echo +-- Event\
        echo +-- Exception\
        echo ``````
        echo.
        echo ---
        echo.
        echo ## Database Schema
        echo.
        echo [Document tables, relationships, and constraints]
        echo.
        echo ---
        echo.
        echo ## DI Container Registrations
        echo.
        echo [Document service provider registrations]
        echo.
        echo ---
        echo.
        echo ## Event System
        echo.
        echo [Document events emitted and consumed]
        echo.
        echo "@
        echo [System.IO.File]::WriteAllText^('!ARCH_FILE!', $content^)
    ) > "!PS_ARCH!"
    powershell -ExecutionPolicy Bypass -File "!PS_ARCH!"
    del "!PS_ARCH!" 2>nul
    echo   Created: !ARCH_FILE!
) else (
    echo   Exists: !ARCH_FILE!
)

REM --- Step 4: Run agent symlinks ---
echo.
echo [4/6] Creating agent symlinks...
echo   (You will be prompted for each agent)
echo.

REM Pipe project name to avoid re-prompting (symlink scripts prompt for name first)
echo !PROJECT_NAME!| call "%AGENTS_SCRIPT%"

REM --- Step 5: Run include symlinks ---
echo.
echo [5/6] Creating include symlinks...
echo   (You will be prompted for each include)
echo.

echo !PROJECT_NAME!| call "%INCLUDES_SCRIPT%"

REM --- Step 6: Summary ---
echo.
echo ============================================
echo   Project Initialization Complete
echo ============================================
echo.
echo   Project: %PROJECT_DIR%
echo   CLAUDE.md: %PROJECT_DIR%\CLAUDE.md
echo   .claude\project-ecosystem.md (update with your services)
echo   .claude\architecture.md      (update with your design)
echo   Agents: %CLAUDE_DIR%\agents\
echo   Includes: %CLAUDE_DIR%\includes\
echo.
echo   Next steps:
echo   1. Open project in PHPStorm
echo   2. Verify CLAUDE.md placeholders are replaced
echo   3. Update .claude\project-ecosystem.md with your services
echo   4. Start Claude Code in the project directory
echo   5. Use the joomla-architect agent for design
echo   6. Use the joomla-orchestrator agent for full builds
echo.

pause
