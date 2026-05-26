// filepath: lib/core/services/entity_vocabulary_service.dart
import 'package:wanzo/core/services/business_context_service.dart';

/// Vocabulaire métier swappable selon le variant de l'entreprise courante.
///
/// Principe : aucune logique applicative ne change selon le variant — seuls
/// les libellés affichés sont remplacés. Une coopérative est, du point de
/// vue du domaine, une PME multi-succursale ; on remplace juste les mots.
///
/// Usage :
/// ```dart
/// final vocab = EntityVocabularyService.current();
/// Text('Vos ${vocab.branches}');
/// // → "Vos succursales" pour une PME
/// // → "Vos coopérants" pour une coopérative
/// ```
///
/// Le mapping ici doit rester strictement aligné avec
/// `wanzo_compta/src/hooks/useEntityVocabulary.ts` côté React.
class EntityVocabulary {
  /// Variant source ('standard' | 'cooperative').
  final String variant;

  /// L'entité ("entreprise" / "coopérative").
  final String entity;
  final String entityCapitalized;

  /// Avec article défini : "l'entreprise" / "la coopérative".
  final String entityWithArticle;

  /// Avec possessif : "votre entreprise" / "votre coopérative".
  final String yourEntity;

  /// Singulier — employé / coopérant.
  final String member;
  final String members;

  /// Singulier — succursale (= coopérant en mode coop).
  final String branch;
  final String branchCapitalized;
  final String branches;
  final String branchesCapitalized;

  /// Libellés d'action contextualisés.
  final String addBranchLabel;
  final String newBranchLabel;
  final String emptyBranchesLabel;
  final String createBranchLabel;
  final String branchNameLabel;

  /// Label commercial (segment client).
  final String segmentLabel;

  const EntityVocabulary({
    required this.variant,
    required this.entity,
    required this.entityCapitalized,
    required this.entityWithArticle,
    required this.yourEntity,
    required this.member,
    required this.members,
    required this.branch,
    required this.branchCapitalized,
    required this.branches,
    required this.branchesCapitalized,
    required this.addBranchLabel,
    required this.newBranchLabel,
    required this.emptyBranchesLabel,
    required this.createBranchLabel,
    required this.branchNameLabel,
    required this.segmentLabel,
  });

  static const EntityVocabulary standard = EntityVocabulary(
    variant: 'standard',
    entity: 'entreprise',
    entityCapitalized: 'Entreprise',
    entityWithArticle: 'l\'entreprise',
    yourEntity: 'votre entreprise',
    member: 'employé',
    members: 'employés',
    branch: 'succursale',
    branchCapitalized: 'Succursale',
    branches: 'succursales',
    branchesCapitalized: 'Succursales',
    addBranchLabel: 'Ajouter une succursale',
    newBranchLabel: 'Nouvelle succursale',
    emptyBranchesLabel: 'Aucune succursale',
    createBranchLabel: 'Créer une succursale',
    branchNameLabel: 'Nom de la succursale',
    segmentLabel: 'PME',
  );

  static const EntityVocabulary cooperative = EntityVocabulary(
    variant: 'cooperative',
    entity: 'coopérative',
    entityCapitalized: 'Coopérative',
    entityWithArticle: 'la coopérative',
    yourEntity: 'votre coopérative',
    member: 'coopérant',
    members: 'coopérants',
    branch: 'coopérant',
    branchCapitalized: 'Coopérant',
    branches: 'coopérants',
    branchesCapitalized: 'Coopérants',
    addBranchLabel: 'Ajouter un coopérant',
    newBranchLabel: 'Nouveau coopérant',
    emptyBranchesLabel: 'Aucun coopérant',
    createBranchLabel: 'Ajouter un coopérant',
    branchNameLabel: 'Nom du coopérant',
    segmentLabel: 'Coopérative',
  );
}

/// Façade statique — résout le vocabulaire à partir du contexte business
/// courant (singleton [BusinessContextService]).
class EntityVocabularyService {
  EntityVocabularyService._();

  /// Vocabulaire pour le variant donné. Tout variant inconnu retombe
  /// sur 'standard' (compat ascendante).
  static EntityVocabulary forVariant(String variant) {
    return variant == 'cooperative'
        ? EntityVocabulary.cooperative
        : EntityVocabulary.standard;
  }

  /// Vocabulaire pour l'entreprise courante (via BusinessContextService).
  /// À appeler depuis n'importe quel build() de widget après init de la
  /// session — pas besoin d'inject ni de provider.
  static EntityVocabulary current() {
    return forVariant(BusinessContextService().companyVariant);
  }
}
