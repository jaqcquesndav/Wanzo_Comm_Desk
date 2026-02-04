// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\settings\models\settings_adapter.dart
import 'package:hive/hive.dart';
import 'settings.dart';
import '../../../core/enums/currency_enum.dart'; // Import Currency

/// Adaptateur Hive pour la classe Settings
class SettingsAdapter extends TypeAdapter<Settings> {
  @override
  final int typeId = 26; // Corrected typeId to match Settings model

  @override
  Settings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    
    // Read activeCurrency (field 5)
    Currency activeCurrencyValue;
    if (fields[5] is String) {
      activeCurrencyValue = Currency.values.firstWhere((e) => e.name == fields[5], orElse: () => Currency.CDF);
    } else if (fields[5] is int) { // Assuming older versions might store int index
      activeCurrencyValue = Currency.values.elementAtOrNull(fields[5] as int) ?? Currency.CDF;
    }
    else {
      activeCurrencyValue = fields[5] as Currency? ?? Currency.CDF;
    }

    return Settings(
      companyName: fields[0] as String? ?? '',
      companyAddress: fields[1] as String? ?? '',
      companyPhone: fields[2] as String? ?? '',
      companyEmail: fields[3] as String? ?? '',
      companyLogo: fields[4] as String? ?? '',
      activeCurrency: activeCurrencyValue, // Use the deserialized value
      dateFormat: fields[6] as String? ?? 'dd/MM/yyyy',
      themeMode: fields[7] is int ? AppThemeMode.values[fields[7] as int] : fields[7] as AppThemeMode? ?? AppThemeMode.system, // Handle int for enum
      language: fields[8] as String? ?? 'fr',
      showTaxes: fields[9] as bool? ?? false,
      defaultTaxRate: fields[10] as double? ?? 0.0,
      invoiceNumberFormat: fields[11] as String? ?? 'INV-{YYYY}-{SEQ}', // Corrected default format
      invoicePrefix: fields[12] as String? ?? 'INV',
      defaultPaymentTerms: fields[13] as String? ?? 'Net 30',
      defaultInvoiceNotes: fields[14] as String? ?? '',
      taxIdentificationNumber: fields[15] as String? ?? '',
      defaultProductCategory: fields[16] as String? ?? '',
      lowStockAlertDays: fields[17] as int? ?? 7,
      backupEnabled: fields[18] as bool? ?? false,
      backupFrequency: fields[19] as int? ?? 24, 
      reportEmail: fields[20] as String? ?? '',
      rccmNumber: fields[21] as String? ?? '',
      idNatNumber: fields[22] as String? ?? '',
      pushNotificationsEnabled: fields[23] as bool? ?? true,
      inAppNotificationsEnabled: fields[24] as bool? ?? true,
      emailNotificationsEnabled: fields[25] as bool? ?? true,
      // Assuming soundNotificationsEnabled was field 26 and activeCurrency was 5
      // The original adapter had 27 fields, but Settings model has 26 fields if activeCurrency is 5
      // Let's assume soundNotificationsEnabled is field 26
      soundNotificationsEnabled: numOfFields > 26 && fields.containsKey(26) ? fields[26] as bool? ?? true : true,
      // Add other fields if any were missed, ensure field indices match write method
    );
  }

  @override
  void write(BinaryWriter writer, Settings obj) {
    writer.writeByte(27); // Number of fields being written
    writer.writeByte(0);
    writer.writeString(obj.companyName);
    writer.writeByte(1);
    writer.writeString(obj.companyAddress);
    writer.writeByte(2);
    writer.writeString(obj.companyPhone);
    writer.writeByte(3);
    writer.writeString(obj.companyEmail);
    writer.writeByte(4);
    writer.writeString(obj.companyLogo);
    writer.writeByte(5);
    writer.write(obj.activeCurrency); // Store Currency enum directly (Hive will use its adapter)
    writer.writeByte(6);
    writer.writeString(obj.dateFormat);
    writer.writeByte(7);
    writer.write(obj.themeMode); 
    writer.writeByte(8);
    writer.writeString(obj.language);
    writer.writeByte(9);
    writer.writeBool(obj.showTaxes);
    writer.writeByte(10);
    writer.writeDouble(obj.defaultTaxRate);
    writer.writeByte(11);
    writer.writeString(obj.invoiceNumberFormat);
    writer.writeByte(12);
    writer.writeString(obj.invoicePrefix);
    writer.writeByte(13);
    writer.writeString(obj.defaultPaymentTerms);
    writer.writeByte(14);
    writer.writeString(obj.defaultInvoiceNotes);
    writer.writeByte(15);
    writer.writeString(obj.taxIdentificationNumber);
    writer.writeByte(16);
    writer.writeString(obj.defaultProductCategory);
    writer.writeByte(17);
    writer.writeInt(obj.lowStockAlertDays);
    writer.writeByte(18);
    writer.writeBool(obj.backupEnabled);
    writer.writeByte(19);
    writer.writeInt(obj.backupFrequency);
    writer.writeByte(20);
    writer.writeString(obj.reportEmail);
    writer.writeByte(21);
    writer.writeString(obj.rccmNumber);
    writer.writeByte(22);
    writer.writeString(obj.idNatNumber);
    writer.writeByte(23);
    writer.writeBool(obj.pushNotificationsEnabled);
    writer.writeByte(24);
    writer.writeBool(obj.inAppNotificationsEnabled);
    writer.writeByte(25);
    writer.writeBool(obj.emailNotificationsEnabled);
    writer.writeByte(26); // Added for soundNotificationsEnabled
    writer.writeBool(obj.soundNotificationsEnabled);
  }
}

// Make sure AppThemeMode also has a TypeAdapter registered if it's an enum
// For example:
// enum AppThemeMode { system, light, dark }
// class AppThemeModeAdapter extends TypeAdapter<AppThemeMode> {
//   @override
//   final typeId = 25; // Ensure this is unique

//   @override
//   AppThemeMode read(BinaryReader reader) {
//     return AppThemeMode.values[reader.readByte()];
//   }

//   @override
//   void write(BinaryWriter writer, AppThemeMode obj) {
//     writer.writeByte(obj.index);
//   }
// }
