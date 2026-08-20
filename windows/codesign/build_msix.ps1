# =============================================================================
#  Build du paquet MSIX de PRODUCTION de Wanzo Commerce, signé avec le
#  certificat PERSISTANT (le même pour toutes les versions).
#
#  Prérequis (variables d'environnement) :
#     WANZO_MSIX_CERT_PATH = chemin absolu du wanzo_codesign.pfx
#     WANZO_MSIX_CERT_PWD  = mot de passe du .pfx
#
#  La version MSIX est dérivée automatiquement de `version:` du pubspec.yaml
#  (ex. 1.0.1+2 -> 1.0.1.2). BUMPEZ `version:` à chaque release, sinon Windows
#  refusera la mise a jour (« version deja installee », 0x80073CF3).
#
#  Usage :
#     powershell -ExecutionPolicy Bypass -File build_msix.ps1
# =============================================================================
$ErrorActionPreference = 'Stop'

if (-not $env:WANZO_MSIX_CERT_PATH) { throw "WANZO_MSIX_CERT_PATH n'est pas definie (chemin du .pfx)." }
if (-not $env:WANZO_MSIX_CERT_PWD)  { throw "WANZO_MSIX_CERT_PWD n'est pas definie (mot de passe du .pfx)." }
if (-not (Test-Path $env:WANZO_MSIX_CERT_PATH)) { throw "Certificat introuvable : $($env:WANZO_MSIX_CERT_PATH)" }

# Racine du projet (deux niveaux au-dessus de windows/codesign/)
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Push-Location $projectRoot
try {
  Write-Host "Build MSIX signe (publisher CN=Wanzo, version derivee du pubspec)..." -ForegroundColor Cyan
  # --install-certificate false : NE PAS demander l'installation du .pfx dans le
  # magasin local (ce prompt interactif fait planter les builds non-interactifs
  # /CI AVANT la signature -> MSIX non signe). La signature avec le .pfx se fait
  # quand meme via --certificate-path.
  dart run msix:create `
    --publisher "CN=Wanzo" `
    --certificate-path "$env:WANZO_MSIX_CERT_PATH" `
    --certificate-password "$env:WANZO_MSIX_CERT_PWD" `
    --install-certificate false
  Write-Host ""
  Write-Host "MSIX genere dans build\windows\x64\runner\Release\*.msix" -ForegroundColor Green
} finally {
  Pop-Location
}
