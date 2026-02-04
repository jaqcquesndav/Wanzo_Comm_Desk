// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\core\services\version_control_service.dart

import 'dart:convert';
import '../utils/logger.dart';
import 'database_service.dart';
import 'conflict_resolution_service.dart';

/// Service pour gérer les versions des données et résoudre les conflits
class VersionControlService {
  static final VersionControlService _instance = VersionControlService._internal();

  /// Instance unique du service (singleton)
  factory VersionControlService() => _instance;

  VersionControlService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final ConflictResolutionService _conflictResolutionService = ConflictResolutionService();

  /// Table pour stocker les versions
  static const String _versionsTable = 'data_versions';

  /// Crée la table de versions si elle n'existe pas
  Future<void> init() async {
    try {
      final db = await _databaseService.database;
      
      // Vérifier si la table existe
      final tables = await db.query(
        'sqlite_master',
        where: 'type = ? AND name = ?',
        whereArgs: ['table', _versionsTable],
      );
      
      // Créer la table si elle n'existe pas
      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE $_versionsTable (
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            local_version INTEGER NOT NULL,
            remote_version INTEGER NOT NULL,
            last_sync_timestamp INTEGER NOT NULL,
            data_hash TEXT NOT NULL,
            conflict_status TEXT,
            PRIMARY KEY (entity_type, entity_id)
          )
        ''');
        
        Logger.info('Table de versions créée');
      }
    } catch (e) {
      Logger.error('Erreur lors de l\'initialisation du service de versions', error: e);
    }
  }

  /// Met à jour la version locale d'une entité
  Future<void> updateLocalVersion({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final db = await _databaseService.database;
      
      // Calculer le hash des données
      final dataHash = _calculateDataHash(data);
      
      // Récupérer la version existante
      final versions = await db.query(
        _versionsTable,
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: [entityType, entityId],
      );
      
      final now = DateTime.now().millisecondsSinceEpoch;
      
      if (versions.isEmpty) {
        // Nouvelle entité
        await db.insert(
          _versionsTable,
          {
            'entity_type': entityType,
            'entity_id': entityId,
            'local_version': 1,
            'remote_version': 0,
            'last_sync_timestamp': now,
            'data_hash': dataHash,
            'conflict_status': 'pending',
          },
        );
      } else {
        // Entité existante
        final currentVersion = versions.first;
        final localVersion = (currentVersion['local_version'] as int) + 1;
        
        await db.update(
          _versionsTable,
          {
            'local_version': localVersion,
            'last_sync_timestamp': now,
            'data_hash': dataHash,
            'conflict_status': 'pending',
          },
          where: 'entity_type = ? AND entity_id = ?',
          whereArgs: [entityType, entityId],
        );
      }
      
      Logger.info('Version locale mise à jour pour $entityType:$entityId');
    } catch (e) {
      Logger.error('Erreur lors de la mise à jour de la version locale', error: e);
    }
  }

  /// Met à jour la version distante d'une entité
  Future<void> updateRemoteVersion({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> data,
    required int remoteVersion,
  }) async {
    try {
      final db = await _databaseService.database;
      
      // Calculer le hash des données
      final dataHash = _calculateDataHash(data);
      
      // Récupérer la version existante
      final versions = await db.query(
        _versionsTable,
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: [entityType, entityId],
      );
      
      final now = DateTime.now().millisecondsSinceEpoch;
      
      if (versions.isEmpty) {
        // Nouvelle entité
        await db.insert(
          _versionsTable,
          {
            'entity_type': entityType,
            'entity_id': entityId,
            'local_version': 0,
            'remote_version': remoteVersion,
            'last_sync_timestamp': now,
            'data_hash': dataHash,
            'conflict_status': null,
          },
        );
      } else {
        // Entité existante
        await db.update(
          _versionsTable,
          {
            'remote_version': remoteVersion,
            'last_sync_timestamp': now,
            'data_hash': dataHash,
            'conflict_status': null,
          },
          where: 'entity_type = ? AND entity_id = ?',
          whereArgs: [entityType, entityId],
        );
      }
      
      Logger.info('Version distante mise à jour pour $entityType:$entityId');
    } catch (e) {
      Logger.error('Erreur lors de la mise à jour de la version distante', error: e);
    }
  }

  /// Vérifie s'il y a un conflit entre les versions locale et distante
  Future<bool> hasConflict({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
  }) async {
    try {
      final localHash = _calculateDataHash(localData);
      final remoteHash = _calculateDataHash(remoteData);
      
      // Si les hash sont identiques, pas de conflit
      if (localHash == remoteHash) {
        return false;
      }
      
      // Récupérer les informations de version
      final db = await _databaseService.database;
      final versions = await db.query(
        _versionsTable,
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: [entityType, entityId],
      );
      
      if (versions.isEmpty) {
        // Pas d'historique de version, on considère qu'il n'y a pas de conflit
        return false;
      }
      
      final version = versions.first;
      final localVersion = version['local_version'] as int;
      final remoteVersion = version['remote_version'] as int;
      
      // S'il y a des modifications locales non synchronisées
      return localVersion > remoteVersion;
    } catch (e) {
      Logger.error('Erreur lors de la vérification des conflits', error: e);
      return false;
    }
  }

  /// Résout un conflit entre données locales et distantes
  Future<Map<String, dynamic>> resolveConflict({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
    ConflictResolutionStrategy? strategy,
  }) async {
    try {
      // Vérifier s'il y a réellement un conflit
      final hasConflictResult = await hasConflict(
        entityType: entityType,
        entityId: entityId,
        localData: localData,
        remoteData: remoteData,
      );
      
      if (!hasConflictResult) {
        // Pas de conflit, retourner les données distantes
        return remoteData;
      }
      
      // Résoudre le conflit
      final resolvedData = _conflictResolutionService.resolveConflict(
        entityType: entityType,
        entityId: entityId,
        localData: localData,
        remoteData: remoteData,
        strategy: strategy,
      );
      
      // Mettre à jour le statut de conflit
      final db = await _databaseService.database;
      await db.update(
        _versionsTable,
        {'conflict_status': 'resolved'},
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: [entityType, entityId],
      );
      
      Logger.info('Conflit résolu pour $entityType:$entityId');
      return resolvedData;
    } catch (e) {
      Logger.error('Erreur lors de la résolution du conflit', error: e);
      
      // En cas d'erreur, utiliser la stratégie par défaut (données distantes)
      return remoteData;
    }
  }

  /// Calcule le hash des données pour la comparaison
  String _calculateDataHash(Map<String, dynamic> data) {
    // Supprimer les champs qui ne doivent pas être pris en compte dans la comparaison
    final cleanData = Map<String, dynamic>.from(data);
    cleanData.remove('updated_at');
    cleanData.remove('last_sync');
    cleanData.remove('_merged');
    cleanData.remove('_merge_timestamp');
    cleanData.remove('_synced');
    
    // Trier les clés pour avoir un ordre déterministe
    final sortedMap = Map.fromEntries(
      cleanData.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    
    // Convertir en JSON et calculer le hash
    final jsonData = jsonEncode(sortedMap);
    return _generateHash(jsonData);
  }

  /// Génère un hash simple à partir d'une chaîne
  String _generateHash(String input) {
    // Méthode simple de hachage pour démo
    // En production, utiliser un algorithme cryptographique comme SHA-256
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash) + input.codeUnitAt(i);
      hash &= hash; // Convertir en 32 bits
    }
    return hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');
  }
}
