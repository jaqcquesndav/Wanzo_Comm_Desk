// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppUserAdapter extends TypeAdapter<AppUser> {
  @override
  final int typeId = 75;

  @override
  AppUser read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppUser(
      id: fields[0] as String,
      email: fields[1] as String,
      firstName: fields[2] as String,
      lastName: fields[3] as String?,
      phoneNumber: fields[4] as String?,
      role: fields[5] as UserRole,
      isActive: fields[6] as bool,
      profilePictureUrl: fields[7] as String?,
      lastLoginAt: fields[8] as DateTime?,
      companyId: fields[9] as String?,
      businessUnitId: fields[10] as String?,
      businessUnitCode: fields[11] as String?,
      businessUnitType: fields[12] as BusinessUnitType?,
      auth0Id: fields[13] as String?,
      settings: fields[14] as UserSettings?,
      createdAt: fields[15] as DateTime?,
      updatedAt: fields[16] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AppUser obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.firstName)
      ..writeByte(3)
      ..write(obj.lastName)
      ..writeByte(4)
      ..write(obj.phoneNumber)
      ..writeByte(5)
      ..write(obj.role)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.profilePictureUrl)
      ..writeByte(8)
      ..write(obj.lastLoginAt)
      ..writeByte(9)
      ..write(obj.companyId)
      ..writeByte(10)
      ..write(obj.businessUnitId)
      ..writeByte(11)
      ..write(obj.businessUnitCode)
      ..writeByte(12)
      ..write(obj.businessUnitType)
      ..writeByte(13)
      ..write(obj.auth0Id)
      ..writeByte(14)
      ..write(obj.settings)
      ..writeByte(15)
      ..write(obj.createdAt)
      ..writeByte(16)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserSettingsAdapter extends TypeAdapter<UserSettings> {
  @override
  final int typeId = 76;

  @override
  UserSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserSettings(
      theme: fields[0] as String?,
      language: fields[1] as String?,
      notifications: fields[2] as NotificationSettings?,
    );
  }

  @override
  void write(BinaryWriter writer, UserSettings obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.theme)
      ..writeByte(1)
      ..write(obj.language)
      ..writeByte(2)
      ..write(obj.notifications);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NotificationSettingsAdapter extends TypeAdapter<NotificationSettings> {
  @override
  final int typeId = 77;

  @override
  NotificationSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NotificationSettings(
      email: fields[0] as bool,
      push: fields[1] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, NotificationSettings obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.email)
      ..writeByte(1)
      ..write(obj.push);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppUser _$AppUserFromJson(Map<String, dynamic> json) => AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      role: json['role'] == null
          ? UserRole.staff
          : AppUser._roleFromJson(json['role'] as String?),
      isActive: json['isActive'] as bool? ?? true,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      lastLoginAt: json['lastLoginAt'] == null
          ? null
          : DateTime.parse(json['lastLoginAt'] as String),
      companyId: json['companyId'] as String?,
      businessUnitId: json['businessUnitId'] as String?,
      businessUnitCode: json['businessUnitCode'] as String?,
      businessUnitType: AppUser._businessUnitTypeFromJson(
          json['businessUnitType'] as String?),
      auth0Id: json['auth0Id'] as String?,
      settings: json['settings'] == null
          ? null
          : UserSettings.fromJson(json['settings'] as Map<String, dynamic>),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$AppUserToJson(AppUser instance) => <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'firstName': instance.firstName,
      if (instance.lastName case final value?) 'lastName': value,
      if (instance.phoneNumber case final value?) 'phoneNumber': value,
      'role': AppUser._roleToJson(instance.role),
      'isActive': instance.isActive,
      if (instance.profilePictureUrl case final value?)
        'profilePictureUrl': value,
      if (instance.lastLoginAt?.toIso8601String() case final value?)
        'lastLoginAt': value,
      if (instance.companyId case final value?) 'companyId': value,
      if (instance.businessUnitId case final value?) 'businessUnitId': value,
      if (instance.businessUnitCode case final value?)
        'businessUnitCode': value,
      if (AppUser._businessUnitTypeToJson(instance.businessUnitType)
          case final value?)
        'businessUnitType': value,
      if (instance.auth0Id case final value?) 'auth0Id': value,
      if (instance.settings?.toJson() case final value?) 'settings': value,
      if (instance.createdAt?.toIso8601String() case final value?)
        'createdAt': value,
      if (instance.updatedAt?.toIso8601String() case final value?)
        'updatedAt': value,
    };

UserSettings _$UserSettingsFromJson(Map<String, dynamic> json) => UserSettings(
      theme: json['theme'] as String?,
      language: json['language'] as String?,
      notifications: json['notifications'] == null
          ? null
          : NotificationSettings.fromJson(
              json['notifications'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UserSettingsToJson(UserSettings instance) =>
    <String, dynamic>{
      if (instance.theme case final value?) 'theme': value,
      if (instance.language case final value?) 'language': value,
      if (instance.notifications?.toJson() case final value?)
        'notifications': value,
    };

NotificationSettings _$NotificationSettingsFromJson(
        Map<String, dynamic> json) =>
    NotificationSettings(
      email: json['email'] as bool? ?? true,
      push: json['push'] as bool? ?? true,
    );

Map<String, dynamic> _$NotificationSettingsToJson(
        NotificationSettings instance) =>
    <String, dynamic>{
      'email': instance.email,
      'push': instance.push,
    };
