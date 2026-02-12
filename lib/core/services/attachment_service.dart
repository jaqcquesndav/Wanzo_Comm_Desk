import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

/// Types de fichiers supportés
enum AttachmentType {
  image, // .jpg, .jpeg, .png, .gif, .webp, .bmp
  pdf, // .pdf
  document, // .doc, .docx, .txt, .rtf, .odt
  spreadsheet, // .xls, .xlsx, .csv, .ods
  audio, // .mp3, .wav, .aac, .m4a, .ogg
  video, // .mp4, .avi, .mov, .mkv, .webm
  unknown, // Autres
}

/// Résultat d'une opération de récupération de fichier
class AttachmentResult {
  final File? file;
  final String? errorMessage;
  final bool isFromCache;
  final bool isFromNetwork;
  final bool isFromLocalPath;

  AttachmentResult({
    this.file,
    this.errorMessage,
    this.isFromCache = false,
    this.isFromNetwork = false,
    this.isFromLocalPath = false,
  });

  bool get isSuccess => file != null;
  bool get hasError => errorMessage != null;
}

/// Service centralisé pour la gestion des pièces jointes
///
/// Gère:
/// - Détection du type de fichier
/// - Téléchargement et cache des fichiers réseau
/// - Fallback vers fichiers locaux en mode offline
/// - Ouverture avec l'application système appropriée
class AttachmentService {
  static final AttachmentService _instance = AttachmentService._internal();
  factory AttachmentService() => _instance;
  AttachmentService._internal();

  final DefaultCacheManager _cacheManager = DefaultCacheManager();

  /// Extensions par type de fichier
  static const Map<AttachmentType, List<String>> _typeExtensions = {
    AttachmentType.image: [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.bmp',
      '.heic',
      '.heif',
    ],
    AttachmentType.pdf: ['.pdf'],
    AttachmentType.document: [
      '.doc',
      '.docx',
      '.txt',
      '.rtf',
      '.odt',
      '.pages',
    ],
    AttachmentType.spreadsheet: ['.xls', '.xlsx', '.csv', '.ods', '.numbers'],
    AttachmentType.audio: [
      '.mp3',
      '.wav',
      '.aac',
      '.m4a',
      '.ogg',
      '.flac',
      '.wma',
    ],
    AttachmentType.video: [
      '.mp4',
      '.avi',
      '.mov',
      '.mkv',
      '.webm',
      '.wmv',
      '.flv',
    ],
  };

  /// Détecte le type de fichier à partir de son chemin ou URL
  AttachmentType getAttachmentType(String source) {
    // Extraire l'extension
    String extension = '';

    // Gérer les URLs Cloudinary avec transformations
    if (source.contains('cloudinary.com')) {
      // Format: .../image/upload/... ou .../raw/upload/...
      if (source.contains('/image/upload/')) {
        return AttachmentType.image;
      }
      if (source.contains('/video/upload/')) {
        return AttachmentType.video;
      }
      if (source.contains('/raw/upload/')) {
        // Pour raw, on doit regarder l'extension
        final uri = Uri.tryParse(source);
        if (uri != null) {
          extension = path.extension(uri.path).toLowerCase();
        }
      }
    }

    // Extraction standard de l'extension
    if (extension.isEmpty) {
      // Enlever les query params si présents
      String cleanSource = source.split('?').first;
      extension = path.extension(cleanSource).toLowerCase();
    }

    // Chercher le type correspondant
    for (final entry in _typeExtensions.entries) {
      if (entry.value.contains(extension)) {
        return entry.key;
      }
    }

    return AttachmentType.unknown;
  }

  /// Vérifie si la source est une URL réseau
  bool isNetworkUrl(String source) {
    return source.startsWith('http://') || source.startsWith('https://');
  }

  /// Récupère un fichier avec stratégie offline-first
  ///
  /// 1. Si url fournie: chercher dans le cache, sinon télécharger
  /// 2. Si échec et localPath fourni: utiliser le fichier local
  /// 3. Si tout échoue: retourner erreur
  Future<AttachmentResult> getFile(String? url, {String? localPath}) async {
    // Essayer l'URL réseau d'abord
    if (url != null && url.isNotEmpty && isNetworkUrl(url)) {
      try {
        // Vérifier le cache
        final fileInfo = await _cacheManager.getFileFromCache(url);
        if (fileInfo != null) {
          return AttachmentResult(file: fileInfo.file, isFromCache: true);
        }

        // Télécharger depuis le réseau
        final file = await _cacheManager.getSingleFile(url);
        return AttachmentResult(file: file, isFromNetwork: true);
      } catch (e) {
        debugPrint('[AttachmentService] Erreur réseau pour $url: $e');
        // Continuer vers le fallback local
      }
    }

    // Fallback vers le fichier local
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (await file.exists()) {
        return AttachmentResult(file: file, isFromLocalPath: true);
      }
    }

