import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/features/business_unit/models/business_unit.dart';
import 'package:wanzo/features/settings/models/settings.dart';

/// Identité imprimée en tête de TOUTES les pièces (facture, proforma, reçu,
/// ticket thermique, folio, bon de sortie). Source unique : chaque document
/// lit ses lignes ici, aucun ne recompose son en-tête.
///
/// Règle des unités d'affaires, quel que soit leur type ou leur activité
/// (succursale, restaurant, point de vente, conciergerie, atelier...) :
/// - raison sociale de l'entreprise, puis le nom de l'unité s'il en diffère ;
/// - adresse et téléphone : ceux de l'unité, sinon de ses unités parentes
///   (résolus par le serveur, champ par champ), sinon ceux de l'entreprise ;
/// - RCCM, Id. Nat. et NIF : toujours ceux de l'entreprise, sauf unité
///   personne morale (coopérant entreprise) qui porte les siens.
class DocumentIssuer {
  const DocumentIssuer({
    required this.name,
    this.unitName = '',
    this.address = '',
    this.phone = '',
    this.rccm = '',
    this.idNat = '',
    this.taxId = '',
  });

  /// Raison sociale (ou nom de l'unité personne morale).
  final String name;

  /// Nom de l'unité émettrice, vide s'il répète la raison sociale.
  final String unitName;

  /// Adresse sur une ligne, vide si rien de saisi.
  final String address;

  /// Téléphone avec indicatif, vide si rien de saisi.
  final String phone;
  final String rccm;
  final String idNat;
  final String taxId;

  /// Identité de la pièce depuis le profil entreprise (Settings, dernier
  /// profil connu, donc hors ligne d'abord) et le contexte d'unité courant.
  factory DocumentIssuer.from(Settings? settings, {BusinessContext? context}) {
    final ctx = context ?? BusinessContextService().currentContext;
    return DocumentIssuer.resolve(
      companyName: _orElse(settings?.companyName ?? '', ctx?.companyName),
      companyAddress: settings?.companyAddress,
      companyPhone: settings?.companyPhone,
      companyRccm: _orElse(settings?.rccmNumber ?? '', ctx?.companyRccm),
      companyIdNat: _orElse(settings?.idNatNumber ?? '', ctx?.companyNationalId),
      companyTaxId:
          _orElse(settings?.taxIdentificationNumber ?? '', ctx?.companyTaxId),
      context: ctx,
    );
  }

  /// Identité d'une pièce DÉJÀ émise (réimpression, ticket, reçu) : celle de
  /// l'unité qui a porté l'opération ([businessUnitId] de la vente), jamais
  /// l'unité courante de l'utilisateur, qui peut avoir changé depuis.
  factory DocumentIssuer.forUnit(Settings? settings, String? businessUnitId) {
    final ctx = issuerContextForUnit(
      BusinessContextService().currentContext,
      businessUnitId,
      lookup: _localUnit,
    );
    return DocumentIssuer.from(settings, context: ctx);
  }

  /// Unité connue localement (box des unités, hors ligne d'abord).
  static IssuerUnit? _localUnit(String id) {
    try {
      if (!Hive.isBoxOpen('businessUnitsBox')) return null;
      final u = Hive.box<BusinessUnit>('businessUnitsBox').get(id);
      if (u == null) return null;
      return IssuerUnit(
        name: u.name,
        code: u.code,
        type: u.type,
        address: u.address,
        phone: u.phone,
      );
    } catch (_) {
      return null;
    }
  }

