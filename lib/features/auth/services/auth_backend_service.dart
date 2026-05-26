import 'package:flutter/material.dart';
import '../../../core/services/api_client.dart';
import '../../../core/exceptions/api_exceptions.dart';
import '../models/user.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';

/// Service pour récupérer les informations utilisateur depuis le backend
/// après authentification Auth0.
///
/// Ce service est responsable de:
/// 1. Récupérer le profil complet de l'utilisateur incluant companyId (UUID)
/// 2. Récupérer les informations de l'entreprise et de l'unité commerciale
/// 3. Synchroniser les données Auth0 avec le backend
/// 4. Mettre à jour le profil utilisateur
class AuthBackendService {
  final ApiClient _apiClient;

  AuthBackendService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Récupère le profil utilisateur complet depuis le backend
  ///
  /// Appelle GET /auth/me après authentification Auth0 (endpoint recommandé)
  /// Retourne une structure complète incluant:
  /// - user: Données de l'utilisateur avec companyId et businessUnitId
  /// - company: Informations de l'entreprise
  /// - businessUnit: Informations de l'unité commerciale avec scope
  /// - syncStatus: État de synchronisation Kafka (cas 3)
  Future<AuthMeResponse?> fetchAuthMe() async {
    try {
      debugPrint(
        'AuthBackendService: Fetching complete auth profile from backend /auth/me',
      );

      final response = await _apiClient.get('auth/me', requiresAuth: true);

      // ignore: avoid_print
      print('');
      // ignore: avoid_print
      print('╔══════════════════════════════════════════════════════════════');
      // ignore: avoid_print
      print('║ 👤 /auth/me RESPONSE');
      // ignore: avoid_print
      print('╠══════════════════════════════════════════════════════════════');
      // ignore: avoid_print
      print('║ success: ${response?['success']}');
      // ignore: avoid_print
      print('║ data keys: ${(response?['data'] as Map?)?.keys.toList()}');
      if (response?['data']?['user'] != null) {
        final user = response!['data']['user'];
        // ignore: avoid_print
        print('║ user.id: ${user['id']}');
        // ignore: avoid_print
        print('║ user.email: ${user['email']}');
        // ignore: avoid_print
        print('║ user.companyId: ${user['companyId']}');
        // ignore: avoid_print
        print('║ user.businessUnitId: ${user['businessUnitId']}');
      }
      if (response?['data']?['company'] != null) {
        final company = response!['data']['company'];
        // ignore: avoid_print
        print('║ company.id: ${company['id']}');
        // ignore: avoid_print
        print('║ company.name: ${company['name']}');
      } else {
        // ignore: avoid_print
        print('║ company: null');
      }
      // ignore: avoid_print
      print('╚══════════════════════════════════════════════════════════════');
      // ignore: avoid_print
      print('');

      if (response != null && response['success'] == true) {
        var data = response['data'] as Map<String, dynamic>?;
        if (data != null) {
          debugPrint('AuthBackendService: Auth profile fetched successfully.');
          debugPrint(
            'AuthBackendService: Raw data keys: ${data.keys.toList()}',
          );

          // Handle double-envelope response structure from backend
          // Backend might return: {success, data: {success, data: {user, company, businessUnit}}}
          if (data.containsKey('success') && data.containsKey('data')) {
            debugPrint(
              'AuthBackendService: Detected double-envelope response, unwrapping...',
            );
            final innerData = data['data'];
            if (innerData is Map<String, dynamic>) {
              data = innerData;
              debugPrint(
                'AuthBackendService: Unwrapped data keys: ${data.keys.toList()}',
              );
            }
          }

          // Check for user data in different possible structures
          final userData = data['user'] as Map<String, dynamic>?;
          if (userData != null) {
            debugPrint(
              'AuthBackendService: User data keys: ${userData.keys.toList()}',
            );
            debugPrint(
              'AuthBackendService: User id: ${userData['id']}, email: ${userData['email']}, companyId: ${userData['companyId']}',
            );
          } else {
            debugPrint(
              'AuthBackendService: No nested user object, checking flat structure',
            );
            debugPrint(
              'AuthBackendService: id: ${data['id']}, email: ${data['email']}, companyId: ${data['companyId']}',
            );
          }

          return AuthMeResponse.fromJson(data);
        }
      }

      debugPrint('AuthBackendService: Failed to parse auth/me response');
      return null;
    } on NetworkException catch (e) {
      debugPrint(
        'AuthBackendService: Network error fetching auth profile: ${e.message}',
      );
      return null;
    } on ApiException catch (e) {
      debugPrint(
        'AuthBackendService: API error fetching auth profile: ${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint(
        'AuthBackendService: Unexpected error fetching auth profile: $e',
      );
      return null;
    }
  }

