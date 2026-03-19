@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM Joomla Development Symlink Script
REM
REM Creates Windows junction links from repository source directories into a
REM local Joomla installation for live development.
REM
REM Supports:
REM   - Components: admin/, site/, api/, media/ subdirectories
REM   - Plugins: auto-detects single-level and group/name structures
REM
REM Requires: Administrator privileges (for mklink /J)
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
echo   Joomla Development Symlink Creator
echo ============================================
echo.

REM --- Gather information ---
set /p REPO_NAME="Repository folder name (under E:\repositories\): "
if "%REPO_NAME%"=="" (
    echo Error: Repository name cannot be empty.
    pause
    exit /b 1
)

set "REPO_DIR=E:\repositories\%REPO_NAME%"
if not exist "%REPO_DIR%" (
    echo Error: Repository not found at %REPO_DIR%
    pause
    exit /b 1
)

set /p DOMAIN="Joomla instance folder name (under E:\www\): "
if "%DOMAIN%"=="" (
    echo Error: Domain name cannot be empty.
    pause
    exit /b 1
)

set "JOOMLA_DIR=E:\www\%DOMAIN%"
if not exist "%JOOMLA_DIR%" (
    echo Error: Joomla installation not found at %JOOMLA_DIR%
    pause
    exit /b 1
)

echo.
echo   Repository: %REPO_DIR%
echo   Joomla:     %JOOMLA_DIR%
echo.

set LINK_COUNT=0

REM ============================================================================
REM Component Linking (admin, site, api, media)
REM ============================================================================

REM --- admin/com_* -> administrator/components/com_* ---
if exist "%REPO_DIR%\admin\" (
    for /d %%C in ("%REPO_DIR%\admin\com_*") do (
        set "COMP_NAME=%%~nxC"
        set "TARGET=%JOOMLA_DIR%\administrator\components\!COMP_NAME!"
        if exist "!TARGET!" (
            echo   SKIP: admin\!COMP_NAME! ^(already exists^)
        ) else (
            echo   LINK: admin\!COMP_NAME! -^> administrator\components\!COMP_NAME!
            mklink /J "!TARGET!" "%%C" >nul
            set /a LINK_COUNT+=1
        )
    )
)

REM --- site/com_* -> components/com_* ---
if exist "%REPO_DIR%\site\" (
    for /d %%C in ("%REPO_DIR%\site\com_*") do (
        set "COMP_NAME=%%~nxC"
        set "TARGET=%JOOMLA_DIR%\components\!COMP_NAME!"
        if exist "!TARGET!" (
            echo   SKIP: site\!COMP_NAME! ^(already exists^)
        ) else (
            echo   LINK: site\!COMP_NAME! -^> components\!COMP_NAME!
            mklink /J "!TARGET!" "%%C" >nul
            set /a LINK_COUNT+=1
        )
    )
)

REM --- api/com_* -> api/components/com_* ---
if exist "%REPO_DIR%\api\" (
    if not exist "%JOOMLA_DIR%\api\components" (
        mkdir "%JOOMLA_DIR%\api\components"
    )
    for /d %%C in ("%REPO_DIR%\api\com_*") do (
        set "COMP_NAME=%%~nxC"
        set "TARGET=%JOOMLA_DIR%\api\components\!COMP_NAME!"
        if exist "!TARGET!" (
            echo   SKIP: api\!COMP_NAME! ^(already exists^)
        ) else (
            echo   LINK: api\!COMP_NAME! -^> api\components\!COMP_NAME!
            mklink /J "!TARGET!" "%%C" >nul
            set /a LINK_COUNT+=1
        )
    )
)

REM --- media/com_* -> media/com_* ---
if exist "%REPO_DIR%\media\" (
    for /d %%C in ("%REPO_DIR%\media\com_*") do (
        set "COMP_NAME=%%~nxC"
        set "TARGET=%JOOMLA_DIR%\media\!COMP_NAME!"
        if exist "!TARGET!" (
            echo   SKIP: media\!COMP_NAME! ^(already exists^)
        ) else (
            echo   LINK: media\!COMP_NAME! -^> media\!COMP_NAME!
            mklink /J "!TARGET!" "%%C" >nul
            set /a LINK_COUNT+=1
        )
    )
)

REM ============================================================================
REM Plugin Linking (auto-detect depth)
REM ============================================================================

if exist "%REPO_DIR%\plugins\" (
    echo.
    echo   Scanning plugins...

    for /d %%G in ("%REPO_DIR%\plugins\*") do (
        set "GROUP_NAME=%%~nxG"
        set "IS_PLUGIN=0"

        REM Check if this directory is itself a plugin (has src/ or .xml manifest)
        if exist "%%G\src\" set "IS_PLUGIN=1"
        if "!IS_PLUGIN!"=="0" (
            for %%X in ("%%G\*.xml") do set "IS_PLUGIN=1"
        )

        if "!IS_PLUGIN!"=="1" (
            REM Single-level: plugins/{name} is a plugin directly
            set "TARGET=%JOOMLA_DIR%\plugins\!GROUP_NAME!"
            if exist "!TARGET!" (
                echo   SKIP: plugins\!GROUP_NAME! ^(already exists^)
            ) else (
                echo   LINK: plugins\!GROUP_NAME! -^> plugins\!GROUP_NAME!
                mklink /J "!TARGET!" "%%G" >nul
                set /a LINK_COUNT+=1
            )
        ) else (
            REM Group directory: iterate sub-plugins
            for /d %%P in ("%%G\*") do (
                set "PLUGIN_NAME=%%~nxP"
                set "IS_SUB_PLUGIN=0"

                if exist "%%P\src\" set "IS_SUB_PLUGIN=1"
                if "!IS_SUB_PLUGIN!"=="0" (
                    for %%X in ("%%P\*.xml") do set "IS_SUB_PLUGIN=1"
                )

                if "!IS_SUB_PLUGIN!"=="1" (
                    if not exist "%JOOMLA_DIR%\plugins\!GROUP_NAME!" (
                        mkdir "%JOOMLA_DIR%\plugins\!GROUP_NAME!"
                    )
                    set "TARGET=%JOOMLA_DIR%\plugins\!GROUP_NAME!\!PLUGIN_NAME!"
                    if exist "!TARGET!" (
                        echo   SKIP: plugins\!GROUP_NAME!\!PLUGIN_NAME! ^(already exists^)
                    ) else (
                        echo   LINK: plugins\!GROUP_NAME!\!PLUGIN_NAME! -^> plugins\!GROUP_NAME!\!PLUGIN_NAME!
                        mklink /J "!TARGET!" "%%P" >nul
                        set /a LINK_COUNT+=1
                    )
                )
            )
        )
    )
)

REM ============================================================================
REM Summary
REM ============================================================================

echo.
echo ============================================
echo   Done: !LINK_COUNT! junction^(s^) created
echo ============================================
echo.

pause