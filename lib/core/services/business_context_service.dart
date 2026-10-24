import 'dart:async';
// filepath: lib/core/services/business_context_service.dart
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';
import 'package:wanzo/core/modules/activity_mode.dart';
import 'package:wanzo/core/services/api_client.dart';
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

  /// Variant de l'entreprise courante ('standard' ou 'cooperative').
  /// Pilote le vocabulaire métier via [EntityVocabularyService].
  String get companyVariant => _currentContext?.companyVariant ?? 'standard';

  /// `true` si l'entreprise courante est une coopérative.
  bool get isCooperative => companyVariant == 'cooperative';

  /// Nom de l'entreprise courante (issu de /auth/me → Company).
  String? get companyName => _currentContext?.companyName;

  /// RCCM de l'entreprise (issu de /auth/me → Company). Sert de repli pour
  /// l'en-tête des pièces commerciales quand les Settings locaux sont vides.
  String? get companyRccm => _currentContext?.companyRccm;

  /// NIF (impôt) de l'entreprise (issu de /auth/me → Company). Requis KYC,
  /// en-têtes d'états de sortie/PDF et scoring.
  String? get companyTaxId => _currentContext?.companyTaxId;

  /// IdNat (identification nationale) de l'entreprise (issu de /auth/me →
  /// Company). Pour une coopérative, l'IdNat reste l'identifiant national.
  String? get companyNationalId => _currentContext?.companyNationalId;

  /// Mode d'activité courant (défaut retail). Pilote l'affichage modulaire
  /// via `ModuleRegistry` (sidebar desktop + bottom-nav mobile).
  ActivityMode get activityMode =>
      ActivityMode.fromString(_currentContext?.activityMode);

  /// Seul un administrateur choisit le mode d'activité de l'entreprise.
  bool get canChangeActivityMode => isAdminRole(_currentContext?.userRole);

  static bool isAdminRole(String? role) {
    final r = (role ?? '').toLowerCase().replaceAll('-', '_');
    return r == 'admin' || r == 'super_admin' || r == 'superadmin';
  }

  /// Écriture du mode côté serveur (remplaçable en test).
  @visibleForTesting
  static Future<void> Function(String companyId, String mode)?
      remoteActivityModeWriter;

  static const String _modeAckKey = 'activity_mode_server_ack';

  /// Vrai quand le mode local a déjà été aligné sur le serveur (lu ou écrit).
  bool get _modeAck => _box?.get(_modeAckKey)?['ack'] == true;
  Future<void> _setModeAck() async {
    try {
      await _box?.put(_modeAckKey, {'ack': true});
    } catch (_) {}
  }

  /// Change le mode d'activité, persiste, notifie (nav recomposée) et
  /// l'ÉCRIT sur la fiche de l'entreprise (`companies.activityMode`) : le
  /// mode n'était gardé que sur l'appareil, chaque poste avait le sien.
  /// Renvoie l'erreur de l'écriture serveur (OfflineQueuedException hors
  /// ligne : en attente), null si tout est passé.
  Future<Object?> setActivityMode(ActivityMode mode) async {
    if (_currentContext == null) return null;
    if (_currentContext!.activityMode == mode.apiValue) return null;
    _currentContext = _currentContext!.copyWith(activityMode: mode.apiValue);
    await _persistContext();
    notifyListeners();
    debugPrint('BusinessContextService: activityMode → ${mode.apiValue}');
    return _pushActivityMode(mode.apiValue);
  }

  Future<Object?> _pushActivityMode(String mode) async {
    final id = companyId;
    if (id == null || id.isEmpty) return null;
    try {
      final writer = remoteActivityModeWriter ??
          (String c, String m) => ApiClient().patch(
                'companies/$c/activity-mode',
                body: {'activityMode': m},
                requiresAuth: true,
              );
      await writer(id, mode);
      await _setModeAck();
      return null;
    } catch (e) {
      debugPrint('BusinessContextService: mode non écrit au serveur : $e');
      return e;
    }
  }

  /// Mode retenu à la lecture de /auth/me. Le serveur fait foi ; seul cas
  /// particulier : un mode choisi sur l'appareil AVANT que le serveur le
  /// connaisse (serveur encore au défaut « retail », jamais aligné) est
  /// gardé, et un admin le publie.
  @visibleForTesting
  static ({String mode, bool publishLocal}) resolveActivityMode({
    required String? serverMode,
    required String? localMode,
    required bool alreadyAligned,
    required bool isAdmin,
  }) {
    final server = serverMode == null
        ? null
        : ActivityMode.fromString(serverMode).apiValue;
    final local = localMode == null
        ? null
        : ActivityMode.fromString(localMode).apiValue;
    if (server != null && server != 'retail') {
      return (mode: server, publishLocal: false);
    }
    if (server == 'retail' && alreadyAligned) {
      return (mode: 'retail', publishLocal: false);
    }
    if (local != null && local != 'retail') {
      return (mode: local, publishLocal: server != null && isAdmin);
    }
    return (mode: server ?? local ?? 'retail', publishLocal: false);
  }

  /// ID de l'unité commerciale courante
  String? get businessUnitId => _currentContext?.businessUnitId;

  /// Code de l'unité commerciale courante
  String? get businessUnitCode => _currentContext?.businessUnitCode;

  /// Type de l'unité courante
  BusinessUnitType? get businessUnitType => _currentContext?.businessUnitType;

  /// Nom de l'unité courante (pour en-tête des pièces).
  String? get businessUnitName => _currentContext?.businessUnitName;

  /// `true` si la BU est personne morale avec identifiants propres.
  bool get businessUnitIsLegalEntity =>
      _currentContext?.businessUnitIsLegalEntity ?? false;

  /// `true` lorsque les pièces commerciales doivent porter l'identité de
  /// la BU (RCCM/NIF/IDNAT) et non celle de l'entreprise parente — cas
  /// coopérant entreprise dans une coopérative.
  bool get shouldUseBusinessUnitIdentity =>
      _currentContext?.shouldUseBusinessUnitIdentity ?? false;

  /// RCCM propre à la BU (si personne morale).
  String? get businessUnitRccm => _currentContext?.businessUnitRccm;

  /// NIF propre à la BU (si personne morale).
  String? get businessUnitTaxId => _currentContext?.businessUnitTaxId;

  /// IDNAT propre à la BU (si personne morale).
  String? get businessUnitIdNat => _currentContext?.businessUnitIdNat;

  /// Adresse de la BU pour en-tête.
  String? get businessUnitAddress => _currentContext?.businessUnitAddress;

  /// Téléphone de la BU pour en-tête.
  String? get businessUnitPhone => _currentContext?.businessUnitPhone;

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
      activityMode: _currentContext?.activityMode ?? 'retail',
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
    // Mode d'activité : celui de la fiche entreprise (serveur) l'emporte.
    final modeChoisi = resolveActivityMode(
      serverMode: company?.activityMode,
      localMode: _currentContext?.activityMode,
      alreadyAligned: _modeAck,
      isAdmin: isAdminRole(user.role),
    );
    if (company?.activityMode != null && !modeChoisi.publishLocal) {
      await _setModeAck();
    }

    _currentContext = BusinessContext(
      companyId: user.companyId ?? company?.id,
      companyName: user.companyName ?? company?.name,
      companyVariant: company?.variant ?? 'standard',
      // Identifiants légaux de l'entreprise issus de /auth/me (Company entity).
      companyRccm: company?.registrationNumber,
      companyTaxId: company?.taxId,
      companyNationalId: company?.nationalId,
      activityMode: modeChoisi.mode,
      businessUnitId: user.businessUnitId ?? businessUnit?.id,
      businessUnitCode: businessUnit?.code,
      businessUnitType:
          businessUnit?.type != null
              ? BusinessUnitTypeExtension.fromApiValue(businessUnit!.type!)
              : null,
      businessUnitName: businessUnit?.name,
      businessUnitIsLegalEntity: businessUnit?.isLegalEntity ?? false,
      businessUnitRccm: businessUnit?.registrationNumber,
      businessUnitTaxId: businessUnit?.taxId,
      businessUnitIdNat: businessUnit?.idNat,
      // En-tête des pièces : coordonnées résolues sur l'unité et ses
      // parentes (serveur), sinon celles saisies sur l'unité.
      businessUnitAddress: businessUnit?.documentAddress ?? businessUnit?.address,
      businessUnitPhone: businessUnit?.documentPhone ?? businessUnit?.phone,
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
    // Mode choisi sur l'appareil avant la version qui l'écrit au serveur :
    // l'admin le publie une fois (les autres postes le reçoivent ensuite).
    if (modeChoisi.publishLocal) {
      unawaited(_pushActivityMode(modeChoisi.mode));
    }
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

  /// Enregistre l'unité que l'utilisateur vient de rejoindre avec son code.
  ///
  /// Le serveur a déjà rattaché l'utilisateur ; il ne reste qu'à refléter ce
  /// rattachement localement, pour que les écrans suivent sans attendre une
  /// reconnexion.
  Future<void> applySwitchedUnit({
    required String businessUnitId,
    required String businessUnitCode,
    String? businessUnitName,
    String? businessUnitType,
    bool niveauEntreprise = false,
  }) async {
    if (_currentContext == null) return;
    // L'identité de l'ancienne unité (adresse, téléphone, identifiants
    // propres) ne doit pas s'imprimer sous la nouvelle : copyWith ne sait pas
    // remettre à null, on repart d'un contexte purgé. Le prochain /auth/me
    // apporte celle de la nouvelle unité ; d'ici là, l'en-tête prend le siège.
    _currentContext = BusinessContext.fromJson({
      ..._currentContext!.toJson(),
      'businessUnitAddress': null,
      'businessUnitPhone': null,
      'businessUnitIsLegalEntity': false,
      'businessUnitRccm': null,
      'businessUnitTaxId': null,
      'businessUnitIdNat': null,
    });
    _currentContext = _currentContext!.copyWith(
      businessUnitId: businessUnitId,
      businessUnitCode: businessUnitCode,
      businessUnitName: businessUnitName,
      businessUnitType: businessUnitType != null
          ? BusinessUnitTypeExtension.fromApiValue(businessUnitType)
          : null,
      // Remonter a l'entreprise rend la portee « company » : sans cela
      // l'utilisateur restait borne a une unite qu'il venait de quitter.
      scope: niveauEntreprise ? 'company' : 'unit',
    );
    await _persistContext();
    notifyListeners();
    debugPrint('BusinessContextService: unité rejointe $businessUnitCode');
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

  /// Variant d'opération de l'entreprise courante : 'standard' (PME) ou
  /// 'cooperative'. Pilote le vocabulaire métier UI sans changer la logique.
  /// Default 'standard' pour rétrocompat.
  final String companyVariant;

  /// RCCM de l'entreprise (source /auth/me → Company). Repli en-tête pièces.
  final String? companyRccm;

  /// NIF (impôt) de l'entreprise (source /auth/me → Company).
  final String? companyTaxId;

  /// IdNat de l'entreprise (source /auth/me → Company).
  final String? companyNationalId;

  /// Mode d'activité ('retail'|'restaurant'|'hotel'|'services'). Défaut
  /// 'retail'. Pilote l'affichage modulaire via `ModuleRegistry`.
  final String activityMode;

  /// ID de l'unité commerciale assignée
  final String? businessUnitId;

  /// Code de l'unité (ex: POS-001)
  final String? businessUnitCode;

  /// Type d'unité
  final BusinessUnitType? businessUnitType;

  /// Nom de l'unité (pour affichage et en-tête des pièces commerciales).
  final String? businessUnitName;

  /// `true` si l'unité est une personne morale ayant ses propres identifiants
  /// légaux. Quand vrai et que le user a `unit` scope, les pièces commerciales
  /// (factures, reçus) doivent afficher RCCM/NIF/IDNAT de la BU à la place
  /// de ceux de l'entreprise parente — cas typique du coopérant entreprise.
  final bool businessUnitIsLegalEntity;

  /// RCCM propre à la BU (renseigné si isLegalEntity=true).
  final String? businessUnitRccm;

  /// NIF propre à la BU (renseigné si isLegalEntity=true).
  final String? businessUnitTaxId;

  /// IDNAT propre à la BU (renseigné si isLegalEntity=true).
  final String? businessUnitIdNat;

  /// Adresse de la BU pour en-tête des pièces.
  final String? businessUnitAddress;

  /// Téléphone de la BU pour en-tête des pièces.
  final String? businessUnitPhone;

  /// Scope d'accès: "company" ou "unit"
  final String? scope;

  /// ID de l'utilisateur
  final String? userId;

  /// Rôle de l'utilisateur
  final String? userRole;

  const BusinessContext({
    this.companyId,
    this.companyName,
    this.companyVariant = 'standard',
    this.companyRccm,
    this.companyTaxId,
    this.companyNationalId,
    this.activityMode = 'retail',
    this.businessUnitId,
    this.businessUnitCode,
    this.businessUnitType,
    this.businessUnitName,
    this.businessUnitIsLegalEntity = false,
    this.businessUnitRccm,
    this.businessUnitTaxId,
    this.businessUnitIdNat,
    this.businessUnitAddress,
    this.businessUnitPhone,
    this.scope,
    this.userId,
    this.userRole,
  });

  factory BusinessContext.fromJson(Map<String, dynamic> json) {
    return BusinessContext(
      companyId: json['companyId'] as String?,
      companyName: json['companyName'] as String?,
      companyVariant:
          (json['companyVariant'] as String?) == 'cooperative'
              ? 'cooperative'
              : 'standard',
      companyRccm: json['companyRccm'] as String?,
      companyTaxId: json['companyTaxId'] as String?,
      companyNationalId: json['companyNationalId'] as String?,
      activityMode: json['activityMode'] as String? ?? 'retail',
      businessUnitId: json['businessUnitId'] as String?,
      businessUnitCode: json['businessUnitCode'] as String?,
      businessUnitType:
          json['businessUnitType'] != null
              ? BusinessUnitTypeExtension.fromApiValue(
                json['businessUnitType'] as String,
              )
              : null,
      businessUnitName: json['businessUnitName'] as String?,
      businessUnitIsLegalEntity:
          json['businessUnitIsLegalEntity'] as bool? ?? false,
      businessUnitRccm: json['businessUnitRccm'] as String?,
      businessUnitTaxId: json['businessUnitTaxId'] as String?,
      businessUnitIdNat: json['businessUnitIdNat'] as String?,
      businessUnitAddress: json['businessUnitAddress'] as String?,
      businessUnitPhone: json['businessUnitPhone'] as String?,
      scope: json['scope'] as String?,
      userId: json['userId'] as String?,
      userRole: json['userRole'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'companyId': companyId,
    'companyName': companyName,
    'companyVariant': companyVariant,
    'companyRccm': companyRccm,
    'companyTaxId': companyTaxId,
    'companyNationalId': companyNationalId,
    'activityMode': activityMode,
    'businessUnitId': businessUnitId,
    'businessUnitCode': businessUnitCode,
    'businessUnitType': businessUnitType?.apiValue,
    'businessUnitName': businessUnitName,
    'businessUnitIsLegalEntity': businessUnitIsLegalEntity,
    'businessUnitRccm': businessUnitRccm,
    'businessUnitTaxId': businessUnitTaxId,
    'businessUnitIdNat': businessUnitIdNat,
    'businessUnitAddress': businessUnitAddress,
    'businessUnitPhone': businessUnitPhone,
    'scope': scope,
    'userId': userId,
    'userRole': userRole,
  };

  /// `true` quand l'utilisateur est rattaché à une BU personne morale (coopérant
  /// entreprise) — les pièces commerciales doivent porter les identifiants
  /// de cette BU et non ceux de l'entreprise parente.
  bool get shouldUseBusinessUnitIdentity =>
      scope == 'unit' &&
      businessUnitIsLegalEntity &&
      businessUnitId != null;

  BusinessContext copyWith({
    String? companyId,
    String? companyName,
    String? companyVariant,
    String? companyRccm,
    String? companyTaxId,
    String? companyNationalId,
    String? activityMode,
    String? businessUnitId,
    String? businessUnitCode,
    BusinessUnitType? businessUnitType,
    String? businessUnitName,
    bool? businessUnitIsLegalEntity,
    String? businessUnitRccm,
    String? businessUnitTaxId,
    String? businessUnitIdNat,
    String? businessUnitAddress,
    String? businessUnitPhone,
    String? scope,
    String? userId,
    String? userRole,
  }) {
    return BusinessContext(
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      companyVariant: companyVariant ?? this.companyVariant,
      companyRccm: companyRccm ?? this.companyRccm,
      companyTaxId: companyTaxId ?? this.companyTaxId,
      companyNationalId: companyNationalId ?? this.companyNationalId,
      activityMode: activityMode ?? this.activityMode,
      businessUnitId: businessUnitId ?? this.businessUnitId,
      businessUnitCode: businessUnitCode ?? this.businessUnitCode,
      businessUnitType: businessUnitType ?? this.businessUnitType,
      businessUnitName: businessUnitName ?? this.businessUnitName,
      businessUnitIsLegalEntity:
          businessUnitIsLegalEntity ?? this.businessUnitIsLegalEntity,
      businessUnitRccm: businessUnitRccm ?? this.businessUnitRccm,
      businessUnitTaxId: businessUnitTaxId ?? this.businessUnitTaxId,
      businessUnitIdNat: businessUnitIdNat ?? this.businessUnitIdNat,
      businessUnitAddress: businessUnitAddress ?? this.businessUnitAddress,
      businessUnitPhone: businessUnitPhone ?? this.businessUnitPhone,
      scope: scope ?? this.scope,
      userId: userId ?? this.userId,
      userRole: userRole ?? this.userRole,
    );
  }
}
