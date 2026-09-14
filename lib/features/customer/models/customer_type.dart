import 'package:flutter/material.dart';

/// Nature juridique du client : personne physique (défaut) ou personne morale.
/// Valeurs alignées sur `CustomerType` du backend gestion (`customers.customer_type`).
enum CustomerType {
  individual,
  company,
  ngo,
  cooperative,
  publicInstitution,
  association,
  other,
}

extension CustomerTypeX on CustomerType {
  String get apiValue {
    switch (this) {
      case CustomerType.individual:
        return 'individual';
      case CustomerType.company:
        return 'company';
      case CustomerType.ngo:
        return 'ngo';
      case CustomerType.cooperative:
        return 'cooperative';
      case CustomerType.publicInstitution:
        return 'public_institution';
      case CustomerType.association:
        return 'association';
      case CustomerType.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case CustomerType.individual:
        return 'Personne physique';
      case CustomerType.company:
        return 'Entreprise (PME, SARL, SA...)';
      case CustomerType.ngo:
        return 'ONG';
      case CustomerType.cooperative:
        return 'Coopérative';
      case CustomerType.publicInstitution:
        return 'Institution publique';
      case CustomerType.association:
        return 'Association';
      case CustomerType.other:
        return 'Autre personne morale';
    }
  }

  /// Libellé court pour les badges et listes.
  String get shortLabel {
    switch (this) {
      case CustomerType.individual:
        return 'Particulier';
      case CustomerType.company:
        return 'Entreprise';
      case CustomerType.ngo:
        return 'ONG';
      case CustomerType.cooperative:
        return 'Coopérative';
      case CustomerType.publicInstitution:
        return 'Institution';
      case CustomerType.association:
        return 'Association';
      case CustomerType.other:
        return 'Personne morale';
    }
  }

  bool get isOrganization => this != CustomerType.individual;

  IconData get icon {
    switch (this) {
      case CustomerType.individual:
        return Icons.person_outline;
      case CustomerType.company:
        return Icons.business_outlined;
      case CustomerType.ngo:
        return Icons.volunteer_activism_outlined;
      case CustomerType.cooperative:
        return Icons.groups_outlined;
      case CustomerType.publicInstitution:
        return Icons.account_balance_outlined;
      case CustomerType.association:
        return Icons.diversity_3_outlined;
      case CustomerType.other:
        return Icons.apartment_outlined;
    }
  }

  static CustomerType fromApiValue(String? value) {
    for (final t in CustomerType.values) {
      if (t.apiValue == value) return t;
    }
    return CustomerType.individual;
  }
}
