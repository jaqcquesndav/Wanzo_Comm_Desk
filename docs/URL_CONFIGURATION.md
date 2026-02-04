# Configuration des URLs et Base URL - Documentation

## Vue d'ensemble

L'application Wanzo Mobile utilise un système de configuration centralisé pour gérer les URLs des différents services backend. Cette configuration est basée sur les variables d'environnement définies dans le fichier `.env`.

## Fichier .env

```env
# Configuration des endpoints API
API_GATEWAY_URL=http://192.168.1.65:8000

# Adresse IP pour le développement sur des appareils physiques
# Remplacez cette valeur par l'adresse IP de votre machine où sont hébergés les services backend
DEV_IP_ADDRESS=192.168.1.65

# Configuration Auth0
AUTH0_DOMAIN=dev-tezmln0tk0g1gouf.eu.auth0.com
AUTH0_CLIENT_ID=PIukJBLfFwQI7slecXaVED61b7ya8IPC
AUTH0_AUDIENCE=https://api.wanzo.com
AUTH0_REDIRECT_URI=com.wanzo.app://dev-tezmln0tk0g1gouf.eu.auth0.com/android/com.wanzo.app/callback
AUTH0_LOGOUT_URI=com.wanzo.app://dev-tezmln0tk0g1gouf.eu.auth0.com/android/com.wanzo.app/callback
AUTH0_SCHEME=com.wanzo.app

# Configuration Cloudinary
CLOUDINARY_CLOUD_NAME=daxvxdecv
CLOUDINARY_UPLOAD_PRESET=ml_default
```

## Structure des URLs

### API Gateway (Point d'entrée principal)
```
http://192.168.1.65:8000  (API_GATEWAY_URL depuis .env)
```

### Préfixe Commerce Service
```
/commerce/api/v1
```

### URL Complète pour Commerce
```
http://192.168.1.65:8000/commerce/api/v1
```

## Classes de Configuration

### EnvConfig (`lib/core/config/env_config.dart`)

Classe principale de configuration qui lit depuis `.env`:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  /// URL de l'API Gateway
  static String get apiGatewayUrl => 
    dotenv.env['API_GATEWAY_URL'] ?? 'http://localhost:8000';
  
  /// Adresse IP pour développement
  static String get devIpAddress => 
    dotenv.env['DEV_IP_ADDRESS'] ?? '192.168.1.65';
  
  /// Préfixe API Commerce
  static const String commerceApiPrefix = 'commerce/api/v1';
  
  /// URL de base complète avec préfixe commerce
  static String get commerceBaseUrl => '$apiGatewayUrl/$commerceApiPrefix';
  
  /// Remplace localhost par DEV_IP_ADDRESS pour appareils physiques
  static String getDeviceCompatibleUrl(String url) {
    final devIpAddress = dotenv.env['DEV_IP_ADDRESS'];
    if (devIpAddress != null && url.contains('localhost')) {
      return url.replaceAll('localhost', devIpAddress);
    }
    return url;
  }
}
```

### ApiClient (`lib/core/services/api_client.dart`)

Service HTTP qui utilise EnvConfig et ajoute automatiquement le préfixe:

```dart
class ApiClient {
  final String _baseUrl;
  
  ApiClient._internal() : 
    _baseUrl = EnvConfig.getBaseUrl(useApiGateway: true);
  
  /// Ajoute automatiquement "commerce/" aux endpoints
  String _addCommercePrefix(String endpoint) {
    if (endpoint.startsWith('commerce/') || endpoint == 'commerce') {
      return endpoint;
    }
    return 'commerce/$endpoint';
  }
  
  Future<dynamic> get(String endpoint, {...}) async {
    final deviceCompatibleBaseUrl = EnvConfig.getDeviceCompatibleUrl(baseUrl);
    final prefixedEndpoint = _addCommercePrefix(endpoint);
    final url = Uri.parse('$deviceCompatibleBaseUrl/$prefixedEndpoint');
    // ...
  }
}
```

## Utilisation dans le Code

### Exemple 1: Appel API Simple

```dart
// L'endpoint est automatiquement préfixé avec "commerce/"
final apiClient = ApiClient();

// Appel: GET http://192.168.1.65:8000/commerce/sales
final sales = await apiClient.get('sales', requiresAuth: true);

// Appel: GET http://192.168.1.65:8000/commerce/products?category=food
final products = await apiClient.get('products', 
  queryParameters: {'category': 'food'},
  requiresAuth: true
);
```

### Exemple 2: Services API Features

```dart
class SalesApiService {
  final ApiClient _apiClient;
  
  SalesApiService() : _apiClient = ApiClient();
  
