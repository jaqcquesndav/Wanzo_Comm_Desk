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

---

# Chemins de PRODUCTION retenus (sans friction pour les utilisateurs)

Le script auto‑signé ci‑dessus (`build_msix.ps1`) reste utile pour les tests
**internes**, mais impose d'approuver le certificat sur chaque poste → trop
compliqué pour les utilisateurs finaux. En production on utilise **A** ou **B**.

## A) Azure Trusted Signing (distribution depuis VOTRE site, sans manip)
Signature par une AC de confiance Microsoft → **install/màj en un clic**, coût
facturé sur **Azure**. Script : `build_msix_azure.ps1`.

1. Portail Azure → créer une ressource **Trusted Signing** (Code Signing Account)
   + un **Certificate profile** (Public Trust). Relever : endpoint (région),
   nom du compte, nom du profil, et le **sujet exact** du certificat.
2. Installer **Windows SDK** (`signtool.exe`) + le **dlib Trusted Signing**
   (`Azure.CodeSigning.Dlib.dll`), puis `az login`.
3. Copier `azure_signing_metadata.template.json` → `azure_signing_metadata.json`
   et renseigner endpoint / compte / profil.
4. Builder :
   ```powershell
   $env:AZURE_TS_DLIB      = "C:\...\Azure.CodeSigning.Dlib.dll"
   $env:AZURE_TS_METADATA  = "windows\codesign\azure_signing_metadata.json"
   $env:AZURE_TS_PUBLISHER = "CN=Wanzo, O=Wanzo, C=CD"   # == sujet du cert Azure
   $env:SIGNTOOL           = "C:\Program Files (x86)\Windows Kits\10\bin\<ver>\x64\signtool.exe"
   powershell -ExecutionPolicy Bypass -File windows\codesign\build_msix_azure.ps1
   ```
   → `.msix` signé AC, publiable tel quel sur le site. Màj = bump `version:`.

## B) Microsoft Store (le Store signe et gère les màj)
Aucun certificat. Script : `build_msix_store.ps1`.

1. **Partner Center** → créer le compte développeur, **réserver le nom**,
   relever l'**Identité du produit** (Identity Name, Publisher `CN=…`,
   Publisher display name).
2. Préparer le listing + **politique de confidentialité (URL obligatoire)**.
3. Builder :
   ```powershell
   $env:WANZO_STORE_IDENTITY_NAME     = "12345Wanzo.WanzoCommerce"
   $env:WANZO_STORE_PUBLISHER         = "CN=ABCD1234-...."
   $env:WANZO_STORE_PUBLISHER_DISPLAY = "Wanzo"
   powershell -ExecutionPolicy Bypass -File windows\codesign\build_msix_store.ps1
   ```
   → téléverser le `.msix` dans Partner Center, soumettre à la certification.

> Le publisher/identité diffèrent entre A (sujet du cert Azure) et B (identité
> Partner Center) : chaque script passe ses propres valeurs en ligne de commande,
> le `pubspec.yaml` reste la base commune.
>
> ⚠️ Azure sponsorship : les **crédits Azure** couvrent **Azure Trusted Signing (A)**,
> PAS le compte Partner Center du Store (B), qui est un programme séparé (sauf
> bénéfice Microsoft for Startups). À vérifier dans vos offres.
