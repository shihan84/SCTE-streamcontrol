@echo off
REM GitHub Repository Update Script for Windows

echo === GitHub Repository Update ===

REM Check if this is a git repository
if not exist ".git" (
    echo ERROR: This directory is not a git repository.
    echo Please run this script from the root of your cloned repository.
    pause
    exit /b 1
)

REM Get current branch
for /f "delims=" %%A in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set CURRENT_BRANCH=%%A
if errorlevel 1 (
    echo ERROR: Not a git repository or git not installed.
    pause
    exit /b 1
)

echo Current branch: %CURRENT_BRANCH%

REM Check for uncommitted changes
git status --porcelain >nul 2>&1
if %errorlevel% equ 0 (
    echo WARNING: You have uncommitted changes.
    echo Stashing them before pulling...
    git stash push -m "Auto-stash %date% %time%" >nul 2>&1
    set STASHED=true
)

REM Fetch latest changes
echo Fetching from remote...
git fetch origin >nul 2>&1
if errorlevel 1 (
    echo ERROR: Failed to fetch from remote.
    echo Please check your internet connection and remote URL.
    pause
    exit /b 1
)

REM Check if we need to pull
for /f "delims=" %%A in ('git rev-list --count HEAD..origin/%CURRENT_BRANCH% 2^>nul') do set BEHIND_COUNT=%%A
if "%BEHIND_COUNT%"=="0" (
    echo Already up to date.
) else (
    echo Pulling %BEHIND_COUNT% new commit^(s^)...
    git pull origin %CURRENT_BRANCH% >nul 2>&1
    if errorlevel 1 (
        echo ERROR: Failed to pull changes.
        echo There might be conflicts. Please resolve manually.
        pause
        exit /b 1
    )
    echo Successfully pulled latest changes.
)

REM Apply stashed changes if any
if defined STASHED (
    echo Applying your stashed changes...
    git stash pop >nul 2>&1
    if errorlevel 1 (
        echo WARNING: Conflicts when applying stashed changes.
        echo Please resolve manually.
    )
)

REM Check if package.json changed
git diff --name-only HEAD@{1} HEAD >nul 2>&1 | findstr "package.json" >nul
if %errorlevel% equ 0 (
    echo package.json was updated.
    echo Consider running 'npm install' to update dependencies.
)

echo === Update completed ===
for /f "delims=" %%A in ('git rev-parse --short HEAD 2^>nul') do echo Current commit: %%A
pause