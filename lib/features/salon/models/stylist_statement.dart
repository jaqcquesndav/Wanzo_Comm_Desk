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

  /// Le detail de ce qu'il a gagne, un acte par ligne.
  final List<StylistEarning> earnings;

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
    this.earnings = const [],
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
        earnings: const [],
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
      earnings: (json['earnings'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => StylistEarning.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  /// Le compte proprement dit : tous les mouvements dans l'ordre du temps,
  /// avec le solde apres chacun.
  ///
  /// C'est la forme sous laquelle un releve se lit et se remet : on suit une
  /// colonne de dates, pas un tableau de bord. Le solde cumule ce qui reste du
  /// au coiffeur ; il monte quand il travaille, il descend quand il touche.
  List<StylistLedgerLine> get ledger {
    final mouvements = <StylistLedgerLine>[
      for (final e in earnings)
        StylistLedgerLine(
          date: e.date,
          libelle: e.label.isEmpty ? 'Prestation' : e.label,
          nature: e.itemType == 'product' ? 'Vente produit' : 'Prestation',
          credit: e.commission,
          debit: 0,
          solde: 0,
        ),
      for (final a in advances)
        StylistLedgerLine(
          date: a.date,
          libelle: a.motif.isEmpty ? 'Avance' : a.motif,
          nature: (a.subCategory ?? '').isEmpty ? 'Avance' : a.subCategory!,
          credit: 0,
          debit: a.amountCdf,
          solde: 0,
        ),
    ];

    // Une ligne sans date se lit en tete : elle n'a pas de place dans le temps,
    // la cacher ferait un solde faux.
    mouvements.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return -1;
      if (b.date == null) return 1;
      return a.date!.compareTo(b.date!);
    });

    var solde = 0.0;
    return [
      for (final m in mouvements)
        m.avecSolde(solde += m.credit - m.debit),
    ];
  }
}

/// Un acte realise par le coiffeur, et la commission qu'il en tire.
class StylistEarning {
  final String id;
  final DateTime? date;
  final String label;
  final String itemType;
  final double revenue;
  final double commission;

  const StylistEarning({
    required this.id,
    required this.date,
    required this.label,
    required this.itemType,
    required this.revenue,
    required this.commission,
  });

  factory StylistEarning.fromJson(Map<String, dynamic> json) => StylistEarning(
        id: (json['id'] ?? '').toString(),
        date: DateTime.tryParse('${json['date']}'),
        label: (json['label'] ?? '').toString(),
        itemType: (json['itemType'] ?? '').toString(),
        revenue: StylistStatement._d(json['revenue']),
        commission: StylistStatement._d(json['commission']),
      );
}

/// Une ligne du compte : ce qui s'est passe ce jour-la, et ou en est le solde.
class StylistLedgerLine {
  final DateTime? date;
  final String libelle;
  final String nature;

  /// Ce que le salon lui doit en plus (une commission gagnee).
  final double credit;

  /// Ce qu'il a deja touche (une avance versee).
  final double debit;

  /// Solde cumule apres ce mouvement. Negatif : il a pris plus qu'il n'a gagne.
  final double solde;

  const StylistLedgerLine({
    required this.date,
    required this.libelle,
    required this.nature,
    required this.credit,
    required this.debit,
    required this.solde,
  });

  StylistLedgerLine avecSolde(double s) => StylistLedgerLine(
        date: date,
        libelle: libelle,
        nature: nature,
        credit: credit,
        debit: debit,
        solde: s,
      );
}

/// Une somme déjà versée au coiffeur : avance, prime, règlement partiel.
class StylistAdvance {
  final String id;
  final DateTime? date;
  final String motif;
  final String? subCategory;
  final double amount;
  final String? currencyCode;

  /// Montant ramene en CDF par le serveur au taux fige du versement. Le compte
  /// se tient en CDF : une avance en dollars s'y retranche pour sa contre-valeur.
  final double amountCdf;

  const StylistAdvance({
    required this.id,
    required this.date,
    required this.motif,
    required this.amount,
    this.subCategory,
    this.currencyCode,
    double? amountCdf,
  }) : amountCdf = amountCdf ?? amount;

  factory StylistAdvance.fromJson(Map<String, dynamic> json) => StylistAdvance(
        id: (json['id'] ?? '').toString(),
        date: DateTime.tryParse('${json['date']}'),
        motif: (json['motif'] ?? '').toString(),
        subCategory: json['subCategory'] as String?,
        amount: StylistStatement._d(json['amount']),
        currencyCode: json['currencyCode'] as String?,
        amountCdf: json['amountCdf'] == null
            ? null
            : StylistStatement._d(json['amountCdf']),
      );
}
