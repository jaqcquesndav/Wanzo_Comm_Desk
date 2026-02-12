import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wanzo/core/services/attachment_service.dart';

/// Widget intelligent pour afficher une pièce jointe (image, PDF, document, etc.)
///
/// Gère automatiquement:
/// - Détection du type de fichier
/// - Affichage adapté selon le type (preview image ou icône)
/// - Mode offline-first (cache + fallback local)
/// - Actions (ouvrir, télécharger)
class SmartAttachment extends StatelessWidget {
  /// URL Cloudinary ou chemin réseau
  final String? url;

  /// Chemin local (fallback pour mode offline)
  final String? localPath;

  /// Taille du widget
  final double size;

  /// Callback lors du tap (par défaut: ouvre le fichier)
  final VoidCallback? onTap;

  /// Afficher le badge de type de fichier
  final bool showTypeBadge;

  /// BorderRadius
  final BorderRadius? borderRadius;

  const SmartAttachment({
    super.key,
    this.url,
    this.localPath,
    this.size = 80,
    this.onTap,
    this.showTypeBadge = true,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final attachmentService = AttachmentService();
    final source = url ?? localPath;

    if (source == null || source.isEmpty) {
      return _buildPlaceholder(context);
    }

    final type = attachmentService.getAttachmentType(source);
    final isImage = type == AttachmentType.image;
    final isNetwork = attachmentService.isNetworkUrl(source);

    return GestureDetector(
      onTap: onTap ?? () => _defaultOnTap(context, source),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: borderRadius ?? BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Contenu principal
            if (isImage)
              _buildImagePreview(context, source, isNetwork)
            else
              _buildFilePreview(context, type, attachmentService),

            // Badge de type (coin supérieur droit)
            if (showTypeBadge && !isImage)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: attachmentService
                        .getColorForType(type)
                        .withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getTypeLabel(type),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(
    BuildContext context,
    String source,
    bool isNetwork,
  ) {
    if (isNetwork) {
      return CachedNetworkImage(
        imageUrl: source,
        fit: BoxFit.cover,
        placeholder:
            (context, url) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        errorWidget: (context, url, error) {
          // Essayer le chemin local si disponible
          if (localPath != null && localPath!.isNotEmpty) {
            final file = File(localPath!);
            if (file.existsSync()) {
              return Image.file(file, fit: BoxFit.cover);
            }
          }
          return _buildErrorWidget(context);
        },
      );
    } else {
      // Fichier local
      final file = File(source);
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) => _buildErrorWidget(context),
      );
    }
  }

  Widget _buildFilePreview(
    BuildContext context,
    AttachmentType type,
    AttachmentService service,
  ) {
    return Container(
      color: service.getColorForType(type).withValues(alpha: 0.1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            service.getIconForType(type),
            size: size * 0.4,
            color: service.getColorForType(type),
          ),
          const SizedBox(height: 4),
          Text(
            'Ouvrir',
            style: TextStyle(
              fontSize: 10,
              color: service.getColorForType(type),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.attach_file,
        size: size * 0.4,
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: size * 0.3,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(height: 4),
          Text(
            'Erreur',
            style: TextStyle(
              fontSize: 9,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeLabel(AttachmentType type) {
    switch (type) {
      case AttachmentType.image:
        return 'IMG';
      case AttachmentType.pdf:
        return 'PDF';
      case AttachmentType.document:
        return 'DOC';
      case AttachmentType.spreadsheet:
        return 'XLS';
      case AttachmentType.audio:
        return 'MP3';
      case AttachmentType.video:
        return 'VID';
      case AttachmentType.unknown:
        return 'FILE';
    }
  }

  Future<void> _defaultOnTap(BuildContext context, String source) async {
    final attachmentService = AttachmentService();
    final type = attachmentService.getAttachmentType(source);

    if (type == AttachmentType.image) {
      // Pour les images, naviguer vers un viewer plein écran
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) =>
                  _FullScreenImageViewer(url: url, localPath: localPath),
        ),
      );
    } else {
      // Pour les autres fichiers, ouvrir avec l'app système
      final scaffold = ScaffoldMessenger.of(context);

      scaffold.showSnackBar(
        const SnackBar(
          content: Text('Chargement du fichier...'),
          duration: Duration(seconds: 1),
        ),
      );

      final success = await attachmentService.openFile(
        source,
        localPath: localPath,
      );

      if (!success) {
        scaffold.showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir le fichier'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Viewer plein écran pour les images
class _FullScreenImageViewer extends StatelessWidget {
  final String? url;
  final String? localPath;

  const _FullScreenImageViewer({this.url, this.localPath});

  @override
  Widget build(BuildContext context) {
    final source = url ?? localPath ?? '';
    final attachmentService = AttachmentService();
    final isNetwork = attachmentService.isNetworkUrl(source);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Image'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              final path = await attachmentService.downloadToDownloads(source);
              if (path != null && context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Téléchargé: $path')));
              }
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child:
              isNetwork
                  ? CachedNetworkImage(
                    imageUrl: source,
                    fit: BoxFit.contain,
                    placeholder:
                        (context, url) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                    errorWidget: (context, url, error) {
                      // Fallback local
                      if (localPath != null && localPath!.isNotEmpty) {
                        return Image.file(
                          File(localPath!),
                          fit: BoxFit.contain,
                        );
                      }
                      return const Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 64,
                      );
                    },
                  )
                  : Image.file(
                    File(source),
                    fit: BoxFit.contain,
                    errorBuilder:
                        (context, error, stackTrace) => const Icon(
                          Icons.error,
                          color: Colors.red,
                          size: 64,
                        ),
                  ),
        ),
      ),
    );
  }
}

/// Widget pour afficher une liste de pièces jointes
class SmartAttachmentGrid extends StatelessWidget {
  /// Liste des URLs Cloudinary
  final List<String>? urls;

  /// Liste des chemins locaux (fallback)
  final List<String>? localPaths;

  /// Nombre de colonnes
  final int crossAxisCount;

  /// Taille de chaque item
  final double itemSize;

  /// Espacement
  final double spacing;

  const SmartAttachmentGrid({
    super.key,
    this.urls,
    this.localPaths,
    this.crossAxisCount = 3,
    this.itemSize = 80,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    final attachments = urls ?? localPaths ?? [];

    if (attachments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.attachment_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Aucune pièce jointe',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: List.generate(attachments.length, (index) {
        final url = urls != null && index < urls!.length ? urls![index] : null;
        final localPath =
            localPaths != null && index < localPaths!.length
                ? localPaths![index]
                : null;

        return SmartAttachment(url: url, localPath: localPath, size: itemSize);
      }),
    );
  }
}
