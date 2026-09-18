import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/config/env_config.dart';
import '../../../core/services/api_client.dart';

/// Sévérité de la bannière d'abonnement.
enum SubscriptionBannerSeverity { warning, danger }

/// État de bannière calculé à partir du statut d'abonnement.
class SubscriptionBannerState {
  final SubscriptionBannerSeverity severity;
  final String message;

  /// Signature stable de l'état courant (mémorise le rejet jusqu'au changement).
  final String signature;

  const SubscriptionBannerState({
    required this.severity,
    required this.message,
    required this.signature,
  });
}

/// Verdict du serveur sur l'accès au compte.
///
/// À ne pas confondre avec l'abonnement. Un abonnement épuisé ou expiré
/// rétrograde le client vers Freemium : il continue de travailler, avec moins
/// de capacités, et la bannière le lui dit. Un compte suspendu par le
/// back-office, lui, ferme la porte : plus aucune application, seul Wanzo Land
/// reste ouvert pour consulter son dossier et écrire au support.
class AccountAccessBlock {
  const AccountAccessBlock({
    required this.message,
    this.reason,
    this.supportEmail,
    this.supportPhone,
    this.supportWhatsapp,
  });

  /// Ce que l'on affiche à l'utilisateur.
  final String message;

  /// Motif saisi par le back-office, quand il y en a un.
  final String? reason;

  /// Coordonnées du support, telles que le back-office les configure. Elles
  /// arrivent avec le statut : un numéro qui change ne demande aucune
  /// nouvelle version de l'application.
  final String? supportEmail;
  final String? supportPhone;
  final String? supportWhatsapp;
}

/// Résultat d'une interrogation du statut : ce qui bloque, et ce qui informe.
class SubscriptionEvaluation {
  const SubscriptionEvaluation({this.accessBlock, this.banner});

  final AccountAccessBlock? accessBlock;
  final SubscriptionBannerState? banner;
}

/// Interroge customer-service (via le gateway `/land/api/v1`) pour déterminer
/// si l'accès est fermé, et sinon s'il faut afficher une bannière d'abonnement.
class SubscriptionStatusService {
  SubscriptionStatusService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  static const int _nearLimitThreshold = 90;
  static const List<String> _inactiveStatuses = [
    'expired',
    'canceled',
    'cancelled',
    'suspended',
    'inactive',
    'past_due',
  ];

  /// Accès fermé ? Sinon, quelle bannière afficher ?
  ///
  /// Sans réponse du serveur (hors ligne, service injoignable), on ne bloque
  /// rien et on n'affiche rien : l'application s'utilise hors ligne, et une
  /// coupure réseau ne doit pas enfermer dehors un client en règle.
  Future<SubscriptionEvaluation> evaluate() async {
    final status = await _getJson('/subscription/effective-status');
    if (status == null) return const SubscriptionEvaluation();

    // L'état du COMPTE passe avant tout le reste : s'il est fermé, aucune
    // considération d'abonnement n'a d'objet.
    if (status['accessBlocked'] == true) {
      final support = status['support'];
      String? contact(String key) {
        if (support is! Map) return null;
        final value = support[key]?.toString().trim();
        return (value == null || value.isEmpty) ? null : value;
      }

      return SubscriptionEvaluation(
        accessBlock: AccountAccessBlock(
          message: status['accessBlockedMessage']?.toString() ??
              'Votre compte est suspendu.',
          reason: status['accountSuspensionReason']?.toString(),
          supportEmail: contact('email'),
          supportPhone: contact('phone'),
          supportWhatsapp: contact('whatsapp'),
        ),
      );
    }

    final banner = await _evaluateBanner(status);
    return SubscriptionEvaluation(banner: banner);
  }

