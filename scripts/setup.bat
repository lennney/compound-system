@echo off
REM Compound System - Windows Setup Wrapper
REM This script helps set up Compound System on Windows

setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set COMPOUND_ROOT=%SCRIPT_DIR%..

echo ==========================================
echo   Compound System - Windows Setup
echo ==========================================
echo.

REM Check if bash is available
where bash >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: bash not found!
    echo.
    echo Please install one of the following:
    echo   1. Git for Windows (https://git-scm.com/download/win)
    echo   2. WSL (Windows Subsystem for Linux)
    echo   3. MSYS2 (https://www.msys2.org/)
    echo.
    echo After installation, run this script again.
    pause
    exit /b 1
)

echo [OK] bash found
echo.

REM Check if Python is available
where python >nul 2>&1
if %errorlevel% neq 0 (
    where python3 >nul 2>&1
    if %errorlevel% neq 0 (
        echo WARNING: Python not found!
        echo.
        echo Python is required for LLM API calls.
        echo Please install Python from https://www.python.org/downloads/
        echo.
        echo After installation, run this script again.
        pause
        exit /b 1
    )
    set PYTHON_CMD=python3
) else (
    set PYTHON_CMD=python
)

echo [OK] Python found: %PYTHON_CMD%
echo.

REM Make scripts executable (for Git Bash)
echo Setting up script permissions...
bash -c "chmod +x '%COMPOUND_ROOT%/scripts/*.sh'"

REM Run setup wizard
echo Running setup wizard...
echo.
bash "%COMPOUND_ROOT%/scripts/setup.sh"

echo.
echo ==========================================
echo   Setup Complete!
echo ==========================================
echo.
echo Next steps:
echo   1. Configure your LLM API: bash scripts/setup.sh
echo   2. Initialize for your platform: bash scripts/init-platform.sh ^<platform^>
echo   3. Start using: bash scripts/reflect.sh "task" success medium
echo.
echo Available platforms:
echo   - claude-code
echo   - cursor
echo   - copilot
echo   - aider
echo.
pause
