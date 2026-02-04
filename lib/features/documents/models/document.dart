import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';

part 'document.g.dart';

/// Type de document
enum DocumentType {
  invoice, // Facture
  receipt, // Reçu
  quote, // Devis
  contract, // Contrat
  report, // Rapport
  other, // Autre
}

/// Modèle représentant un document
@HiveType(typeId: 31)
class Document extends Equatable {
  /// Identifiant unique du document
  @HiveField(0)
  final String id;

  /// Titre du document
  @HiveField(1)
  final String title;

  /// Type de document
  @HiveField(2)
  final DocumentType type;

  /// Date de création
  @HiveField(3)
  final DateTime creationDate;

  /// Chemin du fichier sur le disque
  @HiveField(4)
  final String filePath;

  /// Identifiant de l'entité associée (ex: ID de vente, ID de client, etc.)
  @HiveField(5)
  final String? relatedEntityId;

  /// Type de l'entité associée (ex: "sale", "customer", etc.)
  @HiveField(6)
  final String? relatedEntityType;

  /// Description du document
  @HiveField(7)
  final String? description;

  /// Taille du document en octets
  @HiveField(8)
  final int? fileSize;

  // ============= CHAMPS MANQUANTS (API DOCUMENTATION) =============

  /// Type MIME du fichier (ex: application/pdf, image/png)
  @HiveField(9)
  final String? fileType;

  /// ID de l'utilisateur qui a créé le document
  @HiveField(10)
  final String? userId;

  /// Nom original du fichier
  @HiveField(11)
  final String? fileName;

  /// URL du fichier sur le serveur (si uploadé)
  @HiveField(12)
  final String? fileUrl;

  /// Date de mise à jour
  @HiveField(13)
  final DateTime? updatedAt;

  // ============= BUSINESS UNIT FIELDS =============

  /// ID de l'entreprise associée
  @HiveField(14)
  final String? companyId;

  /// ID de l'unité commerciale
  @HiveField(15)
  final String? businessUnitId;

  /// Code de l'unité (ex: POS-001)
  @HiveField(16)
  final String? businessUnitCode;

  /// Type d'unité: company, branch ou pos
  @HiveField(17)
  final BusinessUnitType? businessUnitType;

  /// Constructeur
  const Document({
    required this.id,
    required this.title,
    required this.type,
    required this.creationDate,
    required this.filePath,
    this.relatedEntityId,
    this.relatedEntityType,
    this.description,
    this.fileSize,
    // Nouveaux champs
    this.fileType,
    this.userId,
    this.fileName,
    this.fileUrl,
    this.updatedAt,
    // Business Unit fields
    this.companyId,
    this.businessUnitId,
    this.businessUnitCode,
    this.businessUnitType,
  });

  /// Crée une copie de ce document avec les champs donnés remplacés par les nouvelles valeurs
  Document copyWith({
    String? id,
    String? title,
    DocumentType? type,
    DateTime? creationDate,
    String? filePath,
    String? relatedEntityId,
    String? relatedEntityType,
    String? description,
    int? fileSize,
    String? fileType,
    String? userId,
    String? fileName,
    String? fileUrl,
    DateTime? updatedAt,
    String? companyId,
    String? businessUnitId,
    String? businessUnitCode,
    BusinessUnitType? businessUnitType,
  }) {
    return Document(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      creationDate: creationDate ?? this.creationDate,
      filePath: filePath ?? this.filePath,
      relatedEntityId: relatedEntityId ?? this.relatedEntityId,
      relatedEntityType: relatedEntityType ?? this.relatedEntityType,
      description: description ?? this.description,
      fileSize: fileSize ?? this.fileSize,
      fileType: fileType ?? this.fileType,
      userId: userId ?? this.userId,
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      companyId: companyId ?? this.companyId,
      businessUnitId: businessUnitId ?? this.businessUnitId,
      businessUnitCode: businessUnitCode ?? this.businessUnitCode,
      businessUnitType: businessUnitType ?? this.businessUnitType,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    type,
    creationDate,
    filePath,
    relatedEntityId,
    relatedEntityType,
    description,
    fileSize,
    fileType,
    userId,
    fileName,
    fileUrl,
    updatedAt,
    companyId,
    businessUnitId,
    businessUnitCode,
    businessUnitType,
  ];
}
