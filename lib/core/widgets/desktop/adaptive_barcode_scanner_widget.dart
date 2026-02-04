import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../constants/constants.dart';
import '../../platform/platform_service.dart';
import '../../platform/scanner/scanner_service_factory.dart';
import 'package:wanzo/l10n/app_localizations.dart';

/// Widget adaptatif pour scanner des codes-barres
/// Sur mobile: utilise la caméra via mobile_scanner
/// Sur desktop: propose une saisie manuelle avec support scanner USB
class AdaptiveBarcodeScannerWidget extends StatefulWidget {
  final Function(String) onBarcodeScanned;
  final String? title;
  final String? subtitle;
  final bool allowManualInput;

  const AdaptiveBarcodeScannerWidget({
    super.key,
    required this.onBarcodeScanned,
    this.title,
    this.subtitle,
    this.allowManualInput = true,
  });

  @override
  State<AdaptiveBarcodeScannerWidget> createState() =>
      _AdaptiveBarcodeScannerWidgetState();
}

class _AdaptiveBarcodeScannerWidgetState
    extends State<AdaptiveBarcodeScannerWidget> {
  final _scannerService = ScannerServiceFactory.getInstance();
  final _manualInputController = TextEditingController();
  final _focusNode = FocusNode();

  bool _isLoading = true;
  bool _isScannerSupported = false;
  String? _lastScannedCode;

  @override
  void initState() {
    super.initState();
    _checkScannerSupport();
  }

  Future<void> _checkScannerSupport() async {
    final isSupported = await _scannerService.isSupported();
    setState(() {
      _isScannerSupported = isSupported;
      _isLoading = false;
    });

    // Sur desktop, focus automatique sur le champ de saisie
    if (!isSupported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _manualInputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onManualSubmit() {
    final code = _manualInputController.text.trim();
    if (_scannerService.isValidBarcode(code)) {
      setState(() {
        _lastScannedCode = code;
      });
      widget.onBarcodeScanned(code);
      _manualInputController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code invalide. Veuillez entrer un code valide.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final platform = PlatformService.instance;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Sur desktop ou si scanner non supporté, utiliser le widget desktop
    if (platform.isDesktop || !_isScannerSupported) {
      return _buildDesktopScanner(l10n);
    }

    // Sur mobile avec support scanner, utiliser le widget mobile
    return _buildMobileScanner(l10n);
  }

  Widget _buildDesktopScanner(AppLocalizations l10n) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Scanner / Saisie code-barres'),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(WanzoSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icône et titre
              Icon(
                Icons.qr_code_scanner,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: WanzoSpacing.lg),
              Text(
                'Scanner de code-barres',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: WanzoSpacing.sm),
              Text(
                widget.subtitle ??
                    'Utilisez un scanner USB ou saisissez le code manuellement',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: WanzoSpacing.xxl),

              // Champ de saisie avec support scanner USB
              KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (event) {
                  // Les scanners USB envoient souvent Enter après le code
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.enter) {
                    _onManualSubmit();
                  }
                },
                child: TextField(
                  controller: _manualInputController,
                  focusNode: _focusNode,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Code-barres',
                    hintText: 'Scannez ou saisissez le code...',
                    prefixIcon: const Icon(Icons.barcode_reader),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _onManualSubmit,
                      tooltip: 'Valider',
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(WanzoBorderRadius.md),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                  ),
                  onSubmitted: (_) => _onManualSubmit(),
                  textInputAction: TextInputAction.done,
                ),
              ),

              const SizedBox(height: WanzoSpacing.lg),

              // Bouton de validation
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _onManualSubmit,
                  icon: const Icon(Icons.check),
                  label: const Text('Valider le code'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              // Affichage du dernier code scanné
              if (_lastScannedCode != null) ...[
                const SizedBox(height: WanzoSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(WanzoSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(WanzoBorderRadius.md),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: WanzoSpacing.sm),
                      Text(
                        'Dernier code: $_lastScannedCode',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: WanzoSpacing.xxl),

              // Instructions
              Container(
                padding: const EdgeInsets.all(WanzoSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(WanzoBorderRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: WanzoSpacing.sm),
                        Text(
                          'Instructions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: WanzoSpacing.sm),
                    const Text(
                      '• Scanner USB : Scannez directement, le code sera validé automatiquement',
                    ),
                    const Text(
                      '• Saisie manuelle : Tapez le code et appuyez sur Entrée',
                    ),
                    const Text(
                      '• Formats supportés : EAN-13, EAN-8, UPC, Code128, QR',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileScanner(AppLocalizations l10n) {
    // Importer dynamiquement le widget mobile original
    // Cette méthode sera appelée uniquement sur mobile
    return const _MobileScannerPlaceholder();
  }
}

/// Placeholder pour le scanner mobile
/// Le vrai widget sera importé conditionnellement
class _MobileScannerPlaceholder extends StatelessWidget {
  const _MobileScannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    // Ce widget ne devrait jamais être affiché car sur mobile
    // on utilisera le BarcodeScannerWidget original
    return const Scaffold(
      body: Center(child: Text('Scanner mobile en cours de chargement...')),
    );
  }
}
