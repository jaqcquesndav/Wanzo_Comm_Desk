import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service pour la gestion du scanner de codes-barres et QR codes
class BarcodeScannerService {
  static final BarcodeScannerService _instance =
      BarcodeScannerService._internal();
  factory BarcodeScannerService() => _instance;
  BarcodeScannerService._internal();

  /// Vérifie si les permissions de caméra sont accordées
  Future<bool> checkCameraPermission() async {
    try {
      final status = await Permission.camera.status;

      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        final result = await Permission.camera.request();
        return result.isGranted;
      }

      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }

      return false;
    } catch (e) {
      debugPrint('Erreur lors de la vérification des permissions caméra: $e');
      return false;
    }
  }

  /// Vérifie si l'appareil supporte le scan de codes-barres
  Future<bool> isScannerSupported() async {
    try {
      // Sur les émulateurs ou appareils sans caméra
      if (kIsWeb) return false;

      // Vérifier si la caméra est disponible via les permissions
      final cameraStatus = await Permission.camera.status;
      return cameraStatus != PermissionStatus.permanentlyDenied;
    } catch (e) {
      debugPrint('Erreur lors de la vérification du support scanner: $e');
      return false;
    }
  }

  /// Valide si un code (barcode ou QR code) est dans un format acceptable
  bool isValidBarcode(String? barcode) {
    if (barcode == null || barcode.isEmpty) return false;

    // Les QR codes peuvent contenir n'importe quoi, on accepte les codes alphanumériques
    // Longueur min 3 (pour éviter les scans accidentels), max 256 (limite raisonnable pour QR)
    if (barcode.length < 3 || barcode.length > 256) return false;

    // Accepter les codes alphanumériques (codes-barres + QR codes)
    // Autoriser chiffres, lettres, tirets, underscores, points
    final validPattern = RegExp(r'^[a-zA-Z0-9\-_\.]+$');
    return validPattern.hasMatch(barcode);
  }

  /// Vérifie si c'est un code-barres traditionnel (numérique)
  bool isTraditionalBarcode(String? barcode) {
    if (barcode == null || barcode.isEmpty) return false;
    if (barcode.length < 8 || barcode.length > 18) return false;
    final numericPattern = RegExp(r'^[0-9]+$');
    return numericPattern.hasMatch(barcode);
  }

  /// Vérifie si c'est un QR code (contient des caractères non numériques ou longueur atypique)
  bool isQRCode(String? code) {
    if (code == null || code.isEmpty) return false;
    // Si ce n'est pas un code-barres traditionnel, c'est probablement un QR code
    return !isTraditionalBarcode(code) && isValidBarcode(code);
  }

  /// Formats de codes supportés (barres + QR)
  List<BarcodeFormat> getSupportedFormats() {
    return [
      // Codes-barres traditionnels
      BarcodeFormat.ean13, // Standard européen
      BarcodeFormat.ean8, // Standard européen court
      BarcodeFormat.upcA, // Standard américain
      BarcodeFormat.upcE, // Standard américain court
      BarcodeFormat.code128, // Code industriel
      BarcodeFormat.code39, // Code industriel
      BarcodeFormat.codabar, // Code pharmaceutique
      // QR Codes
      BarcodeFormat.qrCode, // QR Code standard
      BarcodeFormat.dataMatrix, // DataMatrix (similaire au QR)
    ];
  }

  /// Nettoie et formate un code scanné (barcode ou QR code)
  String cleanBarcode(String rawBarcode) {
    // Supprime les espaces en début/fin
    String cleaned = rawBarcode.trim();

    // Pour les codes-barres traditionnels (numériques), nettoyer plus agressivement
    if (isTraditionalBarcode(cleaned)) {
      cleaned = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
      debugPrint('📊 Code-barres nettoyé: $rawBarcode -> $cleaned');
    } else {
      // Pour les QR codes, garder les caractères alphanumériques valides
      cleaned = cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9\-_\.]'), '');
      debugPrint('📱 QR code nettoyé: $rawBarcode -> $cleaned');
    }

    return cleaned;
  }

  /// Détecte le type de code scanné pour le logging
  String getCodeType(String code) {
    if (isTraditionalBarcode(code)) {
      if (code.length == 13) return 'EAN-13';
      if (code.length == 8) return 'EAN-8';
      if (code.length == 12) return 'UPC-A';
      return 'Barcode';
    }
    return 'QR Code';
  }
}
