import 'dart:async';
import 'catalog_models.dart';
import 'product_api_service.dart';

/// Logique d'amelioration d'image du catalogue partage, factorisee pour etre
/// reutilisee par le gestionnaire de photos (formulaire) et la fiche produit.
///
/// [enhance] appelle `POST catalog/enhance` sur une URL d'image. En cas de
/// succes (`ok`), l'image amelioree est indexee dans le catalogue partage
/// (best-effort, silencieux). Un `pending` n'est PAS une erreur : l'appelant
/// conserve l'image d'origine et affiche un indicateur discret.
class CatalogEnhancer {
  final ProductApiService _api;

  CatalogEnhancer({ProductApiService? api})
      : _api = api ?? ProductApiService();

  /// Ameliore l'image [imageUrl]. Renvoie le resultat brut (`ok` / `pending`).
  /// En cas de succes, indexe l'image amelioree dans le catalogue (best-effort).
  Future<CatalogEnhanceResult> enhance({
    required String imageUrl,
    String? barcode,
    String? name,
  }) async {
    final r = await _api.enhanceCatalogImage(
      imageUrl: imageUrl,
      barcode: barcode,
      name: name,
    );
    if (r.ok && r.imageUrl != null && r.imageUrl!.isNotEmpty) {
      unawaited(_api
          .indexCatalogImage(
            imageUrl: r.imageUrl!,
            publicId: r.publicId,
            barcode: barcode,
            name: name,
            enhanced: true,
            description: r.description,
          )
          .catchError((_) {}));
    }
    return r;
  }
}
