import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'product_attribute.g.dart';

/// Représente un attribut personnalisé d'un produit
/// Ex: { "name": "Couleur", "value": "Noir" }
@HiveType(typeId: 28)
@JsonSerializable()
class ProductAttribute extends Equatable {
  /// Nom de l'attribut (ex: "Couleur", "Taille", "RAM")
  @HiveField(0)
  final String name;

  /// Valeur de l'attribut (ex: "Noir", "XL", "8GB")
  @HiveField(1)
  final String value;

  const ProductAttribute({required this.name, required this.value});

  factory ProductAttribute.fromJson(Map<String, dynamic> json) =>
      _$ProductAttributeFromJson(json);

  Map<String, dynamic> toJson() => _$ProductAttributeToJson(this);

  @override
  List<Object?> get props => [name, value];

  ProductAttribute copyWith({String? name, String? value}) {
    return ProductAttribute(
      name: name ?? this.name,
      value: value ?? this.value,
    );
  }
}
