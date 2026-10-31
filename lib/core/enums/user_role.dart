// filepath: lib/core/enums/user_role.dart
import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:wanzo/l10n/app_localizations.dart';

part 'user_role.g.dart';

/// Enum représentant les rôles utilisateurs dans le système
/// Conformité: Aligné avec user-role.enum.ts (gestion_commerciale_service)
@HiveType(typeId: 74)
enum UserRole {
  /// Administrateur - Propriétaire de l'entreprise avec tous les droits
  @HiveField(0)
  admin,

  /// Super Administrateur - Droits maximaux sur l'entreprise
  @HiveField(8)
  superAdmin,

  /// Manager - Gestionnaire avec droits étendus
  @HiveField(1)
  manager,

  /// Comptable - Accès aux fonctions comptables
  @HiveField(2)
  accountant,

  /// Caissier - Accès aux fonctions de caisse
  @HiveField(3)
  cashier,

  /// Commercial - Accès aux fonctions de vente
  @HiveField(4)
  sales,

  /// Gestionnaire Stock - Accès à la gestion des stocks
  @HiveField(5)
  inventoryManager,

  /// Employé - Employé standard (rôle par défaut)
  @HiveField(6)
  staff,

  /// Support Client - Accès au support client
  @HiveField(7)
  customerSupport,

  /// Réceptionniste - Front desk (réservations, hôtellerie)
  @HiveField(9)
  receptionist,

  /// Technicien - Maintenance, ateliers
  @HiveField(10)
  technician,

  /// Lecteur - Lecture seule (auditeur, analyste, RH, rôles sans équivalent).
  /// Le serveur refuse toute écriture métier (403 READ_ONLY_ROLE).
  @HiveField(11)
  viewer,
}

