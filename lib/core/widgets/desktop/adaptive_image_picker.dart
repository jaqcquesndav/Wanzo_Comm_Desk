import 'dart:io';
import 'package:flutter/material.dart';
import '../../platform/platform_service.dart';
import '../../platform/image_picker/image_picker_service_factory.dart';

/// Widget adaptatif pour sélectionner une image
/// Sur mobile: montre les options camera et galerie
/// Sur desktop: montre uniquement l'option fichier
class AdaptiveImagePicker extends StatelessWidget {
  final Function(File) onImageSelected;
  final Widget? child;
  final String? title;
  final bool allowCamera;
  final bool allowGallery;
  final int? maxWidth;
  final int? maxHeight;
  final int? imageQuality;

  const AdaptiveImagePicker({
    super.key,
    required this.onImageSelected,
    this.child,
    this.title,
    this.allowCamera = true,
    this.allowGallery = true,
    this.maxWidth,
    this.maxHeight,
    this.imageQuality = 85,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showImageSourceDialog(context),
      child: child ?? _buildDefaultChild(context),
    );
  }

  Widget _buildDefaultChild(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_photo_alternate,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(title ?? 'Sélectionner une image'),
        ],
      ),
    );
  }

  void _showImageSourceDialog(BuildContext context) {
    final platform = PlatformService.instance;
    final imageService = ImagePickerServiceFactory.getInstance();

    // Sur desktop, aller directement à la sélection de fichier
    if (platform.isDesktop) {
      _pickFromGallery(context);
      return;
    }

    // Sur mobile, montrer le dialog avec les options
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title ?? 'Sélectionner une image',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  if (allowGallery && imageService.isGalleryAvailable)
                    ListTile(
                      leading: const Icon(Icons.photo_library),
                      title: const Text('Galerie'),
                      subtitle: const Text('Choisir depuis vos photos'),
                      onTap: () {
                        Navigator.pop(context);
                        _pickFromGallery(context);
                      },
                    ),
                  if (allowCamera && imageService.isCameraAvailable)
                    ListTile(
                      leading: const Icon(Icons.camera_alt),
                      title: const Text('Caméra'),
                      subtitle: const Text('Prendre une nouvelle photo'),
                      onTap: () {
                        Navigator.pop(context);
                        _pickFromCamera(context);
                      },
                    ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    final imageService = ImagePickerServiceFactory.getInstance();
    final file = await imageService.pickFromGallery(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );

    if (file != null) {
      onImageSelected(file);
    }
  }

  Future<void> _pickFromCamera(BuildContext context) async {
    final imageService = ImagePickerServiceFactory.getInstance();
    final file = await imageService.pickFromCamera(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );

    if (file != null) {
      onImageSelected(file);
    }
  }
}

/// Widget pour afficher et sélectionner une image avec prévisualisation
class AdaptiveImagePickerWithPreview extends StatefulWidget {
  final Function(File?) onImageChanged;
  final File? initialImage;
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? placeholder;

  const AdaptiveImagePickerWithPreview({
    super.key,
    required this.onImageChanged,
    this.initialImage,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  State<AdaptiveImagePickerWithPreview> createState() =>
      _AdaptiveImagePickerWithPreviewState();
}

class _AdaptiveImagePickerWithPreviewState
    extends State<AdaptiveImagePickerWithPreview> {
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _selectedImage = widget.initialImage;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Image preview
        Container(
          width: widget.width ?? double.infinity,
          height: widget.height ?? 200,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildImagePreview(),
          ),
        ),

        // Edit button
        Positioned(
          right: 8,
          bottom: 8,
          child: AdaptiveImagePicker(
            onImageSelected: (file) {
              setState(() => _selectedImage = file);
              widget.onImageChanged(file);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 20),
            ),
          ),
        ),

        // Remove button (if image selected)
        if (_selectedImage != null)
          Positioned(
            right: 8,
            top: 8,
            child: IconButton(
              onPressed: () {
                setState(() => _selectedImage = null);
                widget.onImageChanged(null);
              },
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImage != null) {
      return Image.file(
        _selectedImage!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
      );
    }

    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      return Image.network(
        widget.imageUrl!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value:
                  loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
            ),
          );
        },
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            widget.placeholder ?? 'Ajouter une image',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
