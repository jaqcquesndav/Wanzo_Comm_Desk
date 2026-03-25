import 'dart:io';

import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/settings/models/settings.dart';
import 'package:wanzo/l10n/app_localizations.dart';
import 'package:wanzo/services/receipt_printer_service.dart';

/// Écran de configuration de l'imprimante thermique
///
/// Accessible depuis les paramètres. Permet de :
/// - Scanner les appareils Bluetooth appairés
/// - Configurer une imprimante réseau TCP (IP:port)
/// - Activer/désactiver l'impression automatique après vente cash
/// - Tester l'impression
class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _printerService = ReceiptPrinterService();

  // État
  ThermalPrinterDevice? _savedPrinter;
  bool _autoPrint = false;
  bool _loading = true;

  // Bluetooth
  List<ThermalPrinterDevice> _btDevices = [];
  bool _btScanning = false;

  // Réseau TCP
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '9100');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _load();
  }

  Future<void> _load() async {
    final printer = await _printerService.getSavedPrinter();
    final autoPrint = await _printerService.getAutoPrintOnCashSale();
    if (mounted) {
      setState(() {
        _savedPrinter = printer;
        _autoPrint = autoPrint;
        _loading = false;
      });
    }
    // Scanner BT automatiquement au chargement
    if (_tabController.index == 0) {
      _startBtScan();
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return; // ignore l'animation
    if (_tabController.index == 0) {
      _startBtScan();
    }
  }

  Future<void> _startBtScan() async {
    setState(() {
      _btDevices.clear();
      _btScanning = true; // PREMIER — avant tout await
    });

    try {
      // Permissions Android uniquement
      if (Platform.isAndroid) {
        // Sur Android, les permissions sont demandées via permission_handler
        // avant d'accéder au Bluetooth. Sur Windows/macOS, pas nécessaire.
        final permOk = await PrintBluetoothThermal.isPermissionBluetoothGranted;
        if (!permOk) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Permission Bluetooth refusée'),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'Paramètres',
                  textColor: Colors.white,
                  onPressed: () {
                    // openAppSettings() si permission_handler est utilisé
                  },
                ),
              ),
            );
          }
          return;
        }

        // Vérifier que le Bluetooth est activé (Android only)
        try {
          final btEnabled = await PrintBluetoothThermal.bluetoothEnabled;
          if (!btEnabled) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Veuillez activer le Bluetooth'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
        } catch (e) {
          debugPrint('[PrinterSettings] bluetoothEnabled error: $e');
        }
      }

      final devices = await _printerService.scanBluetooth();
      if (mounted) {
        setState(() {
          _btDevices = devices;
        });
        if (devices.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucun appareil Bluetooth trouvé'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${devices.length} appareil(s) Bluetooth trouvé(s)',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[PrinterSettings] Scan error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _btScanning = false; // TOUJOURS
        });
      }
    }
  }

  Future<void> _selectPrinter(ThermalPrinterDevice device) async {
    await _printerService.savePrinter(device);
    if (mounted) {
      setState(() {
        _savedPrinter = device;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imprimante "${device.name}" sélectionnée'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _saveNetworkPrinter() async {
    final ip = _ipController.text.trim();
    final port = _portController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer une adresse IP'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final address = port.isNotEmpty ? '$ip:$port' : '$ip:9100';
    final device = ThermalPrinterDevice(
      name: 'Imprimante réseau ($ip)',
      address: address,
      type: ThermalConnectionType.network,
    );
    await _selectPrinter(device);
  }

  Future<void> _clearPrinter() async {
    await _printerService.clearSavedPrinter();
    if (mounted) {
      setState(() {
        _savedPrinter = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Imprimante déconnectée'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _testPrint() async {
    if (_savedPrinter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune imprimante configurée'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test d\'impression en cours...')),
    );

    // Construire un ticket de test simple
    final bytes = <int>[
      ..._escReset(),
      ..._escAlign(1),
      ..._escBold(true),
      ..._encodeWpc1252('=== TEST IMPRESSION ==='),
      0x0A,
      ..._escBold(false),
      ..._encodeWpc1252('Imprimante: ${_savedPrinter!.name}'),
      0x0A,
      ..._encodeWpc1252('Type: ${_savedPrinter!.type.name}'),
      0x0A,
      ..._encodeWpc1252('Accents: éàçùê OK'),
      0x0A,
      ..._encodeWpc1252('================================'),
      0x0A,
      ..._escAlign(1),
      ..._encodeWpc1252('Wanzo Commerce Desk'),
      0x0A, 0x0A, 0x0A,
      // Coupe
      0x1D, 0x56, 0x41, 0x03,
    ];

    bool success;
    if (_savedPrinter!.type == ThermalConnectionType.network) {
      success = await _printerService.printCashReceipt(
        _createTestSale(),
        _createTestSettings(),
      );
    } else {
      // BT
      try {
        final alreadyConnected = await PrintBluetoothThermal.connectionStatus;
        if (alreadyConnected) {
          await PrintBluetoothThermal.disconnect;
        }
        final connected = await PrintBluetoothThermal.connect(
          macPrinterAddress: _savedPrinter!.address,
        );
        if (connected) {
          success = await PrintBluetoothThermal.writeBytes(bytes);
          await PrintBluetoothThermal.disconnect;
        } else {
          success = false;
        }
      } catch (e) {
        debugPrint('[PrinterSettings] Test print error: $e');
        success = false;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Test d\'impression réussi !'
                : 'Échec du test d\'impression',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  // Helpers ESC/POS pour le test
  List<int> _escReset() => [0x1B, 0x40, 0x1B, 0x74, 0x10];
  List<int> _escAlign(int n) => [0x1B, 0x61, n];
  List<int> _escBold(bool on) => [0x1B, 0x45, on ? 1 : 0];
  List<int> _encodeWpc1252(String text) {
    final result = <int>[];
    for (final rune in text.runes) {
      result.add(rune <= 0xFF ? rune : 0x3F);
    }
    return result;
  }

  // Objets factices pour test impression réseau
  Sale _createTestSale() {
    return Sale(
      id: 'TEST12345678',
      date: DateTime.now(),
      customerId: 'test',
      customerName: 'Client Test',
      items: const [],
      totalAmountInCdf: 0,
      paidAmountInCdf: 0,
      discountPercentage: 0,
      paymentMethod: 'Espèces',
      status: SaleStatus.completed,
    );
  }

  Settings _createTestSettings() {
    return const Settings(
      companyName: 'TEST WANZO',
      companyAddress: '123 Avenue Test',
      companyPhone: '+243 000 000 000',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.printerSettingsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.printerSettingsTitle),
        actions: [
          if (_savedPrinter != null)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: l10n.testPrinter,
              onPressed: _testPrint,
            ),
        ],
      ),
      body: Column(
        children: [
          // Imprimante actuellement configurée
          _buildCurrentPrinterCard(),

          // Toggle auto-print
          _buildAutoPrintToggle(l10n),

          // Onglets de connexion
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                icon: const Icon(Icons.bluetooth),
                text: l10n.printerBluetooth,
              ),
              Tab(icon: const Icon(Icons.usb), text: l10n.printerUsb),
              Tab(icon: const Icon(Icons.wifi), text: l10n.printerNetwork),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBluetoothTab(),
                _buildUsbTab(),
                _buildNetworkTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPrinterCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: ListTile(
        leading: Icon(
          _savedPrinter != null ? Icons.print : Icons.print_disabled,
          color: _savedPrinter != null ? Colors.green : Colors.grey,
          size: 32,
        ),
        title: Text(
          _savedPrinter?.name ?? 'Aucune imprimante configurée',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _savedPrinter != null ? null : Colors.grey,
          ),
        ),
        subtitle:
            _savedPrinter != null
                ? Text(
                  '${_savedPrinter!.type.name.toUpperCase()} • ${_savedPrinter!.address}',
                )
                : const Text('Sélectionnez une imprimante ci-dessous'),
        trailing:
            _savedPrinter != null
                ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: _clearPrinter,
                  tooltip: 'Déconnecter',
                )
                : null,
      ),
    );
  }

  Widget _buildAutoPrintToggle(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SwitchListTile(
        title: Text(l10n.autoPrintReceipt),
        subtitle: Text(l10n.autoPrintReceiptSubtitle),
        value: _autoPrint,
        onChanged: (value) async {
          await _printerService.setAutoPrintOnCashSale(value);
          setState(() {
            _autoPrint = value;
          });
        },
        secondary: const Icon(Icons.receipt_long),
      ),
    );
  }

  Widget _buildBluetoothTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Appareils Bluetooth appairés',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _btScanning ? null : _startBtScan,
                icon:
                    _btScanning
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.refresh),
                label: Text(_btScanning ? 'Scan...' : 'Scanner'),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              _btDevices.isEmpty
                  ? Center(
                    child: Text(
                      _btScanning
                          ? 'Recherche en cours...'
                          : 'Aucun appareil trouvé.\nAssurez-vous que l\'imprimante est appairée dans les paramètres Bluetooth du système.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _btDevices.length,
                    itemBuilder: (context, index) {
                      final device = _btDevices[index];
                      final isSelected =
                          _savedPrinter?.address == device.address;
                      return Card(
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                        child: ListTile(
                          leading: Icon(
                            Icons.bluetooth,
                            color:
                                isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                          ),
                          title: Text(device.name),
                          subtitle: Text(device.address),
                          trailing:
                              isSelected
                                  ? Icon(
                                    Icons.check_circle,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  )
                                  : const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                  ),
                          onTap: () => _selectPrinter(device),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildUsbTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.usb, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'USB non disponible',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'L\'impression USB directe n\'est pas encore supportée.\n'
              'Utilisez la connexion Bluetooth ou Réseau TCP.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Imprimante réseau (TCP)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Connectez-vous à une imprimante via son adresse IP.\n'
            'La plupart des imprimantes POS utilisent le port 9100.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ipController,
            decoration: const InputDecoration(
              labelText: 'Adresse IP',
              hintText: '192.168.1.100',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.wifi),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(
              labelText: 'Port',
              hintText: '9100',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveNetworkPrinter,
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer l\'imprimante réseau'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }
}
