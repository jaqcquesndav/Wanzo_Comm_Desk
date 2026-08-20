# =============================================================================
#  A) Build MSIX + signature via AZURE TRUSTED SIGNING
#     -> certificat émis par une AC de confiance Microsoft
#     -> installation & mises à jour EN UN CLIC depuis votre site (ZÉRO manip
#        de certificat côté utilisateur).
#     -> coût facturé sur votre abonnement/crédits Azure.
#
#  À CRÉER UNE FOIS côté Azure (portail) :
#     1. Ressource "Trusted Signing" (Code Signing Account).
#     2. Un "Certificate profile" (type Public Trust).
#     3. Noter : Endpoint (région), nom du compte, nom du profil, et le SUJET
#        exact du certificat (ex. "CN=Wanzo, O=Wanzo, C=CD").
#     4. Installer : Windows SDK (signtool.exe) + le dlib Trusted Signing
#        (Microsoft.Trusted.Signing.Client -> Azure.CodeSigning.Dlib.dll).
#     5. S'authentifier : `az login` (ou service principal via variables AZURE_*).
#
#  Variables d'environnement attendues :
#     AZURE_TS_DLIB      = chemin de Azure.CodeSigning.Dlib.dll
#     AZURE_TS_METADATA  = chemin du JSON (voir azure_signing_metadata.template.json)
#     AZURE_TS_PUBLISHER = sujet EXACT du certificat Trusted Signing
#     SIGNTOOL           = chemin de signtool.exe (Windows SDK)
#
#  La version MSIX est dérivée de `version:` du pubspec (bumpez-la à chaque release).
# =============================================================================
$ErrorActionPreference = 'Stop'
foreach ($v in 'AZURE_TS_DLIB', 'AZURE_TS_METADATA', 'AZURE_TS_PUBLISHER', 'SIGNTOOL') {
  if (-not (Get-Item "env:$v" -ErrorAction SilentlyContinue)) { throw "Variable d'environnement manquante : $v" }
}
if (-not (Test-Path $env:AZURE_TS_DLIB))     { throw "Introuvable : $($env:AZURE_TS_DLIB)" }
if (-not (Test-Path $env:AZURE_TS_METADATA)) { throw "Introuvable : $($env:AZURE_TS_METADATA)" }
if (-not (Test-Path $env:SIGNTOOL))          { throw "Introuvable : $($env:SIGNTOOL)" }

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Push-Location $projectRoot
try {
  # 1) MSIX NON signé, avec le publisher == sujet du certificat Azure.
  Write-Host "Build MSIX non signe (publisher = $($env:AZURE_TS_PUBLISHER))..." -ForegroundColor Cyan
  dart run msix:create --sign-msix false --publisher "$env:AZURE_TS_PUBLISHER"

  $msix = Get-ChildItem "build\windows\x64\runner\Release\*.msix" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $msix) { throw "MSIX introuvable apres build." }

  # 2) Signature via Azure Trusted Signing (horodatage RFC3161 Azure).
  Write-Host "Signature Azure Trusted Signing de $($msix.Name)..." -ForegroundColor Cyan
  & "$env:SIGNTOOL" sign /v /debug /fd SHA256 `
    /tr "http://timestamp.acs.microsoft.com" /td SHA256 `
    /dlib "$env:AZURE_TS_DLIB" /dmdf "$env:AZURE_TS_METADATA" `
    "$($msix.FullName)"
  if ($LASTEXITCODE -ne 0) { throw "signtool a echoue (code $LASTEXITCODE)." }

  Write-Host ""
  Write-Host "OK - MSIX signe Azure Trusted Signing : $($msix.FullName)" -ForegroundColor Green
  Write-Host "     Publiez-le tel quel sur votre site : install/maj en 1 clic, sans manip de certificat."
} finally {
  Pop-Location
}
