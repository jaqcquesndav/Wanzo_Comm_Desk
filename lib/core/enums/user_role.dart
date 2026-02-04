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
    }
  }

  /// Crée un UserRole depuis la valeur API
  static UserRole fromApiValue(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'super_admin':
        return UserRole.superAdmin;
      case 'manager':
        return UserRole.manager;
      case 'accountant':
        return UserRole.accountant;
      case 'cashier':
        return UserRole.cashier;
      case 'sales':
        return UserRole.sales;
      case 'inventory_manager':
        return UserRole.inventoryManager;
      case 'staff':
        return UserRole.staff;
      case 'customer_support':
        return UserRole.customerSupport;
      default:
        return UserRole.staff;
    }
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
      case UserRole.staff:
        return 5;
    }
  }

  /// Vérifie si ce rôle a des droits d'administration
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
}