  /// Bannière d'abonnement : purement informative, ne bloque jamais l'usage.
  Future<SubscriptionBannerState?> _evaluateBanner(Map<String, dynamic> status) async {
    final subscription = status['subscription'];
    final rawStatus =
        (subscription is Map ? subscription['status'] : null)?.toString().toLowerCase() ?? '';
    final statusMessage = status['statusMessage']?.toString() ?? '';

    if (_inactiveStatuses.contains(rawStatus)) {
      return SubscriptionBannerState(
        severity: SubscriptionBannerSeverity.danger,
        message: statusMessage.isNotEmpty
            ? statusMessage
            : 'Votre abonnement est $rawStatus. Réactivez-le pour conserver toutes les fonctionnalités.',
        signature: 'status:$rawStatus',
      );
    }

    final grace = status['gracePeriod'];
    if (grace is Map && grace['inGracePeriod'] == true) {
      final days = (grace['daysRemaining'] as num?)?.toInt() ?? 0;
      final plural = days > 1 ? 's' : '';
      return SubscriptionBannerState(
        severity: SubscriptionBannerSeverity.warning,
        message:
            'Période de grâce : $days jour$plural restant$plural avant la suspension de votre abonnement.',
        signature: 'grace:$days',
      );
    }

    if (status['isDowngraded'] == true) {
      final planName = status['planName']?.toString() ?? '';
      return SubscriptionBannerState(
        severity: SubscriptionBannerSeverity.warning,
        message: statusMessage.isNotEmpty
            ? statusMessage
            : 'Votre plan a été rétrogradé${planName.isNotEmpty ? ' ($planName)' : ''}. Certaines fonctionnalités sont limitées.',
        signature: 'downgraded',
      );
    }

    // Jetons Adha épuisés : les opérations restent enregistrées, mais les
    // écritures et les réponses Adha attendent le renouvellement de la dotation.
    // Un constat et une action, pas d'alarme.
    final tokens = status['tokens'];
    if (tokens is Map) {
      final exhausted = tokens['exhausted'] == true;
      final unlimited = tokens['unlimited'] == true;
      final included = (tokens['included'] as num?)?.toInt() ?? 0;
      final remaining = (tokens['remaining'] as num?)?.toInt() ?? 0;
      final perMessage = (tokens['tokensPerMessage'] as num?)?.toInt() ?? 1000;
      if (exhausted) {
        return const SubscriptionBannerState(
          severity: SubscriptionBannerSeverity.warning,
          message:
              'Vos messages Adha inclus sont épuisés pour ce mois. Vos opérations sont enregistrées ; les écritures et réponses Adha reprendront avec un plan supérieur ou des jetons supplémentaires.',
          signature: 'tokens:exhausted',
        );
      }
      if (!unlimited && included > 0) {
        final remainingMessages = remaining ~/ (perMessage > 0 ? perMessage : 1000);
        if (remainingMessages <= 10) {
          final plural = remainingMessages > 1 ? 's' : '';
          return SubscriptionBannerState(
            severity: SubscriptionBannerSeverity.warning,
            message: 'Il vous reste environ $remainingMessages message$plural Adha ce mois-ci.',
            signature: 'tokens:low:$remainingMessages',
          );
        }
      }
    }

    // Avertissement proactif « proche de la limite ».
    final usage = await _getJson('/subscription/usage');
    final features = usage?['features'];
    if (features is List) {
      for (final f in features) {
        if (f is! Map) continue;
        final limit = (f['limitValue'] as num?)?.toDouble() ?? -1;
        final pct = (f['usagePercentage'] as num?)?.toDouble() ?? 0;
        if (limit > 0 && pct >= _nearLimitThreshold) {
          final current = (f['currentUsage'] as num?)?.toInt() ?? 0;
          final limitInt = limit.toInt();
          return SubscriptionBannerState(
            severity: SubscriptionBannerSeverity.warning,
            message:
                'Vous approchez de la limite de votre plan ($current/$limitInt). Pensez à passer à un plan supérieur.',
            signature: 'limit:${f['feature']}:$current',
          );
        }
      }
    }

    return null;
  }

  /// GET authentifié sur customer-service, tolérant aux pannes (retourne null).
  Future<Map<String, dynamic>?> _getJson(String path) async {
    try {
      final url = EnvConfig.getDeviceCompatibleUrl('${EnvConfig.landBaseUrl}$path');
      final headers = await _apiClient.getHeaders(requiresAuth: true);
      // Pas de token → non authentifié, rien à afficher.
      if (!headers.containsKey('Authorization')) return null;

      final res = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      // customer-service peut renvoyer la donnée telle quelle ou enveloppée { data }.
      final data = decoded.containsKey('data') && decoded['data'] is Map
          ? decoded['data']
          : decoded;
      return Map<String, dynamic>.from(data as Map);
    } catch (_) {
      return null;
    }
  }
}
