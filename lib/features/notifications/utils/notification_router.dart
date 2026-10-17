// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\notifications\utils\notification_router.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/notification_model.dart';

/// Classe utilitaire pour gérer le routage des notifications
class NotificationRouter {
  /// Navigue vers la route associée à la notification
  static void handleNotificationTap(BuildContext context, NotificationModel notification) {
    debugPrint('Notification tappée: ${notification.id} - Route: ${notification.actionRoute}');

    if (notification.actionRoute == null || notification.actionRoute!.isEmpty) {
      // Aucune route spécifiée, ne rien faire
      debugPrint('Aucune route spécifiée pour cette notification');
      return;
    }

    // Analyser les données additionnelles si présentes
    Map<String, dynamic>? additionalData;
    if (notification.additionalData != null && notification.additionalData!.isNotEmpty) {
      try {
        additionalData = jsonDecode(notification.additionalData!) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Erreur lors de l\'analyse des données additionnelles: $e');
      }
    }

    // Router en fonction du type de notification
    switch (notification.type) {
      case NotificationType.lowStock:
        _routeToProduct(context, notification.actionRoute!, additionalData);
        break;
      case NotificationType.sale:
        _routeToSale(context, notification.actionRoute!, additionalData);
        break;
      case NotificationType.payment:
        _routeToPayment(context, notification.actionRoute!, additionalData);
        break;
      case NotificationType.info:
      case NotificationType.success:
      case NotificationType.warning:
      case NotificationType.error:
        // Route générique
        _routeGeneric(context, notification.actionRoute!, additionalData);
    }
  }

  /// Traduit les anciennes routes (envoyées par le serveur ou gardées en
  /// cache) vers les routes réelles du routeur. Sans cela, ouvrir la
  /// notification menait à l'écran d'erreur de route inconnue.
  @visibleForTesting
  static String normalizeRoute(String route) {
    final uri = Uri.tryParse(route);
    final path = uri?.path ?? route;
    final product = RegExp(r'^/products/([^/]+)$').firstMatch(path);
    if (product != null) return '/inventory/product/${product.group(1)}';
    if (path == '/products') return '/inventory';
    // Pas d'écran de détail paiement : le journal des opérations.
    if (path == '/payments' || path.startsWith('/payments/')) {
      return '/operations';
    }
    return route;
  }

  /// Route vers un produit spécifique
  static void _routeToProduct(BuildContext context, String route, Map<String, dynamic>? data) {
    final String? productId = data?['productId'] as String?;

    if (productId != null) {
      // Route réelle du détail produit (il n'existe pas de '/products/:id').
      context.go('/inventory/product/$productId');
    } else {
      context.go(normalizeRoute(route));
    }
  }

  /// Route vers une vente spécifique
  static void _routeToSale(BuildContext context, String route, Map<String, dynamic>? data) {
    final String? saleId = data?['saleId'] as String?;

    if (saleId != null) {
      context.go('/sales/$saleId');
    } else {
      context.go(normalizeRoute(route));
    }
  }

  /// Route vers un paiement : pas d'écran de détail paiement dédié, on ouvre
  /// le journal des opérations (mouvements financiers) au lieu d'une route morte.
  static void _routeToPayment(BuildContext context, String route, Map<String, dynamic>? data) {
    context.go('/operations');
  }

  /// Route générique basée sur la route fournie
  static void _routeGeneric(BuildContext context, String route, Map<String, dynamic>? data) {
    // Extraire les paramètres de l'URL si nécessaire
    String routeWithParams = route;
    if (data != null && data.isNotEmpty) {
      data.forEach((key, value) {
        // Si la route contient un placeholder comme ":id", le remplacer par la valeur
        if (routeWithParams.contains(':$key')) {
          routeWithParams = routeWithParams.replaceAll(':$key', '$value');
        }
      });
    }
    context.go(normalizeRoute(routeWithParams));
  }
}