/// Extension pour les fonctionnalités de UserRole
extension UserRoleExtension on UserRole {
  /// Retourne la valeur API du rôle
  String get apiValue {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.manager:
        return 'manager';
      case UserRole.accountant:
        return 'accountant';
      case UserRole.cashier:
        return 'cashier';
      case UserRole.sales:
        return 'sales';
      case UserRole.inventoryManager:
        return 'inventory_manager';
      case UserRole.staff:
        return 'staff';
      case UserRole.customerSupport:
        return 'customer_support';
      case UserRole.receptionist:
        return 'receptionist';
      case UserRole.technician:
        return 'technician';
      case UserRole.viewer:
        return 'viewer';
    }
  }

  /// Valeur posée quand aucun rôle n'est connu (jeton sans claim de rôle et
  /// aucune réponse du serveur) : jamais lue comme « staff ».
  static const String unknownApiValue = 'unknown';

  /// Rôles de la plateforme vers l'enum de l'app : copie À L'IDENTIQUE de la
  /// matrice des rôles du serveur (Wanzo_Backend packages/shared/src/auth/
  /// role-access-matrix.ts, colonne commerce), comparée par
  /// test/core/enums/role_access_matrix_test.dart à
  /// test/fixtures/role_access_matrix.json. Un rôle sans équivalent prend le
  /// plus proche sans jamais le dépasser ; super_admin reste superAdmin ici.
  static const Map<String, UserRole> _apiValues = {
    'super_admin': UserRole.superAdmin,
    'owner': UserRole.admin,
    'sme_owner': UserRole.admin,
    'sme_admin': UserRole.admin,
    'admin': UserRole.admin,
    'manager': UserRole.manager,
    'accountant': UserRole.accountant,
    'chief_accountant': UserRole.accountant,
    'expert_comptable': UserRole.viewer,
    'audit': UserRole.viewer,
    'analyst': UserRole.viewer,
    'hr': UserRole.viewer,
    'treasurer': UserRole.cashier,
    'viewer': UserRole.viewer,
    'commerce_manager': UserRole.manager,
    'cashier': UserRole.cashier,
    'salesperson': UserRole.sales,
    'stock_keeper': UserRole.inventoryManager,
    'production_manager': UserRole.viewer,
    'production_planner': UserRole.viewer,
    'production_operator': UserRole.viewer,
    'quality_controller': UserRole.viewer,
    'maintenance_technician': UserRole.technician,
    'procurement_officer': UserRole.inventoryManager,
    'asset_manager': UserRole.manager,
    'receptionist': UserRole.receptionist,
    'technician': UserRole.technician,
    'housekeeping': UserRole.staff,
    'portfolio_manager': UserRole.viewer,
    'credit_analyst': UserRole.viewer,
    'loan_officer': UserRole.viewer,
    'risk_officer': UserRole.viewer,
    'compliance_officer': UserRole.viewer,
    'avec_president': UserRole.manager,
    'avec_secretary': UserRole.manager,
    'avec_treasurer': UserRole.accountant,
    'program_manager': UserRole.viewer,
    'program_field_agent': UserRole.viewer,
    'program_me_officer': UserRole.viewer,
    'program_auditor': UserRole.viewer,
    'program_accountant': UserRole.viewer,
    'staff': UserRole.staff,
    'user': UserRole.staff,
    'sme_user': UserRole.staff,
    'sales': UserRole.sales,
    'inventory_manager': UserRole.inventoryManager,
    'customer_support': UserRole.customerSupport,
    'superadmin': UserRole.superAdmin,
  };

  /// La valeur désigne-t-elle un rôle réel (et non une absence de rôle) ?
  static bool isKnownApiValue(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    return v.isNotEmpty && v != unknownApiValue;
  }

  /// Crée un UserRole depuis la valeur API
  static UserRole fromApiValue(String value) {
    final key = value.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
    if (key.isEmpty) return UserRole.staff;
    return _apiValues[key] ?? UserRole.viewer;
  }

  /// Retourne le nom d'affichage localisé
  String displayName(AppLocalizations l10n) {
    switch (this) {
      case UserRole.admin:
        return l10n.userRoleAdmin;
      case UserRole.superAdmin:
        return l10n.userRoleSuperAdmin;
      case UserRole.manager:
        return l10n.userRoleManager;
      case UserRole.accountant:
        return l10n.userRoleAccountant;
      case UserRole.cashier:
        return l10n.userRoleCashier;
      case UserRole.sales:
        return l10n.userRoleSales;
      case UserRole.inventoryManager:
        return l10n.userRoleInventoryManager;
      case UserRole.staff:
        return l10n.userRoleStaff;
      case UserRole.customerSupport:
        return l10n.userRoleCustomerSupport;
      case UserRole.receptionist:
        return 'Réceptionniste';
      case UserRole.technician:
        return 'Technicien';
      case UserRole.viewer:
        return 'Lecteur';
    }
  }

  /// Retourne la description localisée
  String description(AppLocalizations l10n) {
    switch (this) {
      case UserRole.admin:
        return l10n.userRoleAdminDescription;
      case UserRole.superAdmin:
        return l10n.userRoleSuperAdminDescription;
      case UserRole.manager:
        return l10n.userRoleManagerDescription;
      case UserRole.accountant:
        return l10n.userRoleAccountantDescription;
      case UserRole.cashier:
        return l10n.userRoleCashierDescription;
      case UserRole.sales:
        return l10n.userRoleSalesDescription;
      case UserRole.inventoryManager:
        return l10n.userRoleInventoryManagerDescription;
      case UserRole.staff:
        return l10n.userRoleStaffDescription;
      case UserRole.customerSupport:
        return l10n.userRoleCustomerSupportDescription;
      case UserRole.receptionist:
        return 'Réservations et accueil';
      case UserRole.technician:
        return 'Maintenance et interventions';
      case UserRole.viewer:
        return 'Consultation en lecture seule';
    }
  }

  /// Retourne l'icône associée au rôle
  IconData get icon {
    switch (this) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.superAdmin:
        return Icons.security;
      case UserRole.manager:
        return Icons.supervisor_account;
      case UserRole.accountant:
        return Icons.account_balance;
      case UserRole.cashier:
        return Icons.point_of_sale;
      case UserRole.sales:
        return Icons.shopping_cart;
      case UserRole.inventoryManager:
        return Icons.inventory;
      case UserRole.staff:
        return Icons.person;
      case UserRole.customerSupport:
        return Icons.support_agent;
      case UserRole.receptionist:
        return Icons.room_service;
      case UserRole.technician:
        return Icons.build;
      case UserRole.viewer:
        return Icons.visibility;
    }
  }

  /// Retourne la couleur associée au rôle
  Color get color {
    switch (this) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.superAdmin:
        return Colors.deepPurple;
      case UserRole.manager:
        return Colors.purple;
      case UserRole.accountant:
        return Colors.blue;
      case UserRole.cashier:
        return Colors.green;
      case UserRole.sales:
        return Colors.orange;
      case UserRole.inventoryManager:
        return Colors.teal;
      case UserRole.staff:
        return Colors.grey;
      case UserRole.customerSupport:
        return Colors.indigo;
      case UserRole.receptionist:
        return Colors.cyan;
      case UserRole.technician:
        return Colors.brown;
      case UserRole.viewer:
        return Colors.blueGrey;
    }
  }

  /// Niveau de permission (0 = plus élevé)
  int get permissionLevel {
    switch (this) {
      case UserRole.superAdmin:
        return 0;
      case UserRole.admin:
        return 0;
      case UserRole.manager:
        return 1;
      case UserRole.accountant:
        return 2;
      case UserRole.cashier:
        return 3;
      case UserRole.sales:
        return 3;
      case UserRole.inventoryManager:
        return 3;
      case UserRole.customerSupport:
        return 4;
      case UserRole.receptionist:
        return 3;
      case UserRole.technician:
        return 3;
      case UserRole.viewer:
        return 6;
      case UserRole.staff:
        return 5;
    }
  }

  /// Vérifie si ce rôle a des droits d'administration
  /// Lecture seule : le serveur refuse toute écriture métier.
  bool get isReadOnly => this == UserRole.viewer;

  bool get isAdmin => this == UserRole.admin || this == UserRole.superAdmin;

  /// Vérifie si ce rôle est super admin
  bool get isSuperAdmin => this == UserRole.superAdmin;

  /// Vérifie si ce rôle a des droits de management
  bool get isManagerOrAbove =>
      this == UserRole.admin ||
      this == UserRole.superAdmin ||
      this == UserRole.manager;

  /// Vérifie si ce rôle peut gérer les utilisateurs
  bool get canManageUsers => isAdmin;

  /// Vérifie si ce rôle peut voir les rapports financiers
  bool get canViewFinancialReports =>
      this == UserRole.admin ||
      this == UserRole.manager ||
      this == UserRole.accountant;

  /// Vérifie si ce rôle peut accéder au Wallet et aux fonctionnalités de financement
  /// Seuls les admins et comptables ont accès à ces fonctionnalités sensibles
  bool get canAccessWallet =>
      this == UserRole.admin ||
      this == UserRole.superAdmin ||
      this == UserRole.accountant;

  /// Vérifie si ce rôle voit la caisse (ouverture, clôture, ticket Z,
  /// journal vue Caisse) : administrateur, comptable, caissier.
  bool get canAccessCashSession =>
      this == UserRole.admin ||
      this == UserRole.superAdmin ||
      this == UserRole.accountant ||
      this == UserRole.cashier;

  /// Vérifie si ce rôle peut gérer les demandes de crédit/financement
  bool get canManageCredit =>
      this == UserRole.admin ||
      this == UserRole.superAdmin ||
      this == UserRole.accountant;

  /// Vérifie si ce rôle peut gérer les comptes financiers (banque, Mobile
  /// Money) dans les paramètres : même périmètre que le mobile.
  bool get canManageFinancialAccounts =>
      this == UserRole.admin ||
      this == UserRole.superAdmin ||
      this == UserRole.accountant;
}