  /// Méthode legacy pour compatibilité - retourne BackendUserProfile
  Future<BackendUserProfile?> fetchUserProfile() async {
    final authMe = await fetchAuthMe();
    return authMe?.user;
  }

  /// Synchronise les données Auth0 avec le backend
  ///
  /// Appelle POST /auth/sync pour créer/mettre à jour l'utilisateur
  /// côté backend avec les données Auth0
  Future<BackendUserProfile?> syncAuth0User(
    Map<String, dynamic> auth0UserData,
  ) async {
    try {
      debugPrint('AuthBackendService: Syncing Auth0 user with backend');

      final response = await _apiClient.post(
        'auth/sync',
        body: {'auth0Data': auth0UserData},
        requiresAuth: true,
      );

      if (response != null && response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>?;
        if (data != null) {
          debugPrint(
            'AuthBackendService: Auth0 user synced successfully. CompanyId: ${data['companyId']}',
          );
          return BackendUserProfile.fromJson(data);
        }
      }

      debugPrint('AuthBackendService: Failed to sync Auth0 user');
      return null;
    } on NetworkException catch (e) {
      debugPrint(
        'AuthBackendService: Network error syncing user: ${e.message}',
      );
      return null;
    } on ApiException catch (e) {
      debugPrint('AuthBackendService: API error syncing user: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('AuthBackendService: Unexpected error syncing user: $e');
      return null;
    }
  }

  /// Met à jour le profil utilisateur sur le backend
  Future<BackendUserProfile?> updateUserProfile(
    Map<String, dynamic> updates,
  ) async {
    try {
      debugPrint('AuthBackendService: Updating user profile on backend');

      final response = await _apiClient.put(
        'users/me',
        body: updates,
        requiresAuth: true,
      );

      if (response != null && response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>?;
        if (data != null) {
          debugPrint('AuthBackendService: User profile updated successfully');
          return BackendUserProfile.fromJson(data);
        }
      }

      debugPrint('AuthBackendService: Failed to update user profile');
      return null;
    } catch (e) {
      debugPrint('AuthBackendService: Error updating profile: $e');
      return null;
    }
  }

  /// Rejoint une unité d'affaires via son code
  ///
  /// Appelle POST /settings-user-profile/company/join-business-unit
  /// Le code est communiqué par l'admin de l'entreprise.
  Future<JoinBusinessUnitResponse> joinBusinessUnit(
    String businessUnitCode,
  ) async {
    try {
      debugPrint(
        'AuthBackendService: Joining business unit with code: $businessUnitCode',
      );

      final response = await _apiClient.post(
        'settings-user-profile/company/join-business-unit',
        body: {'businessUnitCode': businessUnitCode},
        requiresAuth: true,
      );

      if (response != null && response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>?;
        if (data != null) {
          debugPrint('AuthBackendService: Successfully joined business unit');
          return JoinBusinessUnitResponse.fromJson(
            data,
            message: response['message'] as String?,
          );
        }
      }

      throw BadRequestException(
        response?['message'] as String? ??
            'Échec de la jonction à l\'unité d\'affaires',
      );
    } on NetworkException {
      rethrow;
    } on BadRequestException {
      rethrow;
    } on NotFoundException {
      rethrow;
    } catch (e) {
      debugPrint('AuthBackendService: Error joining business unit: $e');
      throw BadRequestException(e.toString());
    }
  }
}

/// Modèle représentant le profil utilisateur retourné par le backend
///
/// Contient toutes les informations business incluant le companyId UUID
class BackendUserProfile {
  /// ID de l'utilisateur (UUID)
  final String id;

