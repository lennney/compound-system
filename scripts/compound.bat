@echo off
REM Compound System - Windows Wrapper
REM Usage: compound.bat <command> [args]

setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set COMPOUND_ROOT=%SCRIPT_DIR%..

REM Check if bash is available
where bash >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: bash not found!
    echo Please install Git for Windows, WSL, or MSYS2.
    exit /b 1
)

REM Check arguments
if "%~1"=="" (
    echo Compound Engineering System
    echo.
    echo Usage:
    echo   compound.bat ^<command^> [args]
    echo.
    echo Commands:
    echo   setup              - Run setup wizard
    echo   reflect ^<task^> [status] [severity] [error]
    echo   search ^<query^>
    echo   checkpoint ^<action^> [args]
    echo   status
    echo   refresh
    echo   init ^<platform^>   - Initialize for platform
    echo   test               - Test LLM connection
    echo.
    echo Examples:
    echo   compound.bat setup
    echo   compound.bat reflect "fixed login bug" success medium
    echo   compound.bat search "401 error"
    echo   compound.bat checkpoint save "task1" "phase1" "[\"s1\"]" "[\"s2\"]"
    echo   compound.bat checkpoint list
    echo   compound.bat init claude-code
    echo   compound.bat test
    goto :eof
)

REM Execute command
if "%~1"=="setup" (
    bash "%COMPOUND_ROOT%/scripts/setup.sh" %2 %3 %4 %5
    goto :eof
)

if "%~1"=="reflect" (
    bash "%COMPOUND_ROOT%/scripts/reflect.sh" %2 %3 %4 %5
    goto :eof
)

if "%~1"=="search" (
    bash "%COMPOUND_ROOT%/scripts/search.sh" %2
    goto :eof
)

if "%~1"=="checkpoint" (
    bash "%COMPOUND_ROOT%/scripts/checkpoint.sh" %2 %3 %4 %5 %6
    goto :eof
)

if "%~1"=="status" (
    bash "%COMPOUND_ROOT%/scripts/compound.sh" status
    goto :eof
)

if "%~1"=="refresh" (
    bash "%COMPOUND_ROOT%/scripts/refresh.sh" %2 %3
    goto :eof
)

if "%~1"=="init" (
    bash "%COMPOUND_ROOT%/scripts/init-platform.sh" %2 %3 %4
    goto :eof
)

if "%~1"=="test" (
    bash "%COMPOUND_ROOT%/scripts/setup.sh" --test
    goto :eof
)

if "%~1"=="auto" (
    bash "%COMPOUND_ROOT%/scripts/auto-reflect.sh" %2 %3 %4 %5
    goto :eof
)

echo Unknown command: %~1
echo Run compound.bat to see help
exit /b 1
