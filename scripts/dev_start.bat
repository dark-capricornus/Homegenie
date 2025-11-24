@echo off
rem Dev helper (cmd) - starts required dev services with docker-compose
rem Usage: dev_start.bat [--full]
rem Set environment variable DRY_RUN=1 to only echo commands instead of running them.

setlocal
set "DC=d:\Homegenie\docker-compose.yml"
set "DRY=%DRY_RUN%"

if "%~1"=="--full" (
    set "SERVICES=globalone homegenie-mqtt homegenie"
) else (
    set "SERVICES=globalone homegenie-mqtt homegenie-dev"
)

echo [homegenie] Starting services: %SERVICES%

set "CMD=docker-compose -f %DC% up -d --build %SERVICES%"

if "%DRY%"=="1" (
    echo DRY RUN: %CMD%
) else (
    echo Running: %CMD%
    %CMD%
)

endlocal