  /// Email de l'utilisateur
  final String email;

  /// Prénom
  final String? firstName;

  /// Nom de famille
  final String? lastName;

  /// Nom complet
  final String? fullName;

  /// Numéro de téléphone
  final String? phone;

  /// Rôle de l'utilisateur (owner, admin, employee, etc.)
  final String role;

  /// ID de l'entreprise (UUID) - Champ critique pour toutes les opérations
  final String? companyId;

  /// Nom de l'entreprise
  final String? companyName;

  /// Numéro RCCM de l'entreprise
  final String? rccmNumber;

  /// Localisation de l'entreprise
  final String? companyLocation;

  /// Adresse business
  final String? businessAddress;

  /// Secteur d'activité
  final String? businessSector;

  /// ID du secteur d'activité
  final String? businessSectorId;

  /// URL du logo business
  final String? businessLogoUrl;

  /// Photo de profil
  final String? picture;

  /// Titre du poste
  final String? jobTitle;

  /// Adresse physique
  final String? physicalAddress;

  /// Statut de vérification de l'email
  final bool emailVerified;

  /// Statut de vérification du téléphone
  final bool phoneVerified;

  /// Carte d'identité
  final String? idCard;

  /// Statut de la carte d'identité
  final String? idCardStatus;

  /// Raison du statut de la carte d'identité
  final String? idCardStatusReason;

  // ============= BUSINESS UNIT FIELDS =============

  /// ID de l'unité commerciale assignée
  final String? businessUnitId;

  /// Type d'unité: "COMPANY", "BRANCH", "POS"
  final String? businessUnitType;

  /// Indique si l'utilisateur est actif
  final bool isActive;

  /// Date de création
  final DateTime? createdAt;

  /// Date de mise à jour
  final DateTime? updatedAt;

