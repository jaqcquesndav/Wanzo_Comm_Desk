import 'dart:convert';
import 'dart:typed_data';
import 'package:equatable/equatable.dart';

/// Types de pièces jointes supportés par ADHA
enum AdhaAttachmentType {
  /// Image (PNG, JPG, WEBP)
  image('image'),

  /// Document PDF
  pdf('pdf'),

  /// Document Word
  document('document'),

  /// Fichier Excel/CSV
  spreadsheet('spreadsheet'),

  /// Fichier texte
  text('text'),

  /// Autre type de fichier
  other('other');

  final String value;
  const AdhaAttachmentType(this.value);

  static AdhaAttachmentType fromString(String value) {
    return AdhaAttachmentType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AdhaAttachmentType.other,
    );
  }

  static AdhaAttachmentType fromMimeType(String mimeType) {
    final mime = mimeType.toLowerCase();
    if (mime.startsWith('image/')) return AdhaAttachmentType.image;
    if (mime.contains('pdf')) return AdhaAttachmentType.pdf;
    if (mime.contains('word') || mime.contains('document')) {
      return AdhaAttachmentType.document;
    }
    if (mime.contains('excel') ||
        mime.contains('spreadsheet') ||
        mime.contains('csv')) {
      return AdhaAttachmentType.spreadsheet;
    }
    if (mime.startsWith('text/')) return AdhaAttachmentType.text;
    return AdhaAttachmentType.other;
  }
}

/// Représente une pièce jointe dans le chat ADHA
///
/// Selon la documentation (v2.5.0):
/// ```json
/// {
///   "name": "facture_fournisseur.pdf",
///   "mimeType": "application/pdf",
///   "size": 125678,
///   "content": "JVBERi0xLjQK..." // Base64
/// }
/// ```
class AdhaAttachment extends Equatable {
  /// Nom du fichier avec extension
  final String name;

  /// Type MIME du fichier (ex: 'application/pdf', 'image/png')
  final String mimeType;

  /// Taille du fichier en octets
  final int size;

  /// Contenu du fichier encodé en base64
  final String content;

  /// Type de pièce jointe (déterminé à partir du mimeType)
  final AdhaAttachmentType type;

  /// Chemin local du fichier (optionnel, pour l'affichage)
  final String? localPath;

  /// Miniature en base64 (optionnel, pour les images)
  final String? thumbnail;

  const AdhaAttachment({
    required this.name,
    required this.mimeType,
    required this.size,
    required this.content,
    required this.type,
    this.localPath,
    this.thumbnail,
  });

  /// Crée une pièce jointe à partir des bytes du fichier
  factory AdhaAttachment.fromBytes({
    required String name,
    required String mimeType,
    required Uint8List bytes,
    String? localPath,
    Uint8List? thumbnailBytes,
  }) {
    return AdhaAttachment(
      name: name,
      mimeType: mimeType,
      size: bytes.length,
      content: base64Encode(bytes),
      type: AdhaAttachmentType.fromMimeType(mimeType),
      localPath: localPath,
      thumbnail: thumbnailBytes != null ? base64Encode(thumbnailBytes) : null,
    );
  }

  /// Crée une pièce jointe à partir de JSON (réponse API)
  factory AdhaAttachment.fromJson(Map<String, dynamic> json) {
    return AdhaAttachment(
      name: json['name'] as String,
      mimeType: json['mimeType'] as String,
      size: json['size'] as int,
      content: json['content'] as String,
      type: AdhaAttachmentType.fromMimeType(json['mimeType'] as String),
      localPath: json['localPath'] as String?,
      thumbnail: json['thumbnail'] as String?,
    );
  }

  /// Convertit en JSON pour l'envoi à l'API
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mimeType': mimeType,
      'size': size,
      'content': content,
    };
  }

  /// Récupère les bytes du contenu
  Uint8List get contentBytes => base64Decode(content);

  /// Récupère les bytes de la miniature
  Uint8List? get thumbnailBytes =>
      thumbnail != null ? base64Decode(thumbnail!) : null;

  /// Vérifie si c'est une image
  bool get isImage => type == AdhaAttachmentType.image;

  /// Vérifie si c'est un document
  bool get isDocument =>
      type == AdhaAttachmentType.pdf ||
      type == AdhaAttachmentType.document ||
      type == AdhaAttachmentType.spreadsheet ||
      type == AdhaAttachmentType.text;

  /// Taille formatée (ex: "1.5 MB", "256 KB")
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Extension du fichier
  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  @override
  List<Object?> get props => [name, mimeType, size, content, type, localPath];
}
