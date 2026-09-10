import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:wanzo/core/services/catalog_enhancer.dart';
import 'package:wanzo/core/services/catalog_models.dart';
import 'package:wanzo/core/services/image_upload_service.dart';
import 'package:wanzo/core/services/product_api_service.dart';
import 'package:wanzo/features/inventory/models/product.dart';

/// Instantane de la selection de photos, remonte au formulaire produit.
///
/// [images] = images deja disponibles en ligne (URL Cloudinary), dans l'ordre.
/// [primaryLocalPath] = chemin local de l'image principale si elle n'a pas
/// encore pu etre uploadee (hors-ligne) ; le service produit s'en chargera au
/// moment de l'enregistrement.
class ProductPhotoSelection {
  final List<ProductImage> images;
  final String? primaryLocalPath;

  const ProductPhotoSelection({
    required this.images,
    this.primaryLocalPath,
  });
}

/// Gestion optimale des photos d'un produit a la creation / edition.
///
/// Capacites :
/// - grille de miniatures (BoxFit.cover, coins arrondis, jamais d'etirement) ;
/// - tuile "+ Ajouter" (multi via le picker fourni par l'app) ;
/// - glisser-deposer pour reordonner, la 1re image etant la principale ;
/// - suppression ;
/// - upload Cloudinary (client) puis indexation catalogue (`POST catalog`) ;
/// - suggestions du catalogue partage (`GET catalog/lookup`) reutilisables ;
/// - bouton "Ameliorer" par image (`POST catalog/enhance`) : remplace l'image
///   si `ok` et remplit la description si vide ; garde l'original si `pending`
///   (petit indicateur discret, aucun message d'erreur ni de credit).
///
/// Hors-ligne : lookup / enhance / upload echouent en silence, on continue avec
/// l'image locale.
class ProductPhotoManager extends StatefulWidget {
  /// Images deja rattachees au produit (edition).
  final List<ProductImage> initialImages;

  /// Chemin local d'une image existante non uploadee (retro-compat imagePath).
  final String? initialImagePath;

  /// Code-barres courant (pour lookup / enhance). Mettre a jour via setState.
  final String barcode;

  /// Nom courant (pour lookup / enhance). Mettre a jour via setState.
  final String name;

  /// Fournit des fichiers image selectionnes (specifique a l'app : galerie /
  /// camera / multi). Doit ne jamais lever d'exception (retourner [] si annule).
  final Future<List<File>> Function() pickImages;

  /// Remonte l'etat courant de la selection au formulaire.
  final ValueChanged<ProductPhotoSelection> onChanged;

  /// Propose une description (adoptee par le parent seulement si le champ est vide).
  final ValueChanged<String> onDescriptionSuggested;

  /// Layout desktop epure (miniatures un peu plus grandes, libelles visibles).
  final bool desktop;

  const ProductPhotoManager({
    super.key,
    this.initialImages = const [],
    this.initialImagePath,
    required this.barcode,
    required this.name,
    required this.pickImages,
    required this.onChanged,
    required this.onDescriptionSuggested,
    this.desktop = false,
  });

  @override
  State<ProductPhotoManager> createState() => _ProductPhotoManagerState();
}

class _PhotoItem {
  String? localPath;
  String? url;
  String? publicId;
  bool enhanced;
  bool uploading;
  bool enhancing = false;
  bool enhancePending = false;
  final String key;

  _PhotoItem({
    this.localPath,
    this.url,
    this.publicId,
    this.enhanced = false,
    this.uploading = false,
    required this.key,
  });
}

