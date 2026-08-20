# =============================================================================
#  Génère (UNE SEULE FOIS) le certificat de signature de code Wanzo Commerce.
#
#  IMPORTANT : réutilisez le MÊME wanzo_codesign.pfx pour TOUTES les versions.
#  Si vous regénérez un certificat à chaque release, l'identité d'éditeur /
#  la signature changent et les mises à jour MSIX échouent
#  (0x80073CFB « publisher doesn't match » / 0x800B0109 « non approuvé »).
#
#  Le sujet DOIT être CN=Wanzo pour correspondre à `publisher: CN=Wanzo`
#  du pubspec.yaml (msix_config).
#
#  Usage :
#     powershell -ExecutionPolicy Bypass -File generate_cert.ps1 -Password "MotDePasseFort"
# =============================================================================
param(
  [Parameter(Mandatory = $true)][string]$Password,
  [string]$OutDir = $PSScriptRoot
)
$ErrorActionPreference = 'Stop'

$cert = New-SelfSignedCertificate `
  -Type CodeSigningCert `
  -Subject "CN=Wanzo" `
  -KeyUsage DigitalSignature `
  -FriendlyName "Wanzo Commerce Code Signing" `
  -CertStoreLocation "Cert:\CurrentUser\My" `
  -NotAfter (Get-Date).AddYears(5) `
  -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3")

$secure = ConvertTo-SecureString -String $Password -Force -AsPlainText
$pfx = Join-Path $OutDir "wanzo_codesign.pfx"
$cer = Join-Path $OutDir "wanzo_codesign.cer"

Export-PfxCertificate -Cert "Cert:\CurrentUser\My\$($cert.Thumbprint)" -FilePath $pfx -Password $secure | Out-Null
Export-Certificate  -Cert "Cert:\CurrentUser\My\$($cert.Thumbprint)" -FilePath $cer | Out-Null

Write-Host ""
Write-Host "Certificat genere :" -ForegroundColor Green
Write-Host "  PFX (PRIVE - a garder secret, NE PAS committer) : $pfx"
Write-Host "  CER (PUBLIC - a approuver sur les postes clients) : $cer"
Write-Host "  Thumbprint : $($cert.Thumbprint)"
Write-Host ""
Write-Host "Etapes suivantes :" -ForegroundColor Yellow
Write-Host "  1) Conservez le .pfx en lieu sur (gestionnaire de secrets / CI)."
Write-Host "  2) Definissez les variables d'environnement avant chaque build :"
Write-Host "       `$env:WANZO_MSIX_CERT_PATH = '$pfx'"
Write-Host "       `$env:WANZO_MSIX_CERT_PWD  = '<mot de passe>'"
Write-Host "  3) Sur CHAQUE poste client, approuvez UNE FOIS le certificat public"
Write-Host "     (PowerShell ADMINISTRATEUR ; racines de confiance, sinon 0x800B010A) :"
Write-Host "       Import-Certificate -FilePath '$cer' -CertStoreLocation Cert:\LocalMachine\Root"
