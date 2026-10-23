/// Données d'UNE étiquette, préparées par l'écran appelant (stock commerce,
/// produit fini ou matière de production) à partir des données LOCALES : la
/// génération fonctionne hors ligne.
class LabelItem {
  /// Identifiant de la fiche d'origine (produit).
  final String id;
  final String name;

  /// Code encodé (code-barres, SKU ou code généré).
  final String code;

  /// Vrai quand [code] vient d'être généré : il faut l'enregistrer sur la
  /// fiche pour que le scanner de la caisse le retrouve.
  final bool codeIsGenerated;

  /// Prix de vente formaté dans la devise de l'app (null : pas de prix).
  final String? price;

  /// Second prix (autre devise) quand l'affichage CDF et USD est activé.
  final String? secondaryPrice;

  /// Unité de vente (« kg », « pièce »…).
  final String? unit;

  /// Mention libre : lot, date de fabrication ou de péremption.
  final String? extra;

  /// Quantité en stock : quantité d'étiquettes proposée par défaut.
  final double stockQuantity;

  const LabelItem({
    required this.id,
    required this.name,
    required this.code,
    this.codeIsGenerated = false,
    this.price,
    this.secondaryPrice,
    this.unit,
    this.extra,
    this.stockQuantity = 0,
  });

  /// Quantité d'étiquettes par défaut : le stock (arrondi au-dessus), sinon 1.
  int get defaultCopies {
    if (stockQuantity <= 0 || stockQuantity.isNaN) return 1;
    final q = stockQuantity.ceil();
    return q > 999 ? 999 : q;
  }

  LabelItem copyWith({String? code, bool? codeIsGenerated}) => LabelItem(
        id: id,
        name: name,
        code: code ?? this.code,
        codeIsGenerated: codeIsGenerated ?? this.codeIsGenerated,
        price: price,
        secondaryPrice: secondaryPrice,
        unit: unit,
        extra: extra,
        stockQuantity: stockQuantity,
      );
}

/// Une ligne d'impression : un article et son nombre d'exemplaires.
class LabelJob {
  final LabelItem item;
  final int copies;
  const LabelJob(this.item, this.copies);
}

/// Options d'affichage sur l'étiquette.
class LabelOptions {
  final bool showCompany;
  final bool showUnit;
  final bool showExtra;
  final bool showSecondaryPrice;
  final String? companyName;

  const LabelOptions({
    this.showCompany = false,
    this.showUnit = false,
    this.showExtra = true,
    this.showSecondaryPrice = false,
    this.companyName,
  });
}

/// Texte compatible avec les polices standard du PDF et des imprimantes
/// (Latin-1) : espaces fines remplacées, caractères hors Latin-1 retirés.
String labelSafeText(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r == 0x202F || r == 0x00A0 || r == 0x2009) {
      b.write(' ');
    } else if (r == 0x2019 || r == 0x2018) {
      b.write("'");
    } else if (r == 0x2013 || r == 0x2014) {
      b.write('-');
    } else if (r == 0x2026) {
      b.write('...');
    } else if (r >= 0x20 && r <= 0xFF && !(r >= 0x7F && r < 0xA0)) {
      b.writeCharCode(r);
    }
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Texte ASCII strict (polices internes des imprimantes TSPL) : accents
/// retirés.
String labelAsciiText(String s) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿÀÂÄÁÃÅÇÉÈÊËÍÌÎÏÑÓÒÔÖÕÚÙÛÜÝ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyAAAAAACEEEEIIIINOOOOOUUUUY';
  final b = StringBuffer();
  for (final ch in labelSafeText(s).split('')) {
    final i = from.indexOf(ch);
    if (i >= 0) {
      b.write(to[i]);
    } else if (ch.codeUnitAt(0) < 0x7F) {
      b.write(ch);
    }
  }
  return b.toString().replaceAll('"', "'");
}
