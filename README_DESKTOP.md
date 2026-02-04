# Wanzo Desktop

Version desktop de l'application Wanzo - Solution de gestion commerciale pour PME africaines.

## 🖥️ Prérequis

### Windows

1. **Flutter SDK** (version 3.7.0 ou supérieure)
   ```powershell
   flutter --version
   ```

2. **Visual Studio Build Tools 2022** avec les composants suivants :
   - Desktop development with C++
   - MSVC v143 - VS 2022 C++ x64/x86 build tools
   - C++ CMake tools for Windows
   - Windows 10 SDK (ou Windows 11 SDK)

   Pour installer automatiquement :
   ```powershell
   # Exécuter en tant qu'administrateur
   .\scripts\install_build_tools.ps1
   ```

3. **Mode Développeur Windows** activé :
   ```powershell
   start ms-settings:developers
   ```

### Vérification de l'environnement

```powershell
flutter doctor
```

## 🚀 Installation et lancement

### 1. Cloner le repository

```powershell
git clone https://github.com/jaqcquesndav/Wanzo_Comm_Desk.git
cd Wanzo_Comm_Desk
```

### 2. Installer les dépendances

```powershell
flutter pub get
```

### 3. Configurer l'environnement

Créer un fichier `.env` à la racine :
```env
API_BASE_URL=https://api.wanzo.com
AUTH0_DOMAIN=your-domain.auth0.com
AUTH0_CLIENT_ID=your-client-id
CLOUDINARY_CLOUD_NAME=your-cloud-name
ENVIRONMENT=development
```

### 4. Lancer l'application

```powershell
# Mode développement
flutter run -d windows

# Mode release
flutter run -d windows --release
```

### 5. Build pour distribution

```powershell
flutter build windows --release
```

Le build sera disponible dans : `build\windows\x64\runner\Release\`

## 🏗️ Architecture Desktop

### Structure des fichiers spécifiques desktop

```
lib/
├── core/
│   ├── config/
│   │   └── desktop_config.dart      # Configuration desktop
│   ├── platform/
│   │   ├── platform_service.dart    # Détection de plateforme
│   │   ├── scanner/                 # Services de scan adaptatifs
│   │   ├── speech/                  # Services vocaux adaptatifs
│   │   └── image_picker/            # Sélection d'images adaptative
│   └── widgets/
│       └── desktop/
│           ├── adaptive_scaffold.dart          # Layout sidebar/bottom nav
│           ├── adaptive_barcode_scanner.dart   # Scanner ou saisie manuelle
│           ├── adaptive_image_picker.dart      # File picker desktop
│           ├── responsive_layout.dart          # Layouts responsifs
│           ├── keyboard_shortcuts.dart         # Raccourcis clavier
│           └── desktop_data_table.dart         # DataTable paginé
```

### Différences Mobile vs Desktop

| Fonctionnalité | Mobile | Desktop |
|---------------|--------|---------|
| Navigation | Bottom Navigation Bar | Sidebar latérale |
| Scanner code-barres | Caméra (mobile_scanner) | Saisie manuelle / Scanner USB |
| Reconnaissance vocale | speech_to_text | Saisie texte |
| Sélection d'images | Caméra + Galerie | File picker |
| Layout | Single column | Multi-column avec sidebar |

## ⌨️ Raccourcis clavier

| Raccourci | Action |
|-----------|--------|
| `Ctrl + N` | Nouvelle vente |
| `Ctrl + Shift + P` | Nouveau produit |
| `Ctrl + K` | Recherche globale |
| `Ctrl + ,` | Paramètres |
| `F1` | Aide |
| `F5` / `Ctrl + R` | Actualiser |

## 🔧 Développement

### Tests

```powershell
# Tous les tests
flutter test

# Tests avec couverture
flutter test --coverage
```

### Analyse du code

```powershell
flutter analyze
```

### Génération des adaptateurs Hive

```powershell
flutter pub run build_runner build --delete-conflicting-outputs
```

## 📦 Distribution

### Windows Installer (MSIX)

1. Ajouter la configuration MSIX dans `pubspec.yaml` :
   ```yaml
   msix_config:
     display_name: Wanzo
     publisher_display_name: Wanzo Inc
     identity_name: com.wanzo.desktop
     msix_version: 1.0.0.0
     logo_path: assets/icons/app_icon.png
   ```

2. Générer le package :
   ```powershell
   flutter pub run msix:create
   ```

### Portable (ZIP)

Le contenu du dossier `build\windows\x64\runner\Release\` peut être distribué en tant qu'application portable.

## 🐛 Dépannage

### "Unable to find suitable Visual Studio toolchain"

Installez Visual Studio Build Tools 2022 avec les composants C++ :
```powershell
.\scripts\install_build_tools.ps1
```

### "Building with plugins requires symlink support"

Activez le mode développeur Windows :
```powershell
start ms-settings:developers
```

### Problèmes de performance

En mode debug, les performances sont réduites. Testez en mode release :
```powershell
flutter run -d windows --release
```

## 📝 License

Proprietary - Wanzo Inc. Tous droits réservés.
