// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 22;

  @override
  Product read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Product(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      barcode: fields[3] as String,
      category: fields[4] as ProductCategory,
      costPriceInCdf: fields[5] as double,
      sellingPriceInCdf: fields[6] as double,
      stockQuantity: fields[7] as double,
      unit: fields[8] as ProductUnit,
      alertThreshold: fields[9] as double,
      createdAt: fields[10] as DateTime,
      updatedAt: fields[11] as DateTime,
      imagePath: fields[12] as String?,
      imageUrl: fields[21] as String?,
      inputCurrencyCode: fields[13] as String,
      inputExchangeRate: fields[14] as double,
      costPriceInInputCurrency: fields[15] as double,
      sellingPriceInInputCurrency: fields[16] as double,
      supplierIds: (fields[17] as List?)?.cast<String>(),
      tags: (fields[18] as List?)?.cast<String>(),
      taxRate: fields[19] as double?,
      sku: fields[20] as String?,
      companyId: fields[22] as String?,
      businessUnitId: fields[23] as String?,
      businessUnitCode: fields[24] as String?,
      businessUnitType: fields[25] as BusinessUnitType?,
      syncStatus: fields[26] as String,
      localId: fields[27] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer
      ..writeByte(28)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.barcode)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.costPriceInCdf)
      ..writeByte(6)
      ..write(obj.sellingPriceInCdf)
      ..writeByte(7)
      ..write(obj.stockQuantity)
      ..writeByte(8)
      ..write(obj.unit)
      ..writeByte(9)
      ..write(obj.alertThreshold)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(12)
      ..write(obj.imagePath)
      ..writeByte(21)
      ..write(obj.imageUrl)
      ..writeByte(13)
      ..write(obj.inputCurrencyCode)
      ..writeByte(14)
      ..write(obj.inputExchangeRate)
      ..writeByte(15)
      ..write(obj.costPriceInInputCurrency)
      ..writeByte(16)
      ..write(obj.sellingPriceInInputCurrency)
      ..writeByte(17)
      ..write(obj.supplierIds)
      ..writeByte(18)
      ..write(obj.tags)
      ..writeByte(19)
      ..write(obj.taxRate)
      ..writeByte(20)
      ..write(obj.sku)
      ..writeByte(22)
      ..write(obj.companyId)
      ..writeByte(23)
      ..write(obj.businessUnitId)
      ..writeByte(24)
      ..write(obj.businessUnitCode)
      ..writeByte(25)
      ..write(obj.businessUnitType)
      ..writeByte(26)
      ..write(obj.syncStatus)
      ..writeByte(27)
      ..write(obj.localId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProductCategoryAdapter extends TypeAdapter<ProductCategory> {
  @override
  final int typeId = 20;

  @override
  ProductCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ProductCategory.food;
      case 1:
        return ProductCategory.drink;
      case 2:
        return ProductCategory.electronics;
      case 3:
        return ProductCategory.clothing;
      case 4:
        return ProductCategory.household;
      case 5:
        return ProductCategory.hygiene;
      case 6:
        return ProductCategory.office;
      case 7:
        return ProductCategory.cosmetics;
      case 8:
        return ProductCategory.pharmaceuticals;
      case 9:
        return ProductCategory.bakery;
      case 10:
        return ProductCategory.dairy;
      case 11:
        return ProductCategory.meat;
      case 12:
        return ProductCategory.vegetables;
      case 13:
        return ProductCategory.fruits;
      case 14:
        return ProductCategory.other;
      default:
        return ProductCategory.food;
    }
  }

  @override
  void write(BinaryWriter writer, ProductCategory obj) {
    switch (obj) {
      case ProductCategory.food:
        writer.writeByte(0);
        break;
      case ProductCategory.drink:
        writer.writeByte(1);
        break;
      case ProductCategory.electronics:
        writer.writeByte(2);
        break;
      case ProductCategory.clothing:
        writer.writeByte(3);
        break;
      case ProductCategory.household:
        writer.writeByte(4);
        break;
      case ProductCategory.hygiene:
        writer.writeByte(5);
        break;
      case ProductCategory.office:
        writer.writeByte(6);
        break;
      case ProductCategory.cosmetics:
        writer.writeByte(7);
        break;
      case ProductCategory.pharmaceuticals:
        writer.writeByte(8);
        break;
      case ProductCategory.bakery:
        writer.writeByte(9);
        break;
      case ProductCategory.dairy:
        writer.writeByte(10);
        break;
      case ProductCategory.meat:
        writer.writeByte(11);
        break;
      case ProductCategory.vegetables:
        writer.writeByte(12);
        break;
      case ProductCategory.fruits:
        writer.writeByte(13);
        break;
      case ProductCategory.other:
        writer.writeByte(14);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProductUnitAdapter extends TypeAdapter<ProductUnit> {
  @override
  final int typeId = 21;

  @override
  ProductUnit read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ProductUnit.piece;
      case 1:
        return ProductUnit.kg;
      case 2:
        return ProductUnit.g;
      case 3:
        return ProductUnit.l;
      case 4:
        return ProductUnit.ml;
      case 5:
        return ProductUnit.package;
      case 6:
        return ProductUnit.box;
      case 7:
        return ProductUnit.other;
      default:
        return ProductUnit.piece;
    }
  }

  @override
  void write(BinaryWriter writer, ProductUnit obj) {
    switch (obj) {
      case ProductUnit.piece:
        writer.writeByte(0);
        break;
      case ProductUnit.kg:
        writer.writeByte(1);
        break;
      case ProductUnit.g:
        writer.writeByte(2);
        break;
      case ProductUnit.l:
        writer.writeByte(3);
        break;
      case ProductUnit.ml:
        writer.writeByte(4);
        break;
      case ProductUnit.package:
        writer.writeByte(5);
        break;
      case ProductUnit.box:
        writer.writeByte(6);
        break;
      case ProductUnit.other:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductUnitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      barcode: json['barcode'] as String? ?? '',
      category: $enumDecode(_$ProductCategoryEnumMap, json['category']),
      costPriceInCdf: (json['costPriceInCdf'] as num).toDouble(),
      sellingPriceInCdf: (json['sellingPriceInCdf'] as num).toDouble(),
      stockQuantity: (json['stockQuantity'] as num).toDouble(),
      unit: $enumDecode(_$ProductUnitEnumMap, json['unit']),
      alertThreshold: (json['alertThreshold'] as num?)?.toDouble() ?? 5,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      imagePath: json['imagePath'] as String?,
      imageUrl: json['imageUrl'] as String?,
      inputCurrencyCode: json['inputCurrencyCode'] as String,
      inputExchangeRate: (json['inputExchangeRate'] as num).toDouble(),
      costPriceInInputCurrency:
          (json['costPriceInInputCurrency'] as num).toDouble(),
      sellingPriceInInputCurrency:
          (json['sellingPriceInInputCurrency'] as num).toDouble(),
      supplierIds: (json['supplierIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      taxRate: (json['taxRate'] as num?)?.toDouble(),
      sku: json['sku'] as String?,
      companyId: json['companyId'] as String?,
      businessUnitId: json['businessUnitId'] as String?,
      businessUnitCode: json['businessUnitCode'] as String?,
      businessUnitType: Product._businessUnitTypeFromJson(
          json['businessUnitType'] as String?),
      syncStatus: json['syncStatus'] as String? ?? 'pending',
      localId: json['localId'] as String?,
    );

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'barcode': instance.barcode,
      'category': _$ProductCategoryEnumMap[instance.category]!,
      'costPriceInCdf': instance.costPriceInCdf,
      'sellingPriceInCdf': instance.sellingPriceInCdf,
      'stockQuantity': instance.stockQuantity,
      'unit': _$ProductUnitEnumMap[instance.unit]!,
      'alertThreshold': instance.alertThreshold,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      if (instance.imagePath case final value?) 'imagePath': value,
      if (instance.imageUrl case final value?) 'imageUrl': value,
      'inputCurrencyCode': instance.inputCurrencyCode,
      'inputExchangeRate': instance.inputExchangeRate,
      'costPriceInInputCurrency': instance.costPriceInInputCurrency,
      'sellingPriceInInputCurrency': instance.sellingPriceInInputCurrency,
      if (instance.supplierIds case final value?) 'supplierIds': value,
      if (instance.tags case final value?) 'tags': value,
      if (instance.taxRate case final value?) 'taxRate': value,
      if (instance.sku case final value?) 'sku': value,
      if (instance.companyId case final value?) 'companyId': value,
      if (instance.businessUnitId case final value?) 'businessUnitId': value,
      if (instance.businessUnitCode case final value?)
        'businessUnitCode': value,
      if (Product._businessUnitTypeToJson(instance.businessUnitType)
          case final value?)
        'businessUnitType': value,
      'syncStatus': instance.syncStatus,
      if (instance.localId case final value?) 'localId': value,
    };

const _$ProductCategoryEnumMap = {
  ProductCategory.food: 'food',
  ProductCategory.drink: 'drink',
  ProductCategory.electronics: 'electronics',
  ProductCategory.clothing: 'clothing',
  ProductCategory.household: 'household',
  ProductCategory.hygiene: 'hygiene',
  ProductCategory.office: 'office',
  ProductCategory.cosmetics: 'cosmetics',
  ProductCategory.pharmaceuticals: 'pharmaceuticals',
  ProductCategory.bakery: 'bakery',
  ProductCategory.dairy: 'dairy',
  ProductCategory.meat: 'meat',
  ProductCategory.vegetables: 'vegetables',
  ProductCategory.fruits: 'fruits',
  ProductCategory.other: 'other',
};

const _$ProductUnitEnumMap = {
  ProductUnit.piece: 'piece',
  ProductUnit.kg: 'kg',
  ProductUnit.g: 'g',
  ProductUnit.l: 'l',
  ProductUnit.ml: 'ml',
  ProductUnit.package: 'package',
  ProductUnit.box: 'box',
  ProductUnit.other: 'other',
};
