import 'package:flutter/material.dart';

import 'smart_image.dart';

/// Source photo d'un plat (URL réseau prioritaire, sinon chemin local), telle
/// que portée par `MenuItem.photoUrl` / `MenuItem.photoPath`.
class DishThumb {
  final String? photoUrl;
  final String? photoPath;
  const DishThumb({this.photoUrl, this.photoPath});

  bool get hasImage =>
      SmartImage.hasImage(imageUrl: photoUrl, imagePath: photoPath);
}

/// Vignette (1 photo) ou GRILLE de miniatures (plusieurs photos) donnant un
/// aperçu du contenu d'une commande : les photos des plats commandés.
///
/// Règles d'affichage :
///  - photos toujours en `BoxFit.cover` (JAMAIS étirées), coins arrondis ;
///  - 0 photo → repli propre (icône sur fond neutre), jamais d'image cassée ;
///  - 1 photo → une seule miniature pleine ;
///  - 2 à [maxTiles] photos → grille 2 colonnes ;
///  - au-delà de [maxTiles] → la dernière tuile porte un « +N » discret.
///
/// Widget purement présentationnel : il ne connaît ni le modèle de commande ni
/// le catalogue. L'appelant résout `productId` → plat (via `MenuRepository`) et
/// fournit la liste des [DishThumb].
class DishThumbGrid extends StatelessWidget {
  final List<DishThumb> thumbs;

  /// Côté du carré global (px).
  final double size;

  /// Rayon des coins.
  final double radius;

  /// Icône de repli quand aucune photo n'est disponible.
  final IconData fallbackIcon;

  /// Nombre maximum de tuiles affichées (au-delà : « +N » sur la dernière).
  final int maxTiles;

  const DishThumbGrid({
    super.key,
    required this.thumbs,
    this.size = 48,
    this.radius = 10,
    this.fallbackIcon = Icons.restaurant,
    this.maxTiles = 4,
  });

  @override
  Widget build(BuildContext context) {
    final withImages = thumbs.where((t) => t.hasImage).toList();
    final Widget content;
    if (withImages.isEmpty) {
      content = _fallback(context);
    } else {
      final shown = withImages.take(maxTiles).toList();
      final overflow = withImages.length - shown.length;
      content = _layout(context, shown, overflow);
    }
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }

  /// Disposition des tuiles selon leur nombre (1 à [maxTiles]). Gap fin entre
  /// tuiles = fond neutre qui « sépare » les photos sans les étirer.
  Widget _layout(BuildContext context, List<DishThumb> shown, int overflow) {
    const gap = 2.0;
    if (shown.length == 1) {
      return _tile(context, shown.first);
    }
    if (shown.length == 2) {
      return Row(
        children: [
          Expanded(child: _tile(context, shown[0])),
          const SizedBox(width: gap),
          Expanded(child: _tile(context, shown[1])),
        ],
      );
    }
    if (shown.length == 3) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _tile(context, shown[0])),
                const SizedBox(width: gap),
                Expanded(child: _tile(context, shown[1])),
              ],
            ),
          ),
          const SizedBox(height: gap),
          Expanded(child: _tile(context, shown[2])),
        ],
      );
    }
    // 4 tuiles (ou plus, écrêtées) : grille 2x2, « +N » sur la dernière.
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _tile(context, shown[0])),
              const SizedBox(width: gap),
              Expanded(child: _tile(context, shown[1])),
            ],
          ),
        ),
        const SizedBox(height: gap),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _tile(context, shown[2])),
              const SizedBox(width: gap),
              Expanded(
                child: _tile(
                  context,
                  shown[3],
                  overlayText: overflow > 0 ? '+$overflow' : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, DishThumb thumb, {String? overlayText}) {
    final scheme = Theme.of(context).colorScheme;
    Widget img = SmartImage(
      imageUrl: thumb.photoUrl,
      imagePath: thumb.photoPath,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholderIcon: fallbackIcon,
      placeholderColor: scheme.surfaceContainerHighest,
      placeholderIconSize: size * 0.42,
    );
    if (overlayText != null) {
      img = Stack(
        fit: StackFit.expand,
        children: [
          img,
          Container(
            color: Colors.black.withValues(alpha: 0.45),
            alignment: Alignment.center,
            child: Text(
              overlayText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
    }
    return Container(color: scheme.surfaceContainerHighest, child: img);
  }

  Widget _fallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        size: size * 0.42,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
