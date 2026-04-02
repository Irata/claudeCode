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

REM Prompt for PHPStorm project name
set /p PROJECT_NAME="Enter PHPStorm project name: "

REM Validate project name input
if "%PROJECT_NAME%"=="" (
    echo Error: Project name cannot be empty
    pause
    exit /b 1
)

REM Define source and target directories
set SOURCE_DIR=e:\repositories\ClaudeCode\skills
set TARGET_BASE=E:\PHPStorm Project Files
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

REM Process each skill subdirectory (skip .bat files in the root)
set LINK_COUNT=0
for /d %%D in ("%SOURCE_DIR%\*") do (
    set SKILL_NAME=%%~nxD
    set SOURCE_SKILL=%%D
    set TARGET_SKILL=%TARGET_DIR%\!SKILL_NAME!

    REM Check if SKILL.md exists in the source
    if exist "!SOURCE_SKILL!\SKILL.md" (
        if exist "!TARGET_SKILL!" (
            echo Link already exists for !SKILL_NAME! - skipping
        ) else (
            echo ---
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
