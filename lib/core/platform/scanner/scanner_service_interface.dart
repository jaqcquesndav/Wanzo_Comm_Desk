/// Interface abstraite pour le service de scan de codes-barres
/// Permet d'avoir différentes implémentations selon la plateforme
abstract class ScannerServiceInterface {
  /// Vérifie si le scanner est supporté sur cette plateforme
  Future<bool> isSupported();

  /// Vérifie les permissions nécessaires (caméra, etc.)
  Future<bool> checkPermissions();

  /// Demande les permissions nécessaires
  Future<bool> requestPermissions();

  /// Valide un code-barres
  bool isValidBarcode(String code);

  /// Nettoie un code-barres (supprime les espaces, caractères spéciaux)
  String cleanBarcode(String code);

  /// Détermine le type de code (EAN, UPC, QR, etc.)
  String getCodeType(String code);

  /// Vérifie si c'est un QR code
  bool isQRCode(String code);
}
