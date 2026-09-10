import 'package:flutter/material.dart';

import 'package:wanzo/core/widgets/smart_image.dart';

/// Visionneuse plein écran, zoomable et défilable, pour une liste de photos
/// (URLs Cloudinary ou chemins locaux). Réutilise [SmartImage] pour le rendu.
///
/// Ouvrir avec [PhotoGalleryViewer.open] : pincer/molette pour zoomer, glisser
/// pour changer de photo, bouton de fermeture en haut. Utilisée pour les designs
/// / bons à tirer d'imprimerie, mais générique.
class PhotoGalleryViewer extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;

  const PhotoGalleryViewer({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  /// Pousse la visionneuse en plein écran. Sans effet si [photos] est vide.
  static Future<void> open(
    BuildContext context, {
    required List<String> photos,
    int initialIndex = 0,
  }) {
    if (photos.isEmpty) return Future.value();
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            PhotoGalleryViewer(photos: photos, initialIndex: initialIndex),
      ),
    );
  }

  @override
  State<PhotoGalleryViewer> createState() => _PhotoGalleryViewerState();
}

class _PhotoGalleryViewerState extends State<PhotoGalleryViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.photos.length > 1
            ? Text('${_index + 1} / ${widget.photos.length}')
            : null,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Center(
            child: SmartImage(
              imageUrl: widget.photos[i],
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
