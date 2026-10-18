/// Facture PROFORMA (devis chiffré) : pièce distincte de la facture, sans
/// écriture comptable ni mouvement de stock. Numéro définitif PF-AAAA-NNNN
/// donné par le serveur ; hors ligne, un numéro provisoire PF-PROV-... en
/// attendant la synchronisation.
library;

/// Pièce d'origine d'une proforma.
abstract final class ProformaSource {
  static const sale = 'sale'; // Panier de la caisse
  static const restaurantOrder = 'restaurant_order'; // Commande du restaurant
  static const reservation = 'reservation'; // Chambre ou salle, folio compris
  static const manual = 'manual';
}

/// Cycle de vie d'une proforma.
abstract final class ProformaStatus {
  static const issued = 'issued';
  static const accepted = 'accepted';
  static const converted = 'converted';
  static const cancelled = 'cancelled';

  static String label(String s) => switch (s) {
        accepted => 'Acceptée',
        converted => 'Convertie',
        cancelled => 'Annulée',
        _ => 'Émise',
      };
}

double _num(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

String? _texte(dynamic v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

double _round2(double v) => (v * 100).roundToDouble() / 100;

/// Ligne de proforma : même forme qu'une ligne de vente, prix en base CDF.
class ProformaLine {
  final String label;
  final double quantity;
  final double unitPriceCdf;

  /// `product` (article du stock, sortira du stock à la facture) ou `service`.
  final String itemType;
  final String? productId;
  final String? serviceId;
  final String? priceTierCode;
  final String? note;

  const ProformaLine({
    required this.label,
    required this.quantity,
    required this.unitPriceCdf,
    this.itemType = 'service',
    this.productId,
    this.serviceId,
    this.priceTierCode,
    this.note,
  });

  double get totalCdf => _round2(quantity * unitPriceCdf);

  bool get isProduct => itemType == 'product' && productId != null;

  /// Quantité entière (une ligne de vente porte un entier).
  bool get isWholeQuantity => quantity == quantity.roundToDouble();

  /// Quantité lisible : « 2,5 » plutôt qu'un arrondi.
  String get quantityLabel => isWholeQuantity
      ? quantity.toInt().toString()
      : quantity.toString().replaceAll('.', ',');

  factory ProformaLine.fromJson(Map<String, dynamic> j) => ProformaLine(
        label: '${j['label'] ?? ''}',
        quantity: _num(j['quantity']) > 0 ? _num(j['quantity']) : 1,
        unitPriceCdf: _num(j['unitPriceCdf']),
        itemType: j['itemType'] == 'product' ? 'product' : 'service',
        productId: _texte(j['productId']),
        serviceId: _texte(j['serviceId']),
        priceTierCode: _texte(j['priceTierCode']),
        note: _texte(j['note']),
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'quantity': quantity,
        'unitPriceCdf': unitPriceCdf,
        'itemType': isProduct ? 'product' : 'service',
        if (isProduct) 'productId': productId,
        if (serviceId != null) 'serviceId': serviceId,
        if (priceTierCode != null) 'priceTierCode': priceTierCode,
        if (note != null) 'note': note,
      };
}

class Proforma {
  /// Identifiant choisi par l'app (UUID) : un renvoi ne crée pas de doublon.
  final String id;

  /// Numéro définitif (serveur), `null` tant que la proforma n'est pas reçue.
  final String? number;

  /// Numéro provisoire donné hors ligne (PF-PROV, code appareil, rang).
  final String? provisionalNumber;
  final String sourceType;
  final String? sourceId;
  final String? customerId;
  final String? customerName;
  final String? contactName;
  final List<ProformaLine> lines;

  /// Devise de présentation et taux devise vers CDF (1 en CDF).
  final String currencyCode;
  final double exchangeRate;
  final DateTime? validUntil;
  final String? notes;
  final String status;
  final String? convertedSaleId;
  final String? convertedReservationId;
  final DateTime issuedAt;

  /// LOCAL : reçue par le serveur.
  final bool synced;

  const Proforma({
    required this.id,
    required this.sourceType,
    required this.lines,
    required this.issuedAt,
    this.number,
    this.provisionalNumber,
    this.sourceId,
    this.customerId,
    this.customerName,
    this.contactName,
    this.currencyCode = 'CDF',
    this.exchangeRate = 1,
    this.validUntil,
    this.notes,
    this.status = ProformaStatus.issued,
    this.convertedSaleId,
    this.convertedReservationId,
    this.synced = false,
  });

  double get totalCdf => _round2(lines.fold(0.0, (s, l) => s + l.totalCdf));

  /// Total dans la devise de présentation (jamais de taux 1 pour une devise).
  double get totalInCurrency => currencyCode == 'CDF' || exchangeRate <= 0
      ? totalCdf
      : _round2(totalCdf / exchangeRate);

  bool get isProvisional => number == null;

  /// Numéro affiché : définitif, sinon provisoire.
  String get displayNumber => number ?? provisionalNumber ?? 'PF';

  bool get isOpen =>
      status == ProformaStatus.issued || status == ProformaStatus.accepted;

  bool get isExpired =>
      validUntil != null &&
      isOpen &&
      DateTime.now().isAfter(validUntil!.add(const Duration(days: 1)));

  String get statusLabel =>
      isExpired ? 'Expirée' : ProformaStatus.label(status);

  Proforma copyWith({
    String? number,
    String? status,
    String? convertedSaleId,
    String? convertedReservationId,
    bool? synced,
  }) =>
      Proforma(
        id: id,
        number: number ?? this.number,
        provisionalNumber: provisionalNumber,
        sourceType: sourceType,
        sourceId: sourceId,
        customerId: customerId,
        customerName: customerName,
        contactName: contactName,
        lines: lines,
        currencyCode: currencyCode,
        exchangeRate: exchangeRate,
        validUntil: validUntil,
        notes: notes,
        status: status ?? this.status,
        convertedSaleId: convertedSaleId ?? this.convertedSaleId,
        convertedReservationId:
            convertedReservationId ?? this.convertedReservationId,
        issuedAt: issuedAt,
        synced: synced ?? this.synced,
      );

  factory Proforma.fromJson(Map<String, dynamic> j, {bool? synced}) {
    final rate = _num(j['exchangeRate']);
    return Proforma(
      id: '${j['id']}',
      number: _texte(j['number']),
      provisionalNumber: _texte(j['provisionalNumber']),
      sourceType: _texte(j['sourceType']) ?? ProformaSource.manual,
      sourceId: _texte(j['sourceId']),
      customerId: _texte(j['customerId']),
      customerName: _texte(j['customerName']),
      contactName: _texte(j['contactName']),
      lines: [
        for (final l in (j['lines'] as List? ?? const []))
          if (l is Map) ProformaLine.fromJson(Map<String, dynamic>.from(l)),
      ],
      currencyCode: (_texte(j['currencyCode']) ?? 'CDF').toUpperCase(),
      exchangeRate: rate > 0 ? rate : 1,
      validUntil: DateTime.tryParse('${j['validUntil'] ?? ''}'),
      notes: _texte(j['notes']),
      status: _texte(j['status']) ?? ProformaStatus.issued,
      convertedSaleId: _texte(j['convertedSaleId']),
      convertedReservationId: _texte(j['convertedReservationId']),
      issuedAt: DateTime.tryParse('${j['issuedAt'] ?? ''}')?.toLocal() ??
          DateTime.now(),
      // Copie locale : son drapeau fait foi (une proforma numérotée puis
      // convertie hors ligne reste à envoyer). Réponse serveur : numérotée.
      synced: synced ??
          (j.containsKey('synced')
              ? j['synced'] == true
              : _texte(j['number']) != null),
    );
  }

  /// Copie locale complète (Hive).
  Map<String, dynamic> toJson() => {
        ...toApiJson(),
        if (number != null) 'number': number,
        'status': status,
        if (convertedReservationId != null)
          'convertedReservationId': convertedReservationId,
        'synced': synced,
      };

  /// Corps de `POST proformas` (le statut part avec la proforma : une
  /// conversion ou une annulation hors ligne suit à la synchronisation).
  Map<String, dynamic> toApiJson() => {
        if (status != ProformaStatus.issued) 'status': status,
        if (convertedSaleId != null) 'convertedSaleId': convertedSaleId,
        'id': id,
        if (provisionalNumber != null) 'provisionalNumber': provisionalNumber,
        'sourceType': sourceType,
        if (sourceId != null) 'sourceId': sourceId,
        if (customerId != null) 'customerId': customerId,
        if (customerName != null) 'customerName': customerName,
        if (contactName != null) 'contactName': contactName,
        'lines': lines.map((l) => l.toJson()).toList(),
        'currencyCode': currencyCode,
        if (currencyCode != 'CDF') 'exchangeRate': exchangeRate,
        if (validUntil != null)
          'validUntil':
              '${validUntil!.year.toString().padLeft(4, '0')}-${validUntil!.month.toString().padLeft(2, '0')}-${validUntil!.day.toString().padLeft(2, '0')}',
        if (notes != null) 'notes': notes,
        'issuedAt': issuedAt.toUtc().toIso8601String(),
      };

  /// Mention imprimée sur le PDF (titre, numéro, validité).
  ProformaMention get mention => ProformaMention(
        number: displayNumber,
        provisional: isProvisional,
        validUntil: validUntil,
        attention: contactName,
      );
}

/// Ce qui distingue l'impression d'une proforma de celle d'une facture.
class ProformaMention {
  final String number;
  final bool provisional;
  final DateTime? validUntil;

  /// « À l'attention de » (contact de l'entreprise cliente).
  final String? attention;

  const ProformaMention({
    required this.number,
    this.provisional = false,
    this.validUntil,
    this.attention,
  });
}
