# Guide de Bonnes Pratiques pour les Services API

## Introduction

Ce document définit les standards et bonnes pratiques à suivre lors de la création ou modification des services API dans l'application Wanzo.

## Structure Standard

### 1. Définition d'Interface

Chaque service API doit d'abord définir une interface abstraite claire :

```dart
abstract class SomeEntityApiService {
  Future<ApiResponse<List<SomeEntity>>> getEntities({
    int? page,
    int? limit,
    String? sortBy,
    String? sortOrder,
    // autres paramètres de filtre pertinents
  });

  Future<ApiResponse<SomeEntity>> createEntity(SomeEntity entity, {File? attachment});

  Future<ApiResponse<SomeEntity>> getEntityById(String id);

  Future<ApiResponse<SomeEntity>> updateEntity(String id, SomeEntity entity, {File? attachment});

  Future<ApiResponse<void>> deleteEntity(String id);
}
```

### 2. Classe d'Implémentation

```dart
class SomeEntityApiServiceImpl implements SomeEntityApiService {
  final ApiClient _apiClient;

  SomeEntityApiServiceImpl(this._apiClient);

  // Implémentations des méthodes...
}
```

## Utilisation de ApiResponse

Toutes les méthodes API doivent renvoyer un objet `ApiResponse<T>` :

```dart
Future<ApiResponse<T>> someApiMethod() async {
  try {
    // Logique d'appel API...
    
    // Succès
    return ApiResponse<T>(
      success: true,
      data: result,
      message: 'Opération réussie',
      statusCode: 200,
    );
  } catch (e) {
    // Échec
    return ApiResponse<T>(
      success: false,
      data: null,
      message: 'Échec de l'opération: ${e.toString()}',
      statusCode: 500,
    );
  }
}
```

## Gestion des Erreurs

Toutes les méthodes doivent implémenter un try-catch et renvoyer une réponse appropriée :

```dart
try {
  // Code qui peut échouer
} on ApiException catch (e) {
  // Gestion des exceptions API connues
  return ApiResponse<T>(
    success: false,
    data: null,
    message: e.message,
    statusCode: e.statusCode ?? 500,
  );
} catch (e) {
  // Gestion des exceptions génériques
  return ApiResponse<T>(
    success: false,
    data: null,
    message: 'Une erreur est survenue: ${e.toString()}',
    statusCode: 500,
  );
}
```

## Traitement des Réponses

Les services doivent gérer de manière flexible les différents formats de réponse :

```dart
if (response is List<dynamic>) {
  // API renvoie une liste directement
  final entities = response
      .map((json) => SomeEntity.fromJson(json as Map<String, dynamic>))
      .toList();
      
  return ApiResponse<List<SomeEntity>>(
    success: true,
    data: entities,
    message: 'Entités récupérées avec succès',
    statusCode: 200,
  );
} else if (response is Map<String, dynamic> && response['data'] != null) {
  // API renvoie un wrapper avec champ data
  final List<dynamic> data = response['data'] as List<dynamic>;
  final entities = data
      .map((json) => SomeEntity.fromJson(json as Map<String, dynamic>))
      .toList();
      
  return ApiResponse<List<SomeEntity>>(
    success: true,
    data: entities,
    message: response['message'] as String? ?? 'Entités récupérées avec succès',
    statusCode: response['statusCode'] as int? ?? 200,
  );
}
```

## Logging

Utilisez un logging approprié pour faciliter le débogage :

```dart
try {
  // Code...
} catch (e) {
  debugPrint("Erreur lors de l'appel API: $e");
  // Traitement de l'erreur...
}
```

## Tests

Chaque service API doit être accompagné de tests unitaires qui vérifient :
- Les réponses de succès
- Les différentes erreurs possibles
- Les cas limites (listes vides, etc.)

## Injection de Dépendances

Les services API doivent être injectés via un système de dépendances plutôt que créés directement :

```dart
// Recommandé
final someEntityApiService = getIt<SomeEntityApiService>();

// Non recommandé
final someEntityApiService = SomeEntityApiServiceImpl(apiClient);
```

## Synchronisation avec le Backend

Toute modification des services API doit être coordonnée avec l'équipe backend pour assurer la compatibilité des endpoints.

## Versions

Si une API change de façon non rétrocompatible, considérez l'utilisation d'un nouveau service avec un suffixe de version.
