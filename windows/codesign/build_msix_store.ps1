# =============================================================================
#  B) Build MSIX pour le MICROSOFT STORE
#     -> c'est le Store qui SIGNE le paquet : AUCUN certificat à gérer.
#     -> mises à jour gérées automatiquement par le Store.
#
#  À FAIRE UNE FOIS côté Partner Center (https://partner.microsoft.com) :
#     1. Créer le compte développeur (Partner Center).
#     2. Réserver le nom de l'app -> "Nouveau produit".
#     3. Page "Identité du produit" : relever
#          - Package/Identity Name          (ex. 12345Wanzo.WanzoCommerce)
#          - Publisher (Publisher ID)       (ex. CN=ABCD1234-5678-...)
#          - Publisher display name         (ex. Wanzo)
#     4. Préparer le listing (description, captures, POLITIQUE DE CONFIDENTIALITÉ
#        (URL obligatoire), classification d'âge).
#
#  Variables d'environnement (valeurs de la page "Identité du produit") :
#     WANZO_STORE_IDENTITY_NAME      = Package/Identity Name
#     WANZO_STORE_PUBLISHER          = Publisher (CN=...)
#     WANZO_STORE_PUBLISHER_DISPLAY  = Publisher display name
#
#  Puis : téléverser le .msix produit dans Partner Center et soumettre à la
#  certification (~1 à 3 jours). BUMPEZ `version:` du pubspec à chaque soumission.
# =============================================================================
$ErrorActionPreference = 'Stop'
foreach ($v in 'WANZO_STORE_IDENTITY_NAME', 'WANZO_STORE_PUBLISHER', 'WANZO_STORE_PUBLISHER_DISPLAY') {
  if (-not (Get-Item "env:$v" -ErrorAction SilentlyContinue)) { throw "Variable d'environnement manquante : $v" }
}

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Push-Location $projectRoot
try {
  Write-Host "Build MSIX Store (identite Partner Center, non signe localement)..." -ForegroundColor Cyan
  dart run msix:create `
    --store `
    --identity-name "$env:WANZO_STORE_IDENTITY_NAME" `
    --publisher "$env:WANZO_STORE_PUBLISHER" `
    --publisher-display-name "$env:WANZO_STORE_PUBLISHER_DISPLAY"
  Write-Host ""
  Write-Host "OK - MSIX Store : build\windows\x64\runner\Release\*.msix" -ForegroundColor Green
  Write-Host "     Televersez-le dans Partner Center puis soumettez a la certification."
} finally {
  Pop-Location
}
