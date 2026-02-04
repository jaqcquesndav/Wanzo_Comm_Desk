import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'document_model.g.dart';

@JsonSerializable(explicitToJson: true)
class Document extends Equatable {
  final String id;
  final String fileName;
  final String? fileType; // e.g., pdf, jpg, png
  final String url; // URL to access the document
  final DateTime uploadedAt;
  final String? userId; // User who uploaded
  final String? entityId; // ID of the entity this document is related to (e.g., invoice, expense)
  final String? entityType; // Type of the entity (e.g., 'invoice', 'expense')
  final int? fileSize; // Size in bytes

  const Document({
    required this.id,
    required this.fileName,
    this.fileType,
    required this.url,
    required this.uploadedAt,
    this.userId,
    this.entityId,
    this.entityType,
    this.fileSize,
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
    String? entityId,
    String? entityType,
    int? fileSize,
  }) {
    return Document(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      url: url ?? this.url,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      userId: userId ?? this.userId,
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
      fileSize: fileSize ?? this.fileSize,
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
        entityId,
        entityType,
        fileSize,
      ];
}
