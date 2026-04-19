@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM Claude Code Skills Symlink Script
REM
REM Creates symbolic links from shared skills in ClaudeCode repository
REM into a PHPStorm project's .claude\skills\ directory.
REM
REM Each skill is a subdirectory containing a SKILL.md file.
REM Requires: Administrator privileges (for mklink)
REM ============================================================================

REM --- Check for Administrator privileges and self-elevate if needed ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
    exit /b
)

REM --- Load configuration ---
set "CLAUDECODE_DIR=%~dp0.."
for %%I in ("!CLAUDECODE_DIR!") do set "CLAUDECODE_DIR=%%~fI"
if exist "!CLAUDECODE_DIR!\config.bat" (
    call "!CLAUDECODE_DIR!\config.bat"
) else (
    echo Error: config.bat not found. Copy config.bat.example to config.bat and edit it.
    pause
    exit /b 1
)

REM Prompt for PHPStorm project name
set /p PROJECT_NAME="Enter PHPStorm project name: "

REM Validate project name input
if "%PROJECT_NAME%"=="" (
    echo Error: Project name cannot be empty
    pause
    exit /b 1
)

REM Define source and target directories
set SOURCE_DIR=%CLAUDECODE_DIR%\skills
set TARGET_BASE=%PROJECTS_DIR%
set TARGET_DIR=%TARGET_BASE%\%PROJECT_NAME%\.claude\skills

REM Check if source directory exists
if not exist "%SOURCE_DIR%" (
    echo Error: Source directory "%SOURCE_DIR%" does not exist
    pause
    exit /b 1
)

REM Check if project directory exists
if not exist "%TARGET_BASE%\%PROJECT_NAME%" (
    echo Error: Project directory "%TARGET_BASE%\%PROJECT_NAME%" does not exist
    pause
    exit /b 1
)

REM Create target skills directory if needed
if not exist "%TARGET_DIR%" (
    echo Creating directory: %TARGET_DIR%
    mkdir "%TARGET_DIR%"
)

echo.
echo Creating symbolic links from:
echo   Source: %SOURCE_DIR%
echo   Target: %TARGET_DIR%
echo.

REM Recursively discover all SKILL.md files (supports nested directories like joomla/)
REM Source may be nested (e.g. skills/joomla/version-bump/) but target is always flat
REM because Claude Code only discovers skills at the root of .claude/skills/
REM   skills/work-log/SKILL.md            -> .claude/skills/work-log/
REM   skills/joomla/version-bump/SKILL.md  -> .claude/skills/version-bump/
set LINK_COUNT=0
for /r "%SOURCE_DIR%" %%F in (SKILL.md) do (
    if exist "%%F" (
        REM Get the skill's parent directory (full absolute path, trailing backslash removed)
        set SOURCE_SKILL=%%~dpF
        set SOURCE_SKILL=!SOURCE_SKILL:~0,-1!

        REM Extract skill name (last path component only — target is flat)
        for %%N in ("!SOURCE_SKILL!") do set SKILL_NAME=%%~nxN
        set TARGET_SKILL=%TARGET_DIR%\!SKILL_NAME!

        if exist "!TARGET_SKILL!" (
            echo Link already exists for !SKILL_NAME! - skipping
        ) else (
            echo ---
            echo Source: !SOURCE_SKILL!
            set /p CONFIRM="Create link for skill '!SKILL_NAME!'? (Y/N): "
            if /i "!CONFIRM!"=="Y" (
                echo Creating junction: !SKILL_NAME!
                mklink /J "!TARGET_SKILL!" "!SOURCE_SKILL!"
                if !errorlevel! equ 0 (
                    set /a LINK_COUNT+=1
                ) else (
                    echo Warning: Failed to create link for !SKILL_NAME!
                )
            ) else (
                echo Skipping !SKILL_NAME! - user declined
            )
        )
    )
)

echo.
echo Process completed. Created %LINK_COUNT% junction(s).
echo Target directory: %TARGET_DIR%
pause
