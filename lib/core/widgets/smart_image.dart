import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Widget intelligent pour afficher des images depuis:
/// - Une URL réseau (Cloudinary, etc.)
/// - Un chemin local (fichier système)
/// - Un asset Flutter
///
/// Gère automatiquement le type d'image et affiche un placeholder en cas d'erreur.
class SmartImage extends StatelessWidget {
  /// URL réseau (https://...) ou null
  final String? imageUrl;

  /// Chemin local du fichier ou null
  final String? imagePath;

  /// Comment l'image doit remplir l'espace
  final BoxFit fit;

  /// Largeur de l'image
  final double? width;

  /// Hauteur de l'image
  final double? height;

  /// Widget à afficher en cas d'erreur ou si aucune image n'est disponible
  final Widget? placeholder;

  /// Widget à afficher pendant le chargement (pour les images réseau)
  final Widget? loadingWidget;

  /// Couleur de fond du placeholder
  final Color? placeholderColor;

  /// Icône du placeholder
  final IconData placeholderIcon;

  /// Taille de l'icône du placeholder
  final double placeholderIconSize;

  /// BorderRadius pour l'image
  final BorderRadius? borderRadius;

  const SmartImage({
    super.key,
    this.imageUrl,
    this.imagePath,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.loadingWidget,
    this.placeholderColor,
    this.placeholderIcon = Icons.image,
    this.placeholderIconSize = 48,
    this.borderRadius,
  });

  /// Vérifie si une chaîne est une URL réseau
  static bool isNetworkUrl(String? path) {
    if (path == null || path.isEmpty) return false;
    return path.startsWith('http://') || path.startsWith('https://');
  }

  /// Vérifie si une chaîne est un chemin d'asset
  static bool isAssetPath(String? path) {
    if (path == null || path.isEmpty) return false;
    return path.startsWith('assets/');
  }

  /// Retourne la source d'image à utiliser (priorité: imageUrl > imagePath)
  String? get _effectiveSource {
    // Priorité à l'URL Cloudinary si disponible
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return imageUrl;
    }
    // Sinon, utiliser le chemin local
    if (imagePath != null && imagePath!.isNotEmpty) {
      return imagePath;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final source = _effectiveSource;
    final theme = Theme.of(context);

    Widget imageWidget;

    if (source == null) {
      // Aucune image disponible
      imageWidget = _buildPlaceholder(theme);
    } else if (isNetworkUrl(source)) {
      // Image depuis URL (Cloudinary, etc.)
      imageWidget = _buildNetworkImage(source, theme);
    } else if (isAssetPath(source)) {
      // Image depuis assets Flutter
      imageWidget = _buildAssetImage(source, theme);
    } else {
      // Image depuis fichier local
      imageWidget = _buildFileImage(source, theme);
    }

    // Appliquer le borderRadius si spécifié
    if (borderRadius != null) {
      imageWidget = ClipRRect(borderRadius: borderRadius!, child: imageWidget);
    }

    return SizedBox(width: width, height: height, child: imageWidget);
  }

  Widget _buildNetworkImage(String url, ThemeData theme) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      placeholder:
          (context, url) => loadingWidget ?? _buildLoadingWidget(theme),
      errorWidget: (context, url, error) {
        debugPrint('❌ Erreur chargement image réseau: $url - $error');
        return _buildPlaceholder(theme);
      },
    );
  }

  Widget _buildFileImage(String path, ThemeData theme) {
    final file = File(path);

    // Vérifier si le fichier existe
    if (!file.existsSync()) {
      debugPrint('⚠️ Fichier image introuvable: $path');
      return _buildPlaceholder(theme);
    }

    return Image.file(
      file,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('❌ Erreur chargement image fichier: $path - $error');
        return _buildPlaceholder(theme);
      },
    );
  }

  Widget _buildAssetImage(String assetPath, ThemeData theme) {
    return Image.asset(
      assetPath,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('❌ Erreur chargement asset: $assetPath - $error');
        return _buildPlaceholder(theme);
      },
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    if (placeholder != null) {
      return placeholder!;
    }

    return Container(
      width: width,
      height: height,
      color: placeholderColor ?? theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          placeholderIcon,
          size: placeholderIconSize,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget(ThemeData theme) {
    return Container(
      width: width,
      height: height,
      color: placeholderColor ?? theme.colorScheme.surfaceContainerHighest,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

/// Extension pour faciliter l'utilisation avec Product
extension ProductImageExtension on SmartImage {
  /// Crée un SmartImage à partir d'un Product
  static SmartImage fromProduct({
    required String? imageUrl,
    required String? imagePath,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    BorderRadius? borderRadius,
  }) {
    return SmartImage(
      imageUrl: imageUrl,
      imagePath: imagePath,
      fit: fit,
      width: width,
      height: height,
      placeholderIcon: Icons.inventory_2,
      borderRadius: borderRadius,
    );
  }
}
