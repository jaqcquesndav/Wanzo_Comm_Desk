import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../constants/constants.dart';
import '../../core/services/barcode_scanner_service.dart';
import '../../core/services/audio_service.dart';
import 'package:wanzo/l10n/app_localizations.dart';

/// Widget réutilisable pour scanner des codes-barres
class BarcodeScannerWidget extends StatefulWidget {
  final Function(String) onBarcodeScanned;
  final String? title;
  final String? subtitle;
  final bool allowManualInput;

  const BarcodeScannerWidget({
    super.key,
    required this.onBarcodeScanned,
    this.title,
    this.subtitle,
    this.allowManualInput = true,
  });

  @override
  State<BarcodeScannerWidget> createState() => _BarcodeScannerWidgetState();
}

class _BarcodeScannerWidgetState extends State<BarcodeScannerWidget> {
  late MobileScannerController _controller;
  final BarcodeScannerService _scannerService = BarcodeScannerService();
  final AudioService _audioService = AudioService();
  final TextEditingController _manualInputController = TextEditingController();

  bool _isScanning = true;
  bool _hasPermission = false;
  bool _isSupported = false;
  String? _lastScannedCode;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    // Vérifier le support et les permissions
    final isSupported = await _scannerService.isScannerSupported();
    final hasPermission = await _scannerService.checkCameraPermission();

    setState(() {
      _isSupported = isSupported;
      _hasPermission = hasPermission;
    });

