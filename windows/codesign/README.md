# Signature & MSIX — Wanzo Commerce (desktop Windows)

Ce dossier permet de produire un **MSIX de production** dont les **mises à jour
s'installent par‑dessus** l'ancienne version (sans désinstaller).

## Pourquoi les mises à jour MSIX échouaient

1. **Version figée** : `msix_version` était codée en dur (`1.0.1.0`). Windows
   refuse d'installer si la version n'est pas **strictement supérieure**
   (erreur `0x80073CF3` / `0x80073D06`).
2. **Certificat régénéré** : avec `store: false` sans certificat fixe,
   `msix:create` créait un **nouveau** certificat auto‑signé à chaque build →
   éditeur/signature différents → `0x80073CFB` (publisher mismatch) ou
   `0x800B0109` (non approuvé).

## Correctif en place

- `pubspec.yaml` → `msix_config` :
  - `publisher: CN=Wanzo` **fixe** (doit == sujet du certificat).
  - **plus de `msix_version`** : dérivée automatiquement de `version:` du
    pubspec (`1.0.1+2` → `1.0.1.2`). **Bumpez `version:` à chaque release.**
- Le certificat n'est **pas** dans le pubspec (le mot de passe ne doit pas être
  commité) : il est passé au build via variables d'environnement.
- `*.pfx` est git‑ignoré.

## Procédure

### 1) Générer le certificat — UNE SEULE FOIS (à conserver)
```powershell
powershell -ExecutionPolicy Bypass -File windows\codesign\generate_cert.ps1 -Password "MotDePasseFort"
```
Produit `wanzo_codesign.pfx` (privé, à sécuriser) et `wanzo_codesign.cer`
(public, à approuver sur les postes). **Réutilisez ce même .pfx pour TOUTES les
versions.**

### 2) Approuver le certificat sur chaque poste client — UNE FOIS
```powershell
# PowerShell administrateur
Import-Certificate -FilePath wanzo_codesign.cer -CertStoreLocation Cert:\LocalMachine\TrustedPeople
```

### 3) Builder le MSIX (à chaque release)
```powershell
$env:WANZO_MSIX_CERT_PATH = "C:\chemin\wanzo_codesign.pfx"
$env:WANZO_MSIX_CERT_PWD  = "MotDePasseFort"
powershell -ExecutionPolicy Bypass -File windows\codesign\build_msix.ps1
```
Le `.msix` sort dans `build\windows\x64\runner\Release\`.

### 4) Release suivante
Incrémentez `version:` dans `pubspec.yaml` (ex. `1.0.1+2` → `1.0.2+3`), puis
relancez l'étape 3 avec **le même** certificat. La mise à jour s'installe
par‑dessus l'ancienne. ✅

## Prérequis
- Visual Studio avec la charge « Développement Desktop en C++ » (build Flutter Windows).
- Ne jamais changer `publisher` / le certificat entre deux versions destinées à
  se mettre à jour l'une l'autre.

> Alternative Store : mettre `store: true` dans `msix_config` et publier sur le
> Microsoft Store (c'est le Store qui signe et gère les mises à jour).
