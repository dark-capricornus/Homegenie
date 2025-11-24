<#
Open the Visual C++ Build Tools download page and provide brief guidance.

This script cannot silently install MSVC (requires interactive installer and admin).
It will open the browser to the download page and print next steps.

Run:
    .\scripts\install_msvc_build_tools.ps1
#>

Start-Process "https://visualstudio.microsoft.com/visual-cpp-build-tools/"
Write-Host "Opened browser to Visual C++ Build Tools download page."
Write-Host "1) Download the installer, run it, and select 'C++ build tools' workload."
Write-Host "2) After install, restart PowerShell, reactivate your venv, and run:"
Write-Host "    pip install -r config/requirements.txt"