  /// Règle pure (testable sans singleton).
  factory DocumentIssuer.resolve({
    required String companyName,
    String? companyAddress,
    String? companyPhone,
    String? companyRccm,
    String? companyIdNat,
    String? companyTaxId,
    BusinessContext? context,
  }) {
    final ctx = context;
    final inUnit = ctx?.businessUnitId != null && ctx?.scope != 'company';
    final legalUnit = ctx?.shouldUseBusinessUnitIdentity ?? false;
    final company = companyName.trim();
    final unit = inUnit ? (ctx?.businessUnitName ?? '').trim() : '';

    String legal(String? own, String? fallback) => legalUnit
        ? _orElse(own ?? '', fallback)
        : (fallback ?? '').trim();

    final name = legalUnit && unit.isNotEmpty ? unit : company;
    final showUnit = !legalUnit &&
        unit.isNotEmpty &&
        unit.toLowerCase() != company.toLowerCase();

    final unitAddress = inUnit ? cleanAddress(ctx?.businessUnitAddress) : '';
    final unitPhone = inUnit ? formatPhone(ctx?.businessUnitPhone) : '';

    return DocumentIssuer(
      name: name,
      unitName: showUnit ? unit : '',
      address:
          unitAddress.isNotEmpty ? unitAddress : cleanAddress(companyAddress),
      phone: unitPhone.isNotEmpty ? unitPhone : formatPhone(companyPhone),
      rccm: legal(ctx?.businessUnitRccm, companyRccm),
      idNat: legal(ctx?.businessUnitIdNat, companyIdNat),
      taxId: legal(ctx?.businessUnitTaxId, companyTaxId),
    );
  }

  /// Lignes sous la raison sociale, dans l'ordre unique de toutes les pièces :
  /// unité, adresse, téléphone, puis RCCM, Id. Nat. et NIF. Aucune ligne vide.
  List<String> get detailLines => [
        if (unitName.isNotEmpty) unitName,
        if (address.isNotEmpty) address,
        if (phone.isNotEmpty) 'Tél. $phone',
        ...legalLines,
      ];

  /// Identifiants légaux présents, dans l'ordre RCCM, Id. Nat., NIF.
  List<String> get legalLines => [
        if (rccm.isNotEmpty) 'RCCM : $rccm',
        if (idNat.isNotEmpty) 'Id. Nat. : $idNat',
        if (taxId.isNotEmpty) 'NIF : $taxId',
      ];

  /// Lignes d'un ticket de [width] caractères (32 en 58 mm, 48 en 80 mm) :
  /// raison sociale en premier, chaque ligne repliée entre les mots.
  List<String> ticketLines(int width) => [
        if (name.isNotEmpty) ...wrapWords(name.toUpperCase(), width),
        for (final l in detailLines) ...wrapWords(l, width),
      ];

  static String _orElse(String local, String? fallback) {
    final l = local.trim();
    return l.isNotEmpty ? l : (fallback ?? '').trim();
  }
}

/// Unité émettrice minimale, lue dans le cache local des unités.
class IssuerUnit {
  const IssuerUnit({
    required this.name,
    this.code,
    this.type,
    this.address,
    this.phone,
  });
  final String name;
  final String? code;
  final dynamic type;
  final String? address;
  final String? phone;
}

/// Contexte d'émission d'une pièce portée par l'unité [unitId] :
/// - unité inconnue de la pièce (anciennes ventes) : contexte courant ;
/// - même unité que l'utilisateur : contexte courant ;
/// - autre unité connue localement : ses nom, adresse et téléphone ;
/// - autre unité inconnue : identité de l'ENTREPRISE, jamais l'unité courante.
BusinessContext? issuerContextForUnit(
  BusinessContext? current,
  String? unitId, {
  IssuerUnit? Function(String id)? lookup,
}) {
  final id = unitId?.trim() ?? '';
  if (id.isEmpty || current == null) return current;
  if (current.businessUnitId == id) return current;
  final unit = lookup?.call(id);
  return BusinessContext(
    companyId: current.companyId,
    companyName: current.companyName,
    companyVariant: current.companyVariant,
    companyRccm: current.companyRccm,
    companyTaxId: current.companyTaxId,
    companyNationalId: current.companyNationalId,
    activityMode: current.activityMode,
    businessUnitId: unit == null ? null : id,
    businessUnitCode: unit?.code,
    businessUnitName: unit?.name,
    businessUnitAddress: unit?.address,
    businessUnitPhone: unit?.phone,
    scope: unit == null ? 'company' : 'unit',
    userId: current.userId,
    userRole: current.userRole,
  );
}

