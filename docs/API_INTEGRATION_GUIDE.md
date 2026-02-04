# Guide d'intégration API pour Wanzo

## Structure des URLs API

Dans notre application Flutter, toutes les requêtes API sont gérées de manière centralisée via la classe `ApiClient`. Cette classe s'occupe de :

1. Ajouter automatiquement le préfixe `/commerce/` à tous les endpoints
2. Gérer l'authentification avec les tokens JWT
3. Traiter les réponses standardisées

## Exemples d'utilisation

### Appel d'un endpoint

Pour appeler un endpoint, vous pouvez simplement spécifier le chemin sans le préfixe `/commerce/`:

```dart
// Exemple d'utilisation d'un service API
Future<ApiResponse<List<Product>>> getProducts() async {
  // L'ApiClient ajoutera automatiquement "commerce/" à "products"
  final response = await _apiClient.get('products', requiresAuth: true);
  // Traitement de la réponse
}
```

### Points importants à retenir

1. **Ne pas inclure le préfixe `/commerce/`** dans les appels d'API dans vos services spécifiques. Ce préfixe est automatiquement ajouté par la classe `ApiClient`.

2. **Format de réponse standardisé** : Toutes les réponses suivent un format standardisé avec les champs `success`, `message`, `statusCode`, et `data`.

3. **Authentification** : Tous les appels qui nécessitent une authentification doivent inclure le paramètre `requiresAuth: true`.

## Adaptation des services existants

Si vous avez des services existants qui incluent déjà le préfixe `/commerce/`, vous n'avez pas besoin de les modifier. La méthode `_addCommercePrefix` dans `ApiClient` vérifie si le préfixe existe déjà avant de l'ajouter.

## Configuration des URLs et environnements

### Configuration de la base URL

Assurez-vous que votre fichier `.env` est correctement configuré selon l'environnement :

#### 1. Développement avec émulateur
```
API_GATEWAY_URL=http://localhost:8000
```

#### 2. Développement avec appareil physique
```
API_GATEWAY_URL=http://192.168.1.65:8000
DEV_IP_ADDRESS=192.168.1.65
```
Remplacez `192.168.1.65` par l'adresse IP de votre machine de développement.

#### 3. Environnement de staging/test
```
API_GATEWAY_URL=https://api-staging.wanzo.com
```

#### 4. Environnement de production
```
API_GATEWAY_URL=https://api.wanzo.com
```

### Timeouts configurés

Le client API utilise maintenant les timeouts recommandés par le backend :
- **Timeout de connexion** : 10 secondes
- **Timeout de réception** : 15 secondes

### Configuration Android

Les permissions réseau sont automatiquement configurées avec :
- Autorisation du trafic HTTP en développement via `network_security_config.xml`
- Support des adresses IP locales et localhost
- Configuration sécurisée pour la production

### Comment fonctionne la gestion des URLs

1. `EnvConfig.getBaseUrl()` récupère l'URL de base depuis les variables d'environnement
2. `EnvConfig.getDeviceCompatibleUrl()` transforme les URLs avec "localhost" en utilisant l'adresse IP réelle définie dans `DEV_IP_ADDRESS`
3. `ApiClient` ajoute automatiquement le préfixe "/commerce/" aux endpoints si nécessaire
4. Les timeouts sont appliqués automatiquement à toutes les requêtes

Cette configuration assure que votre application mobile communique correctement avec le backend, que ce soit en développement ou en production, tout en respectant les recommandations du backend.

## Troubleshooting

Si vous rencontrez des erreurs 404, vérifiez :
1. Que l'URL complète de la requête inclut bien le préfixe `/commerce/`
2. Que l'endpoint existe bien dans la documentation de l'API

## Référence

Pour plus de détails sur les endpoints disponibles, consultez le fichier `COMMERCE_API_DOCUMENTATION.md` à la racine du projet.