    // Tout a échoué
    return AttachmentResult(errorMessage: 'Impossible de récupérer le fichier');
  }

  /// Ouvre un fichier avec l'application système appropriée
  ///
  /// Pour les images: retourne false (géré par le widget avec viewer intégré)
  /// Pour les autres: lance l'app système via url_launcher
  Future<bool> openFile(String source, {String? localPath}) async {
    final type = getAttachmentType(source);

    // Les images sont gérées par le widget
    if (type == AttachmentType.image) {
      return false;
    }

    try {
      // Récupérer le fichier (cache ou local)
      final result = await getFile(
        isNetworkUrl(source) ? source : null,
        localPath: isNetworkUrl(source) ? localPath : source,
      );

      if (!result.isSuccess || result.file == null) {
        debugPrint('[AttachmentService] Fichier non trouvé: $source');
        return false;
      }

      // Ouvrir avec l'application système
      final uri = Uri.file(result.file!.path);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }

      debugPrint('[AttachmentService] Impossible de lancer: $uri');
      return false;
    } catch (e) {
      debugPrint('[AttachmentService] Erreur ouverture: $e');
      return false;
    }
  }

  /// Télécharge un fichier vers le dossier Downloads
  Future<String?> downloadToDownloads(String source) async {
    try {
      // Récupérer le fichier
      final result = await getFile(
        isNetworkUrl(source) ? source : null,
        localPath: isNetworkUrl(source) ? null : source,
      );

      if (!result.isSuccess || result.file == null) {
        debugPrint(
          '[AttachmentService] Fichier non trouvé pour téléchargement: $source',
        );
        return null;
      }

      // Obtenir le dossier Downloads
      Directory? downloadsDir;
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        downloadsDir = await getDownloadsDirectory();
      } else {
        // Mobile fallback
        downloadsDir = await getExternalStorageDirectory();
        downloadsDir ??= await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        debugPrint(
          '[AttachmentService] Impossible de trouver le dossier Downloads',
        );
        return null;
      }

      // Générer le nom du fichier
      String fileName = path.basename(source);
      if (fileName.isEmpty || fileName == '/') {
        fileName = 'download_${DateTime.now().millisecondsSinceEpoch}';
        final ext = _getExtensionFromType(getAttachmentType(source));
        if (ext.isNotEmpty) fileName += ext;
      }

      // Copier le fichier
      final destinationPath = path.join(downloadsDir.path, fileName);
      final destinationFile = await result.file!.copy(destinationPath);

      debugPrint(
        '[AttachmentService] Fichier téléchargé: ${destinationFile.path}',
      );
      return destinationFile.path;
    } catch (e) {
      debugPrint('[AttachmentService] Erreur téléchargement: $e');
      return null;
    }
  }

  /// Obtient l'icône appropriée pour un type de fichier
  IconData getIconForType(AttachmentType type) {
    switch (type) {
      case AttachmentType.image:
        return Icons.image;
      case AttachmentType.pdf:
        return Icons.picture_as_pdf;
      case AttachmentType.document:
        return Icons.description;
      case AttachmentType.spreadsheet:
        return Icons.table_chart;
      case AttachmentType.audio:
        return Icons.audiotrack;
      case AttachmentType.video:
        return Icons.videocam;
      case AttachmentType.unknown:
        return Icons.insert_drive_file;
    }
  }

  /// Obtient la couleur appropriée pour un type de fichier
  Color getColorForType(AttachmentType type) {
    switch (type) {
      case AttachmentType.image:
        return const Color(0xFF4CAF50); // Green
      case AttachmentType.pdf:
        return const Color(0xFFE53935); // Red
      case AttachmentType.document:
        return const Color(0xFF2196F3); // Blue
      case AttachmentType.spreadsheet:
        return const Color(0xFF4CAF50); // Green
      case AttachmentType.audio:
        return const Color(0xFFFF9800); // Orange
      case AttachmentType.video:
        return const Color(0xFF9C27B0); // Purple
      case AttachmentType.unknown:
        return const Color(0xFF607D8B); // Blue Grey
    }
  }

  String _getExtensionFromType(AttachmentType type) {
    switch (type) {
      case AttachmentType.image:
        return '.jpg';
      case AttachmentType.pdf:
        return '.pdf';
      case AttachmentType.document:
        return '.docx';
      case AttachmentType.spreadsheet:
        return '.xlsx';
      case AttachmentType.audio:
        return '.mp3';
      case AttachmentType.video:
        return '.mp4';
      case AttachmentType.unknown:
        return '';
    }
  }
}