  Future<List<Sale>> getSales() async {
    // Appelle automatiquement: GET /commerce/sales
    final response = await _apiClient.get('sales', requiresAuth: true);
    // ...
  }
}
```

### Exemple 3: URLs Codées en Dur (À ÉVITER)

❌ **Ancien code (incorrect)**:
```dart
class RegistrationRepository {
  final String _baseUrl = 'https://api.wanzo.app';
}
```

✅ **Nouveau code (correct)**:
```dart
import '../../../core/config/env_config.dart';

class RegistrationRepository {
  String get _baseUrl => EnvConfig.apiGatewayUrl;
}
```

## Endpoints Disponibles

### Format Standard
```
BASE_URL/commerce/api/v1/{endpoint}
```

### Exemples d'Endpoints

| Module | Endpoint | URL Complète |
|--------|----------|--------------|
| Sales | `/sales` | `http://192.168.1.65:8000/commerce/api/v1/sales` |
| Products | `/products` | `http://192.168.1.65:8000/commerce/api/v1/products` |
| Customers | `/customers` | `http://192.168.1.65:8000/commerce/api/v1/customers` |
| Expenses | `/expenses` | `http://192.168.1.65:8000/commerce/api/v1/expenses` |
| Dashboard | `/dashboard/data` | `http://192.168.1.65:8000/commerce/api/v1/dashboard/data` |
| Financing | `/financing/requests` | `http://192.168.1.65:8000/commerce/api/v1/financing/requests` |

## Configuration pour Développement

### Émulateur Android/iOS
Utiliser `http://10.0.2.2:8000` (Android) ou `http://localhost:8000` (iOS)

### Appareil Physique
1. Identifier l'adresse IP de votre machine:
   ```bash
   # Windows
   ipconfig
   
   # macOS/Linux
   ifconfig
   ```

2. Mettre à jour `.env`:
   ```env
   DEV_IP_ADDRESS=192.168.1.65  # Votre adresse IP
   API_GATEWAY_URL=http://192.168.1.65:8000
   ```

3. Redémarrer l'application

## Configuration pour Production

### Fichier `.env.production`
```env
API_GATEWAY_URL=https://api.wanzo.com
DEV_IP_ADDRESS=  # Vide pour production
```

### Build de Production
```bash
flutter build apk --dart-define-from-file=.env.production
```

## Dépannage

### Problème: "Could not connect to server"

**Solution 1**: Vérifier que l'adresse IP est correcte
```dart
// Ajouter dans main.dart pour debug
print('API Gateway URL: ${EnvConfig.apiGatewayUrl}');
print('Commerce Base URL: ${EnvConfig.commerceBaseUrl}');
```

**Solution 2**: Vérifier que le serveur backend est accessible
```bash
# Tester depuis le terminal
curl http://192.168.1.65:8000/commerce/api/v1/health
```

**Solution 3**: Vérifier le pare-feu
- Autoriser le port 8000 sur votre machine
- Sur Windows: `netsh advfirewall firewall add rule name="API Gateway" dir=in action=allow protocol=TCP localport=8000`

### Problème: URLs avec "localhost" sur appareil physique

**Cause**: Le fichier `.env` n'est pas chargé ou DEV_IP_ADDRESS n'est pas défini

**Solution**:
1. Vérifier que `flutter_dotenv` est initialisé dans `main.dart`:
   ```dart
   await dotenv.load(fileName: ".env");
   ```

2. Vérifier que `.env` contient `DEV_IP_ADDRESS`

3. Utiliser `EnvConfig.getDeviceCompatibleUrl()` pour convertir automatiquement

## Bonnes Pratiques

✅ **À FAIRE**:
- Utiliser `EnvConfig` pour toutes les URLs
- Définir `DEV_IP_ADDRESS` dans `.env`
- Tester sur appareil physique avant déploiement
- Utiliser différents fichiers `.env` par environnement

❌ **À ÉVITER**:
- Coder les URLs en dur dans le code
- Utiliser `localhost` sur appareil physique
- Modifier `ApiClient` directement pour changer les URLs
- Commiter les fichiers `.env` avec des données sensibles

## Migration du Code Existant

Si vous avez des URLs codées en dur, suivez ces étapes:

1. Identifier les URLs hardcodées:
   ```bash
   grep -r "http://" lib/ --include="*.dart"
   grep -r "https://" lib/ --include="*.dart"
   ```

2. Remplacer par `EnvConfig`:
   ```dart
   // Avant
   final url = 'https://api.wanzo.app/v1/sales';
   
   // Après
   import '../../../core/config/env_config.dart';
   final url = '${EnvConfig.commerceBaseUrl}/sales';
   ```

3. Tester les changements:
   ```bash
   flutter test
   flutter run --debug
   ```

## Références

- Documentation API Gateway: `API_DOCUMENTATION/COMMERCE_API_DOCUMENTATION.md`
- Configuration Auth0: `API_DOCUMENTATION/auth/README.md`
- Package flutter_dotenv: https://pub.dev/packages/flutter_dotenv
