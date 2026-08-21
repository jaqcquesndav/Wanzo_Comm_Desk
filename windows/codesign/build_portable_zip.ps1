# =============================================================================
#  Construit la version DESKTOP PORTABLE (ZIP) de Wanzo Commerce.
#
#  Portable = l'utilisateur dézippe et lance wanzo.exe. AUCUNE installation,
#  AUCUN certificat, AUCUN droit admin.
#
#  ⚠️ Inclut le RUNTIME Visual C++ (msvcp140/vcruntime140...) : sans lui,
#  l'app plante au lancement sur un PC "propre" avec une erreur trompeuse du
#  type « connectivity_plus_plugin.dll introuvable » (la DLL est là, mais sa
#  dépendance runtime manque).
#
#  Usage :
#     powershell -ExecutionPolicy Bypass -File windows\codesign\build_portable_zip.ps1
# =============================================================================
$ErrorActionPreference = 'Stop'
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Push-Location $projectRoot
try {
  Write-Host "1/3 flutter build windows --release..." -ForegroundColor Cyan
  flutter build windows --release

  $rel = Join-Path $projectRoot "build\windows\x64\runner\Release"
  if (-not (Test-Path (Join-Path $rel 'wanzo.exe'))) { throw "Release/wanzo.exe introuvable." }

  # Staging propre
  $stage = Join-Path $env:TEMP ("wanzo_portable_" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $stage -Force | Out-Null

  Write-Host "2/3 assemblage (app + runtime VC++)..." -ForegroundColor Cyan
  # App : exe + DLLs plugins + data/ ; on exclut les artefacts msix/zip/certs.
  Get-ChildItem $rel -Exclude *.msix, *.zip, *.pfx, *.cer | Copy-Item -Destination $stage -Recurse -Force
  # Runtime Visual C++ 2015-2022 x64 (redistribuable Microsoft).
  $vc = 'msvcp140.dll','msvcp140_1.dll','msvcp140_2.dll','vcruntime140.dll','vcruntime140_1.dll','concrt140.dll','vcruntime140_threads.dll'
  foreach ($d in $vc) { $src = "C:\Windows\System32\$d"; if (Test-Path $src) { Copy-Item $src -Destination $stage -Force } }

  Write-Host "3/3 compression..." -ForegroundColor Cyan
  $zip = Join-Path $projectRoot "build\Wanzo_Commerce_windows_portable.zip"
  Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal -Force
  Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue

  Write-Host ""
  Write-Host "OK - ZIP portable : $zip" -ForegroundColor Green
  Write-Host "     Uploadez-le sur Drive (remplacez le fichier existant pour garder le meme lien)."
} finally {
  Pop-Location
}
