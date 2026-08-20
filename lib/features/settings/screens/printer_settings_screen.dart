import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../services/receipt_printer_service.dart';

/// Écran de configuration de l'imprimante (paramètres de facturation).
///
/// Compatible avec toutes les formes d'imprimantes du commerce / POS :
/// - **Bluetooth** (Classic SPP) — imprimantes portables type MPT-II.
/// - **Réseau (TCP 9100)** — imprimantes ESC/POS en réseau / WiFi.
/// - **E-POS** (Epson ePOS-Print XML sur HTTP) — imprimantes réseau Epson TM.
/// - **Système / pilote** — via la boîte d'impression de l'OS : couvre TOUT
///   pilote installé (USB Mopria / constructeur, WiFi, « E-POS Printer Driver »,
///   etc.), y compris les imprimantes non ESC/POS brut.
class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen>
    with SingleTickerProviderStateMixin {
  final _printerService = ReceiptPrinterService();

  late TabController _tabController;

  bool _autoPrint = false;
  ThermalPrinterDevice? _savedPrinter;

  // Bluetooth
  final List<ThermalPrinterDevice> _btDevices = [];
  bool _btScanning = false;

  // Réseau (TCP 9100)
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '9100');
  final _networkFormKey = GlobalKey<FormState>();

  // E-POS (Epson ePOS-Print HTTP)
  final _eposIpController = TextEditingController();
  final _eposPortController = TextEditingController(text: '80');
  final _eposFormKey = GlobalKey<FormState>();

  // Onglets : 0=Bluetooth, 1=Réseau, 2=E-POS, 3=Système
  static const _typeIndex = {
    ThermalConnectionType.bluetooth: 0,
    ThermalConnectionType.network: 1,
    ThermalConnectionType.epos: 2,
    ThermalConnectionType.system: 3,
    ThermalConnectionType.usb: 3, // USB brut (legacy) → routé via le système
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _load();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 0 && !_btScanning) {
      _startBtScan();
    }
  }

  Future<void> _load() async {
    final auto = await _printerService.getAutoPrintOnCashSale();
    final saved = await _printerService.getSavedPrinter();
    if (!mounted) return;
    setState(() {
      _autoPrint = auto;
      _savedPrinter = saved;
      if (saved != null) {
        _tabController.index = _typeIndex[saved.type] ?? 0;
        if (saved.type == ThermalConnectionType.network) {
          final parts = saved.address.split(':');
          _ipController.text = parts[0];
          if (parts.length > 1) _portController.text = parts[1];
        } else if (saved.type == ThermalConnectionType.epos) {
          final parts = saved.address.split(':');
          _eposIpController.text = parts[0];
          if (parts.length > 1) _eposPortController.text = parts[1];
        }
      }
    });
    if (_tabController.index == 0) {
      _startBtScan();
    }
  }

  Future<void> _toggleAutoPrint(bool value) async {
    await _printerService.setAutoPrintOnCashSale(value);
    setState(() => _autoPrint = value);
  }

  // ── Bluetooth ──────────────────────────────────────────────────────────

  Future<void> _startBtScan() async {
    setState(() {
      _btDevices.clear();
      _btScanning = true;
    });

    try {
      if (Platform.isAndroid) {
        final statuses = await [
          Permission.bluetoothConnect,
          Permission.bluetoothScan,
        ].request();

        final connectStatus =
            statuses[Permission.bluetoothConnect] ?? PermissionStatus.denied;
        if (connectStatus.isDenied || connectStatus.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Permission Bluetooth requise pour voir les appareils appairés.',
                ),
                backgroundColor: Colors.red,
                action: connectStatus.isPermanentlyDenied
                    ? SnackBarAction(
                        label: 'Paramètres',
                        onPressed: openAppSettings,
                      )
                    : null,
              ),
            );
          }
          return;
        }

        final btEnabled = await PrintBluetoothThermal.bluetoothEnabled;
        if (!btEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Veuillez activer le Bluetooth sur votre appareil.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      }

      final devices = await _printerService.scanBluetooth();
      if (mounted) {
        setState(() => _btDevices.addAll(devices));
        if (devices.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Aucun appareil trouvé.\n'
                '→ Paramètres du téléphone → Bluetooth → appairez l\'imprimante, puis revenez ici.',
              ),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 7),
              action: SnackBarAction(
                label: 'Réessayer',
                textColor: Colors.white,
                onPressed: _startBtScan,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${devices.length} appareil(s) Bluetooth trouvé(s).'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur Bluetooth : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _btScanning = false);
    }
  }

  Future<void> _selectBtDevice(ThermalPrinterDevice d) async {
    await _printerService.savePrinter(d);
    if (!mounted) return;
    setState(() => _savedPrinter = d);
    _showSavedSnack(d);
  }

  // ── Réseau ───────────────────────────────────────────────────────────────

  Future<void> _saveNetworkPrinter() async {
    if (!_networkFormKey.currentState!.validate()) return;
    final printer = ThermalPrinterDevice(
      name: 'Imprimante réseau',
      address: '${_ipController.text.trim()}:${_portController.text.trim()}',
      type: ThermalConnectionType.network,
    );
    await _printerService.savePrinter(printer);
    if (!mounted) return;
    setState(() => _savedPrinter = printer);
    _showSavedSnack(printer);
  }

  // ── E-POS ──────────────────────────────────────────────────────────────

  Future<void> _saveEposPrinter() async {
    if (!_eposFormKey.currentState!.validate()) return;
    final printer = ThermalPrinterDevice(
      name: 'Epson ePOS',
      address: '${_eposIpController.text.trim()}:${_eposPortController.text.trim()}',
      type: ThermalConnectionType.epos,
    );
    await _printerService.savePrinter(printer);
    if (!mounted) return;
    setState(() => _savedPrinter = printer);
    _showSavedSnack(printer);
  }

  // ── Système / pilote ─────────────────────────────────────────────────────

  Future<void> _saveSystemPrinter() async {
    const printer = ThermalPrinterDevice(
      name: 'Imprimante système (pilote)',
      address: 'system',
      type: ThermalConnectionType.system,
    );
    await _printerService.savePrinter(printer);
    if (!mounted) return;
    setState(() => _savedPrinter = printer);
    _showSavedSnack(printer);
  }

  // ── Clear ──────────────────────────────────────────────────────────────

  Future<void> _clearPrinter() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'imprimante'),
        content: const Text(
          'Voulez-vous supprimer la configuration de l\'imprimante ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _printerService.clearSavedPrinter();
      if (!mounted) return;
      setState(() => _savedPrinter = null);
    }
  }

  void _showSavedSnack(ThermalPrinterDevice printer) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Imprimante enregistrée : ${printer.displayName}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Imprimante')),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: SwitchListTile(
              secondary: const Icon(Icons.print),
              title: const Text('Impression automatique'),
              subtitle: const Text(
                'Imprime le ticket de caisse automatiquement\naprès chaque vente payée en espèces.',
              ),
              value: _autoPrint,
              onChanged: _toggleAutoPrint,
            ),
          ),
          if (_savedPrinter != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: ListTile(
                  leading: Icon(_connectionIcon(_savedPrinter!.type)),
                  title: Text(
                    _savedPrinter!.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${_connectionLabel(_savedPrinter!.type)} · ${_savedPrinter!.address}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Supprimer',
                    onPressed: _clearPrinter,
                  ),
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sélectionner une imprimante',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.bluetooth), text: 'Bluetooth'),
              Tab(icon: Icon(Icons.wifi), text: 'Réseau'),
              Tab(icon: Icon(Icons.receipt_long), text: 'E-POS'),
              Tab(icon: Icon(Icons.print), text: 'Système'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBluetoothTab(),
                _buildNetworkTab(),
                _buildEposTab(),
                _buildSystemTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bluetooth tab ──────────────────────────────────────────────────────

  Widget _buildBluetoothTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _btScanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth_searching),
              label: Text(
                _btScanning ? 'Recherche en cours…' : 'Rechercher des appareils',
              ),
              onPressed: _btScanning ? null : _startBtScan,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '⚠ L\'imprimante doit être appairée dans les paramètres Bluetooth du téléphone avant d\'apparaître ici.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _btDevices.isEmpty
              ? Center(
                  child: Text(
                    _btScanning
                        ? 'Recherche des imprimantes Bluetooth…'
                        : 'Aucun appareil trouvé.\nAppuyez sur Rechercher.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _btDevices.length,
                  itemBuilder: (_, i) {
                    final d = _btDevices[i];
                    final isSaved = _savedPrinter?.address == d.address &&
                        _savedPrinter?.type == ThermalConnectionType.bluetooth;
                    return ListTile(
                      leading: const Icon(Icons.print),
                      title: Text(d.displayName),
                      subtitle: Text(d.address),
                      trailing: isSaved
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.add_circle_outline),
                      onTap: () => _selectBtDevice(d),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Réseau tab ─────────────────────────────────────────────────────────

  Widget _buildNetworkTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _networkFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Imprimante réseau (TCP/IP)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Compatible : imprimantes POS ESC/POS en réseau local / WiFi (port 9100).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'Adresse IP',
                hintText: 'ex : 192.168.1.100',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lan),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: _validateIp,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '9100',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.settings_ethernet),
              ),
              keyboardType: TextInputType.number,
              validator: _validatePort,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer l\'imprimante réseau'),
                onPressed: _saveNetworkPrinter,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── E-POS tab ──────────────────────────────────────────────────────────

  Widget _buildEposTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _eposFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Imprimante Epson E-POS (ePOS-Print)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Imprimantes réseau Epson TM en mode ePOS-Print (protocole XML/HTTP). '
              'Utilisez l\'adresse IP de l\'imprimante (port 80 par défaut).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _eposIpController,
              decoration: const InputDecoration(
                labelText: 'Adresse IP de l\'imprimante Epson',
                hintText: 'ex : 192.168.1.200',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lan),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: _validateIp,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _eposPortController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '80',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.settings_ethernet),
              ),
              keyboardType: TextInputType.number,
              validator: _validatePort,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer l\'imprimante E-POS'),
                onPressed: _saveEposPrinter,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Système tab ────────────────────────────────────────────────────────

  Widget _buildSystemTab() {
    final isSaved = _savedPrinter?.type == ThermalConnectionType.system;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Impression via le système / pilote',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ouvre la boîte d\'impression du système d\'exploitation. Compatible '
            'avec TOUTE imprimante disposant d\'un pilote installé sur l\'appareil :\n'
            '• USB (via Mopria ou le pilote du constructeur)\n'
            '• WiFi / réseau\n'
            '• « E-POS Printer Driver » (pilote Epson Android)\n'
            '• Toute imprimante A4 / laser / jet d\'encre\n\n'
            'Le ticket est rendu au format rouleau 80 mm puis envoyé au pilote choisi.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(isSaved ? Icons.check_circle : Icons.print),
              label: Text(
                isSaved
                    ? 'Impression système activée'
                    : 'Utiliser l\'impression système',
              ),
              onPressed: _saveSystemPrinter,
            ),
          ),
        ],
      ),
    );
  }

  // ── Validators ───────────────────────────────────────────────────────────

  String? _validateIp(String? v) {
    if (v == null || v.trim().isEmpty) return 'Champ obligatoire';
    final ipPattern = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipPattern.hasMatch(v.trim())) return 'Adresse IP invalide';
    return null;
  }

  String? _validatePort(String? v) {
    if (v == null || v.trim().isEmpty) return 'Champ obligatoire';
    final port = int.tryParse(v.trim());
    if (port == null || port < 1 || port > 65535) return 'Port invalide (1–65535)';
    return null;
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  IconData _connectionIcon(ThermalConnectionType type) {
    switch (type) {
      case ThermalConnectionType.bluetooth:
        return Icons.bluetooth;
      case ThermalConnectionType.usb:
        return Icons.usb;
      case ThermalConnectionType.network:
        return Icons.wifi;
      case ThermalConnectionType.epos:
        return Icons.receipt_long;
      case ThermalConnectionType.system:
        return Icons.print;
    }
  }

  String _connectionLabel(ThermalConnectionType type) {
    switch (type) {
      case ThermalConnectionType.bluetooth:
        return 'Bluetooth';
      case ThermalConnectionType.usb:
        return 'USB';
      case ThermalConnectionType.network:
        return 'Réseau';
      case ThermalConnectionType.epos:
        return 'E-POS';
      case ThermalConnectionType.system:
        return 'Système';
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _eposIpController.dispose();
    _eposPortController.dispose();
    super.dispose();
  }
}
