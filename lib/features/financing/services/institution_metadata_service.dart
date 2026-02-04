import 'package:hive/hive.dart';
import '../models/institution_metadata.dart';
import '../models/financing_request.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/logging_service.dart';

/// Service pour gérer les métadonnées des institutions financières
class InstitutionMetadataService {
  static const _metadataBoxName = 'institution_metadata';
  late final Box<InstitutionMetadata> _metadataBox;
  // ignore: unused_field - Reserved for future API integration
  final ApiClient _apiClient;

  // Cache des métadonnées par institution
  final Map<FinancialInstitution, InstitutionMetadata> _cache = {};

  InstitutionMetadataService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Initialisation du service
  Future<void> init() async {
    try {
      _metadataBox = await Hive.openBox<InstitutionMetadata>(_metadataBoxName);
      await _loadCacheFromLocal();
    } catch (e) {
      LoggingService.instance.error(
        'Error opening institution metadata box',
        error: e,
      );
      await Hive.deleteBoxFromDisk(_metadataBoxName);
      _metadataBox = await Hive.openBox<InstitutionMetadata>(_metadataBoxName);
    }
  }

  /// Charge le cache depuis le stockage local
  Future<void> _loadCacheFromLocal() async {
    for (final metadata in _metadataBox.values) {
      _cache[metadata.institution] = metadata;
    }
  }

  /// Récupère les métadonnées pour une institution spécifique
  Future<InstitutionMetadata?> getInstitutionMetadata(
    FinancialInstitution institution,
  ) async {
    // Vérifier le cache d'abord
    if (_cache.containsKey(institution)) {
      final cached = _cache[institution]!;
      // Si les données sont récentes (< 24h), les retourner
      if (DateTime.now().difference(cached.lastUpdated).inHours < 24) {
        return cached;
      }
    }

    // Sinon, récupérer depuis l'API
    try {
      final metadata = await _fetchFromApi(institution);
      if (metadata != null) {
        await _saveToCache(metadata);
        return metadata;
      }
    } catch (e) {
      LoggingService.instance.error(
        'Error fetching metadata from API',
        error: e,
      );
    }

    // En cas d'erreur, retourner les données du cache si disponibles
    return _cache[institution];
  }

  /// Récupère toutes les métadonnées disponibles
  Future<List<InstitutionMetadata>> getAllInstitutionMetadata() async {
    final List<InstitutionMetadata> results = [];

    for (final institution in FinancialInstitution.values) {
      final metadata = await getInstitutionMetadata(institution);
      if (metadata != null) {
        results.add(metadata);
      }
    }

    return results;
  }

  /// Récupère les produits financiers pour une institution
  Future<List<FinancialProductInfo>> getProductsForInstitution(
    FinancialInstitution institution,
  ) async {
    final metadata = await getInstitutionMetadata(institution);
    return metadata?.availableProducts ?? [];
  }

  /// Récupère l'ID du portefeuille pour une institution
  Future<String?> getPortfolioId(FinancialInstitution institution) async {
    final metadata = await getInstitutionMetadata(institution);
    return metadata?.portfolioId;
  }

  /// Récupère depuis l'API
  /// Note: L'endpoint portfolio_inst n'existe pas dans l'API commerce.
  /// Les métadonnées des institutions sont récupérées via financing/products
  /// et les données sont mises en cache localement.
  Future<InstitutionMetadata?> _fetchFromApi(
    FinancialInstitution institution,
  ) async {
    try {
      // L'API commerce n'expose pas d'endpoint direct pour les métadonnées d'institutions.
      // Les produits de financement sont disponibles via financing/products.
      // Pour l'instant, on retourne null et on utilise les données en cache.
      // TODO: Implémenter un endpoint côté backend ou utiliser financing/products
      LoggingService.instance.warning(
        'Institution metadata endpoint not available for ${institution.toString().split('.').last}. '
        'Using cached data if available.',
      );
      return null;
    } catch (e) {
      LoggingService.instance.error('API error', error: e);
    }

    return null;
  }

