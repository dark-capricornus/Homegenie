<#
Create and activate a Python 3.11 virtual environment and install requirements.

Behavior:
- If `py -3.11` is present, it creates `.venv311`, activates it, upgrades pip, and installs requirements.
- If not present, it downloads the official Python 3.11 installer to `./bootstrap/` and prints next steps.

Run from repository root in PowerShell (not elevated unless installing Python):
    .\scripts\setup_py311_venv.ps1
#>

Set-StrictMode -Version Latest

param()

function Exec([string]$cmd) {
    Write-Host "> $cmd"
    iex $cmd
}

Write-Host "Checking for Python 3.11 (py -3.11)..."
$py311 = & py -3.11 --version 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Found Python 3.11: $py311"
    if (-Not (Test-Path .venv311)) {
        Write-Host "Creating virtualenv .venv311..."
        Exec "py -3.11 -m venv .venv311"
    } else {
        Write-Host ".venv311 already exists"
    }

    Write-Host "Activating venv and installing requirements..."
    Exec ".\.venv311\Scripts\Activate.ps1; python -m pip install --upgrade pip"
    Exec ".\.venv311\Scripts\Activate.ps1; pip install -r config/requirements.txt"
    Write-Host "Done. Activate with: .\\.venv311\\Scripts\\Activate.ps1"
    exit 0
} else {
    Write-Host "Python 3.11 not found via py launcher."
    $bootstrap = Join-Path (Get-Location) "bootstrap"
    if (-Not (Test-Path $bootstrap)) { New-Item -ItemType Directory -Path $bootstrap | Out-Null }
    $installer = Join-Path $bootstrap "python-3.11.19-amd64.exe"
    if (-Not (Test-Path $installer)) {
        Write-Host "Downloading Python 3.11 installer to $installer..."
        $url = 'https://www.python.org/ftp/python/3.11.19/python-3.11.19-amd64.exe'
        Invoke-WebRequest -Uri $url -OutFile $installer
        Write-Host "Downloaded installer. To install Python 3.11 run the installer (recommended: Run as Administrator)"
    } else {
        Write-Host "Installer already present at $installer"
    }

    Write-Host "After installing Python 3.11, re-run this script. Or create a venv manually with:\n    py -3.11 -m venv .venv311\n    .\\.venv311\\Scripts\\Activate.ps1\n    pip install -r config/requirements.txt"
    exit 2
}
