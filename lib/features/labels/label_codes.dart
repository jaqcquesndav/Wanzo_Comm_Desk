/// Codes imprimés sur les étiquettes produit : choix de la symbologie,
/// validation EAN-13 (clé de contrôle), Code 128 et génération d'un code
/// stable quand le produit n'en a pas.
///
/// Le code imprimé est TOUJOURS celui que le scanner de la caisse sait
/// retrouver : le code-barres du produit, sinon son SKU, sinon un code généré
/// puis enregistré sur la fiche produit.
library;

/// Choix de l'utilisateur sur l'étiquette.
enum LabelCodeChoice { barcode, qr }

/// Symbologie effectivement imprimée.
enum LabelSymbology { code128, ean13, qr }

class LabelCodes {
  LabelCodes._();

  /// Clé de contrôle EAN-13 pour les 12 premiers chiffres.
  static int ean13CheckDigit(String twelveDigits) {
    if (twelveDigits.length != 12 || !_digits.hasMatch(twelveDigits)) {
      throw ArgumentError('12 chiffres attendus');
    }
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      final d = twelveDigits.codeUnitAt(i) - 48;
      sum += i.isEven ? d : d * 3;
    }
    return (10 - sum % 10) % 10;
  }

  /// Vrai si [code] est un EAN-13 complet avec une clé de contrôle exacte.
  static bool isValidEan13(String code) {
    final c = code.trim();
    if (c.length != 13 || !_digits.hasMatch(c)) return false;
    return ean13CheckDigit(c.substring(0, 12)) == c.codeUnitAt(12) - 48;
  }

  /// Code 128 (jeu B) : ASCII imprimable uniquement, longueur raisonnable.
  static bool isCode128Encodable(String code) {
    if (code.isEmpty || code.length > 48) return false;
    for (final u in code.codeUnits) {
      if (u < 32 || u > 126) return false;
    }
    return true;
  }

  /// Nettoie un code saisi (espaces de bord, retours chariot).
  static String clean(String? raw) =>
      (raw ?? '').replaceAll(RegExp(r'[\r\n\t]'), '').trim();

  /// Code stable dérivé d'un identifiant (id produit) : « WZ » + 8 caractères
  /// sans lettres ambiguës (pas de I, O, 0, 1). Le même identifiant donne
  /// toujours le même code, sur tous les appareils.
  static String generateSku(String seed) {
    // FNV-1a 32 bits, deux passes pour 40 bits utiles.
    int fnv(String s, int basis) {
      var h = basis;
      for (final u in s.codeUnits) {
        h ^= u;
        h = (h * 0x01000193) & 0xFFFFFFFF;
      }
      return h;
    }

    final a = fnv(seed, 0x811C9DC5);
    final b = fnv('$seed#wanzo', 0x050C5D1F);
    final buf = StringBuffer('WZ');
    var bits = (a.toUnsigned(32) << 8) ^ (b & 0xFF);
    for (var i = 0; i < 8; i++) {
      buf.write(_alphabet[bits & 31]);
      bits >>= 5;
    }
    return buf.toString();
  }

  /// Code à imprimer pour un produit : code-barres, sinon SKU, sinon `null`
  /// (il faudra en générer un).
  static String? pickExistingCode({String? barcode, String? sku}) {
    final b = clean(barcode);
    if (b.isNotEmpty && isCode128Encodable(b)) return b;
    final s = clean(sku);
    if (s.isNotEmpty && isCode128Encodable(s)) return s;
    return null;
  }

  /// Symbologie retenue : QR si demandé, EAN-13 si le code en est un valide,
  /// sinon Code 128.
  static LabelSymbology symbologyFor(String code, LabelCodeChoice choice) {
    if (choice == LabelCodeChoice.qr) return LabelSymbology.qr;
    return isValidEan13(code) ? LabelSymbology.ean13 : LabelSymbology.code128;
  }

  /// Jeu C (paires de chiffres) quand le code n'est fait que de chiffres en
  /// nombre pair : barre deux fois plus compacte.
  static bool usesCode128C(String code) =>
      code.length >= 4 && code.length.isEven && _digits.hasMatch(code);

  /// Nombre de modules d'un Code 128 (départ, données, clé, arrêt).
  static int code128Modules(String code) {
    final symbols = usesCode128C(code) ? code.length ~/ 2 : code.length;
    return (symbols + 2) * 11 + 13;
  }

  /// Modules d'un EAN-13 (95 + zones de garde courantes).
  static const int ean13Modules = 95;

  /// Données ESC/POS pour `GS k 73` (Code 128) : préfixe de jeu {B ou {C.
  static List<int> escPosCode128Payload(String code) {
    if (usesCode128C(code)) {
      final out = <int>[0x7B, 0x43]; // {C
      for (var i = 0; i < code.length; i += 2) {
        out.add(int.parse(code.substring(i, i + 2)));
      }
      return out;
    }
    return [0x7B, 0x42, ...code.codeUnits]; // {B
  }

  static final RegExp _digits = RegExp(r'^\d+$');
  static const String _alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
}