  /// Sauvegarde dans le cache local et Hive
  Future<void> _saveToCache(InstitutionMetadata metadata) async {
    _cache[metadata.institution] = metadata;
    await _metadataBox.put(metadata.institution.toString(), metadata);
  }

  /// Force la mise à jour des métadonnées depuis l'API
  Future<void> refreshMetadata([
    FinancialInstitution? specificInstitution,
  ]) async {
    if (specificInstitution != null) {
      final metadata = await _fetchFromApi(specificInstitution);
      if (metadata != null) {
        await _saveToCache(metadata);
      }
    } else {
      for (final institution in FinancialInstitution.values) {
        final metadata = await _fetchFromApi(institution);
        if (metadata != null) {
          await _saveToCache(metadata);
        }
      }
    }
  }

  /// Nettoie le cache expiré
  Future<void> clearExpiredCache() async {
    final now = DateTime.now();
    final expiredKeys = <FinancialInstitution>[];

    for (final entry in _cache.entries) {
      if (now.difference(entry.value.lastUpdated).inDays > 7) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _cache.remove(key);
      await _metadataBox.delete(key.toString());
    }
  }

  /// Données de fallback pour les institutions si l'API n'est pas disponible
  InstitutionMetadata _getFallbackMetadata(FinancialInstitution institution) {
    final Map<FinancialInstitution, Map<String, dynamic>> fallbackData = {
      FinancialInstitution.bonneMoisson: {
        'portfolio_id': 'portfolio_bonne_moisson',
        'institution_name': 'Bonne Moisson',
        'available_products': [
          {
            'product_id': 'bm_credit_tresorerie',
            'product_type': 'cashFlow',
            'product_name': 'Crédit de Trésorerie',
            'description':
                'Financement de court terme pour vos besoins de trésorerie',
            'min_amount': 100000.0,
            'max_amount': 5000000.0,
            'min_duration_months': 1,
            'max_duration_months': 12,
            'base_interest_rate': 12.0,
            'required_documents': [
              'Bilan',
              'Compte de résultat',
              'Business plan',
            ],
            'product_config': {},
          },
          {
            'product_id': 'bm_credit_investissement',
            'product_type': 'investment',
            'product_name': 'Crédit d\'Investissement',
            'description': 'Financement pour vos projets d\'investissement',
            'min_amount': 500000.0,
            'max_amount': 50000000.0,
            'min_duration_months': 12,
            'max_duration_months': 60,
            'base_interest_rate': 10.5,
            'required_documents': [
              'Bilan',
              'Compte de résultat',
              'Business plan',
              'Étude de faisabilité',
            ],
            'product_config': {},
          },
        ],
      },
      FinancialInstitution.equitybcdc: {
        'portfolio_id': 'portfolio_equity_bcdc',
        'institution_name': 'EquityBCDC',
        'available_products': [
          {
            'product_id': 'eq_credit_tresorerie',
            'product_type': 'cashFlow',
            'product_name': 'Facilité de Trésorerie',
            'description': 'Solutions de financement de trésorerie flexibles',
            'min_amount': 200000.0,
            'max_amount': 10000000.0,
            'min_duration_months': 3,
            'max_duration_months': 18,
            'base_interest_rate': 11.5,
            'required_documents': [
              'États financiers',
              'Prévisions de trésorerie',
            ],
            'product_config': {},
          },
        ],
      },
      // Ajouter d'autres institutions selon les besoins
    };

    final data = fallbackData[institution];
    if (data != null) {
      data['institution'] = institution.toString().split('.').last;
      data['last_updated'] = DateTime.now().toIso8601String();
      return InstitutionMetadata.fromJson(data);
    }

    // Données par défaut minimales
    return InstitutionMetadata(
      institution: institution,
      portfolioId: 'default_portfolio',
      institutionName: institution.displayName,
      availableProducts: [],
      institutionConfig: {},
      lastUpdated: DateTime.now(),
    );
  }

  /// Récupère les métadonnées avec fallback
  Future<InstitutionMetadata> getInstitutionMetadataWithFallback(
    FinancialInstitution institution,
  ) async {
    final metadata = await getInstitutionMetadata(institution);
    return metadata ?? _getFallbackMetadata(institution);
  }
}
