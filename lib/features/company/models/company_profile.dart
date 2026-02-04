import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'company_profile.g.dart';

@JsonSerializable(explicitToJson: true)
class CompanyProfile extends Equatable {
  final String id;
  final String name;
  final String? registrationNumber;
  final String? taxId;
  final String? address;
  final String? city;
  final String? country;
  final String? phoneNumber;
  final String? email;
  final String? website;
  final String? logoUrl;
  final String? industry;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CompanyProfile({
    required this.id,
    required this.name,
    this.registrationNumber,
    this.taxId,
    this.address,
    this.city,
    this.country,
    this.phoneNumber,
    this.email,
    this.website,
    this.logoUrl,
    this.industry,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompanyProfile.fromJson(Map<String, dynamic> json) =>
      _$CompanyProfileFromJson(json);

  Map<String, dynamic> toJson() => _$CompanyProfileToJson(this);

  CompanyProfile copyWith({
    String? id,
    String? name,
    String? registrationNumber,
    String? taxId,
    String? address,
    String? city,
    String? country,
    String? phoneNumber,
    String? email,
    String? website,
    String? logoUrl,
    String? industry,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      taxId: taxId ?? this.taxId,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      website: website ?? this.website,
      logoUrl: logoUrl ?? this.logoUrl,
      industry: industry ?? this.industry,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        registrationNumber,
        taxId,
        address,
        city,
        country,
        phoneNumber,
        email,
        website,
        logoUrl,
        industry,
        createdAt,
        updatedAt,
      ];
}
