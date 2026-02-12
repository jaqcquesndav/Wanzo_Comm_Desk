// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Document _$DocumentFromJson(Map<String, dynamic> json) => Document(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      fileType: json['fileType'] as String?,
      url: json['url'] as String,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      userId: json['userId'] as String?,
      fileSize: (json['fileSize'] as num?)?.toInt(),
      documentType:
          $enumDecodeNullable(_$DocumentTypeEnumMap, json['documentType']),
      entityId: json['relatedToEntityId'] as String?,
      entityType: $enumDecodeNullable(
          _$DocumentRelatedEntityTypeEnumMap, json['relatedToEntityType']),
      description: json['description'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

Map<String, dynamic> _$DocumentToJson(Document instance) => <String, dynamic>{
      'id': instance.id,
      'fileName': instance.fileName,
      if (instance.fileType case final value?) 'fileType': value,
      'url': instance.url,
      'uploadedAt': instance.uploadedAt.toIso8601String(),
      if (instance.userId case final value?) 'userId': value,
      if (instance.fileSize case final value?) 'fileSize': value,
      if (_$DocumentTypeEnumMap[instance.documentType] case final value?)
        'documentType': value,
      if (instance.entityId case final value?) 'relatedToEntityId': value,
      if (_$DocumentRelatedEntityTypeEnumMap[instance.entityType]
          case final value?)
        'relatedToEntityType': value,
      if (instance.description case final value?) 'description': value,
      if (instance.tags case final value?) 'tags': value,
    };

const _$DocumentTypeEnumMap = {
  DocumentType.invoice: 'Invoice',
  DocumentType.contract: 'Contract',
  DocumentType.receipt: 'Receipt',
  DocumentType.report: 'Report',
  DocumentType.other: 'Other',
};

const _$DocumentRelatedEntityTypeEnumMap = {
  DocumentRelatedEntityType.expense: 'Expense',
  DocumentRelatedEntityType.sale: 'Sale',
  DocumentRelatedEntityType.customer: 'Customer',
  DocumentRelatedEntityType.supplier: 'Supplier',
  DocumentRelatedEntityType.companyProfile: 'CompanyProfile',
  DocumentRelatedEntityType.product: 'Product',
  DocumentRelatedEntityType.other: 'Other',
};
