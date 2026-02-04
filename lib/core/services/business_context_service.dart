// filepath: lib/core/services/business_context_service.dart
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';
import 'package:wanzo/features/auth/models/user.dart';
import 'package:wanzo/features/auth/services/auth_backend_service.dart';
import 'package:wanzo/features/business_unit/models/business_unit.dart';

/// Service singleton pour gérer le contexte business global de l'application
///
/// Ce service maintient:
/// - Le companyId et businessUnitId de l'utilisateur connecté
/// - Les informations de l'entreprise et de l'unité commerciale
/// - Le scope d'accès (company ou unit)
///
/// Ces informations sont utilisées par tous les services et repositories
/// pour filtrer les données selon le contexte multi-tenant.
class BusinessContextService extends ChangeNotifier {
  static final BusinessContextService _instance =
      BusinessContextService._internal();
  factory BusinessContextService() => _instance;
  BusinessContextService._internal();

  static const String _boxName = 'business_context';
  static const String _contextKey = 'current_context';

  Box<Map>? _box;
  BusinessContext? _currentContext;

  /// Le contexte business actuel
  BusinessContext? get currentContext => _currentContext;

  /// ID de l'entreprise courante
  String? get companyId => _currentContext?.companyId;

  /// ID de l'utilisateur courant (UUID de la base de données)
  String? get userId => _currentContext?.userId;

  /// ID de l'unité commerciale courante
  String? get businessUnitId => _currentContext?.businessUnitId;

  /// Code de l'unité commerciale courante
  String? get businessUnitCode => _currentContext?.businessUnitCode;

  /// Type de l'unité courante
  BusinessUnitType? get businessUnitType => _currentContext?.businessUnitType;

  /// Scope d'accès: "company" ou "unit"
  String? get scope => _currentContext?.scope;

  /// Vérifie si l'utilisateur a un accès niveau entreprise
  bool get hasCompanyScope => _currentContext?.scope == 'company';

  /// Vérifie si l'utilisateur est limité à une unité spécifique
  bool get hasUnitScope =>
      _currentContext?.scope == 'unit' || _currentContext?.scope == null;

  /// Vérifie si le contexte est initialisé
  bool get isInitialized => _currentContext != null;

  /// Initialise le service et charge le contexte depuis le cache
  Future<void> initialize() async {
    try {
      _box = await Hive.openBox<Map>(_boxName);
      final cached = _box?.get(_contextKey);
      if (cached != null) {
        _currentContext = BusinessContext.fromJson(
          Map<String, dynamic>.from(cached),
        );
        debugPrint(
          'BusinessContextService: Loaded context from cache - CompanyId: $companyId, BusinessUnitId: $businessUnitId',
        );
      }
    } catch (e) {
      debugPrint('BusinessContextService: Error initializing: $e');
    }
  }

  /// Met à jour le contexte business depuis les données utilisateur
  ///
  /// Appelé après une connexion réussie ou un rafraîchissement du profil
  Future<void> updateFromUser(User user) async {
    _currentContext = BusinessContext(
      companyId: user.companyId,
      companyName: user.companyName,
      businessUnitId: user.businessUnitId,
      businessUnitCode: user.businessUnitCode,
      businessUnitType: user.businessUnitType,
      // Le scope est déterminé par la présence d'un businessUnitId
      // Admin/SuperAdmin sans businessUnitId = scope "company"
      // Autres rôles avec businessUnitId = scope "unit"
      scope: user.businessUnitId == null ? 'company' : 'unit',
      userId: user.id,
      userRole: user.role,
    );

    await _persistContext();
    notifyListeners();

    debugPrint(
      'BusinessContextService: Updated context from user - CompanyId: $companyId, BusinessUnitId: $businessUnitId, Scope: $scope',
    );
  }

  /// Met à jour le contexte depuis la réponse complète de /users/me
  Future<void> updateFromAuthMeResponse(AuthMeResponse authMeResponse) async {
    final user = authMeResponse.user;
    final company = authMeResponse.company;
    final businessUnit = authMeResponse.businessUnit;

    _currentContext = BusinessContext(
      companyId: user.companyId ?? company?.id,
      companyName: user.companyName ?? company?.name,
      businessUnitId: user.businessUnitId ?? businessUnit?.id,
      businessUnitCode: businessUnit?.code,
      businessUnitType:
          businessUnit?.type != null
              ? BusinessUnitTypeExtension.fromApiValue(businessUnit!.type!)
              : null,
      scope:
          businessUnit?.scope ??
          (user.businessUnitId == null ? 'company' : 'unit'),
      userId: user.id,
      userRole: user.role,
    );

    await _persistContext();
    notifyListeners();

    debugPrint(
      'BusinessContextService: Updated context from /users/me - CompanyId: $companyId, BusinessUnitId: $businessUnitId, Scope: $scope',
    );
  }

