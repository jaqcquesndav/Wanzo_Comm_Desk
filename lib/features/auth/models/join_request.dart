/// Demande de rattachement par code.
///
/// Un compte sans entreprise qui saisit le code d'une unité ne rejoint plus
/// directement : il crée une demande que l'administrateur accepte (avec un
/// rôle) ou refuse (avec un motif). Le serveur est la seule source de vérité,
/// rien n'est conservé hors ligne.
library;

/// Statuts possibles d'une demande (valeurs du serveur).
class JoinRequestStatus {
  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String refused = 'refused';
  static const String cancelled = 'cancelled';
  static const String all = 'all';

  /// Libellé lisible d'un statut.
  static String label(String status) {
    switch (status) {
      case pending:
        return 'En attente';
      case accepted:
        return 'Acceptée';
      case refused:
        return 'Refusée';
      case cancelled:
        return 'Annulée';
      case all:
        return 'Toutes';
      default:
        return status;
    }
  }

  /// Ordre des filtres proposés à l'administrateur.
  static const List<String> filters = [pending, accepted, refused, cancelled, all];
}

/// Personne à l'origine de la demande.
class JoinRequester {
  final String? auth0Id;
  final String? email;
  final String? name;

  const JoinRequester({this.auth0Id, this.email, this.name});

  factory JoinRequester.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const JoinRequester();
    return JoinRequester(
      auth0Id: json['auth0Id']?.toString(),
      email: json['email']?.toString(),
      name: json['name']?.toString(),
    );
  }

  /// Nom affichable : nom, sinon courriel, sinon mention neutre.
  String get displayName {
    final n = name?.trim() ?? '';
    if (n.isNotEmpty) return n;
    final e = email?.trim() ?? '';
    if (e.isNotEmpty) return e;
    return 'Compte sans nom';
  }
}

/// Une demande de rattachement telle que renvoyée par le serveur.
class JoinRequest {
  final String id;
  final String status;
  final String? companyId;
  final String? companyName;
  final String? businessUnitId;
  final String? businessUnitCode;
  final String? businessUnitName;
  final JoinRequester requester;
  final String? reason;
  final String? grantedRole;
  final String? decidedByEmail;
  final DateTime? decidedAt;
  final DateTime? createdAt;