  const BackendUserProfile({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.fullName,
    this.phone,
    required this.role,
    this.companyId,
    this.companyName,
    this.rccmNumber,
    this.companyLocation,
    this.businessAddress,
    this.businessSector,
    this.businessSectorId,
    this.businessLogoUrl,
    this.picture,
    this.jobTitle,
    this.physicalAddress,
    required this.emailVerified,
    required this.phoneVerified,
    this.idCard,
    this.idCardStatus,
    this.idCardStatusReason,
    this.businessUnitId,
    this.businessUnitType,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory BackendUserProfile.fromJson(Map<String, dynamic> json) {
    return BackendUserProfile(
      id: (json['id'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      fullName:
          json['fullName'] as String? ??
          '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim(),
      phone: json['phone'] as String?,
      role: (json['role'] as String?) ?? 'user',
      companyId: json['companyId'] as String?,
      companyName: json['companyName'] as String?,
      rccmNumber: json['rccmNumber'] as String?,
      companyLocation: json['companyLocation'] as String?,
      businessAddress: json['businessAddress'] as String?,
      businessSector: json['businessSector'] as String?,
      businessSectorId: json['businessSectorId'] as String?,
      businessLogoUrl: json['businessLogoUrl'] as String?,
      picture: json['picture'] as String?,
      jobTitle: json['jobTitle'] as String?,
      physicalAddress: json['physicalAddress'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
      phoneVerified: json['phoneVerified'] as bool? ?? false,
      idCard: json['idCard'] as String?,
      idCardStatus: json['idCardStatus'] as String?,
      idCardStatusReason: json['idCardStatusReason'] as String?,
      businessUnitId: json['businessUnitId'] as String?,
      businessUnitType: json['businessUnitType'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt:
          json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'] as String)
              : null,
      updatedAt:
          json['updatedAt'] != null
              ? DateTime.tryParse(json['updatedAt'] as String)
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'fullName': fullName,
    'phone': phone,
    'role': role,
    'companyId': companyId,
    'companyName': companyName,
    'rccmNumber': rccmNumber,
    'companyLocation': companyLocation,
    'businessAddress': businessAddress,
    'businessSector': businessSector,
    'businessSectorId': businessSectorId,
    'businessLogoUrl': businessLogoUrl,
    'picture': picture,
    'jobTitle': jobTitle,
    'physicalAddress': physicalAddress,
    'emailVerified': emailVerified,
    'phoneVerified': phoneVerified,
    'idCard': idCard,
    'idCardStatus': idCardStatus,
    'idCardStatusReason': idCardStatusReason,
    'businessUnitId': businessUnitId,
    'businessUnitType': businessUnitType,
    'isActive': isActive,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  /// Vérifie si le companyId est un UUID valide
  bool get hasValidCompanyId {
    if (companyId == null || companyId!.isEmpty) return false;
    // Regex pour UUID v4
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(companyId!);
  }

  /// Convertit vers le modèle User de l'app
  ///
  /// [businessUnit] et [company] permettent le fallback RCCM/NIF:
  /// RCCM affiché = BU.registrationNumber > Company.registrationNumber > User.rccmNumber
  /// NIF affiché  = BU.taxId > Company.taxId
  User toUser({
    String? token,
    BackendBusinessUnit? businessUnit,
    BackendCompany? company,
  }) {
    // Logique de fallback RCCM/NIF comme spécifié par le backend
    final effectiveRccm =
        businessUnit?.registrationNumber ??
        company?.registrationNumber ??
        rccmNumber;
    final effectiveCompanyName = company?.name ?? companyName;
    final effectiveLogoUrl = company?.logoUrl ?? businessLogoUrl;
    final effectiveLocation = company?.address ?? companyLocation;
    final effectiveSector = company?.sector ?? businessSector;

    return User(
      id: id,
      name: fullName ?? '$firstName $lastName'.trim(),
      email: email,
      phone: phone ?? '',
      role: role,
      token: token,
      picture: picture,
      jobTitle: jobTitle,
      physicalAddress: physicalAddress,
      idCard: idCard,
      idCardStatus: _parseIdStatus(idCardStatus),
      idCardStatusReason: idCardStatusReason,
      companyId: companyId,
      companyName: effectiveCompanyName,
      rccmNumber: effectiveRccm,
      companyLocation: effectiveLocation,
      businessSector: effectiveSector,
      businessSectorId: businessSectorId,
      businessAddress: businessAddress,
      businessLogoUrl: effectiveLogoUrl,
      emailVerified: emailVerified,
      phoneVerified: phoneVerified,
      // Business Unit fields from /auth/me response
      businessUnitId: businessUnitId ?? businessUnit?.id,
      businessUnitCode: businessUnit?.code,
      businessUnitType:
          businessUnitType != null
              ? BusinessUnitTypeExtension.fromApiValue(businessUnitType!)
              : businessUnit?.type != null
              ? BusinessUnitTypeExtension.fromApiValue(businessUnit!.type!)
              : null,
      isActive: isActive,
    );
  }

  IdStatus _parseIdStatus(String? statusString) {
    if (statusString == null) return IdStatus.UNKNOWN;
    switch (statusString.toUpperCase()) {
      case 'PENDING':
        return IdStatus.PENDING;
      case 'VERIFIED':
        return IdStatus.VERIFIED;
      case 'REJECTED':
        return IdStatus.REJECTED;
      default:
        return IdStatus.UNKNOWN;
    }
  }
}

/// Réponse complète du endpoint /auth/me
///
/// 3 cas possibles:
/// - Cas 1: Profil complet (user + company + BU confirmée, scope unit)
/// - Cas 2: Admin/Manager sans BU spécifique (scope company)
/// - Cas 3: Synchronisation Kafka en cours (syncStatus.pending == true)
class AuthMeResponse {
  /// Profil utilisateur complet
  final BackendUserProfile user;

  /// Informations de l'entreprise (null en cas 3 — sync Kafka en cours)
  final BackendCompany? company;

  /// Informations de l'unité commerciale avec scope
  final BackendBusinessUnit? businessUnit;

  /// État de synchronisation (présent uniquement en cas 3)
  final SyncStatus? syncStatus;

  const AuthMeResponse({
    required this.user,
    this.company,
    this.businessUnit,
    this.syncStatus,
  });

  factory AuthMeResponse.fromJson(Map<String, dynamic> json) {
    // Support both nested structure and flat structure
    final userData = json['user'] as Map<String, dynamic>? ?? json;
    final companyData = json['company'] as Map<String, dynamic>?;
    final businessUnitData = json['businessUnit'] as Map<String, dynamic>?;
    final syncStatusData = json['syncStatus'] as Map<String, dynamic>?;

    return AuthMeResponse(
      user: BackendUserProfile.fromJson(userData),
      company:
          companyData != null ? BackendCompany.fromJson(companyData) : null,
      businessUnit:
          businessUnitData != null
              ? BackendBusinessUnit.fromJson(businessUnitData)
              : null,
      syncStatus:
          syncStatusData != null ? SyncStatus.fromJson(syncStatusData) : null,
    );
  }

  /// Convertit vers le modèle User de l'app avec toutes les données enrichies
  User toUser({String? token}) {
    return user.toUser(
      token: token,
      businessUnit: businessUnit,
      company: company,
    );
  }

  /// Vérifie si la synchronisation Kafka est en cours (cas 3)
  bool get isSyncPending => syncStatus?.pending == true;

  /// Vérifie si l'utilisateur non-admin doit rejoindre une BU
  bool get needsBusinessUnitJoin {
    final role = user.role.toLowerCase();
    final isAdminOrManager = role == 'admin' || role == 'manager';
    if (isAdminOrManager) return false;
    return user.businessUnitId == null || user.businessUnitId!.isEmpty;
  }

  /// Vérifie si l'utilisateur a un accès niveau entreprise
  bool get hasCompanyScope => businessUnit?.scope == 'company';

  /// Vérifie si l'utilisateur est limité à une unité
  bool get hasUnitScope => businessUnit?.scope == 'unit';
}

/// État de synchronisation Kafka (cas 3 de /auth/me)
class SyncStatus {
  final bool pending;
  final String? message;

  const SyncStatus({required this.pending, this.message});

  factory SyncStatus.fromJson(Map<String, dynamic> json) {
    return SyncStatus(
      pending: json['pending'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }
}

/// Réponse du endpoint POST /settings-user-profile/company/join-business-unit
class JoinBusinessUnitResponse {
  final bool success;
  final String businessUnitId;
  final String businessUnitCode;
  final String businessUnitType;
  final String businessUnitName;
  final String? message;

  const JoinBusinessUnitResponse({
    required this.success,
    required this.businessUnitId,
    required this.businessUnitCode,
    required this.businessUnitType,
    required this.businessUnitName,
    this.message,
  });

  factory JoinBusinessUnitResponse.fromJson(
    Map<String, dynamic> json, {
    String? message,
  }) {
    return JoinBusinessUnitResponse(
      success: true,
      businessUnitId: (json['businessUnitId'] as String?) ?? '',
      businessUnitCode: (json['businessUnitCode'] as String?) ?? '',
      businessUnitType: (json['businessUnitType'] as String?) ?? '',
      businessUnitName: (json['businessUnitName'] as String?) ?? '',
      message: message ?? json['message'] as String?,
    );
  }
}

/// Informations de l'entreprise retournées par /auth/me
/// Enrichi avec les champs légaux et métadonnées exposés par le backend
class BackendCompany {
  final String id;
  final String name;
  final String? registrationNumber; // RCCM
  final String? taxId; // NIF
  final String? nationalId; // IdNat
  final String? sector; // Secteur d'activité
  final String? legalForm; // Forme juridique (SARL, SA...)
  final double? capital; // Capital social
  final String? capitalCurrency; // Devise du capital

  /// Variant d'opération : 'standard' (PME classique) ou 'cooperative'.
  /// Pilote le vocabulaire métier de l'UI (succursale ↔ coopérant,
  /// entreprise ↔ coopérative) sans changer la logique applicative.
  /// Default 'standard' si absent (compat ascendante).
  final String variant;
  final String? logoUrl; // URL du logo
  final String? address;
  final String? city;
  final String? province;
  final String? country;
  final String? phone;
  final String? email;
  final String? website;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BackendCompany({
    required this.id,
    required this.name,
    this.registrationNumber,
    this.taxId,
    this.nationalId,
    this.sector,
    this.legalForm,
    this.capital,
    this.capitalCurrency,
    this.logoUrl,
    this.address,
    this.city,
    this.province,
    this.country,
    this.phone,
    this.email,
    this.website,
    this.isActive = true,
    this.variant = 'standard',
    this.createdAt,
    this.updatedAt,
  });

  factory BackendCompany.fromJson(Map<String, dynamic> json) {
    return BackendCompany(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      registrationNumber: json['registrationNumber'] as String?,
      taxId: json['taxId'] as String?,
      nationalId: json['nationalId'] as String?,
      sector: json['sector'] as String?,
      legalForm: json['legalForm'] as String?,
      capital: (json['capital'] as num?)?.toDouble(),
      capitalCurrency: json['capitalCurrency'] as String?,
      logoUrl: json['logoUrl'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      country: json['country'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      variant: (json['variant'] as String?) == 'cooperative'
          ? 'cooperative'
          : 'standard',
      createdAt:
          json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'] as String)
              : null,
      updatedAt:
          json['updatedAt'] != null
              ? DateTime.tryParse(json['updatedAt'] as String)
              : null,
    );
  }
}

/// Informations de l'unité commerciale retournées par /auth/me
/// Enrichi avec les champs légaux RCCM/NIF propres à la succursale
class BackendBusinessUnit {
  final String id;
  final String name;
  final String code;
  final String? type; // "company", "branch", "pos"

  /// `true` si la BU est une personne morale (autre entreprise, coopérant
  /// entreprise). Conditionne l'usage de RCCM/NIF/IDNAT propres à la BU
  /// sur les pièces commerciales (factures, reçus, tickets de caisse).
  final bool isLegalEntity;
  final String? registrationNumber; // RCCM propre à la succursale
  final String? taxId; // NIF propre à la succursale
  final String? idNat; // Identification Nationale propre à la succursale
  final int? hierarchyLevel;
  final String? hierarchyPath;
  final String? parentId;
  final String? address;
  final String? city;
  final String? province;
  final String? country;
  final String? phone;
  final String? email;
  final String? currency;
  final String? timezone;
  final String? managerId;
  final String? managerName;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Scope d'accès:
  /// - "company": Accès niveau entreprise (admin/super_admin sans businessUnitId)
  /// - "unit": Limité à cette unité (utilisateurs assignés)
  final String? scope;

  const BackendBusinessUnit({
    required this.id,
    required this.name,
    required this.code,
    this.type,
    this.isLegalEntity = false,
    this.registrationNumber,
    this.taxId,
    this.idNat,
    this.hierarchyLevel,
    this.hierarchyPath,
    this.parentId,
    this.address,
    this.city,
    this.province,
    this.country,
    this.phone,
    this.email,
    this.currency,
    this.timezone,
    this.managerId,
    this.managerName,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.scope,
  });

  factory BackendBusinessUnit.fromJson(Map<String, dynamic> json) {
    return BackendBusinessUnit(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      code: (json['code'] as String?) ?? '',
      type: json['type'] as String?,
      isLegalEntity: json['isLegalEntity'] as bool? ?? false,
      registrationNumber: json['registrationNumber'] as String?,
      taxId: json['taxId'] as String?,
      idNat: json['idNat'] as String?,
      hierarchyLevel: json['hierarchyLevel'] as int?,
      hierarchyPath: json['hierarchyPath'] as String?,
      parentId: json['parentId'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      country: json['country'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      currency: json['currency'] as String?,
      timezone: json['timezone'] as String?,
      managerId: json['managerId'] as String?,
      managerName: json['managerName'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt:
          json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'] as String)
              : null,
      updatedAt:
          json['updatedAt'] != null
              ? DateTime.tryParse(json['updatedAt'] as String)
              : null,
      scope: json['scope'] as String?,
    );
  }
}
