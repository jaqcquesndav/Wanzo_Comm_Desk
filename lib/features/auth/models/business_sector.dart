import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:flutter/material.dart';
import 'package:wanzo/l10n/app_localizations.dart'; // Import AppLocalizations

part 'business_sector.g.dart';

/// Modèle représentant un secteur d'activité pour une entreprise
@JsonSerializable()
@HiveType(typeId: 40) // Added HiveType
class BusinessSector extends Equatable {
  /// Identifiant unique du secteur
  @HiveField(0) // Added HiveField
  final String id;
  
  /// Nom du secteur d'activité
  @HiveField(1) // Added HiveField
  final String name;
  
  /// Description du secteur
  @HiveField(2) // Added HiveField
  final String description;
  
  /// Icône représentant le secteur
  @HiveField(3) // Added HiveField
  final String icon;
  
  /// Constructeur
  const BusinessSector({
    required this.id,
    required this.name,
    this.description = '',
    this.icon = 'business',
  });
  
  @override
  List<Object?> get props => [id, name, description, icon];

  /// Creates a BusinessSector from a JSON object.
  factory BusinessSector.fromJson(Map<String, dynamic> json) => _$BusinessSectorFromJson(json);

  /// Converts this BusinessSector instance to a JSON object.
  Map<String, dynamic> toJson() => _$BusinessSectorToJson(this);
}

/// Liste des secteurs d'activité courants en Afrique
List<BusinessSector> getAfricanBusinessSectors(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return [
    BusinessSector(
      id: 'agriculture',
      name: l10n.sectorAgricultureName,
      description: l10n.sectorAgricultureDescription,
      icon: 'agriculture',
    ),
    BusinessSector(
      id: 'commerce',
      name: l10n.sectorCommerceName,
      description: l10n.sectorCommerceDescription,
      icon: 'store',
    ),
    BusinessSector(
      id: 'services',
      name: l10n.sectorServicesName,
      description: l10n.sectorServicesDescription,
      icon: 'business_center',
    ),
    BusinessSector(
      id: 'technology',
      name: l10n.sectorTechnologyName,
      description: l10n.sectorTechnologyDescription,
      icon: 'computer',
    ),
    BusinessSector(
      id: 'manufacturing',
      name: l10n.sectorManufacturingName,
      description: l10n.sectorManufacturingDescription,
      icon: 'factory',
    ),
    BusinessSector(
      id: 'construction',
      name: l10n.sectorConstructionName,
      description: l10n.sectorConstructionDescription,
      icon: 'construction',
    ),
    BusinessSector(
      id: 'transportation',
      name: l10n.sectorTransportationName,
      description: l10n.sectorTransportationDescription,
      icon: 'local_shipping',
    ),
    BusinessSector(
      id: 'energy',
      name: l10n.sectorEnergyName,
      description: l10n.sectorEnergyDescription,
      icon: 'bolt',
    ),
    BusinessSector(
      id: 'tourism',
      name: l10n.sectorTourismName,
      description: l10n.sectorTourismDescription,
      icon: 'hotel',
    ),
    BusinessSector(
      id: 'education',
      name: l10n.sectorEducationName,
      description: l10n.sectorEducationDescription,
      icon: 'school',
    ),
    BusinessSector(
      id: 'health',
      name: l10n.sectorHealthName,
      description: l10n.sectorHealthDescription,
      icon: 'local_hospital',
    ),
    BusinessSector(
      id: 'finance',
      name: l10n.sectorFinanceName,
      description: l10n.sectorFinanceDescription,
      icon: 'account_balance',
    ),
    BusinessSector(
      id: 'other',
      name: l10n.sectorOtherName,
      description: l10n.sectorOtherDescription,
      icon: 'category',
    ),
  ];
}
