import 'package:flutter/foundation.dart';
import '../repositories/inventory_repository.dart';
import '../models/product.dart';
import '../../notifications/services/notification_service.dart';
import '../../notifications/models/notification_model.dart';

/// Service pour vérifier les expirations de produits et envoyer des alertes
class ExpirationAlertService {
  final InventoryRepository _inventoryRepository;
  final NotificationService _notificationService;

  /// Date de la dernière vérification (pour éviter les doublons)
  DateTime? _lastCheckDate;

  /// Singleton instance
  static ExpirationAlertService? _instance;

  ExpirationAlertService._({
    required InventoryRepository inventoryRepository,
    required NotificationService notificationService,
  }) : _inventoryRepository = inventoryRepository,
       _notificationService = notificationService;

  /// Factory constructor pour obtenir l'instance
  factory ExpirationAlertService({
    required InventoryRepository inventoryRepository,
    required NotificationService notificationService,
  }) {
    _instance ??= ExpirationAlertService._(
      inventoryRepository: inventoryRepository,
      notificationService: notificationService,
    );
    return _instance!;
  }

  /// Vérifie les produits expirés et ceux qui expirent bientôt
  /// et envoie des notifications si nécessaire
  Future<ExpirationCheckResult> checkExpirations({
    bool forceCheck = false,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Éviter les vérifications multiples le même jour (sauf si forcé)
    if (!forceCheck && _lastCheckDate != null) {
      final lastCheck = DateTime(
        _lastCheckDate!.year,
        _lastCheckDate!.month,
        _lastCheckDate!.day,
      );
      if (lastCheck.isAtSameMomentAs(today)) {
        debugPrint('⏭️ Vérification d\'expiration déjà effectuée aujourd\'hui');
        return ExpirationCheckResult(
          checkedAt: _lastCheckDate!,
          expiredProducts: [],
          expiringVerySoonProducts: [],
          expiringSoonProducts: [],
          notificationsSent: 0,
        );
      }
    }

    _lastCheckDate = now;

    // Récupérer les produits problématiques
    final expiredProducts = _inventoryRepository.getExpiredProducts();
    final expiringVerySoonProducts =
        _inventoryRepository.getExpiringVerySoonProducts();
    final expiringSoonProducts =
        _inventoryRepository
            .getExpiringSoonProducts()
            .where(
              (p) => !p.isExpiringVerySoon,
            ) // Exclure ceux déjà dans "très bientôt"
            .toList();

    int notificationsSent = 0;

    // Notification pour produits expirés
    if (expiredProducts.isNotEmpty) {
      await _sendExpiredNotification(expiredProducts);
      notificationsSent++;
    }

    // Notification pour produits expirant très bientôt (< 7 jours)
    if (expiringVerySoonProducts.isNotEmpty) {
      await _sendExpiringVerySoonNotification(expiringVerySoonProducts);
      notificationsSent++;
    }

    // Notification pour produits expirant bientôt (7-30 jours)
    if (expiringSoonProducts.isNotEmpty) {
      await _sendExpiringSoonNotification(expiringSoonProducts);
      notificationsSent++;
    }

    debugPrint('🔍 Vérification d\'expiration terminée:');
    debugPrint('   - Expirés: ${expiredProducts.length}');
    debugPrint('   - Expirent sous 7j: ${expiringVerySoonProducts.length}');
    debugPrint('   - Expirent sous 30j: ${expiringSoonProducts.length}');
    debugPrint('   - Notifications envoyées: $notificationsSent');

    return ExpirationCheckResult(
      checkedAt: now,
      expiredProducts: expiredProducts,
      expiringVerySoonProducts: expiringVerySoonProducts,
      expiringSoonProducts: expiringSoonProducts,
      notificationsSent: notificationsSent,
    );
  }

  Future<void> _sendExpiredNotification(List<Product> products) async {
    final productNames = products.take(3).map((p) => p.name).join(', ');
    final suffix =
        products.length > 3 ? ' et ${products.length - 3} autre(s)' : '';

    await _notificationService.sendNotification(
      title: '⚠️ Produits expirés',
      message:
          '$productNames$suffix ont expiré. Veuillez les retirer du stock.',
      type: NotificationType.warning,
      actionRoute: '/inventory?filter=expired',
      additionalData: products.map((p) => p.id).join(','),
    );
  }

  Future<void> _sendExpiringVerySoonNotification(List<Product> products) async {
    final productNames = products
        .take(3)
        .map((p) {
          final days = p.daysUntilExpiration ?? 0;
          return '${p.name} (${days}j)';
        })
        .join(', ');
    final suffix =
        products.length > 3 ? ' et ${products.length - 3} autre(s)' : '';

    await _notificationService.sendNotification(
      title: '⏰ Expiration imminente',
      message: '$productNames$suffix expirent dans moins de 7 jours.',
      type: NotificationType.warning,
      actionRoute: '/inventory?filter=expiring',
      additionalData: products.map((p) => p.id).join(','),
    );
  }

  Future<void> _sendExpiringSoonNotification(List<Product> products) async {
    await _notificationService.sendNotification(
      title: '📅 Expiration prochaine',
      message:
          '${products.length} produit(s) expirent dans les 30 prochains jours.',
      type: NotificationType.info,
      actionRoute: '/inventory?filter=expiring',
      additionalData: products.map((p) => p.id).join(','),
    );
  }

  /// Obtient un résumé des expirations sans envoyer de notifications
  ExpirationSummary getExpirationSummary() {
    return ExpirationSummary(
      expiredCount: _inventoryRepository.getExpiredProducts().length,
      expiringVerySoonCount:
          _inventoryRepository.getExpiringVerySoonProducts().length,
      expiringSoonCount: _inventoryRepository.getExpiringSoonProducts().length,
    );
  }
}

/// Résultat d'une vérification d'expiration
class ExpirationCheckResult {
  final DateTime checkedAt;
  final List<Product> expiredProducts;
  final List<Product> expiringVerySoonProducts;
  final List<Product> expiringSoonProducts;
  final int notificationsSent;

  ExpirationCheckResult({
    required this.checkedAt,
    required this.expiredProducts,
    required this.expiringVerySoonProducts,
    required this.expiringSoonProducts,
    required this.notificationsSent,
  });

  /// Nombre total de produits avec problèmes d'expiration
  int get totalProblematicCount =>
      expiredProducts.length +
      expiringVerySoonProducts.length +
      expiringSoonProducts.length;

  /// Indique si des problèmes d'expiration ont été détectés
  bool get hasIssues => totalProblematicCount > 0;
}

/// Résumé des expirations
class ExpirationSummary {
  final int expiredCount;
  final int expiringVerySoonCount;
  final int expiringSoonCount;

  ExpirationSummary({
    required this.expiredCount,
    required this.expiringVerySoonCount,
    required this.expiringSoonCount,
  });

  int get totalCount =>
      expiredCount + expiringVerySoonCount + expiringSoonCount;
  bool get hasIssues => totalCount > 0;
}
