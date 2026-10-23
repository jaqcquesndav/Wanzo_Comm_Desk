import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'label_codes.dart';

/// Support physique de l'étiquette.
enum LabelMedia {
  /// Rouleau de ticket continu (imprimante de caisse).
  roll,

  /// Étiquette adhésive prédécoupée (imprimante d'étiquettes ou thermique).
  label,

  /// Planche A4 (imprimante bureautique, toujours par le système).
  sheet,
}

/// Langage de l'imprimante thermique configurée.
enum LabelPrinterLanguage { escPos, tspl, zpl }

extension LabelPrinterLanguageX on LabelPrinterLanguage {
  String get label => switch (this) {
        LabelPrinterLanguage.escPos => 'ESC/POS (imprimante de caisse)',
        LabelPrinterLanguage.tspl => 'TSPL (étiquettes TSC, Xprinter)',
        LabelPrinterLanguage.zpl => 'ZPL (étiquettes Zebra)',
      };
}

/// Format d'étiquette. Toutes les mesures en millimètres ; pour un rouleau,
/// [widthMm] est la largeur IMPRIMABLE (48 mm sur 58, 72 mm sur 80).
class LabelFormat {
  final String id;
  final String name;
  final double widthMm;
  final double heightMm;
  final LabelMedia media;

  /// Largeur du papier (rouleau) ou de l'étiquette, pour l'ESC/POS.
  final double paperWidthMm;

  // Planche : grille posée sur une page A4.
  final int columns;
  final int rows;
  final double pageWidthMm;
  final double pageHeightMm;
  final double marginTopMm;
  final double marginLeftMm;

  const LabelFormat({
    required this.id,
    required this.name,
    required this.widthMm,
    required this.heightMm,
    required this.media,
    double? paperWidthMm,
    this.columns = 1,
    this.rows = 1,
    this.pageWidthMm = 0,
    this.pageHeightMm = 0,
    this.marginTopMm = 0,
    this.marginLeftMm = 0,
  }) : paperWidthMm = paperWidthMm ?? widthMm;

  bool get isSheet => media == LabelMedia.sheet;
  int get perPage => isSheet ? columns * rows : 1;

  /// Libellé court pour la sélection.
  String get description {
    String n(double v) =>
        v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    if (isSheet) return '$name, étiquettes ${n(widthMm)} x ${n(heightMm)} mm';
    return '$name (${n(widthMm)} x ${n(heightMm)} mm)';
  }

  static const String customId = 'custom';
  static const double minSideMm = 15;
  static const double maxSideMm = 150;

  static const List<LabelFormat> presets = [
    LabelFormat(
      id: 'roll58',
      name: 'Rouleau 58 mm',
      widthMm: 48,
      heightMm: 30,
      paperWidthMm: 58,
      media: LabelMedia.roll,
    ),
    LabelFormat(
      id: 'roll80',
      name: 'Rouleau 80 mm',
      widthMm: 72,
      heightMm: 40,
      paperWidthMm: 80,
      media: LabelMedia.roll,
    ),
    LabelFormat(
      id: 'l40x30',
      name: 'Étiquette 40 x 30',
      widthMm: 40,
      heightMm: 30,
      media: LabelMedia.label,
    ),
    LabelFormat(
      id: 'l50x30',
      name: 'Étiquette 50 x 30',
      widthMm: 50,
      heightMm: 30,
      media: LabelMedia.label,
    ),
    LabelFormat(
      id: 'l60x40',
      name: 'Étiquette 60 x 40',
      widthMm: 60,
      heightMm: 40,
      media: LabelMedia.label,
    ),
    LabelFormat(
      id: 'a4_3x8',
      name: 'Planche A4, 3 x 8',
      widthMm: 70,
      heightMm: 37,
      media: LabelMedia.sheet,
      columns: 3,
      rows: 8,
      pageWidthMm: 210,
      pageHeightMm: 297,
      marginTopMm: 0.5,
      marginLeftMm: 0,
    ),
    LabelFormat(
      id: 'a4_4x10',
      name: 'Planche A4, 4 x 10',
      widthMm: 52.5,
      heightMm: 29.7,
      media: LabelMedia.sheet,
      columns: 4,
      rows: 10,
      pageWidthMm: 210,
      pageHeightMm: 297,
      marginTopMm: 0,
      marginLeftMm: 0,
    ),
  ];

