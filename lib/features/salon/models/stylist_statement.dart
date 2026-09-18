/// Relevé de compte d'un coiffeur sur une période.
///
/// Deux colonnes qui se répondent : ce qu'il a gagné (ses commissions, figées
/// ligne de vente par ligne de vente) et ce qu'il a déjà perçu (les avances,
/// enregistrées comme des sorties de fonds). Le solde est la différence, et
/// c'est la seule question qu'on se pose en fin de mois.
class StylistStatement {
  final String stylistId;
  final String stylistName;

  /// Chiffre réalisé par ce coiffeur, prestations et produits.
  final double serviceRevenue;
  final double retailRevenue;
  final int servicesCount;

  final double serviceCommission;
  final double retailCommission;
  final double totalCommission;

  /// Total des avances et autres sommes déjà versées sur la période.
  final double advancesTotal;

  /// Ce qui reste dû. Négatif : le coiffeur a pris plus qu'il n'a gagné.
  final double balance;

  final List<StylistAdvance> advances;

  const StylistStatement({
    required this.stylistId,
    required this.stylistName,
    required this.serviceRevenue,
    required this.retailRevenue,
    required this.servicesCount,
    required this.serviceCommission,
    required this.retailCommission,
    required this.totalCommission,
    required this.advancesTotal,
    required this.balance,
    required this.advances,
  });

  /// Vide : un coiffeur sans mouvement sur la période reste affichable.
  factory StylistStatement.empty(String id, String name) => StylistStatement(
        stylistId: id,
        stylistName: name,
        serviceRevenue: 0,
        retailRevenue: 0,
        servicesCount: 0,
        serviceCommission: 0,
        retailCommission: 0,
        totalCommission: 0,
        advancesTotal: 0,
        balance: 0,
        advances: const [],
      );

  /// Parse tolérant : Postgres renvoie ses `numeric` en chaîne.
  static double _d(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
  static int _i(dynamic v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

  factory StylistStatement.fromJson(Map<String, dynamic> json) {
    return StylistStatement(
      stylistId: (json['stylistId'] ?? '').toString(),
      stylistName: (json['stylistName'] ?? '').toString(),
      serviceRevenue: _d(json['serviceRevenue']),
      retailRevenue: _d(json['retailRevenue']),
      servicesCount: _i(json['servicesCount']),
      serviceCommission: _d(json['serviceCommission']),
      retailCommission: _d(json['retailCommission']),
      totalCommission: _d(json['totalCommission']),
      advancesTotal: _d(json['advancesTotal']),
      balance: _d(json['balance']),
      advances: (json['advances'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => StylistAdvance.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// Une somme déjà versée au coiffeur : avance, prime, règlement partiel.
class StylistAdvance {
  final String id;
  final DateTime? date;
  final String motif;
  final String? subCategory;
  final double amount;
  final String? currencyCode;

  const StylistAdvance({
    required this.id,
    required this.date,
    required this.motif,
    required this.amount,
    this.subCategory,
    this.currencyCode,
  });

  factory StylistAdvance.fromJson(Map<String, dynamic> json) => StylistAdvance(
        id: (json['id'] ?? '').toString(),
        date: DateTime.tryParse('${json['date']}'),
        motif: (json['motif'] ?? '').toString(),
        subCategory: json['subCategory'] as String?,
        amount: StylistStatement._d(json['amount']),
        currencyCode: json['currencyCode'] as String?,
      );
}
