// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\core\utils\logger.dart

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Niveau de log
enum LogLevel {
  /// Niveau de debug
  debug,
  
  /// Niveau d'information
  info,
  
  /// Niveau d'avertissement
  warning,
  
  /// Niveau d'erreur
  error,
}

/// Classe utilitaire pour la journalisation
class Logger {
  static LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  static bool _enableColoredLogs = true;
  
  /// Définir le niveau minimal de log
  static void setMinLevel(LogLevel level) {
    _minLevel = level;
  }
  
  /// Activer ou désactiver la coloration des logs
  static void setColoredLogs(bool enabled) {
    _enableColoredLogs = enabled;
  }
  
  /// Log de debug
  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _log(message, LogLevel.debug, error, stackTrace);
  }
  
  /// Log d'information
  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    _log(message, LogLevel.info, error, stackTrace);
  }
  
  /// Log d'avertissement
  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _log(message, LogLevel.warning, error, stackTrace);
  }
  
  /// Log d'erreur
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log(message, LogLevel.error, error, stackTrace);
  }
  
  /// Méthode interne pour la journalisation
  static void _log(
    String message, 
    LogLevel level, 
    Object? error, 
    StackTrace? stackTrace,
  ) {
    if (level.index < _minLevel.index) {
      return;
    }
    
    String prefix;
    String? messageColor;
    
    switch (level) {
      case LogLevel.debug:
        prefix = '[DEBUG]';
        messageColor = '\x1B[37m'; // Blanc
        break;
      case LogLevel.info:
        prefix = '[INFO]';
        messageColor = '\x1B[32m'; // Vert
        break;
      case LogLevel.warning:
        prefix = '[WARNING]';
        messageColor = '\x1B[33m'; // Jaune
        break;
      case LogLevel.error:
        prefix = '[ERROR]';
        messageColor = '\x1B[31m'; // Rouge
        break;
    }
    
    final timestamp = DateTime.now().toIso8601String();
    String fullMessage = '$prefix [$timestamp] $message';
    
    if (error != null) {
      fullMessage += '\nError: $error';
    }
    
    if (_enableColoredLogs) {
      fullMessage = '$messageColor$fullMessage\x1B[0m'; // Reset color
    }
    
    // Utiliser le log de la console en mode debug
    if (kDebugMode) {
      debugPrint(fullMessage);
      
      if (stackTrace != null) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    
    // Utiliser le log de développement pour la production
    developer.log(
      message,
      name: prefix.replaceAll('[', '').replaceAll(']', ''),
      error: error,
      stackTrace: stackTrace,
      time: DateTime.now(),
    );
  }
}
