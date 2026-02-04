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
      entityId: json['entityId'] as String?,
      entityType: json['entityType'] as String?,
      fileSize: (json['fileSize'] as num?)?.toInt(),
    );

Map<String, dynamic> _$DocumentToJson(Document instance) => <String, dynamic>{
      'id': instance.id,
      'fileName': instance.fileName,
      if (instance.fileType case final value?) 'fileType': value,
      'url': instance.url,
      'uploadedAt': instance.uploadedAt.toIso8601String(),
      if (instance.userId case final value?) 'userId': value,
      if (instance.entityId case final value?) 'entityId': value,
      if (instance.entityType case final value?) 'entityType': value,
      if (instance.fileSize case final value?) 'fileSize': value,
    };
