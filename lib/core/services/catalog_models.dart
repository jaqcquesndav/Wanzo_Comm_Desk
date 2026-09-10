// Modeles legers pour le catalogue partage Wanzo (images de produits mutualisees
// entre entreprises + amelioration IA). Volontairement decouples de `Product`
// pour rester reutilisables par le service API et le widget de gestion photos.

/// Une suggestion d'image renvoyee par `GET catalog/lookup`.
class CatalogSuggestion {
  /// Identifiant de l'entree catalogue (sert a `POST catalog/:id/use`).
  final String id;

  /// URL publique de l'image (Cloudinary).
  final String imageUrl;

  /// Description associee (peut alimenter le champ description du produit).
  final String? description;

  /// L'image a-t-elle deja ete amelioree par l'IA.
  final bool enhanced;

  /// Nombre d'entreprises ayant reutilise cette image.
  final int usageCount;

  const CatalogSuggestion({
    required this.id,
    required this.imageUrl,
    this.description,
    this.enhanced = false,
    this.usageCount = 0,
  });

  /// Lecture defensive : accepte `imageUrl` ou `url`, tolere les champs manquants.
  factory CatalogSuggestion.fromJson(Map<String, dynamic> json) {
    return CatalogSuggestion(
      id: (json['id'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? json['url'] ?? '').toString(),
      description: json['description']?.toString(),
      enhanced: json['enhanced'] == true,
      usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Resultat de `POST catalog/enhance`.
/// `status:'ok'` => image amelioree disponible. `status:'pending'` => amelioration
/// indisponible pour l'instant (ce n'est PAS une erreur : on garde l'original).
class CatalogEnhanceResult {
  /// L'amelioration a reussi et une nouvelle image est disponible.
  final bool ok;

  /// L'amelioration est differee (indisponible pour l'instant).
  final bool pending;

  /// URL de l'image amelioree (quand `ok`).
  final String? imageUrl;

  /// publicId Cloudinary de l'image amelioree (quand `ok`).
  final String? publicId;

  /// Description generee (peut alimenter le champ description si vide).
  final String? description;

  const CatalogEnhanceResult({
    required this.ok,
    required this.pending,
    this.imageUrl,
    this.publicId,
    this.description,
  });

  factory CatalogEnhanceResult.fromJson(Map<String, dynamic> json) {
    final status = (json['status'] ?? '').toString();
    return CatalogEnhanceResult(
      ok: status == 'ok',
      pending: status == 'pending',
      imageUrl: (json['imageUrl'] ?? json['url'])?.toString(),
      publicId: json['publicId']?.toString(),
      description: json['description']?.toString(),
    );
  }
}
