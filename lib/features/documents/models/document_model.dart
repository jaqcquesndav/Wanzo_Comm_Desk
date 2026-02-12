import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'document_model.g.dart';

/// Types de documents supportés
enum DocumentType {
  @JsonValue('Invoice')
  invoice,
  @JsonValue('Contract')
  contract,
  @JsonValue('Receipt')
  receipt,
  @JsonValue('Report')
  report,
  @JsonValue('Other')
  other,
}

/// Types d'entités auxquelles un document peut être lié
enum DocumentRelatedEntityType {
  @JsonValue('Expense')
  expense,
  @JsonValue('Sale')
  sale,
  @JsonValue('Customer')
  customer,
  @JsonValue('Supplier')
  supplier,
  @JsonValue('CompanyProfile')
  companyProfile,
  @JsonValue('Product')
  product,
  @JsonValue('Other')
  other,
}

@JsonSerializable(explicitToJson: true)
class Document extends Equatable {
  final String id;
  final String fileName;
  final String? fileType; // MIME type, e.g., application/pdf, image/jpg
  final String url; // URL Cloudinary to access the document
  final DateTime uploadedAt;
  final String? userId; // User who uploaded
  final int? fileSize; // Size in bytes

  /// Type de document (Invoice, Contract, Receipt, Report, Other)
  @JsonKey(name: 'documentType')
  final DocumentType? documentType;

  /// ID de l'entité liée (expense, sale, customer, etc.)
  @JsonKey(name: 'relatedToEntityId')
  final String? entityId;

  /// Type de l'entité liée
  @JsonKey(name: 'relatedToEntityType')
  final DocumentRelatedEntityType? entityType;

  /// Description optionnelle du document
  final String? description;

  /// Tags pour faciliter la recherche
  final List<String>? tags;

  const Document({
    required this.id,
    required this.fileName,
    this.fileType,
    required this.url,
    required this.uploadedAt,
    this.userId,
    this.fileSize,
    this.documentType,
    this.entityId,
    this.entityType,
    this.description,
    this.tags,
  });

  factory Document.fromJson(Map<String, dynamic> json) =>
      _$DocumentFromJson(json);

  Map<String, dynamic> toJson() => _$DocumentToJson(this);

  Document copyWith({
    String? id,
    String? fileName,
    String? fileType,
    String? url,
    DateTime? uploadedAt,
    String? userId,
    int? fileSize,
    DocumentType? documentType,
    String? entityId,
    DocumentRelatedEntityType? entityType,
    String? description,
    List<String>? tags,
  }) {
    return Document(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      url: url ?? this.url,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      userId: userId ?? this.userId,
      fileSize: fileSize ?? this.fileSize,
      documentType: documentType ?? this.documentType,
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
      description: description ?? this.description,
      tags: tags ?? this.tags,
    );
  }

  @override
  List<Object?> get props => [
    id,
    fileName,
    fileType,
    url,
    uploadedAt,
    userId,
    fileSize,
    documentType,
    entityId,
    entityType,
    description,
    tags,
  ];
}