/// Adresse lisible sur une ligne, ou '' : jamais « null », jamais un objet
/// sérialisé (« {"city":"Kinshasa"} » vu en base), jamais le libellé posé par
/// la carte de Wanzo Land (« Position GPS... », coordonnées brutes).
String cleanAddress(Object? raw) {
  if (raw == null) return '';
  Object? value = raw;
  if (value is String) {
    final t = value.trim();
    if (t.startsWith('{') && t.endsWith('}')) {
      try {
        value = jsonDecode(t);
      } catch (_) {
        value = t;
      }
    }
  }
  if (value is Map) {
    final parts = <String>[];
    for (final key in const ['street', 'address', 'commune', 'city', 'province']) {
      final v = value[key];
      if (v is! String) continue;
      final p = cleanAddress(v);
      if (p.isNotEmpty &&
          !parts.any((x) => x.toLowerCase() == p.toLowerCase())) {
        parts.add(p);
      }
    }
    return parts.join(', ');
  }
  if (value is! String) return '';
  final line = value
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .join(', ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  if (line.isEmpty) return '';
  final lower = line.toLowerCase();
  if (lower == 'null' || lower == 'undefined') return '';
  if (RegExp(r'^-?\d{1,3}(\.\d+)?\s*,\s*-?\d{1,3}(\.\d+)?$').hasMatch(line)) {
    return '';
  }
  if (RegExp(r'^position (gps|temporaire)', caseSensitive: false)
      .hasMatch(line)) {
    return '';
  }
  return line;
}

/// Numéro de contact avec indicatif (« +243 995 656 451 »), ou '' pour une
/// valeur d'attente (« +243 000 000 000 », zéros, blob chiffré). Plusieurs
/// numéros séparés par « / » ou « , » sont gardés, chacun mis en forme.
String formatPhone(Object? raw, {String countryCode = '243'}) {
  if (raw is! String) return '';
  final text = raw.trim();
  if (text.isEmpty || text.startsWith('{')) return '';
  final parts = text
      .split(RegExp(r'\s*[/,;]\s*'))
      .map((p) => _formatOne(p, countryCode))
      .where((p) => p.isNotEmpty)
      .toList();
  return parts.join(' / ');
}

String _formatOne(String raw, String countryCode) {
  final t = raw.trim();
  if (t.isEmpty) return '';
  final digits = t.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty || RegExp(r'^0+$').hasMatch(digits)) return '';
  if (RegExp(r'^\d{1,3}0{6,}$').hasMatch(digits)) return '';
  String? national;
  var cc = countryCode;
  if (t.startsWith('+') || digits.startsWith('00')) {
    final d = digits.startsWith('00') ? digits.substring(2) : digits;
    if (d.startsWith(countryCode) && d.length == countryCode.length + 9) {
      national = d.substring(countryCode.length);
    } else if (d.startsWith(countryCode) &&
        d.length == countryCode.length + 10 &&
        d[countryCode.length] == '0') {
      national = d.substring(countryCode.length + 1);
    } else {
      return '+$d'; // autre pays : gardé tel quel, sans espace inventé
    }
  } else if (digits.length == 10 && digits.startsWith('0')) {
    national = digits.substring(1);
  } else if (digits.length == 9) {
    national = digits;
  } else if (digits.startsWith(countryCode) &&
      digits.length == countryCode.length + 9) {
    national = digits.substring(countryCode.length);
  }
  if (national == null) return t; // forme inconnue : la saisie telle quelle
  if (RegExp(r'^0+$').hasMatch(national)) return '';
  return '+$cc ${national.substring(0, 3)} ${national.substring(3, 6)} ${national.substring(6)}';
}

/// Replie [text] en lignes d'au plus [width] caractères en coupant entre les
/// mots (espace, virgule, barre oblique). Un mot plus long que la ligne est le
/// seul cas coupé, jamais tronqué.
List<String> wrapWords(String text, int width) {
  final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty) return const [];
  if (t.length <= width) return [t];
  // Jetons : chaque mot garde son séparateur final (« Butembo, » « com. »).
  final tokens = RegExp(r'[^ ,/]+[,/]?\s?|[,/]\s?|\s')
      .allMatches(t)
      .map((m) => m.group(0)!)
      .toList();
  final lines = <String>[];
  var current = '';
  void flush() {
    final l = current.trim();
    if (l.isNotEmpty) lines.add(l);
    current = '';
  }

  for (var tok in tokens) {
    if ((current + tok).trimRight().length <= width) {
      current += tok;
      continue;
    }
    flush();
    while (tok.trimRight().length > width) {
      lines.add(tok.substring(0, width));
      tok = tok.substring(width);
    }
    current = tok.trimLeft();
  }
  flush();
  return lines;
}
