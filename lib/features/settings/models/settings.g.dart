// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SettingsAdapter extends TypeAdapter<Settings> {
  @override
  final int typeId = 26;

  @override
  Settings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Settings(
      companyName: fields[0] as String,
      companyAddress: fields[1] as String,
      companyPhone: fields[2] as String,
      companyEmail: fields[3] as String,
      companyLogo: fields[4] as String,
      dateFormat: fields[6] as String,
      timeFormat: fields[33] as String,
      themeMode: fields[7] as AppThemeMode,
      language: fields[8] as String,
      showTaxes: fields[9] as bool,
      defaultTaxRate: fields[10] as double,
      invoiceNumberFormat: fields[11] as String,
      invoicePrefix: fields[12] as String,
      defaultPaymentTerms: fields[13] as String,
      defaultInvoiceNotes: fields[14] as String,
      taxIdentificationNumber: fields[15] as String,
      defaultProductCategory: fields[16] as String,
      lowStockAlertDays: fields[17] as int,
      backupEnabled: fields[18] as bool,
      backupFrequency: fields[19] as int,
      reportEmail: fields[20] as String,
      rccmNumber: fields[21] as String,
      idNatNumber: fields[22] as String,
      pushNotificationsEnabled: fields[23] as bool,
      inAppNotificationsEnabled: fields[24] as bool,
      emailNotificationsEnabled: fields[25] as bool,
      soundNotificationsEnabled: fields[26] as bool,
      activeCurrency: fields[27] as Currency,
      businessUnitId: fields[28] as String?,
      businessUnitCode: fields[29] as String?,
      businessUnitType: fields[30] as BusinessUnitType,
      businessUnitName: fields[31] as String?,
      isRetailStore: fields[32] as bool,
      socialMediaLinks: (fields[34] as Map?)?.cast<String, String>(),
      maintenanceMode: fields[35] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Settings obj) {
    writer
      ..writeByte(35)
      ..writeByte(0)
      ..write(obj.companyName)
      ..writeByte(1)
      ..write(obj.companyAddress)
      ..writeByte(2)
      ..write(obj.companyPhone)
      ..writeByte(3)
      ..write(obj.companyEmail)
      ..writeByte(4)
      ..write(obj.companyLogo)
      ..writeByte(6)
      ..write(obj.dateFormat)
      ..writeByte(33)
      ..write(obj.timeFormat)
      ..writeByte(7)
      ..write(obj.themeMode)
      ..writeByte(8)
      ..write(obj.language)
      ..writeByte(9)
      ..write(obj.showTaxes)
      ..writeByte(10)
      ..write(obj.defaultTaxRate)
      ..writeByte(11)
      ..write(obj.invoiceNumberFormat)
      ..writeByte(12)
      ..write(obj.invoicePrefix)
      ..writeByte(13)
      ..write(obj.defaultPaymentTerms)
      ..writeByte(14)
      ..write(obj.defaultInvoiceNotes)
      ..writeByte(15)
      ..write(obj.taxIdentificationNumber)
      ..writeByte(16)
      ..write(obj.defaultProductCategory)
      ..writeByte(17)
      ..write(obj.lowStockAlertDays)
      ..writeByte(18)
      ..write(obj.backupEnabled)
      ..writeByte(19)
      ..write(obj.backupFrequency)
      ..writeByte(20)
      ..write(obj.reportEmail)
      ..writeByte(21)
      ..write(obj.rccmNumber)
      ..writeByte(22)
      ..write(obj.idNatNumber)
      ..writeByte(23)
      ..write(obj.pushNotificationsEnabled)
      ..writeByte(24)
      ..write(obj.inAppNotificationsEnabled)
      ..writeByte(25)
      ..write(obj.emailNotificationsEnabled)
      ..writeByte(26)
      ..write(obj.soundNotificationsEnabled)
      ..writeByte(27)
      ..write(obj.activeCurrency)
      ..writeByte(28)
      ..write(obj.businessUnitId)
      ..writeByte(29)
      ..write(obj.businessUnitCode)
      ..writeByte(30)
      ..write(obj.businessUnitType)
      ..writeByte(31)
      ..write(obj.businessUnitName)
      ..writeByte(32)
      ..write(obj.isRetailStore)
      ..writeByte(34)
      ..write(obj.socialMediaLinks)
      ..writeByte(35)
      ..write(obj.maintenanceMode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AppThemeModeAdapter extends TypeAdapter<AppThemeMode> {
  @override
  final int typeId = 27;

  @override
  AppThemeMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AppThemeMode.light;
      case 1:
        return AppThemeMode.dark;
      case 2:
        return AppThemeMode.system;
      default:
        return AppThemeMode.light;
    }
  }

  @override
  void write(BinaryWriter writer, AppThemeMode obj) {
    switch (obj) {
      case AppThemeMode.light:
        writer.writeByte(0);
        break;
      case AppThemeMode.dark:
        writer.writeByte(1);
        break;
      case AppThemeMode.system:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppThemeModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Settings _$SettingsFromJson(Map<String, dynamic> json) => Settings(
      companyName: json['companyName'] as String? ?? '',
      companyAddress: json['companyAddress'] as String? ?? '',
      companyPhone: json['companyPhone'] as String? ?? '',
      companyEmail: json['companyEmail'] as String? ?? '',
      companyLogo: json['companyLogo'] as String? ?? '',
      dateFormat: json['dateFormat'] as String? ?? 'DD/MM/YYYY',
      timeFormat: json['timeFormat'] as String? ?? 'HH:mm',
      themeMode:
          $enumDecodeNullable(_$AppThemeModeEnumMap, json['themeMode']) ??
              AppThemeMode.light,
      language: json['language'] as String? ?? 'fr',
      showTaxes: json['showTaxes'] as bool? ?? true,
      defaultTaxRate: (json['defaultTaxRate'] as num?)?.toDouble() ?? 16.0,
      invoiceNumberFormat:
          json['invoiceNumberFormat'] as String? ?? 'INV-{YEAR}-{SEQ}',
      invoicePrefix: json['invoicePrefix'] as String? ?? 'INV',
      defaultPaymentTerms:
          json['defaultPaymentTerms'] as String? ?? 'Paiement sous 30 jours',
      defaultInvoiceNotes: json['defaultInvoiceNotes'] as String? ??
          'Merci pour votre confiance !',
      taxIdentificationNumber: json['taxIdentificationNumber'] as String? ?? '',
      defaultProductCategory:
          json['defaultProductCategory'] as String? ?? 'Général',
      lowStockAlertDays: (json['lowStockAlertDays'] as num?)?.toInt() ?? 7,
      backupEnabled: json['backupEnabled'] as bool? ?? false,
      backupFrequency: (json['backupFrequency'] as num?)?.toInt() ?? 7,
      reportEmail: json['reportEmail'] as String? ?? '',
      rccmNumber: json['rccmNumber'] as String? ?? '',
      idNatNumber: json['idNatNumber'] as String? ?? '',
      pushNotificationsEnabled:
          json['pushNotificationsEnabled'] as bool? ?? true,
      inAppNotificationsEnabled:
          json['inAppNotificationsEnabled'] as bool? ?? true,
      emailNotificationsEnabled:
          json['emailNotificationsEnabled'] as bool? ?? false,
      soundNotificationsEnabled:
          json['soundNotificationsEnabled'] as bool? ?? true,
      activeCurrency:
          $enumDecodeNullable(_$CurrencyEnumMap, json['activeCurrency']) ??
              Currency.CDF,
      businessUnitId: json['businessUnitId'] as String?,
      businessUnitCode: json['businessUnitCode'] as String?,
      businessUnitType: $enumDecodeNullable(
              _$BusinessUnitTypeEnumMap, json['businessUnitType']) ??
          BusinessUnitType.company,
      businessUnitName: json['businessUnitName'] as String?,
      isRetailStore: json['isRetailStore'] as bool? ?? false,
      socialMediaLinks:
          (json['socialMediaLinks'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      maintenanceMode: json['maintenanceMode'] as bool? ?? false,
    );

Map<String, dynamic> _$SettingsToJson(Settings instance) => <String, dynamic>{
      'companyName': instance.companyName,
      'companyAddress': instance.companyAddress,
      'companyPhone': instance.companyPhone,
      'companyEmail': instance.companyEmail,
      'companyLogo': instance.companyLogo,
      'dateFormat': instance.dateFormat,
      'timeFormat': instance.timeFormat,
      'themeMode': _$AppThemeModeEnumMap[instance.themeMode]!,
      'language': instance.language,
      'showTaxes': instance.showTaxes,
      'defaultTaxRate': instance.defaultTaxRate,
      'invoiceNumberFormat': instance.invoiceNumberFormat,
      'invoicePrefix': instance.invoicePrefix,
      'defaultPaymentTerms': instance.defaultPaymentTerms,
      'defaultInvoiceNotes': instance.defaultInvoiceNotes,
      'taxIdentificationNumber': instance.taxIdentificationNumber,
      'defaultProductCategory': instance.defaultProductCategory,
      'lowStockAlertDays': instance.lowStockAlertDays,
      'backupEnabled': instance.backupEnabled,
      'backupFrequency': instance.backupFrequency,
      'reportEmail': instance.reportEmail,
      'rccmNumber': instance.rccmNumber,
      'idNatNumber': instance.idNatNumber,
      'pushNotificationsEnabled': instance.pushNotificationsEnabled,
      'inAppNotificationsEnabled': instance.inAppNotificationsEnabled,
      'emailNotificationsEnabled': instance.emailNotificationsEnabled,
      'soundNotificationsEnabled': instance.soundNotificationsEnabled,
      'activeCurrency': _$CurrencyEnumMap[instance.activeCurrency]!,
      if (instance.businessUnitId case final value?) 'businessUnitId': value,
      if (instance.businessUnitCode case final value?)
        'businessUnitCode': value,
      'businessUnitType': _$BusinessUnitTypeEnumMap[instance.businessUnitType]!,
      if (instance.businessUnitName case final value?)
        'businessUnitName': value,
      'isRetailStore': instance.isRetailStore,
      if (instance.socialMediaLinks case final value?)
        'socialMediaLinks': value,
      'maintenanceMode': instance.maintenanceMode,
    };

const _$AppThemeModeEnumMap = {
  AppThemeMode.light: 'light',
  AppThemeMode.dark: 'dark',
  AppThemeMode.system: 'system',
};

const _$CurrencyEnumMap = {
  Currency.CDF: 'CDF',
  Currency.USD: 'USD',
  Currency.FCFA: 'FCFA',
};

const _$BusinessUnitTypeEnumMap = {
  BusinessUnitType.company: 'company',
  BusinessUnitType.branch: 'branch',
  BusinessUnitType.pos: 'pos',
};
