# Script d'installation des outils de build Windows pour Flutter Desktop
# Exécuter en tant qu'administrateur

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Installation des outils Flutter Desktop" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Vérifier si winget est disponible
$wingetInstalled = Get-Command winget -ErrorAction SilentlyContinue

if ($wingetInstalled) {
    Write-Host "`nInstallation de Visual Studio Build Tools 2022..." -ForegroundColor Yellow
    
    # Installer VS Build Tools avec les workloads nécessaires
    winget install Microsoft.VisualStudio.2022.BuildTools --silent --accept-package-agreements --accept-source-agreements
    
    Write-Host "`nConfiguration des workloads C++..." -ForegroundColor Yellow
    
    # Télécharger le Visual Studio Installer
    $vsInstallerPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe"
    
    if (Test-Path $vsInstallerPath) {
        # Modifier l'installation pour ajouter les composants nécessaires
        Start-Process -FilePath $vsInstallerPath -ArgumentList "modify", "--installPath", "`"${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools`"", "--add", "Microsoft.VisualStudio.Workload.VCTools", "--add", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "--add", "Microsoft.VisualStudio.Component.VC.CMake.Project", "--add", "Microsoft.VisualStudio.Component.Windows10SDK.19041", "--passive" -Wait
    }
} else {
    Write-Host "winget n'est pas disponible. Installation manuelle requise." -ForegroundColor Red
    Write-Host "`nVeuillez télécharger Visual Studio Build Tools depuis:" -ForegroundColor Yellow
    Write-Host "https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022" -ForegroundColor White
    Write-Host "`nPendant l'installation, sélectionnez:" -ForegroundColor Yellow
    Write-Host "  - 'Desktop development with C++'" -ForegroundColor White
    Write-Host "  - MSVC v143 - VS 2022 C++ x64/x86 build tools" -ForegroundColor White
    Write-Host "  - C++ CMake tools for Windows" -ForegroundColor White
    Write-Host "  - Windows 10 SDK (ou Windows 11 SDK)" -ForegroundColor White
}

Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "Après l'installation, exécutez:" -ForegroundColor Cyan
Write-Host "  flutter doctor" -ForegroundColor White
Write-Host "  flutter build windows" -ForegroundColor White
Write-Host "=============================================" -ForegroundColor Cyan
