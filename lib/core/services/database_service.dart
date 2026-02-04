// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\core\services\database_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Service pour la gestion de la base de données SQLite locale
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  
  /// Instance unique du service (singleton)
  factory DatabaseService() => _instance;
  
  DatabaseService._internal();
  
  static Database? _database;
  static const String _databaseName = 'wanzo_local.db';
  static const int _databaseVersion = 2; // Incremented version
  
  /// Table pour stocker les réponses API mises en cache
  static const String tableApiCache = 'api_cache';
  
  /// Table pour stocker les données en attente de synchronisation
  static const String tablePendingSync = 'pending_sync';
  
  /// Table pour stocker les téléversements de fichiers en attente
  static const String tablePendingFileUploads = 'pending_file_uploads';
  
  /// Obtient une instance de la base de données
  Future<Database> get database async {
    if (_database != null) return _database!;
    
    _database = await _initDatabase();
    return _database!;
  }
  
  /// Initialise la base de données
  Future<Database> _initDatabase() async {
    final Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final String path = join(documentsDirectory.path, _databaseName);
    
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // Added onUpgrade
    );
  }
  
  /// Crée les tables de la base de données lors de la première création
  Future<void> _onCreate(Database db, int version) async {
    await _createApiCacheTable(db);
    await _createPendingSyncTable(db);
    await _createNotificationsTable(db);
    await _createUserDataCacheTable(db);
    await _createPendingFileUploadsTable(db); // Call new table creation
  }
  
  /// Gère les migrations de la base de données lors d'une mise à niveau de version
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrations pour la version 2
      await _createPendingFileUploadsTable(db);
      debugPrint("Database upgraded to version 2: $tablePendingFileUploads table created.");
    }
    // Ajouter d'autres blocs if pour les versions futures
    // if (oldVersion < 3) {
    //   // Migrations pour la version 3
    // }
  }
  
  // Méthodes de création de table séparées pour la clarté
  Future<void> _createApiCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableApiCache (
        id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        method TEXT NOT NULL,
        response TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');
  }
  
  Future<void> _createPendingSyncTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tablePendingSync (
        id TEXT PRIMARY KEY,
        endpoint TEXT NOT NULL,
        method TEXT NOT NULL,
        body TEXT,
        timestamp INTEGER NOT NULL,
        synchronized INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }
  
  Future<void> _createNotificationsTable(Database db) async {
    // Table pour les notifications
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        type TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        action_route TEXT,
        additional_data TEXT,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }
  
  Future<void> _createUserDataCacheTable(Database db) async {
    // Table pour le cache des données utilisateur
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_data_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        data_type TEXT NOT NULL,
        data TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        UNIQUE(user_id, data_type)
      )
    ''');
  }
  
  Future<void> _createPendingFileUploadsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tablePendingFileUploads (
        id TEXT PRIMARY KEY,
        endpoint TEXT NOT NULL,
        filePath TEXT NOT NULL,
        fileField TEXT NOT NULL,
        fieldsJson TEXT, -- Store Map<String, String> as JSON string
        timestamp INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }
  
  /// Stocke une réponse API en cache
  Future<void> cacheApiResponse({
    required String url,
    required String method,
    required Map<String, dynamic> response,
    Duration expiration = const Duration(hours: 24),
  }) async {
    final db = await database;
    final String id = _generateCacheId(url, method);
    final int expiryTimestamp = DateTime.now().add(expiration).millisecondsSinceEpoch;
    
    await db.insert(
      tableApiCache,
      {
        'id': id,
        'url': url,
        'method': method,
        'response': jsonEncode(response),
        'timestamp': expiryTimestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    debugPrint('Réponse API mise en cache pour $url');
  }
  
  /// Génère un identifiant unique pour une requête API
  String _generateCacheId(String url, String method) {
    return '$method-${url.hashCode}';
  }
  
  /// Récupère une réponse API du cache
  Future<Map<String, dynamic>?> getCachedApiResponse(String url, String method) async {
    final db = await database;
    final String id = _generateCacheId(url, method);
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Supprimer les entrées expirées
    await db.delete(
      tableApiCache,
      where: 'timestamp < ?',
      whereArgs: [now],
    );
    
    final List<Map<String, dynamic>> maps = await db.query(
      tableApiCache,
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      final cachedData = maps.first;
      final responseString = cachedData['response'] as String;
      debugPrint('Donnée récupérée du cache pour $url');
      return jsonDecode(responseString) as Map<String, dynamic>;
    }
    
    debugPrint('Pas de donnée en cache pour $url');
    return null;
  }
  
  /// Enregistre une opération en attente de synchronisation
  Future<void> savePendingOperation({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
  }) async {
    final db = await database;
    final String id = '$method-$endpoint-${DateTime.now().millisecondsSinceEpoch}';
    
    await db.insert(
      tablePendingSync,
      {
        'id': id,
        'endpoint': endpoint,
        'method': method,
        'body': body != null ? jsonEncode(body) : null,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'synchronized': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    debugPrint('Opération enregistrée pour synchronisation ultérieure: $method $endpoint');
  }
  
  /// Récupère les opérations en attente de synchronisation
  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      tablePendingSync,
      where: 'synchronized = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );
    
    return maps.map((operation) {
      final bodyString = operation['body'] as String?;
      final Map<String, dynamic>? bodyMap = bodyString != null 
          ? jsonDecode(bodyString) as Map<String, dynamic> 
          : null;
      
      return {
        'id': operation['id'],
        'endpoint': operation['endpoint'],
        'method': operation['method'],
        'body': bodyMap,
        'timestamp': operation['timestamp'],
      };
    }).toList();
  }
  
  /// Marque une opération comme synchronisée
  Future<void> markOperationAsSynchronized(String id) async {
    final db = await database;
    
    await db.update(
      tablePendingSync,
      {'synchronized': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    
    debugPrint('Opération $id marquée comme synchronisée');
  }
  
  /// Supprime les opérations déjà synchronisées plus anciennes qu'une durée spécifiée
  Future<void> cleanupSynchronizedOperations({
    Duration retention = const Duration(days: 7),
  }) async {
    final db = await database;
    final cutoffTimestamp = DateTime.now().subtract(retention).millisecondsSinceEpoch;
    
    await db.delete(
      tablePendingSync,
      where: 'synchronized = ? AND timestamp < ?',
      whereArgs: [1, cutoffTimestamp],
    );
    
    debugPrint('Nettoyage des opérations synchronisées terminé');
  }
  
  /// Supprime les données en cache périmées
  Future<void> cleanupExpiredCache() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.delete(
      tableApiCache,
      where: 'timestamp < ?',
      whereArgs: [now],
    );
    
    debugPrint('Nettoyage du cache expiré terminé');
  }
  
  // --- Méthodes pour les téléversements de fichiers en attente ---
  
  /// Enregistre un téléversement de fichier en attente de synchronisation
  Future<void> savePendingFileUpload({
    required String endpoint,
    required String filePath,
    required String fileField,
    Map<String, String>? fields,
  }) async {
    final db = await database;
    final String id = 'file-${DateTime.now().millisecondsSinceEpoch}-${filePath.hashCode}';
    
    await db.insert(
      tablePendingFileUploads,
      {
        'id': id,
        'endpoint': endpoint,
        'filePath': filePath,
        'fileField': fileField,
        'fieldsJson': fields != null ? jsonEncode(fields) : null,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'attempts': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('Téléversement de fichier en attente enregistré pour $endpoint: $filePath');
  }
  
  /// Récupère les téléversements de fichiers en attente de synchronisation
  Future<List<Map<String, dynamic>>> getPendingFileUploads() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tablePendingFileUploads,
      orderBy: 'timestamp ASC',
    );
    
    return maps.map((upload) {
      final fieldsJson = upload['fieldsJson'] as String?;
      final Map<String, String>? fieldsMap = fieldsJson != null
          ? (jsonDecode(fieldsJson) as Map<String, dynamic>).map((key, value) => MapEntry(key, value.toString()))
          : null;
      
      return {
        'id': upload['id'],
        'endpoint': upload['endpoint'],
        'filePath': upload['filePath'],
        'fileField': upload['fileField'],
        'fields': fieldsMap,
        'timestamp': upload['timestamp'],
        'attempts': upload['attempts'],
      };
    }).toList();
  }
  
  /// Met à jour le nombre de tentatives pour un téléversement en attente
  Future<void> updatePendingFileUploadAttempts(String id, int attempts) async {
    final db = await database;
    await db.update(
      tablePendingFileUploads,
      {'attempts': attempts},
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('Nombre de tentatives mis à jour pour le téléversement $id à $attempts');
  }
  
  /// Supprime un téléversement de fichier en attente (par exemple, après succès)
  Future<void> deletePendingFileUpload(String id) async {
    final db = await database;
    await db.delete(
      tablePendingFileUploads,
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('Téléversement de fichier en attente $id supprimé');
  }
}
