import 'scanner_service_interface.dart';

/// Implémentation du service de scan pour desktop
/// Sur desktop, le scan de codes-barres n'est pas supporté par caméra
/// L'utilisateur doit utiliser la saisie manuelle ou un scanner USB
class DesktopScannerService implements ScannerServiceInterface {
  static DesktopScannerService? _instance;

  DesktopScannerService._();

  static DesktopScannerService get instance {
    _instance ??= DesktopScannerService._();
    return _instance!;
  }

  @override
  Future<bool> isSupported() async {
    // Sur desktop, le scan par caméra n'est pas supporté
    // mais la saisie manuelle ou scanner USB est toujours disponible
    return false;
  }

  @override
  Future<bool> checkPermissions() async {
    // Pas de permissions nécessaires pour la saisie manuelle
    return true;
  }

  @override
  Future<bool> requestPermissions() async {
    return true;
  }

  @override
  bool isValidBarcode(String code) {
    if (code.isEmpty) return false;
    // Accepte les codes alphanumériques avec tirets et underscores
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
