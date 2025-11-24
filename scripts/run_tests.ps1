<#
PowerShell helper to run tests. Usage: .\run_tests.ps1 [-DbUrl <string>]
Set environment variable DRY_RUN=1 to echo the pytest command instead of running.
#>

param(
    [string]$DbUrl
)

$pytest = 'pytest -q'

if ($DbUrl) {
    $env:POSTGRES_URL = $DbUrl
    Write-Host "Using POSTGRES_URL=$DbUrl"
}

if ($env:DRY_RUN -eq '1') {
    Write-Host "DRY RUN: $pytest"
} else {
    Write-Host "Running: $pytest"
    & pytest -q
}