    if (isSupported && hasPermission) {
      _controller = MobileScannerController(
        formats: _scannerService.getSupportedFormats(),
        detectionSpeed: DetectionSpeed.normal,
        returnImage: false,
      );
    }
  }

  @override
  void dispose() {
    if (_hasPermission && _isSupported) {
      _controller.dispose();
    }
    _manualInputController.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue != null) {
      final cleanedBarcode = _scannerService.cleanBarcode(barcode!.rawValue!);

      if (_scannerService.isValidBarcode(cleanedBarcode) &&
          cleanedBarcode != _lastScannedCode) {
        setState(() {
          _lastScannedCode = cleanedBarcode;
          _isScanning = false;
        });

        // Vibration légère pour feedback
        _controller.stop();

        // Jouer le son de bip
        _audioService.playBeep();

        // Retourner le code scanné après un délai court
        Future.delayed(const Duration(milliseconds: 500), () {
          widget.onBarcodeScanned(cleanedBarcode);
        });
      }
    }
  }

  void _onManualSubmit() {
    final manualCode = _manualInputController.text.trim();
    if (_scannerService.isValidBarcode(manualCode)) {
      widget.onBarcodeScanned(manualCode);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Code invalide. Veuillez entrer un code valide (lettres, chiffres, tirets).',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Scanner code-barres'),
        actions: [
          if (_hasPermission && _isSupported && !_isScanning)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _isScanning = true;
                  _lastScannedCode = null;
                });
                _controller.start();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Zone de scan
          Expanded(flex: 3, child: _buildScannerArea(l10n)),

          // Informations et saisie manuelle
          Expanded(flex: 1, child: _buildBottomSection(l10n)),
        ],
      ),
    );
  }

  Widget _buildScannerArea(AppLocalizations l10n) {
    if (!_isSupported) {
      return _buildErrorState(
        icon: Icons.camera_alt_outlined,
        title: 'Caméra non supportée',
        subtitle: 'Cet appareil ne supporte pas le scan de codes-barres',
      );
    }

    if (!_hasPermission) {
      return _buildErrorState(
        icon: Icons.camera_enhance_outlined,
        title: 'Permission caméra requise',
        subtitle:
            'Veuillez autoriser l\'accès à la caméra pour scanner les codes-barres',
        action: ElevatedButton(
          onPressed: () async {
            final granted = await _scannerService.checkCameraPermission();
            setState(() {
              _hasPermission = granted;
            });
            if (granted) {
              _initializeScanner();
            }
          },
          child: Text('Autoriser'),
        ),
      );
    }

    if (!_isScanning && _lastScannedCode != null) {
      return _buildSuccessState(l10n);
    }

    return Stack(
      children: [
        MobileScanner(controller: _controller, onDetect: _onBarcodeDetected),
        _buildScannerOverlay(l10n),
      ],
    );
  }

  Widget _buildErrorState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WanzoSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey),
          const SizedBox(height: WanzoSpacing.md),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: WanzoSpacing.sm),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: WanzoSpacing.lg),
            action,
          ],
        ],
      ),
    );
  }

  Widget _buildSuccessState(AppLocalizations l10n) {
    final codeType = _scannerService.getCodeType(_lastScannedCode!);
    final isQR = _scannerService.isQRCode(_lastScannedCode);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WanzoSpacing.lg),
      decoration: BoxDecoration(color: Colors.green.shade50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isQR ? Icons.qr_code_2 : Icons.check_circle,
            size: 80,
            color: Colors.green.shade700,
          ),
          const SizedBox(height: WanzoSpacing.md),
          Text(
            '$codeType scanné avec succès',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.green.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: WanzoSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: WanzoSpacing.md,
              vertical: WanzoSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(WanzoRadius.sm),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Text(
              _lastScannedCode!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay(AppLocalizations l10n) {
    return Container(
      decoration: ShapeDecoration(
        shape: QrScannerOverlayShape(
          borderColor: Theme.of(context).colorScheme.primary,
          borderRadius: WanzoRadius.md,
          borderLength: 30,
          borderWidth: 4,
          cutOutSize: 250,
        ),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.all(WanzoSpacing.lg),
          padding: const EdgeInsets.all(WanzoSpacing.md),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(WanzoRadius.sm),
          ),
          child: Text(
            widget.subtitle ?? 'Pointez vers le code-barres ou QR code',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSection(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(WanzoSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.allowManualInput) ...[
              Text(
                'Saisie manuelle du code',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: WanzoSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _manualInputController,
                      decoration: InputDecoration(
                        hintText: 'Entrez le code-barres ou QR code',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: WanzoSpacing.sm,
                          vertical: WanzoSpacing.xs,
                        ),
                      ),
                      keyboardType: TextInputType.text,
                      onFieldSubmitted: (_) => _onManualSubmit(),
                    ),
                  ),
                  const SizedBox(width: WanzoSpacing.xs),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: _onManualSubmit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: WanzoSpacing.sm,
                        ),
                      ),
                      child: Text('Valider'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Forme personnalisée pour l'overlay du scanner
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top + borderRadius)
        ..quadraticBezierTo(
          rect.left,
          rect.top,
          rect.left + borderRadius,
          rect.top,
        )
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = width / 2;
    final height = rect.height;
    final borderHeightSize = height / 2;
    final cutOutWidth = cutOutSize < width ? cutOutSize : width - borderWidth;
    final cutOutHeight =
        cutOutSize < height ? cutOutSize : height - borderWidth;

    final backgroundPaint =
        Paint()
          ..color = overlayColor
          ..style = PaintingStyle.fill;

    final borderPaint =
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth;

    final cutOutRect = Rect.fromLTWH(
      rect.left + (width - cutOutWidth) / 2 + borderWidth,
      rect.top + (height - cutOutHeight) / 2 + borderWidth,
      cutOutWidth - borderWidth * 2,
      cutOutHeight - borderWidth * 2,
    );

    // Dessiner l'overlay
    canvas
      ..saveLayer(rect, backgroundPaint)
      ..drawRect(rect, backgroundPaint)
      // Découper le centre
      ..drawRRect(
        RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
        Paint()..blendMode = BlendMode.clear,
      )
      ..restore();

    // Dessiner les coins du cadre de scan
    final borderOffset = borderWidth / 2;
    final borderLengthValue =
        borderLength > cutOutWidth / 2 + borderWidth * 2
            ? borderWidthSize / 2
            : borderLength;
    final borderHeightValue =
        borderLength > cutOutHeight / 2 + borderWidth * 2
            ? borderHeightSize / 2
            : borderLength;

    // Coin supérieur gauche
    canvas.drawPath(
      Path()
        ..moveTo(
          cutOutRect.left - borderOffset,
          cutOutRect.top + borderHeightValue,
        )
        ..lineTo(cutOutRect.left - borderOffset, cutOutRect.top + borderRadius)
        ..quadraticBezierTo(
          cutOutRect.left - borderOffset,
          cutOutRect.top - borderOffset,
          cutOutRect.left + borderRadius,
          cutOutRect.top - borderOffset,
        )
        ..lineTo(
          cutOutRect.left + borderLengthValue,
          cutOutRect.top - borderOffset,
        ),
      borderPaint,
    );

    // Coin supérieur droit
    canvas.drawPath(
      Path()
        ..moveTo(
          cutOutRect.right + borderOffset,
          cutOutRect.top + borderHeightValue,
        )
        ..lineTo(cutOutRect.right + borderOffset, cutOutRect.top + borderRadius)
        ..quadraticBezierTo(
          cutOutRect.right + borderOffset,
          cutOutRect.top - borderOffset,
          cutOutRect.right - borderRadius,
          cutOutRect.top - borderOffset,
        )
        ..lineTo(
          cutOutRect.right - borderLengthValue,
          cutOutRect.top - borderOffset,
        ),
      borderPaint,
    );

    // Coin inférieur droit
    canvas.drawPath(
      Path()
        ..moveTo(
          cutOutRect.right + borderOffset,
          cutOutRect.bottom - borderHeightValue,
        )
        ..lineTo(
          cutOutRect.right + borderOffset,
          cutOutRect.bottom - borderRadius,
        )
        ..quadraticBezierTo(
          cutOutRect.right + borderOffset,
          cutOutRect.bottom + borderOffset,
          cutOutRect.right - borderRadius,
          cutOutRect.bottom + borderOffset,
        )
        ..lineTo(
          cutOutRect.right - borderLengthValue,
          cutOutRect.bottom + borderOffset,
        ),
      borderPaint,
    );

    // Coin inférieur gauche
    canvas.drawPath(
      Path()
        ..moveTo(
          cutOutRect.left - borderOffset,
          cutOutRect.bottom - borderHeightValue,
        )
        ..lineTo(
          cutOutRect.left - borderOffset,
          cutOutRect.bottom - borderRadius,
        )
        ..quadraticBezierTo(
          cutOutRect.left - borderOffset,
          cutOutRect.bottom + borderOffset,
          cutOutRect.left + borderRadius,
          cutOutRect.bottom + borderOffset,
        )
        ..lineTo(
          cutOutRect.left + borderLengthValue,
          cutOutRect.bottom + borderOffset,
        ),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
