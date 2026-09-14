import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'customer_contact.g.dart';

/// Personne de contact d'un client personne morale (gérant, comptable,
/// responsable achats...). Portée par le client (jsonb côté backend).
@HiveType(typeId: 205)
@JsonSerializable()
class CustomerContact extends Equatable {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String? role;

  @HiveField(2)
  final String? phone;

  @HiveField(3)
  final String? email;

  const CustomerContact({
    required this.name,
    this.role,
    this.phone,
    this.email,
  });

  bool get isEmpty =>
      name.trim().isEmpty &&
      (role ?? '').trim().isEmpty &&
      (phone ?? '').trim().isEmpty &&
      (email ?? '').trim().isEmpty;

  CustomerContact copyWith({String? name, String? role, String? phone, String? email}) =>
      CustomerContact(
        name: name ?? this.name,
        role: role ?? this.role,
        phone: phone ?? this.phone,
        email: email ?? this.email,
      );

  factory CustomerContact.fromJson(Map<String, dynamic> json) => _$CustomerContactFromJson(json);
  Map<String, dynamic> toJson() => _$CustomerContactToJson(this);

  @override
  List<Object?> get props => [name, role, phone, email];
}
