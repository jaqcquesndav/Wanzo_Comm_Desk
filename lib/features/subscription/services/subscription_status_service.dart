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

/// Interroge customer-service (via le gateway `/land/api/v1`) pour déterminer,
/// de façon non bloquante, s'il faut afficher une bannière d'abonnement.
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

  /// Calcule l'état de bannière à afficher, ou null si tout est nominal / injoignable.
  Future<SubscriptionBannerState?> evaluate() async {
    final status = await _getJson('/subscription/effective-status');
    if (status == null) return null;

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
