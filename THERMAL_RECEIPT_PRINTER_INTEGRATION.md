# Intégration de l'impression thermique – Documentation technique

> **Audience** : Équipe desktop (Flutter Windows/macOS/Linux)
> **Auteur** : Résultat de l'intégration mobile effectuée en session (non encore committée)
> **État** : Prêt pour réplication sur desktop

---

## Table des matières

1. [Contexte et choix du package](#1-contexte-et-choix-du-package)
2. [Dépendances pubspec.yaml](#2-dépendances-pubspecyaml)
3. [Permissions Android](#3-permissions-android)
4. [Architecture du service](#4-architecture-du-service)
5. [Protocole ESC/POS – détails techniques](#5-protocole-escpos--détails-techniques)
6. [Mise en page du ticket](#6-mise-en-page-du-ticket)
7. [Écran de configuration de l'imprimante](#7-écran-de-configuration-de-limprimante)
8. [Intégration dans sale\_details\_screen](#8-intégration-dans-sale_details_screen)
9. [Intégration dans add\_sale\_screen (impression auto)](#9-intégration-dans-add_sale_screen-impression-auto)
10. [Adaptation pour Desktop (Windows/macOS/Linux)](#10-adaptation-pour-desktop-windowsmacoslinux)
11. [Problèmes résolus et leçons apprises](#11-problèmes-résolus-et-leçons-apprises)

---

## 1. Contexte et choix du package

### Packages candidats évalués

| Package | Raison d'exclusion |
|---|---|
| `bluetooth_print 4.3.0` | Incompatible AGP 8+ – utilise l'API `Registrar` (Flutter v1 embedding). Erreur de build Android Gradle. |
| `flutter_bluetooth_serial` | Exige `ACCESS_FINE_LOCATION` (refus Play Store catégoriel). Abandonné par l'auteur. |
| `esc_pos_bluetooth` | Dépend de `flutter_bluetooth_serial`. |
| **`print_bluetooth_thermal ^1.1.9`** | ✅ Choisi – AGP 8 compatible, Android 12+ Bluetooth permissions, iOS, **macOS, Windows** natifs, TCP réseau, pas de permission location. |

### Pourquoi `print_bluetooth_thermal`

- API **statique** (pas d'instance à gérer) : `PrintBluetoothThermal.connect(...)`, etc.
- Envoie des `List<int>` bruts (ESC/POS bytes) → total contrôle sur le rendu.
- Le plugin Windows est déjà enregistré automatiquement par Flutter via `generated_plugin_registrant.cc` :
  ```cpp
  PrintBluetoothThermalPluginCApiRegisterWithRegistrar(
    registry->GetRegistrarForPlugin("PrintBluetoothThermalPluginCApi"));
  ```
- Support **Bluetooth Classic (SPP/RFCOMM)** + **TCP réseau port 9100** (identique mobile et desktop).

---

## 2. Dépendances pubspec.yaml

```yaml
dependencies:
  print_bluetooth_thermal: ^1.1.9
  permission_handler: ^11.3.1   # déjà présent, bloc Android uniquement
  shared_preferences: ^2.2.3    # déjà présent, pour persister l'imprimante choisie
  intl: ^0.19.0                 # déjà présent, pour le formatage des montants
```

`permission_handler` pour desktop → le plugin Windows retourne toujours `granted` pour les permissions Bluetooth (pas de runtime permission sur Windows).

---

## 3. Permissions Android

Dans `android/app/src/main/AndroidManifest.xml` :

```xml
<!-- BT classique (Android ≤ 11) -->
<uses-permission android:name="android.permission.BLUETOOTH"
    android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"
    android:maxSdkVersion="30"/>

<!-- BT moderne (Android 12+ / API 31+) -->
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
```

**Desktop** : aucune `AndroidManifest.xml` à modifier. Sur Windows, les appareils BT appairés sont accessibles sans permission runtime.

---

## 4. Architecture du service

**Fichier** : `lib/services/receipt_printer_service.dart`

```
ReceiptPrinterService
│
├── ThermalConnectionType { bluetooth | usb | network }
├── ThermalPrinterDevice { name, address, type }
│
├── Persistance (SharedPreferences)
│   ├── getSavedPrinter() → ThermalPrinterDevice?
│   ├── savePrinter(printer)
│   ├── clearSavedPrinter()
│   ├── getAutoPrintOnCashSale() → bool
│   └── setAutoPrintOnCashSale(bool)
│
├── Découverte
│   ├── scanBluetooth() → List<ThermalPrinterDevice>   ← BT appairés
│   └── scanUsb()       → List<ThermalPrinterDevice>   ← stub (non impl.)
│
├── Détection paiement
│   └── isCashPayment(String?) → bool  [static]
│
├── Construction du ticket
│   └── buildCashReceiptBytes(Sale, Settings) → List<int>
│
└── Impression
    ├── printCashReceipt(Sale, Settings) → Future<bool>  ← point d'entrée public
    ├── _printBluetooth(printer, bytes)
    ├── _printUsb(printer)           ← retourne false (non impl.)
    └── _printNetwork(printer, bytes) ← TCP/IP port 9100
```

### API Package utilisée

```dart
// Découverte
List<BluetoothInfo> paired = await PrintBluetoothThermal.pairedBluetooths;
// BluetoothInfo.name, BluetoothInfo.macAdress (TYPO intentionnel dans le pkg)

// Connexion / impression
bool ok = await PrintBluetoothThermal.connect(macPrinterAddress: "AA:BB:CC:DD:EE:FF");
bool status = await PrintBluetoothThermal.connectionStatus;
bool sent   = await PrintBluetoothThermal.writeBytes(bytes);
await PrintBluetoothThermal.disconnect;  // getter, pas une méthode

// État
bool btOn      = await PrintBluetoothThermal.bluetoothEnabled;
bool permOK    = await PrintBluetoothThermal.isPermissionBluetoothGranted;
```

> **Piège** : `disconnect` est un **getter** (`await PrintBluetoothThermal.disconnect`), pas une méthode. Appeler `.disconnect()` avec parenthèses lève une erreur de compilation.

---

## 5. Protocole ESC/POS – détails techniques

### 5.1 Reset et sélection de la table de caractères

```dart
List<int> _escReset() => [
  0x1B, 0x40,        // ESC @ — Reset complet de l'imprimante
  0x1B, 0x74, 0x10,  // ESC t 16 — Sélectionne WPC1252 (Windows Latin-1)
];
```

**Pourquoi WPC1252 (code 16 = 0x10) ?**

Les imprimantes thermiques démarrent en CP437 (OEM DOS) par défaut. En CP437 :
- `é` (U+00E9 = 0xE9) → `Θ` (theta grec)
- `à` (U+00E0 = 0xE0) → `α` (alpha grec)
- `ç` (U+00E7 = 0xE7) → rien d'intelligible

Avec WPC1252 : 0xE9 = `é`, 0xE0 = `à`, 0xE7 = `ç` — les octets 0x80–0xFF sont exactement les caractères Windows Latin-1 → le français s'affiche correctement.

### 5.2 Encodage des chaînes (bug `codeUnits` évité)

```dart
// ❌ MAUVAIS — codeUnits = valeurs UTF-16, > 0xFF cassent CP437
List<int> bytes = text.codeUnits;

// ✅ CORRECT — rune par rune, hors Latin-1 → '?'
List<int> _encodeWpc1252(String text) {
  final result = <int>[];
  for (final rune in text.runes) {
    result.add(rune < 0x100 ? rune : 0x3F); // 0x3F = '?'
  }
  return result;
}
```

### 5.3 Bug `intl` fr_FR – U+202F (espace fine insécable)

```dart
// ❌ NumberFormat('fr_FR').format(12000) → "12 000" mais espace = U+202F (8239 > 0xFF)
// → _encodeWpc1252 le remplace par '?' → "12?000" sur le ticket

// ✅ FIX :
String _fmt(double amount, String currency) {
  final formatter = NumberFormat('#,##0', 'fr_FR');
  return '${formatter.format(amount)
      .replaceAll('\u202F', ' ')   // narrow no-break space → espace normal
      .replaceAll('\u00A0', ' ')}  // no-break space → espace normal
   $currency';
}
```

### 5.4 Commandes ESC/POS utilisées

```dart
// Alignement : ESC a n  (0=gauche, 1=centre, 2=droite)
List<int> _escAlign(int n) => [0x1B, 0x61, n];

// Gras : ESC E n  (0=off, 1=on)
List<int> _escBold(bool on) => [0x1B, 0x45, on ? 1 : 0];

// Saut de ligne (n fois)
List<int> _escFeed(int n) => List.filled(n, 0x0A);

// Coupe du papier : GS V A 3  (coupe partielle)
List<int> _escCut() => [0x1D, 0x56, 0x41, 0x03];

// Séparateurs
List<int> _escSeparator()       => _escLine('-' * 32); // tirets simples
List<int> _escSeparatorDouble() => _escLine('=' * 32); // doubles barres

// --- NE PAS utiliser GS ! (double size) ---
// GS ! 0x11 divise la largeur utile par 2 → noms tronqués à 16 chars sur 58mm.
// On utilise la taille normale (32 chars disponibles) avec gras pour l'accroche.
```

### 5.5 QR Code ESC/POS (commandes GS ( k)

```dart
List<int> _escQrCode(String data) {
  final dataBytes = data.codeUnits; // URL en ASCII pur — pas de pb d'encodage
  final storeLen = dataBytes.length + 3;
  final pL = storeLen & 0xFF;
  final pH = (storeLen >> 8) & 0xFF;
  return [
    // 1. Sélectionner modèle QR Code 2
    0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00,
    // 2. Taille du module : 4 (lisible 58mm sans être immense)
    0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x04,
    // 3. Niveau de correction d'erreurs : M (15%)
    0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31,
    // 4. Stocker les données dans le buffer interne
    0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30, ...dataBytes,
    // 5. Imprimer le QR code
    0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30,
  ];
}
```

---

## 6. Mise en page du ticket

**Largeur papier** : 58 mm → `_colWidth = 32` caractères (police A, taille normale).

```
════════════════════════════════  ← _escSeparatorDouble()
        NOM ENTREPRISE            ← gras, centré, tronqué à 32 chars
   Av. de la Paix, Kinshasa       ← _wrapText() si > 32
   Tel: +243 999 123 456
   NIF:CD123456  RCCM:KNG/123     ← sur une ligne si ça tient
   ID NAT: 01-A23456-P            ← si renseigné
════════════════════════════════
       TICKET DE CAISSE
════════════════════════════════
25/03/2026 14:32       #A1B2C3D4  ← date + shortId sur une ligne
Client: Jean Dupont
────────────────────────────────  ← _escSeparator()
Produit XYZ           10 000 CDF  ← _rowText(nom, montant)
  2 x 5 000 CDF
────────────────────────────────
TOTAL                 10 000 CDF  ← gras
════════════════════════════════
Especes:              15 000 CDF  ← gras
Monnaie:               5 000 CDF
════════════════════════════════
     Merci pour votre achat !
          wanzzo.com
          [QR CODE https://wanzzo.com/]
                                       ← 3 sauts de ligne avant coupe
```

### Helpers de mise en page

```dart
// Deux colonnes dynamiques (gauche aligné-gauche, droite aligné-droite)
String _rowText(String left, String right) {
  final available = _colWidth - right.length;
  if (available <= 0) return '$left $right';
  return left.padRight(available).substring(0, available) + right;
}

// Découpage automatique aux espaces (économie de papier)
List<String> _wrapText(String text, int maxWidth) {
  if (text.length <= maxWidth) return [text];
  final lines = <String>[];
  var remaining = text.trim();
  while (remaining.length > maxWidth) {
    var split = maxWidth;
    final spaceIdx = remaining.lastIndexOf(' ', maxWidth);
    if (spaceIdx > maxWidth ~/ 2) split = spaceIdx;
    lines.add(remaining.substring(0, split).trim());
    remaining = remaining.substring(split).trim();
  }
  if (remaining.isNotEmpty) lines.add(remaining);
  return lines;
}
```

### Champs `Settings` utilisés

```dart
settings.companyName               // Nom entreprise (en-tête gras)
settings.companyAddress            // Adresse (avec word-wrap)
settings.companyPhone              // Téléphone
settings.taxIdentificationNumber   // NIF
settings.rccmNumber                // RCCM
settings.idNatNumber               // Identifiant National
```

### Champs `Sale` utilisés

```dart
sale.id                              // Référence (8 derniers chars)
sale.date                            // Date/heure
sale.customerName                    // Client (omis si "Inconnu")
sale.items                           // List<SaleItem> (productName, quantity, unitPrice)
sale.discountPercentage              // Remise (si > 0)
sale.transactionCurrencyCode         // "CDF" ou "USD"
sale.totalAmountInTransactionCurrency ?? sale.totalAmountInCdf
sale.paidAmountInTransactionCurrency ?? sale.paidAmountInCdf
sale.paymentMethod                   // pour isCashPayment()
sale.status                          // SaleStatus enum
```

---

## 7. Écran de configuration de l'imprimante

**Fichier** : `lib/features/settings/screens/printer_settings_screen.dart`

Accessible depuis `InvoiceSettingsScreen` (section « Facturation et Imprimante »).

### Fonctionnalités

- **Toggle auto-print** : active l'impression automatique après chaque vente cash.
- **3 onglets** : Bluetooth | USB | Réseau TCP
- **Scan BT automatique** au chargement de l'écran (et à chaque retour sur l'onglet BT).
- **Sélection et persistance** de l'imprimante choisie.

### Flux de scan Bluetooth (ordre critique)

```
1. setState _btScanning = true  ← IMMÉDIATEMENT (active le spinner)
2. [Permission.bluetoothConnect, Permission.bluetoothScan].request()
   (Note: Android uniquement — bloc if (Platform.isAndroid))
3. Vérifier connectStatus.isDenied/isPermanentlyDenied
   → si refusé : snackbar rouge + action 'Paramètres' (openAppSettings)
4. PrintBluetoothThermal.bluetoothEnabled
   → si BT éteint : snackbar orange 'Veuillez activer le Bluetooth'
5. _printerService.scanBluetooth()
   → résultats → setState _btDevices
   → 0 résultats : snackbar orange avec instructions + bouton 'Réessayer'
   → N résultats : snackbar verte 'N appareil(s) Bluetooth trouvé(s)'
6. finally: setState _btScanning = false  ← TOUJOURS
```

> **Bug critique résolu** : `_btScanning = true` doit être placé en **premier** dans `setState`, avant tout `await`. Si placé après, le widget se rebuilde avec `_btScanning = false` au premier frame → le spinner n'apparaît jamais → l'utilisateur perçoit le bouton comme insensible.

```dart
// ✅ CORRECT
setState(() {
  _btDevices.clear();
  _btScanning = true;   // ← PREMIER
});
// ... puis les awaits

// ❌ MAUVAIS
final statuses = await [...].request();
setState(() { _btScanning = true; }); // trop tard — déjà un rebuild
```

> **Bug critique résolu** : `PrintBluetoothThermal.bluetoothEnabled` lève une `PlatformException` si `BLUETOOTH_CONNECT` n'est pas encore accordé. Vérifier TOUJOURS la permission AVANT d'appeler `bluetoothEnabled`.

### Auto-scan au changement d'onglet

```dart
@override
void initState() {
  super.initState();
  _tabController = TabController(length: 3, vsync: this);
  _tabController.addListener(_onTabChanged);
  _load();
}

void _onTabChanged() {
  if (_tabController.indexIsChanging) return; // ignore l'animation
  if (_tabController.index == 0 && !_btScanning) {
    _startBtScan();
  }
}

@override
void dispose() {
  _tabController.removeListener(_onTabChanged); // éviter les memory leaks
  _tabController.dispose();
  super.dispose();
}
```

---

## 8. Intégration dans sale_details_screen

**Fichier** : `lib/features/sales/screens/sale_details_screen.dart`

### Import ajouté

```dart
import 'package:wanzo/services/receipt_printer_service.dart';
```

### Détection paiement cash

```dart
bool get _hasCashTransaction {
  if (ReceiptPrinterService.isCashPayment(sale.paymentMethod)) return true;
  if (sale.paidAmountInCdf > 0 &&
      (sale.status == SaleStatus.partiallyPaid ||
       sale.status == SaleStatus.completed)) {
    return true;
  }
  return false;
}
```

### Dialogue de sélection intelligente

```dart
void _showDocumentTypeSelectionDialog(BuildContext context, {required bool isPrintAction}) {
  if (!_hasCashTransaction) {
    // Vente crédit : pas de ticket thermique → directement facture PDF
    _printOrShareInvoice(context, print: isPrintAction, documentType: 'invoice');
    return;
  }
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(isPrintAction ? 'Imprimer le document' : 'Partager le document'),
      actions: [
        if (isPrintAction)
          TextButton.icon(
            icon: const Icon(Icons.print, color: Colors.teal),
            label: const Text('Ticket thermique'),
            onPressed: () { Navigator.pop(dialogContext); _printThermalReceipt(context); },
          ),
        TextButton.icon(
          icon: const Icon(Icons.description_outlined),
          label: const Text('Facture (PDF)'),
          onPressed: () { Navigator.pop(dialogContext); _printOrShareInvoice(...); },
        ),
        TextButton.icon(
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Reçu (PDF)'),
          onPressed: () { Navigator.pop(dialogContext); _printOrShareInvoice(...); },
        ),
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
      ],
    ),
  );
}
```

### Impression thermique depuis la page de détail

```dart
void _printThermalReceipt(BuildContext context) async {
  // 1. Récupérer Settings depuis le Bloc
  final settingsState = context.read<SettingsBloc>().state;
  Settings? settings;
  if (settingsState is SettingsLoaded) settings = settingsState.settings;
  else if (settingsState is SettingsUpdated) settings = settingsState.settings;
  if (settings == null) { /* snackbar erreur */ return; }

  // 2. Spinner non-bloquant
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Row(children: [
      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
      SizedBox(width: 12),
      Text('Envoi vers l\'imprimante…'),
    ]), duration: Duration(seconds: 8)),
  );

  // 3. Impression
  final ok = await ReceiptPrinterService().printCashReceipt(sale, settings);

  // 4. Résultat
  if (context.mounted) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Ticket imprimé avec succès.' : 'Impression échouée. Vérifiez la connexion.'),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
  }
}
```

---

## 9. Intégration dans add_sale_screen (impression auto)

Après validation d'une vente, si `autoPrint` est activé et le paiement est en espèces :

```dart
// Dans le handler de succès de la vente
final printerService = ReceiptPrinterService();
final autoPrint = await printerService.getAutoPrintOnCashSale();
if (autoPrint && ReceiptPrinterService.isCashPayment(sale.paymentMethod)) {
  await printerService.printCashReceipt(sale, settings);
}
```

---

## 10. Adaptation pour Desktop (Windows/macOS/Linux)

### 10.1 Bluetooth sur Windows

Le plugin `print_bluetooth_thermal` a un backend Windows natif (déjà enregistré dans `generated_plugin_registrant.cc`). Les différences comportementales sur Windows :

| Comportement | Android | Windows |
|---|---|---|
| `isPermissionBluetoothGranted` | Runtime check BLUETOOTH_CONNECT | Retourne **toujours `true`** |
| `bluetoothEnabled` | Vérifie l'état Bluetooth | **Non disponible** – retourne `true` (pas d'API WinRT utilisée) |
| `pairedBluetooths` | `BluetoothManager.getBondedDevices()` | Utilise WinRT `DeviceInformation.FindAllAsync` ou registry |
| `connect(macPrinterAddress:)` | SPP RFCOMM socket | WinRT BT serial stream |
| `writeBytes(bytes)` | BT socket write | Stream write |

> **Action desktop** : Retirer ou court-circuiter le bloc `if (Platform.isAndroid)` dans `_startBtScan()` (ou le laisser tel quel — il ne s'exécutera pas sur Windows).

```dart
// Le service est déjà gated correctement :
Future<List<ThermalPrinterDevice>> scanBluetooth() async {
  if (Platform.isAndroid) {  // ← ce bloc est ignoré sur Windows
    final granted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
    if (!granted) throw Exception('...');
  }
  // Cette ligne s'exécute sur TOUTES les plateformes :
  final paired = await PrintBluetoothThermal.pairedBluetooths;
  return ...;
}
```

### 10.2 Réseau TCP (identique desktop/mobile)

`_printNetwork()` utilise `dart:io Socket` standard → aucune modification pour desktop.

```dart
Future<bool> _printNetwork(ThermalPrinterDevice printer, List<int> bytes) async {
  final parts = printer.address.split(':');
  final ip = parts[0];
  final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;
  Socket? socket;
  try {
    socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 10));
    socket.add(bytes);
    await socket.flush();
    return true;
  } catch (e) {
    return false;
  } finally {
    socket?.destroy();
  }
}
```

### 10.3 USB sur Desktop

Sur mobile, USB OTG est stubbed (retourne `false`). Pour desktop Windows, deux approches :

**Option A : Port COM (RS-232 émulé USB)** → via package `flutter_libserialport` :
```dart
// Remplacer _printUsb() par :
Future<bool> _printUsb(ThermalPrinterDevice printer) async {
  final port = SerialPort(printer.address); // ex: "COM3"
  if (!port.openWrite()) return false;
  try {
    port.write(Uint8List.fromList(bytes));
    return true;
  } finally {
    port.close();
  }
}
```

**Option B : Imprimante Windows (spooler)** → via le package `printing` (déjà dans pubspec) avec `Printing.directPrintPdf(...)` ou `dart:ffi` vers `winspool.drv`. Non recommandé pour tickets ESC/POS bruts.

**Option C (recommandée)** : Utiliser la connexion **réseau TCP** (configurée avec `ip:port`) même pour une imprimante USB si elle dispose d'un serveur TCP intégré (la plupart des imprimantes POS modernes en ont un).

### 10.4 ESC/POS bytes : 100% portable

`buildCashReceiptBytes()` retourne `List<int>` pur — pas de `dart:io` ou Android API. Fonctionne identiquement sur toutes les plateformes. Aucune modification à apporter.

### 10.5 Permissions sur Windows

```dart
// Dans printer_settings_screen.dart, le bloc est déjà gated :
if (Platform.isAndroid) {
  final statuses = await [
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
  ].request();
  // ...
}
// Sur Windows, ce bloc est ignoré → scan BT direct sans demande de permission
```

### 10.6 Checklist adaptation desktop

- [x] `print_bluetooth_thermal ^1.1.9` dans `pubspec.yaml` — déjà fait, Windows auto-registré
- [x] `generated_plugin_registrant.cc` — déjà mis à jour par `flutter pub get`
- [x] `generated_plugins.cmake` — déjà mis à jour
- [ ] Tester `PrintBluetoothThermal.pairedBluetooths` sur Windows avec une imprimante appairée
- [ ] Si BT non fonctionnel sur Windows, fallback vers **réseau TCP** (recommandé pour desktop)
- [ ] Adapter `PrinterSettingsScreen` pour cacher ou désactiver l'onglet USB si non implémenté
- [ ] Remplacer le stub USB par `flutter_libserialport` si nécessaire

---

## 11. Problèmes résolus et leçons apprises

| Symptôme | Cause racine | Solution appliquée |
|---|---|---|
| Bouton de scan insensible | `setState(_btScanning = true)` après des `await` | Placer `_btScanning = true` en **premier** dans `setState` |
| Liste d'appareils toujours vide | `BLUETOOTH_CONNECT` non accordé avant `pairedBluetooths` | Demander les permissions **avant** tout appel BT |
| `PlatformException` sur `bluetoothEnabled` | Appel sans `BLUETOOTH_CONNECT` accordé | Vérifier permission **avant** `bluetoothEnabled` |
| Chiffres `12?000` sur ticket | `fr_FR` utilise U+202F (8239 > 0xFF) comme séparateur milliers | `.replaceAll('\u202F', ' ')` dans `_fmt()` |
| Accents illisibles (`é`→`Θ`) | Police CP437 par défaut, `codeUnits` envoyés sans remapping | `ESC t 0x10` (WPC1252) + `_encodeWpc1252()` rune par rune |
| Deuxième `connect()` échoue | Coroutine Kotlin garde la socket SPP ouverte | Déconnecter **avant** chaque `connect()` si `connectionStatus = true` |
| `connect()` retourne `true` mais print échoue | Socket SPP pas encore prête | Vérifier `connectionStatus` **après** `connect()` |
| Nom entreprise tronqué | `GS ! 0x11` (double taille) réduit largeur à 16 chars | Suppression du double-size, gras seul sur taille normale |
| Ticket imprimé pour vente crédit | Pas de garde sur `_hasCashTransaction` | `_hasCashTransaction` getter + court-circuit vers facture PDF |

---

## Fichiers modifiés (résumé pour le merge desktop)

```
lib/services/receipt_printer_service.dart        ← NOUVEAU (à créer)
lib/features/settings/screens/
  printer_settings_screen.dart                   ← NOUVEAU (à créer)
  invoice_settings_screen.dart                   ← Modifier pour naviguer vers PrinterSettingsScreen
lib/features/sales/screens/
  sale_details_screen.dart                       ← Ajouter _hasCashTransaction + _printThermalReceipt
  add_sale_screen.dart                           ← Ajouter auto-print après vente cash
lib/l10n/app_fr.arb
  invoiceSettingsTitle    → "Facturation et Imprimante"
  invoiceSettingsSubtitle → "Facturation, taxes et configuration de l'imprimante"
lib/l10n/app_en.arb
  invoiceSettingsTitle    → "Billing & Printer"
  invoiceSettingsSubtitle → "Billing, taxes, and printer configuration"
pubspec.yaml
  + print_bluetooth_thermal: ^1.1.9
android/app/src/main/AndroidManifest.xml
  + BLUETOOTH_CONNECT, BLUETOOTH_SCAN permissions
```

---

*Document généré le 2026-03-25 — reçu_printer_service.dart v1.0 (session non committée)*
