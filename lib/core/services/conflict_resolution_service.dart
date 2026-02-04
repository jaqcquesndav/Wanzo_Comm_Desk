// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\core\services\conflict_resolution_service.dart

import '../utils/logger.dart';

/// Stratégies de résolution des conflits
enum ConflictResolutionStrategy {
  /// Conserver la version locale
  useLocal,

  /// Conserver la version distante
  useRemote,

  /// Fusionner les versions avec priorité locale
  mergeLocalPriority,

  /// Fusionner les versions avec priorité distante
  mergeRemotePriority,

  /// Conserver les deux versions (crée une copie)
  keepBoth,
}

/// Service pour gérer les conflits lors de la synchronisation des données
class ConflictResolutionService {
  static final ConflictResolutionService _instance = ConflictResolutionService._internal();

  /// Instance unique du service (singleton)
  factory ConflictResolutionService() => _instance;

  ConflictResolutionService._internal();

  /// Stratégie par défaut pour résoudre les conflits
  ConflictResolutionStrategy _defaultStrategy = ConflictResolutionStrategy.mergeRemotePriority;

  /// Définit la stratégie par défaut pour résoudre les conflits
  void setDefaultStrategy(ConflictResolutionStrategy strategy) {
    _defaultStrategy = strategy;
    Logger.info('Stratégie de résolution des conflits mise à jour: $_defaultStrategy');
  }

  /// Résout un conflit entre données locales et distantes
  Map<String, dynamic> resolveConflict({
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
    required String entityType,
    required String entityId,
    ConflictResolutionStrategy? strategy,
  }) {
    final resolveStrategy = strategy ?? _defaultStrategy;
    Logger.info('Résolution de conflit pour $entityType:$entityId avec stratégie $resolveStrategy');

    switch (resolveStrategy) {
      case ConflictResolutionStrategy.useLocal:
        return localData;

      case ConflictResolutionStrategy.useRemote:
        return remoteData;

      case ConflictResolutionStrategy.mergeLocalPriority:
        return _mergeData(localData, remoteData);

      case ConflictResolutionStrategy.mergeRemotePriority:
        return _mergeData(remoteData, localData);

      case ConflictResolutionStrategy.keepBoth:
        // Dans ce cas, nous devons informer la méthode appelante qu'il faut créer une copie
        // On ajoute un champ spécial pour indiquer que les données doivent être dupliquées
        final merged = _mergeData(localData, remoteData);
        merged['_conflict_resolution'] = 'keep_both';
        merged['_original_id'] = entityId;
        return merged;
    }
  }

  /// Fusionne deux ensembles de données, avec priorité aux données primaires
  Map<String, dynamic> _mergeData(
    Map<String, dynamic> primaryData,
    Map<String, dynamic> secondaryData,
  ) {
    // Créer une copie des données primaires
    final result = Map<String, dynamic>.from(primaryData);

    // Ajouter les champs des données secondaires qui ne sont pas présents dans les données primaires
    for (final entry in secondaryData.entries) {
      if (!result.containsKey(entry.key)) {
        result[entry.key] = entry.value;
      } else if (result[entry.key] == null && entry.value != null) {
        // Si la valeur primaire est null mais la secondaire ne l'est pas, utiliser la secondaire
        result[entry.key] = entry.value;
      } else if (entry.value is Map && result[entry.key] is Map) {
        // Récursion pour les objets imbriqués
        result[entry.key] = _mergeData(
          result[entry.key] as Map<String, dynamic>,
          entry.value as Map<String, dynamic>,
        );
      }
    }

    // Ajouter un champ de métadonnées indiquant que les données ont été fusionnées
    result['_merged'] = true;
    result['_merge_timestamp'] = DateTime.now().toIso8601String();

    return result;
  }
}
