@echo off
rem Run tests helper (cmd)
rem Usage: run_tests.bat [--db-url "<url>"]
rem Set DRY_RUN=1 to only echo the pytest command.

setlocal
set "PYTEST=pytest -q"

if "%~1"=="--db-url" (
    shift
    set "POSTGRES_URL=%~1"
    set "POSTGRES_SET=1"
) else (
    set "POSTGRES_SET=%POSTGRES_SET%"
)

if "%POSTGRES_SET%"=="1" (
    set "OLD=%%POSTGRES_URL%%"
    set "POSTGRES_URL=%POSTGRES_URL%"
    echo Using POSTGRES_URL=%POSTGRES_URL%
)

if "%DRY_RUN%"=="1" (
    echo DRY RUN: %PYTEST%
) else (
    echo Running: %PYTEST%
    %PYTEST%
)

endlocal
