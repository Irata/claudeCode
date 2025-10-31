@echo off
setlocal enabledelayedexpansion

REM   1. Prompts for a PHPStorm project name
REM   2. Validates the source directory e:\repositories\ClaudeCode\includes\joomla exists
REM   3. Validates the target project directory exists
REM   4. Creates the .claude\includes folder if needed
REM   5. Creates symbolic links for each file from the Joomla includes directory
REM   6. Provides progress feedback and error handling
REM   7. Shows a summary of created links
REM   The batch file includes error checking for missing directories and handles existing links gracefully.

REM Prompt for PHPStorm project name
set /p PROJECT_NAME="Enter PHPStorm project name: "

REM Validate project name input
if "%PROJECT_NAME%"=="" (
    echo Error: Project name cannot be empty
    pause
    exit /b 1
)

REM Define source and target directories
set SOURCE_DIR=e:\repositories\ClaudeCode\includes
set TARGET_BASE=E:\PHPStorm Project Files
set TARGET_DIR=%TARGET_BASE%\%PROJECT_NAME%\.claude\includes

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


echo.
echo Creating symbolic links from:
echo   Source: %SOURCE_DIR%
echo   Target: %TARGET_DIR%
echo.

REM Process files recursively
set LINK_COUNT=0
for /f "delims=" %%f in ('dir /s /b /a-d "%SOURCE_DIR%"') do (
    set SOURCE_FILE=%%f
    set RELATIVE_PATH=%%~dpf
    set RELATIVE_PATH=!RELATIVE_PATH:%SOURCE_DIR%\=!
    set FILENAME=%%~nxf
    set TARGET_FILE=%TARGET_DIR%\!RELATIVE_PATH!!FILENAME!

    REM Check if target link already exists
    if exist "!TARGET_FILE!" (
        echo Link already exists for !FILENAME! - skipping
    ) else (
    	echo ---
        set /p CONFIRM="Create link for !FILENAME!? (Y/N): "
        if /i "!CONFIRM!"=="Y" (
            REM Create target directory if it doesn't exist
            if not exist "%TARGET_DIR%\!RELATIVE_PATH!" (
                echo Creating directory: %TARGET_DIR%\!RELATIVE_PATH!
                mkdir "%TARGET_DIR%\!RELATIVE_PATH!"
                if !errorlevel! neq 0 (
                    echo Error: Failed to create directory "%TARGET_DIR%\!RELATIVE_PATH!"
                    pause
                    exit /b 1
                )
            )
            echo Creating link: !FILENAME!
            mklink "!TARGET_FILE!" "!SOURCE_FILE!"
            if !errorlevel! equ 0 (
                set /a LINK_COUNT+=1
            ) else (
                echo Warning: Failed to create link for !FILENAME!
            )
        ) else (
            echo Skipping !FILENAME! - user declined
        )
    )
)

echo.
echo Process completed. Created %LINK_COUNT% symbolic links.
echo Target directory: %TARGET_DIR%
pause