  /// Dimension personnalisée (étiquette adhésive).
  static LabelFormat custom(double widthMm, double heightMm) => LabelFormat(
        id: customId,
        name: 'Personnalisé',
        widthMm: widthMm.clamp(minSideMm, maxSideMm).toDouble(),
        heightMm: heightMm.clamp(minSideMm, maxSideMm).toDouble(),
        media: LabelMedia.label,
      );

  /// Message d'erreur de saisie d'un côté personnalisé, ou `null` si valide.
  static String? validateSide(String? raw) {
    final v = double.tryParse((raw ?? '').trim().replaceAll(',', '.'));
    if (v == null) return 'Saisissez un nombre';
    if (v < minSideMm) return 'Minimum ${minSideMm.toInt()} mm';
    if (v > maxSideMm) return 'Maximum ${maxSideMm.toInt()} mm';
    return null;
  }

  static LabelFormat byId(String id) =>
      presets.firstWhere((f) => f.id == id, orElse: () => presets[2]);
}

/// Réglages mémorisés sur l'appareil (dernier format, code, options).
class LabelSettings {
  final String formatId;
  final double customWidthMm;
  final double customHeightMm;
  final LabelCodeChoice codeChoice;
  final bool showCompany;
  final bool showUnit;
  final bool showExtra;
  final bool showSecondaryPrice;
  final LabelPrinterLanguage language;

  const LabelSettings({
    this.formatId = 'l40x30',
    this.customWidthMm = 50,
    this.customHeightMm = 25,
    this.codeChoice = LabelCodeChoice.barcode,
    this.showCompany = false,
    this.showUnit = false,
    this.showExtra = true,
    this.showSecondaryPrice = false,
    this.language = LabelPrinterLanguage.escPos,
  });

  LabelFormat get format => formatId == LabelFormat.customId
      ? LabelFormat.custom(customWidthMm, customHeightMm)
      : LabelFormat.byId(formatId);

  LabelSettings copyWith({
    String? formatId,
    double? customWidthMm,
    double? customHeightMm,
    LabelCodeChoice? codeChoice,
    bool? showCompany,
    bool? showUnit,
    bool? showExtra,
    bool? showSecondaryPrice,
    LabelPrinterLanguage? language,
  }) =>
      LabelSettings(
        formatId: formatId ?? this.formatId,
        customWidthMm: customWidthMm ?? this.customWidthMm,
        customHeightMm: customHeightMm ?? this.customHeightMm,
        codeChoice: codeChoice ?? this.codeChoice,
        showCompany: showCompany ?? this.showCompany,
        showUnit: showUnit ?? this.showUnit,
        showExtra: showExtra ?? this.showExtra,
        showSecondaryPrice: showSecondaryPrice ?? this.showSecondaryPrice,
        language: language ?? this.language,
      );

  Map<String, dynamic> toJson() => {
        'formatId': formatId,
        'customWidthMm': customWidthMm,
        'customHeightMm': customHeightMm,
        'codeChoice': codeChoice.name,
        'showCompany': showCompany,
        'showUnit': showUnit,
        'showExtra': showExtra,
        'showSecondaryPrice': showSecondaryPrice,
        'language': language.name,
      };

  factory LabelSettings.fromJson(Map<String, dynamic> j) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    double num_(Object? v, double d) => v is num ? v.toDouble() : d;
    const d = LabelSettings();
    return LabelSettings(
      formatId: j['formatId'] as String? ?? d.formatId,
      customWidthMm: num_(j['customWidthMm'], d.customWidthMm),
      customHeightMm: num_(j['customHeightMm'], d.customHeightMm),
      codeChoice: pick(LabelCodeChoice.values, j['codeChoice'], d.codeChoice),
      showCompany: j['showCompany'] as bool? ?? d.showCompany,
      showUnit: j['showUnit'] as bool? ?? d.showUnit,
      showExtra: j['showExtra'] as bool? ?? d.showExtra,
      showSecondaryPrice:
          j['showSecondaryPrice'] as bool? ?? d.showSecondaryPrice,
      language: pick(LabelPrinterLanguage.values, j['language'], d.language),
    );
  }

  static const String _prefKey = 'label_print_settings_v1';

  static Future<LabelSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null) return const LabelSettings();
      return LabelSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const LabelSettings();
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(toJson()));
    } catch (_) {
      // Préférence de confort : sans elle, on garde les défauts.
    }
  }
}