  /// Définit manuellement le BusinessUnit actif (pour changement de contexte)
  ///
  /// Utilisé quand un admin veut filtrer par une unité spécifique
  Future<void> setActiveBusinessUnit(BusinessUnit unit) async {
    if (_currentContext != null) {
      _currentContext = _currentContext!.copyWith(
        businessUnitId: unit.id,
        businessUnitCode: unit.code,
        businessUnitType: unit.type,
        // Garder le scope original
      );
      await _persistContext();
      notifyListeners();
      debugPrint(
        'BusinessContextService: Active business unit changed to ${unit.id}',
      );
    }
  }

  /// Réinitialise au niveau entreprise (pour admins)
  Future<void> resetToCompanyLevel() async {
    if (_currentContext != null && hasCompanyScope) {
      _currentContext = _currentContext!.copyWith(
        businessUnitId: null,
        businessUnitCode: null,
        businessUnitType: null,
      );
      await _persistContext();
      notifyListeners();
      debugPrint('BusinessContextService: Reset to company level');
    }
  }

  /// Efface le contexte (déconnexion)
  Future<void> clear() async {
    _currentContext = null;
    await _box?.delete(_contextKey);
    notifyListeners();
    debugPrint('BusinessContextService: Context cleared');
  }

  /// Génère les paramètres de query pour les appels API
  ///
  /// Retourne les paramètres companyId et businessUnitId à inclure
  /// dans les requêtes API pour le filtrage multi-tenant
  Map<String, String> getApiQueryParams({bool includeBusinessUnit = true}) {
    final params = <String, String>{};

    if (companyId != null) {
      params['companyId'] = companyId!;
    }

    if (includeBusinessUnit && businessUnitId != null && hasUnitScope) {
      params['businessUnitId'] = businessUnitId!;
    }

    return params;
  }

  Future<void> _persistContext() async {
    if (_currentContext != null) {
      await _box?.put(_contextKey, _currentContext!.toJson());
    }
  }
}

/// Modèle représentant le contexte business de l'utilisateur
class BusinessContext {
  /// ID de l'entreprise
  final String? companyId;

  /// Nom de l'entreprise
  final String? companyName;

  /// ID de l'unité commerciale assignée
  final String? businessUnitId;

  /// Code de l'unité (ex: POS-001)
  final String? businessUnitCode;

  /// Type d'unité
  final BusinessUnitType? businessUnitType;

  /// Scope d'accès: "company" ou "unit"
  final String? scope;

  /// ID de l'utilisateur
  final String? userId;

  /// Rôle de l'utilisateur
  final String? userRole;

  const BusinessContext({
    this.companyId,
    this.companyName,
    this.businessUnitId,
    this.businessUnitCode,
    this.businessUnitType,
    this.scope,
    this.userId,
    this.userRole,
  });

  factory BusinessContext.fromJson(Map<String, dynamic> json) {
    return BusinessContext(
      companyId: json['companyId'] as String?,
      companyName: json['companyName'] as String?,
      businessUnitId: json['businessUnitId'] as String?,
      businessUnitCode: json['businessUnitCode'] as String?,
      businessUnitType:
          json['businessUnitType'] != null
              ? BusinessUnitTypeExtension.fromApiValue(
                json['businessUnitType'] as String,
              )
              : null,
      scope: json['scope'] as String?,
      userId: json['userId'] as String?,
      userRole: json['userRole'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'companyId': companyId,
    'companyName': companyName,
    'businessUnitId': businessUnitId,
    'businessUnitCode': businessUnitCode,
    'businessUnitType': businessUnitType?.apiValue,
    'scope': scope,
    'userId': userId,
    'userRole': userRole,
  };

  BusinessContext copyWith({
    String? companyId,
    String? companyName,
    String? businessUnitId,
    String? businessUnitCode,
    BusinessUnitType? businessUnitType,
    String? scope,
    String? userId,
    String? userRole,
  }) {
    return BusinessContext(
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      businessUnitId: businessUnitId ?? this.businessUnitId,
      businessUnitCode: businessUnitCode ?? this.businessUnitCode,
      businessUnitType: businessUnitType ?? this.businessUnitType,
      scope: scope ?? this.scope,
      userId: userId ?? this.userId,
      userRole: userRole ?? this.userRole,
    );
  }
}
