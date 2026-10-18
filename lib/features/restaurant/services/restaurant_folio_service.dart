import '../../../core/exceptions/api_exceptions.dart';
import '../../../core/services/api_client.dart';
import '../models/restaurant_order.dart';

/// Réservation (chambre ou salle) sur laquelle une commande du restaurant peut
/// être reportée : la consommation rejoint son folio et figurera sur LA
/// facture du séjour ou de la location, émise une seule fois par le serveur
/// (`gestion_commerciale_service`, module `spaces`, `POST reservations/:id/folio`).
///
/// Modèle volontairement réduit à ce dont la caisse a besoin : la gestion des
/// réservations elle-même vit dans l'app Assets.
class FolioReservation {
  final String id;
  final String? spaceName;
  final String? customerName;
  final String status;
  final DateTime startAt;
  final DateTime endAt;
  final String? saleId;
  final String currencyCode;

  const FolioReservation({
    required this.id,
    required this.status,
    required this.startAt,
    required this.endAt,
    this.spaceName,
    this.customerName,
    this.saleId,
    this.currencyCode = 'CDF',
  });

  static DateTime _date(dynamic v) =>
      DateTime.tryParse('${v ?? ''}')?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  static String? _texte(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  factory FolioReservation.fromJson(Map<String, dynamic> json) {
    return FolioReservation(
      id: (json['id'] ?? '').toString(),
      spaceName: _texte(json['spaceName']),
      customerName: _texte(json['customerName']),
      status: (json['status'] ?? 'quote').toString(),
      startAt: _date(json['startAt']),
      endAt: _date(json['endAt']),
      saleId: _texte(json['saleId']),
      currencyCode: (_texte(json['currencyCode']) ?? 'CDF').toUpperCase(),
    );
  }

  bool get enCours => status == 'inProgress';

  /// Libellé lisible du statut (mêmes termes que l'app Assets).
  String get statusLabel => switch (status) {
        'quote' => 'Devis',
        'option' => 'Option',
        'confirmed' => 'Confirmée',
        'inProgress' => 'En cours',
        'completed' => 'Terminée',
        'cancelled' => 'Annulée',
        'invoiced' => 'Facturée',
        _ => status,
      };
}

/// Réservation d'une commande sur réservation (chambre ou salle), connue sans réseau : la commande
/// porte sa réservation dès l'ouverture. À l'encaissement, « Sur une
/// réservation » est proposé d'office avec ce séjour (même report sur le folio
/// que le choix manuel, aucune logique de facturation en plus).
FolioReservation? sejourDeLaCommande(RestaurantOrder order) {
  if (!order.isOnReservation) return null;
  return FolioReservation(
    id: order.reservationId!,
    spaceName: order.label,
    customerName: order.customerName,
    status: 'inProgress',
    startAt: order.createdAt,
    endAt: order.createdAt,
  );
}

/// Statuts qui acceptent encore des consommations (le serveur refuse une
/// réservation facturée ou annulée). Devis et options comptent : un traiteur
/// se commande souvent avant que l'événement soit confirmé.
const _statutsOuverts = {'quote', 'option', 'confirmed', 'inProgress'};

/// Réservations sur lesquelles reporter une commande : non facturées, encore
/// ouvertes, en cours ou qui commencent dans les 7 prochains jours (et pas
/// terminées depuis plus de 12 h). En cours d'abord, puis par date de début.
List<FolioReservation> reservationsFacturables(
  List<FolioReservation> toutes,
  DateTime now,
) {
  final liste = toutes
      .where((r) =>
          r.saleId == null &&
          _statutsOuverts.contains(r.status) &&
          !r.startAt.isAfter(now.add(const Duration(days: 7))) &&
          !r.endAt.isBefore(now.subtract(const Duration(hours: 12))))
      .toList()
    ..sort((a, b) {
      final ea = a.enCours ? 0 : 1;
      final eb = b.enCours ? 0 : 1;
      if (ea != eb) return ea - eb;
      return a.startAt.compareTo(b.startAt);
    });
  return liste;
}

/// Lignes de folio d'une commande, au format `AddFolioItemsDto` du serveur :
/// prix unitaire en BASE CDF (le serveur convertit dans la devise de la
/// réservation). Un article pris au stock garde son `productId` : il sortira
/// du stock UNE fois, à la facturation du séjour (aucun décrément ici).
List<Map<String, dynamic>> lignesDeFolio(RestaurantOrder order) => [
      for (final l in order.lines)
        if (l.quantity > 0)
          {
            'label': (l.note != null && l.note!.trim().isNotEmpty)
                ? '${l.productName} (${l.note!.trim()})'
                : l.productName,
            'quantity': l.quantity,
            'unitPriceCdf': l.unitPriceCdf,
            if (l.fromStock) 'productId': l.productId,
          },
    ];

/// Client HTTP de la facturation croisée restaurant vers réservation.
class RestaurantFolioService {
  final ApiClient _apiClient;

  RestaurantFolioService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Déballe la (double) enveloppe `{success, data}` de gestion.
  List<dynamic> _asList(dynamic response) {
    dynamic data = response;
    while (data is Map && data.containsKey('data')) {
      data = data['data'];
    }
    return data is List ? data : const [];
  }

  /// Réservations qui chevauchent [now - 60 j, now + 8 j], filtrées par
  /// [reservationsFacturables].
  Future<List<FolioReservation>> reservationsOuvertes({DateTime? now}) async {
    final t = now ?? DateTime.now();
    final res = await _apiClient.get(
      'reservations',
      queryParameters: {
        'from': t.subtract(const Duration(days: 60)).toUtc().toIso8601String(),
        'to': t.add(const Duration(days: 8)).toUtc().toIso8601String(),
      },
      requiresAuth: true,
    );
    final toutes = <FolioReservation>[];
    for (final raw in _asList(res)) {
      if (raw is Map) {
        try {
          toutes.add(FolioReservation.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          // Réservation illisible : ignorée, les autres restent proposées.
        }
      }
    }
    return reservationsFacturables(toutes, t);
  }

  /// Reporte la commande sur le folio de la réservation. `sourceId` = id de la
  /// commande : un renvoi (reprise réseau, file hors ligne) est ignoré par le
  /// serveur, jamais de consommation comptée deux fois.
  ///
  /// Renvoie `true` quand le serveur a confirmé, `false` quand l'envoi a été
  /// mis en file hors ligne par [ApiClient] (rejoué au retour du réseau).
  /// Toute autre erreur (réservation facturée ou annulée, refus) remonte.
  Future<bool> reporterSurReservation(
    String reservationId,
    RestaurantOrder order,
  ) async {
    final lignes = lignesDeFolio(order);
    if (lignes.isEmpty) {
      throw ArgumentError('La commande ne porte aucun article.');
    }
    try {
      await _apiClient.post(
        'reservations/$reservationId/folio',
        body: {
          'items': lignes,
          'source': 'restaurant',
          'sourceId': order.id,
        },
        requiresAuth: true,
      );
      return true;
    } on OfflineQueuedException {
      return false;
    }
  }
}