  const JoinRequest({
    required this.id,
    required this.status,
    this.companyId,
    this.companyName,
    this.businessUnitId,
    this.businessUnitCode,
    this.businessUnitName,
    this.requester = const JoinRequester(),
    this.reason,
    this.grantedRole,
    this.decidedByEmail,
    this.decidedAt,
    this.createdAt,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    DateTime? date(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
    final requester = json['requester'];
    return JoinRequest(
      id: (json['id'] ?? json['requestId'] ?? '').toString(),
      status: (json['status'] ?? JoinRequestStatus.pending).toString(),
      companyId: json['companyId']?.toString(),
      companyName: json['companyName']?.toString(),
      businessUnitId: json['businessUnitId']?.toString(),
      businessUnitCode: json['businessUnitCode']?.toString(),
      businessUnitName: json['businessUnitName']?.toString(),
      requester: JoinRequester.fromJson(
        requester is Map ? Map<String, dynamic>.from(requester) : null,
      ),
      reason: json['reason']?.toString(),
      grantedRole: json['grantedRole']?.toString(),
      decidedByEmail: json['decidedByEmail']?.toString(),
      decidedAt: date(json['decidedAt']),
      createdAt: date(json['createdAt']),
    );
  }

  bool get isPending => status == JoinRequestStatus.pending;
  bool get isAccepted => status == JoinRequestStatus.accepted;
  bool get isRefused => status == JoinRequestStatus.refused;
  bool get isCancelled => status == JoinRequestStatus.cancelled;

  /// « Entreprise (Unité) », ou ce qui est connu des deux.
  String get destinationLabel {
    final company = (companyName ?? '').trim();
    final unit = (businessUnitName ?? businessUnitCode ?? '').trim();
    if (company.isEmpty && unit.isEmpty) return "l'entreprise";
    if (company.isEmpty) return unit;
    if (unit.isEmpty || unit == company) return company;
    return '$company ($unit)';
  }

  @override
  bool operator ==(Object other) =>
      other is JoinRequest &&
      other.id == id &&
      other.status == status &&
      other.reason == reason &&
      other.grantedRole == grantedRole;

  @override
  int get hashCode => Object.hash(id, status, reason, grantedRole);
}

/// Page de demandes (liste administrateur).
class JoinRequestPage {
  final List<JoinRequest> items;
  final int total;
  final int page;
  final int limit;

  const JoinRequestPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  int get pageCount {
    if (limit <= 0 || total <= 0) return 1;
    return (total + limit - 1) ~/ limit;
  }

  bool get hasNext => page < pageCount;
  bool get hasPrevious => page > 1;

  factory JoinRequestPage.fromJson(Map<String, dynamic> json, {int fallbackLimit = 20}) {
    final raw = json['items'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => JoinRequest.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <JoinRequest>[];
    int n(dynamic v, int d) => v is num ? v.toInt() : int.tryParse('$v') ?? d;
    return JoinRequestPage(
      items: items,
      total: n(json['total'], items.length),
      page: n(json['page'], 1),
      limit: n(json['limit'], fallbackLimit),
    );
  }
}

/// Rôle accordable à l'acceptation, avec son libellé métier.
class GrantableRole {
  final String value;
  final String label;
  final String description;

  const GrantableRole(this.value, this.label, this.description);
}

/// Rôles qu'un administrateur peut accorder par une demande (entreprise
/// classique). Jamais administrateur ni propriétaire : le serveur le refuse.
const List<GrantableRole> kGrantableRoles = [
  GrantableRole('user', 'Employé', 'Accès standard, rôle par défaut'),
  GrantableRole('cashier', 'Caissier', 'Encaissements et ventes au comptoir'),
  GrantableRole('salesperson', 'Vendeur', 'Ventes et suivi des clients'),
  GrantableRole('stock_keeper', 'Magasinier', 'Entrées, sorties et inventaires'),
  GrantableRole('commerce_manager', 'Responsable commercial', 'Pilotage des ventes et du stock'),
  GrantableRole('manager', 'Gérant', 'Gestion courante de l\'unité'),
  GrantableRole('accountant', 'Comptable', 'Dépenses, finances et rapports'),
  GrantableRole('receptionist', 'Réceptionniste', 'Accueil et réservations'),
  GrantableRole('technician', 'Technicien', 'Ateliers et interventions'),
  GrantableRole('housekeeping', 'Agent d\'entretien', 'Chambres et locaux'),
  GrantableRole('viewer', 'Lecture seule', 'Consultation sans modification'),
];

/// Rôle proposé par défaut à l'acceptation.
const String kDefaultGrantedRole = 'user';

/// Libellé métier d'un rôle (valeur brute si inconnue).
String grantableRoleLabel(String? value) {
  if (value == null || value.isEmpty) return '';
  for (final r in kGrantableRoles) {
    if (r.value == value) return r.label;
  }
  return value;
}

/// Motifs de refus proposés (complétés par une précision libre).
const List<String> kRefusalReasons = [
  'Personne inconnue de l\'entreprise',
  'Mauvaise entreprise ou mauvaise unité',
  'Demande en double',
  'Poste non ouvert pour le moment',
  'Autre motif',
];

/// Rôles qui décident des demandes (administrateur ou propriétaire).
bool canDecideJoinRequests(String? role) {
  switch ((role ?? '').toLowerCase()) {
    case 'admin':
    case 'super_admin':
    case 'superadmin':
    case 'owner':
    case 'sme_owner':
    case 'sme_admin':
      return true;
    default:
      return false;
  }
}