class _ProductPhotoManagerState extends State<ProductPhotoManager> {
  final ProductApiService _api = ProductApiService();
  final CatalogEnhancer _enhancer = CatalogEnhancer();
  final ImageUploadService _uploader = ImageUploadService();
  final List<_PhotoItem> _items = [];
  List<CatalogSuggestion> _suggestions = [];
  Timer? _debounce;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    for (final img in widget.initialImages) {
      if (img.url.isNotEmpty) {
        _items.add(_PhotoItem(
          url: img.url,
          publicId: img.publicId,
          enhanced: img.enhanced,
          key: _nextKey(),
        ));
      }
    }
    final localPath = widget.initialImagePath;
    if (localPath != null &&
        localPath.isNotEmpty &&
        !localPath.startsWith('http')) {
      _items.add(_PhotoItem(localPath: localPath, key: _nextKey()));
    }
    // Remonter l'etat initial apres le premier frame (evite setState en build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notify();
    });
    _fetchSuggestions();
  }

  @override
  void didUpdateWidget(covariant ProductPhotoManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barcode != widget.barcode || oldWidget.name != widget.name) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), _fetchSuggestions);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  String _nextKey() => 'photo_${_seq++}';

  String? get _barcode =>
      widget.barcode.trim().isEmpty ? null : widget.barcode.trim();
  String? get _name => widget.name.trim().isEmpty ? null : widget.name.trim();

  void _notify() {
    final images = <ProductImage>[];
    String? primaryLocal;
    for (final it in _items) {
      if (it.url != null && it.url!.isNotEmpty) {
        images.add(ProductImage(
          url: it.url!,
          publicId: it.publicId,
          enhanced: it.enhanced,
        ));
      } else if (primaryLocal == null &&
          it.localPath != null &&
          it.localPath!.isNotEmpty) {
        primaryLocal = it.localPath;
      }
    }
    widget.onChanged(
      ProductPhotoSelection(images: images, primaryLocalPath: primaryLocal),
    );
  }

  Future<void> _fetchSuggestions() async {
    final barcode = _barcode;
    final name = _name;
    // Pas assez d'info pour une recherche pertinente.
    if (barcode == null && (name == null || name.length < 3)) {
      if (mounted && _suggestions.isNotEmpty) {
        setState(() => _suggestions = []);
      }
      return;
    }
    try {
      final res = await _api.lookupCatalog(barcode: barcode, name: name);
      if (!mounted) return;
      setState(() => _suggestions = res);
    } catch (_) {
      // Hors-ligne : silencieux.
    }
  }

  List<CatalogSuggestion> get _visibleSuggestions {
    final existing = _items.map((e) => e.url).whereType<String>().toSet();
    return _suggestions
        .where((s) => s.imageUrl.isNotEmpty && !existing.contains(s.imageUrl))
        .toList();
  }

  Future<void> _addPicked() async {
    List<File> files;
    try {
      files = await widget.pickImages();
    } catch (_) {
      files = [];
    }
    if (files.isEmpty) return;
    for (final f in files) {
      final item = _PhotoItem(localPath: f.path, uploading: true, key: _nextKey());
      setState(() => _items.add(item));
      _notify();
      unawaited(_uploadItem(item, f));
    }
  }

  Future<String?> _uploadItem(_PhotoItem item, File file) async {
    try {
      final url = await _uploader.uploadImage(file);
      if (!mounted) return null;
      if (url != null && url.isNotEmpty) {
        setState(() {
          item.url = url;
          item.uploading = false;
        });
        _notify();
        // Indexer dans le catalogue partage (silencieux).
        unawaited(_api
            .indexCatalogImage(imageUrl: url, barcode: _barcode, name: _name)
            .catchError((_) {}));
        return url;
      }
      setState(() => item.uploading = false); // Reste local (hors-ligne).
      _notify();
      return null;
    } catch (_) {
      if (mounted) {
        setState(() => item.uploading = false);
        _notify();
      }
      return null;
    }
  }

  void _removeItem(_PhotoItem item) {
    setState(() => _items.remove(item));
    _notify();
  }

  void _adoptSuggestion(CatalogSuggestion s) {
    if (_items.any((i) => i.url == s.imageUrl)) return;
    setState(() {
      _items.add(_PhotoItem(
        url: s.imageUrl,
        enhanced: s.enhanced,
        key: _nextKey(),
      ));
      _suggestions = _suggestions.where((e) => e.id != s.id).toList();
    });
    _notify();
    unawaited(_api.useCatalogImage(s.id).catchError((_) {}));
    final desc = s.description;
    if (desc != null && desc.isNotEmpty) {
      widget.onDescriptionSuggested(desc);
    }
  }

  Future<void> _enhance(_PhotoItem item) async {
    if (item.enhancing) return;
    setState(() {
      item.enhancing = true;
      item.enhancePending = false;
    });
    try {
      // L'amelioration se fait sur une URL : uploader d'abord si besoin.
      var url = item.url;
      if (url == null && item.localPath != null) {
        url = await _uploadItem(item, File(item.localPath!));
      }
      if (url == null) {
        // Toujours pas d'URL (hors-ligne) : indicateur differe discret.
        if (mounted) {
          setState(() {
            item.enhancing = false;
            item.enhancePending = true;
          });
        }
        return;
      }
      final r = await _enhancer.enhance(
        imageUrl: url,
        barcode: _barcode,
        name: _name,
      );
      if (!mounted) return;
      if (r.ok && r.imageUrl != null && r.imageUrl!.isNotEmpty) {
        setState(() {
          item.url = r.imageUrl;
          item.publicId = r.publicId ?? item.publicId;
          item.enhanced = true;
          item.enhancing = false;
          item.enhancePending = false;
        });
        _notify();
        final desc = r.description;
        if (desc != null && desc.isNotEmpty) {
          widget.onDescriptionSuggested(desc);
        }
      } else {
        // pending : garder l'original, indicateur discret, aucune erreur.
        setState(() {
          item.enhancing = false;
          item.enhancePending = true;
        });
        final desc = r.description;
        if (desc != null && desc.isNotEmpty) {
          widget.onDescriptionSuggested(desc);
        }
      }
    } catch (_) {
      // Hors-ligne / erreur reseau : silencieux, on garde l'image telle quelle.
      if (mounted) setState(() => item.enhancing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tile = widget.desktop ? 116.0 : 104.0;
    final suggestions = _visibleSuggestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: tile + 8,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _addTile(theme, tile),
              const SizedBox(width: 8),
              Expanded(
                child: _items.isEmpty
                    ? _emptyHint(theme, tile)
                    : ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        buildDefaultDragHandles: true,
                        proxyDecorator: (child, index, animation) => Material(
                          color: Colors.transparent,
                          elevation: 6,
                          borderRadius: BorderRadius.circular(12),
                          child: child,
                        ),
                        itemCount: _items.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final it = _items.removeAt(oldIndex);
                            _items.insert(newIndex, it);
                          });
                          _notify();
                        },
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Padding(
                            key: ValueKey(item.key),
                            padding: const EdgeInsets.only(right: 8),
                            child: _tile(theme, item, index == 0, tile),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.auto_awesome_mosaic,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Images du catalogue Wanzo',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) =>
                  _suggestionTile(theme, suggestions[index]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _addTile(ThemeData theme, double size) {
    return InkWell(
      onTap: _addPicked,
      borderRadius: BorderRadius.circular(12),
      child: DottedBorderBox(
        size: size,
        color: theme.colorScheme.outline,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo,
                size: 26, color: theme.colorScheme.primary),
            const SizedBox(height: 6),
            Text(
              'Ajouter',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyHint(ThemeData theme, double size) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: size,
        child: Center(
          child: Text(
            'Aucune photo. Ajoutez la vitrine du produit.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(ThemeData theme, _PhotoItem item, bool isPrimary, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: _thumb(item, size),
              ),
            ),
          ),
          if (item.uploading)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          if (isPrimary)
            Positioned(
              top: 4,
              left: 4,
              child: _chip(
                theme,
                icon: Icons.star,
                label: 'Principale',
                background: theme.colorScheme.primary,
                foreground: theme.colorScheme.onPrimary,
              ),
            ),
          Positioned(
            top: 2,
            right: 2,
            child: _circleButton(
              icon: Icons.close,
              tooltip: 'Retirer',
              background: Colors.black.withValues(alpha: 0.5),
              foreground: Colors.white,
              onTap: () => _removeItem(item),
            ),
          ),
          // Bandeau d'amelioration, clairement visible tant que l'image n'est
          // pas encore amelioree ; etat discret « Amelioré » une fois faite.
          Positioned(
            left: 4,
            right: 4,
            bottom: 4,
            child: _enhanceStrip(theme, item),
          ),
        ],
      ),
    );
  }

  Widget _thumb(_PhotoItem item, double size) {
    if (item.url != null && item.url!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: item.url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) =>
            const Icon(Icons.broken_image_outlined, color: Colors.grey),
      );
    }
    final local = item.localPath;
    if (local != null && local.isNotEmpty && File(local).existsSync()) {
      return Image.file(
        File(local),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image_outlined, color: Colors.grey),
      );
    }
    return const Icon(Icons.inventory_2_outlined, color: Colors.grey);
  }

  /// Bandeau d'amelioration en bas de la miniature. Regle : bouton d'action
  /// present si et seulement si l'image existe et n'est PAS encore amelioree.
  /// - en cours : bandeau « Amélioration... » avec indicateur ;
  /// - non amelioree : bouton clair et libelle « Améliorer » (icone + texte) ;
  /// - en attente : bandeau discret « En attente » (pas d'erreur) ;
  /// - deja amelioree : etat discret « Amélioré », sans action.
  Widget _enhanceStrip(ThemeData theme, _PhotoItem item) {
    if (item.enhancing) {
      return _enhanceBar(
        background: theme.colorScheme.primary,
        foreground: theme.colorScheme.onPrimary,
        loading: true,
        label: 'Amélioration...',
      );
    }
    if (item.enhanced) {
      return _enhanceBar(
        background: theme.colorScheme.surface.withValues(alpha: 0.9),
        foreground: theme.colorScheme.primary,
        icon: Icons.auto_awesome,
        label: 'Amélioré',
      );
    }
    if (item.enhancePending) {
      return _enhanceBar(
        background: theme.colorScheme.surface.withValues(alpha: 0.9),
        foreground: theme.colorScheme.onSurfaceVariant,
        icon: Icons.hourglass_empty,
        label: 'En attente',
      );
    }
    // Image existante non amelioree : action bien visible.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _enhance(item),
        borderRadius: BorderRadius.circular(8),
        child: _enhanceBar(
          background: theme.colorScheme.primary,
          foreground: theme.colorScheme.onPrimary,
          icon: Icons.auto_fix_high,
          label: 'Améliorer',
        ),
      ),
    );
  }

  Widget _enhanceBar({
    required Color background,
    required Color foreground,
    required String label,
    IconData? icon,
    bool loading = false,
  }) {
    return Container(
      height: 24,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: foreground),
            )
          else if (icon != null)
            Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionTile(ThemeData theme, CatalogSuggestion s) {
    return InkWell(
      onTap: () => _adoptSuggestion(s),
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 76,
        height: 76,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: CachedNetworkImage(
                    imageUrl: s.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.image_not_supported_outlined,
                            color: Colors.grey, size: 20),
                  ),
                ),
              ),
            ),
            if (s.enhanced)
              Positioned(
                top: 2,
                left: 2,
                child: Icon(Icons.auto_awesome,
                    size: 14, color: theme.colorScheme.primary),
              ),
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.add,
                    size: 14, color: theme.colorScheme.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required Color background,
    required Color foreground,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: foreground),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: compact ? 8.5 : 9.5,
                  color: foreground,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required String tooltip,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: foreground),
        ),
      ),
    );
  }
}

/// Petit conteneur a bordure en pointilles pour la tuile "Ajouter".
class DottedBorderBox extends StatelessWidget {
  final double size;
  final Color color;
  final Widget child;

  const DottedBorderBox({
    super.key,
    required this.size,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(color: color),
      child: SizedBox(width: size, height: size, child: Center(child: child)),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;

  _DashedRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const radius = 12.0;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color;
}
