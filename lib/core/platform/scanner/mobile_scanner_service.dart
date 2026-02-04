import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'scanner_service_interface.dart';

/// Implémentation du service de scan pour mobile
/// Utilise mobile_scanner pour le scan par caméra
class MobileScannerService implements ScannerServiceInterface {
  static MobileScannerService? _instance;

  MobileScannerService._();

  static MobileScannerService get instance {
    _instance ??= MobileScannerService._();
    return _instance!;
  }

  /// Retourne les formats de codes-barres supportés
  List<BarcodeFormat> getSupportedFormats() {
    return [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.codabar,
      BarcodeFormat.itf,
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.pdf417,
    ];
  }

  @override
  Future<bool> isSupported() async {
    return true;
  }

  @override
  Future<bool> checkPermissions() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  @override
  Future<bool> requestPermissions() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  @override
  bool isValidBarcode(String code) {
    if (code.isEmpty) return false;
    final regex = RegExp(r'^[a-zA-Z0-9\-_]+$');
    return regex.hasMatch(code) && code.length >= 3 && code.length <= 50;
  }

  @override
  String cleanBarcode(String code) {
    return code.trim().replaceAll(RegExp(r'\s+'), '');
  }

  @override
  String getCodeType(String code) {
    if (code.length == 13 && RegExp(r'^\d+$').hasMatch(code)) {
      return 'EAN-13';
    } else if (code.length == 8 && RegExp(r'^\d+$').hasMatch(code)) {
      return 'EAN-8';
    } else if (code.length == 12 && RegExp(r'^\d+$').hasMatch(code)) {
      return 'UPC-A';
    } else if (code.length > 20) {
      return 'QR Code';
    } else {
      return 'Code-barres';
    }
  }

  @override
  bool isQRCode(String code) {
    return code.length > 20 || code.contains('http') || code.contains('{');
  }
}
