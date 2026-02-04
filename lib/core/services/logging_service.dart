import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service de logging pour la production
class LoggingService {
  static LoggingService? _instance;
  File? _logFile;
  bool _isInitialized = false;

  static LoggingService get instance {
    _instance ??= LoggingService._internal();
    return _instance!;
  }

  LoggingService._internal();

  /// Getter pour vérifier si le service est initialisé
  bool get isInitialized => _isInitialized;

  /// Initialise le service de logging
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (!kIsWeb) {
        final directory = await getApplicationDocumentsDirectory();
        final logDirectory = Directory('${directory.path}/logs');
        
        if (!await logDirectory.exists()) {
          await logDirectory.create(recursive: true);
        }

        final now = DateTime.now();
        final dateString = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        _logFile = File('${logDirectory.path}/wanzo_$dateString.log');
      }
      
      _isInitialized = true;
      info('LoggingService initialized');
    } catch (e) {
      debugPrint('Failed to initialize logging service: $e');
    }
  }

  /// Log de niveau debug
  void debug(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? context}) {
    _log(LogLevel.debug, message, error: error, stackTrace: stackTrace, context: context);
  }

  /// Log de niveau info
  void info(String message, {Map<String, dynamic>? context}) {
    _log(LogLevel.info, message, context: context);
  }

  /// Log de niveau warning
  void warning(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? context}) {
    _log(LogLevel.warning, message, error: error, stackTrace: stackTrace, context: context);
  }

  /// Log de niveau error
  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? context}) {
    _log(LogLevel.error, message, error: error, stackTrace: stackTrace, context: context);
  }

  /// Log de niveau critique
  void critical(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? context}) {
    _log(LogLevel.critical, message, error: error, stackTrace: stackTrace, context: context);
  }

  /// Log spécialisé pour les erreurs API
  void apiError(String endpoint, Object error, {StackTrace? stackTrace, Map<String, dynamic>? requestData}) {
    final context = <String, dynamic>{
      'endpoint': endpoint,
      if (requestData != null) 'requestData': requestData,
    };
    
    _log(LogLevel.error, 'API Error on $endpoint', 
         error: error, stackTrace: stackTrace, context: context);
  }

  /// Log spécialisé pour les tentatives de ré-authentification
  void authAttempt(String action, {bool success = false, String? reason, Map<String, dynamic>? context}) {
    final logContext = <String, dynamic>{
      'action': action,
      'success': success,
      if (reason != null) 'reason': reason,
      if (context != null) ...context,
    };
    
    final level = success ? LogLevel.info : LogLevel.warning;
    _log(level, 'Auth $action: ${success ? 'Success' : 'Failed'}${reason != null ? ' - $reason' : ''}', 
         context: logContext);
  }

  /// Log spécialisé pour les performances
  void performance(String operation, Duration duration, {Map<String, dynamic>? context}) {
    final logContext = <String, dynamic>{
      'operation': operation,
      'duration_ms': duration.inMilliseconds,
      if (context != null) ...context,
    };
    
    final level = duration.inMilliseconds > 5000 ? LogLevel.warning : LogLevel.info;
    _log(level, 'Performance $operation: ${duration.inMilliseconds}ms', context: logContext);
  }

  /// Méthode interne de logging
  void _log(LogLevel level, String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? context}) {
    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase();
    
    // Construire le message de log
    final buffer = StringBuffer();
    buffer.write('[$timestamp] [$levelStr] $message');
    
    if (context != null && context.isNotEmpty) {
      buffer.write(' | Context: ${context.toString()}');
    }
    
    if (error != null) {
      buffer.write(' | Error: $error');
    }
    
    if (stackTrace != null) {
      buffer.write('\nStackTrace: $stackTrace');
    }
    
    final logMessage = buffer.toString();

    // Afficher dans la console en mode debug
    if (kDebugMode) {
      switch (level) {
        case LogLevel.debug:
          debugPrint(logMessage);
          break;
        case LogLevel.info:
          debugPrint(logMessage);
          break;
        case LogLevel.warning:
          debugPrint('⚠️ $logMessage');
          break;
        case LogLevel.error:
        case LogLevel.critical:
          debugPrint('❌ $logMessage');
          break;
      }
    }

    // Utiliser developer.log pour les outils de développement
    developer.log(
      message,
      name: 'Wanzo',
      level: _mapLogLevel(level),
      error: error,
      stackTrace: stackTrace,
    );

    // Écrire dans le fichier de log (seulement en production)
    if (kReleaseMode && _logFile != null) {
      _writeToFile(logMessage);
    }
  }

  /// Écrit le message dans le fichier de log
  void _writeToFile(String message) {
    try {
      _logFile?.writeAsStringSync('$message\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('Failed to write to log file: $e');
    }
  }

  /// Mappe les niveaux de log vers les niveaux de developer.log
  int _mapLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
      case LogLevel.critical:
        return 1200;
    }
  }

  /// Nettoie les anciens fichiers de log
  Future<void> cleanOldLogs({int maxDays = 7}) async {
    if (kIsWeb || _logFile == null) return;

    try {
      final logDirectory = _logFile!.parent;
      final files = await logDirectory.list().toList();
      final cutoffDate = DateTime.now().subtract(Duration(days: maxDays));

      for (final file in files) {
        if (file is File && file.path.endsWith('.log')) {
          final stat = await file.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await file.delete();
            info('Deleted old log file: ${file.path}');
          }
        }
      }
    } catch (e) {
      error('Failed to clean old logs', error: e);
    }
  }

  /// Exporte les logs actuels
  Future<File?> exportLogs() async {
    if (kIsWeb || _logFile == null) return null;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final exportFile = File('${directory.path}/wanzo_logs_export_${DateTime.now().millisecondsSinceEpoch}.log');
      
      final logDirectory = _logFile!.parent;
      final files = await logDirectory.list().toList();
      
      final buffer = StringBuffer();
      buffer.writeln('=== WANZO APP LOGS EXPORT ===');
      buffer.writeln('Export Date: ${DateTime.now().toIso8601String()}');
      buffer.writeln('=====================================\n');

      for (final file in files) {
        if (file is File && file.path.endsWith('.log')) {
          buffer.writeln('--- ${file.path} ---');
          final content = await file.readAsString();
          buffer.writeln(content);
          buffer.writeln();
        }
      }

      await exportFile.writeAsString(buffer.toString());
      info('Logs exported to: ${exportFile.path}');
      return exportFile;
    } catch (e) {
      error('Failed to export logs', error: e);
      return null;
    }
  }
}

/// Niveaux de logging
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// Extension pour faciliter l'utilisation du logging
extension LoggingExtension on Object {
  void logDebug(String message, {Map<String, dynamic>? context}) {
    LoggingService.instance.debug('[$runtimeType] $message', context: context);
  }

  void logInfo(String message, {Map<String, dynamic>? context}) {
    LoggingService.instance.info('[$runtimeType] $message', context: context);
  }

  void logWarning(String message, {Object? error, Map<String, dynamic>? context}) {
    LoggingService.instance.warning('[$runtimeType] $message', error: error, context: context);
  }

  void logError(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? context}) {
    LoggingService.instance.error('[$runtimeType] $message', error: error, stackTrace: stackTrace, context: context);
  }
}
