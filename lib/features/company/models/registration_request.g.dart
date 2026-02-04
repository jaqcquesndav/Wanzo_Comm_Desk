// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'registration_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegistrationRequest _$RegistrationRequestFromJson(Map<String, dynamic> json) =>
    RegistrationRequest(
      ownerName: json['ownerName'] as String,
      email: json['email'] as String,
      password: json['password'] as String,
      phoneNumber: json['phoneNumber'] as String,
      companyName: json['companyName'] as String,
      rccmNumber: json['rccmNumber'] as String,
      location: json['location'] as String,
      sector: BusinessSector.fromJson(json['sector'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$RegistrationRequestToJson(
        RegistrationRequest instance) =>
    <String, dynamic>{
      'ownerName': instance.ownerName,
      'email': instance.email,
      'password': instance.password,
      'phoneNumber': instance.phoneNumber,
      'companyName': instance.companyName,
      'rccmNumber': instance.rccmNumber,
      'location': instance.location,
      'sector': instance.sector.toJson(),
    };
