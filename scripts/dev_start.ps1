<#
Dev helper (PowerShell) - starts required dev services with docker-compose
Usage: .\dev_start.ps1 [-Full]
Set environment variable DRY_RUN=1 to only echo commands instead of running them.
#>

param(
    [switch]$Full
)

$DC = 'd:\Homegenie\docker-compose.yml'
$services = if ($Full) { 'globalone','homegenie-mqtt','homegenie' } else { 'globalone','homegenie-mqtt','homegenie-dev' }

Write-Host "[homegenie] Starting services: $($services -join ' ')"

$cmd = "docker-compose -f $DC up -d --build $($services -join ' ')"

if ($env:DRY_RUN -eq '1') {
    Write-Host "DRY RUN: $cmd"
} else {
    Write-Host "Running: $cmd"
    Invoke-Expression $cmd
}
