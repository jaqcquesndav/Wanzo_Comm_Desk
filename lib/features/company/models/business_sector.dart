import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'business_sector.g.dart';

/// Modèle pour les secteurs d'activité en Afrique
@HiveType(typeId: 12)
@JsonSerializable()
class BusinessSector extends Equatable {
  /// Identifiant unique du secteur
  @HiveField(0)
  final String id;
  
  /// Nom du secteur
  @HiveField(1)
  final String name;
  
  /// Description du secteur
  @HiveField(2)
  final String description;
  
  /// Constructeur
  const BusinessSector({
    required this.id,
    required this.name,
    this.description = '',
  });
  
  factory BusinessSector.fromJson(Map<String, dynamic> json) => _$BusinessSectorFromJson(json);
  Map<String, dynamic> toJson() => _$BusinessSectorToJson(this);

  @override
  List<Object?> get props => [id, name, description];
}

/// Liste des secteurs d'activité courants en Afrique
final List<BusinessSector> africanBusinessSectors = [
  const BusinessSector(
    id: 'agriculture',
    name: 'Agriculture et agroalimentaire',
    description: 'Production agricole, transformation alimentaire, élevage',
  ),
  const BusinessSector(
    id: 'mining',
    name: 'Mines et ressources naturelles',
    description: 'Extraction minière, exploitation des ressources naturelles',
  ),
  const BusinessSector(
    id: 'energy',
    name: 'Énergie',
    description: 'Production et distribution d\'électricité, énergies renouvelables',
  ),
  const BusinessSector(
    id: 'construction',
    name: 'Construction et immobilier',
    description: 'BTP, promotion immobilière, matériaux de construction',
  ),
  const BusinessSector(
    id: 'trade',
    name: 'Commerce et distribution',
    description: 'Commerce de gros et détail, import-export',
  ),
  const BusinessSector(
    id: 'transport',
    name: 'Transport et logistique',
    description: 'Transport de marchandises et passagers, logistique, entreposage',
  ),
  const BusinessSector(
    id: 'telecom',
    name: 'Télécommunications',
    description: 'Opérateurs téléphoniques, fournisseurs d\'accès internet',
  ),
  const BusinessSector(
    id: 'finance',
    name: 'Services financiers',
    description: 'Banques, assurances, microfinance, fintech',
  ),
  const BusinessSector(
    id: 'tourism',
    name: 'Tourisme et hôtellerie',
    description: 'Hôtels, restauration, agences de voyage',
  ),
  const BusinessSector(
    id: 'education',
    name: 'Éducation et formation',
    description: 'Établissements d\'enseignement, centres de formation',
  ),
  const BusinessSector(
    id: 'healthcare',
    name: 'Santé et pharmaceutique',
    description: 'Cliniques, hôpitaux, pharmacies, industries pharmaceutiques',
  ),
  const BusinessSector(
    id: 'ict',
    name: 'Technologies de l\'information',
    description: 'Développement logiciel, services informatiques, e-commerce',
  ),
  const BusinessSector(
    id: 'entertainment',
    name: 'Arts, médias et divertissement',
    description: 'Production média, cinéma, musique, événementiel',
  ),
  const BusinessSector(
    id: 'manufacturing',
    name: 'Industrie manufacturière',
    description: 'Production de biens et produits manufacturés',
  ),
  const BusinessSector(
    id: 'textiles',
    name: 'Textile et habillement',
    description: 'Production textile, confection, mode',
  ),
  const BusinessSector(
    id: 'retail',
    name: 'Commerce de détail',
    description: 'Magasins, boutiques, supermarchés',
  ),
  const BusinessSector(
    id: 'other',
    name: 'Autre',
    description: 'Autre secteur d\'activité',
  ),
];
