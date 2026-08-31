import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:wanzo/core/platform/image_picker/image_picker_service_factory.dart';
import 'package:wanzo/core/platform/image_picker/image_picker_service_interface.dart';
import 'package:wanzo/core/shared_widgets/empty_state_view.dart';
import 'package:wanzo/core/widgets/smart_image.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';

import '../models/menu_course.dart';
import '../models/menu_item.dart';
import '../repositories/menu_repository.dart';
import '../services/restaurant_api_service.dart';

/// Composition de la CARTE du restaurant : un vrai catalogue de plats, authoré
/// directement (nom, prix, photo, description, catégorie). Chaque plat est une
/// entité [MenuItem] à part entière — PAS une surcouche du stock. On ajoute /
/// modifie / supprime des plats, groupés par service (Entrées, Plats, …).
///
/// Version DESKTOP : le formulaire d'ajout/édition d'un plat s'ouvre en MODAL
/// (Dialog centré), pas en feuille basse ; la sélection d'image passe par le
/// service d'images de l'app (comme l'écran produit).
class RestaurantMenuConfigScreen extends StatefulWidget {
  const RestaurantMenuConfigScreen({super.key});

  @override
  State<RestaurantMenuConfigScreen> createState() =>
      _RestaurantMenuConfigScreenState();
}

class _RestaurantMenuConfigScreenState
    extends State<RestaurantMenuConfigScreen> {
  final MenuRepository _repo = MenuRepository();
  final RestaurantApiService _api = RestaurantApiService();
  List<MenuItem> _items = [];
  bool _loading = true;
  bool _publishing = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _repo.loadAll();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  /// Publie la carte locale vers le backend (upsert en masse) afin que la page
  /// publique (QR par table) affiche la carte à jour. Best-effort : en cas
  /// d'échec réseau on prévient l'utilisateur sans casser l'écran.
  Future<void> _publishMenu() async {
    if (_items.isEmpty) return;
    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.bulkUpsertMenuItems(_items);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Carte publiée (${_items.length} plats).'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Publication impossible. Vérifiez votre connexion.'),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  /// Plats groupés par service, filtrés par la recherche (nom + description).
  /// Requête vide → carte complète. Le regroupement par service est conservé
  /// sur les résultats filtrés.
  Map<MenuCourse, List<MenuItem>> get _byCourse {
    final q = _search.trim().toLowerCase();
    final grouped = <MenuCourse, List<MenuItem>>{};
    for (final item in _items) {
      if (q.isNotEmpty) {
        final inName = item.name.toLowerCase().contains(q);
        final inDesc = (item.description?.toLowerCase().contains(q)) ?? false;
        if (!inName && !inDesc) continue;
      }
      grouped.putIfAbsent(item.course, () => []).add(item);
    }
    return grouped;
  }

  Widget _thumbFallback(double size) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(Icons.restaurant,
          size: size * 0.42, color: theme.colorScheme.onSurfaceVariant),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _byCourse;
    final courses = grouped.keys.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: const Text('Composer la carte'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FilledButton.icon(
              onPressed:
                  (_publishing || _items.isEmpty) ? null : _publishMenu,
              icon: _publishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: const Text('Publier la carte'),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ajouter un plat',
        onPressed: () => _openDishForm(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const EmptyStateView(
                  icon: Icons.restaurant_menu,
                  message: 'Votre carte est vide. Ajoutez vos plats.',
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher un plat…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  tooltip: 'Effacer',
                                  onPressed: () => setState(() => _search = ''),
                                ),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    Expanded(
                      child: courses.isEmpty
                          ? const EmptyStateView(
                              icon: Icons.search_off,
                              message: 'Aucun plat ne correspond.',
                            )
                          : ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 96),
                              children: [
                                for (final course in courses)
                                  _courseSection(course, grouped[course]!),
                              ],
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _courseSection(MenuCourse course, List<MenuItem> dishes) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(course.label,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${dishes.length}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in dishes) _dishCard(item),
        ],
      ),
    );
  }

  Widget _dishCard(MenuItem item) {
    final theme = Theme.of(context);
    final description = item.description?.trim() ?? '';
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openDishForm(existing: item),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SmartImage(
                  imageUrl: item.photoUrl,
                  imagePath: item.photoPath,
                  fit: BoxFit.cover,
                  width: 56,
                  height: 56,
                  placeholder: _thumbFallback(56),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                        if (!item.available)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Épuisé',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.error)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(formatCurrency(item.priceCdf, 'CDF'),
                        style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              // Bascule disponible / épuisé.
              IconButton(
                tooltip: item.available ? 'Marquer épuisé' : 'Rendre disponible',
                icon: Icon(
                  item.available
                      ? Icons.check_circle_outline
                      : Icons.remove_circle_outline,
                  color:
                      item.available ? Colors.green : theme.colorScheme.error,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () => _toggleAvailable(item),
              ),
              IconButton(
                tooltip: 'Modifier',
                icon: const Icon(Icons.edit_outlined),
                visualDensity: VisualDensity.compact,
                onPressed: () => _openDishForm(existing: item),
              ),
              IconButton(
                tooltip: 'Supprimer',
                icon:
                    Icon(Icons.delete_outline, color: theme.colorScheme.error),
                visualDensity: VisualDensity.compact,
                onPressed: () => _confirmDelete(item),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleAvailable(MenuItem item) async {
    await _repo.upsert(item.copyWith(available: !item.available));
    await _load();
  }

  Future<void> _confirmDelete(MenuItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le plat'),
        content: Text('Retirer « ${item.name} » de la carte ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _repo.delete(item.id);
      await _load();
    }
  }

  /// Ouvre le formulaire d'un plat en MODAL (Dialog centré) — convention
  /// desktop de l'app (cf. `FormNavigationService`), pas une feuille basse.
  Future<void> _openDishForm({MenuItem? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DishFormDialog(repo: _repo, existing: existing),
    );
    if (saved == true) {
      await _load();
    }
  }
}

/// Formulaire DÉDIÉ d'un plat, présenté en DIALOG (modal desktop) : nom, prix,
/// description, catégorie, photo. Ce n'est PAS le formulaire de stock ni un
/// sélecteur de produits — un plat est authoré directement.
class _DishFormDialog extends StatefulWidget {
  final MenuRepository repo;
  final MenuItem? existing;
  const _DishFormDialog({required this.repo, this.existing});

  @override
  State<_DishFormDialog> createState() => _DishFormDialogState();
}

class _DishFormDialogState extends State<_DishFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  late final ImagePickerServiceInterface _imagePicker;
  late MenuCourse _course;
  String? _photoPath;
  String? _photoUrl;
  bool _saving = false;

  /// Groupes de modificateurs authorés (cuisson, suppléments…). Copie mutable
  /// de ceux du plat existant pour édition locale.
  late List<ModifierGroup> _groups;

  @override
  void initState() {
    super.initState();
    _imagePicker = ImagePickerServiceFactory.getInstance();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _priceController = TextEditingController(
        text: e != null ? e.priceCdf.toStringAsFixed(0) : '');
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _course = e?.course ?? MenuCourse.plat;
    _photoPath = e?.photoPath;
    _photoUrl = e?.photoUrl;
    _groups = List<ModifierGroup>.from(e?.modifierGroups ?? const []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Copie l'image choisie dans le dossier de l'app (même motif que l'écran
  /// produit) et retient son chemin local.
  Future<void> _handlePicked(File? picked) async {
    if (picked == null) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final baseName = path.basename(picked.path);
      String savedPath = path.join(appDir.path, baseName);
      int counter = 1;
      while (await File(savedPath).exists()) {
        final newName =
            '${path.basenameWithoutExtension(baseName)}_$counter${path.extension(baseName)}';
        savedPath = path.join(appDir.path, newName);
        counter++;
      }
      await picked.copy(savedPath);
      if (!mounted) return;
      setState(() {
        _photoPath = savedPath;
        // Une nouvelle photo locale prime sur l'URL réseau existante.
        _photoUrl = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de charger la photo : $e')),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    final file = await _imagePicker.pickFromGallery(
      maxWidth: 1280,
      imageQuality: 80,
    );
    await _handlePicked(file);
  }

  Future<void> _pickFromCamera() async {
    final file = await _imagePicker.pickFromCamera(
      maxWidth: 1280,
      imageQuality: 80,
    );
    await _handlePicked(file);
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (bc) => SafeArea(
        child: Wrap(
          children: [
            if (_imagePicker.isGalleryAvailable)
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galerie'),
                onTap: () {
                  Navigator.pop(bc);
                  _pickFromGallery();
                },
              ),
            if (_imagePicker.isCameraAvailable)
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Appareil photo'),
                onTap: () {
                  Navigator.pop(bc);
                  _pickFromCamera();
                },
              ),
            if (SmartImage.hasImage(imageUrl: _photoUrl, imagePath: _photoPath))
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Retirer la photo',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(bc);
                  setState(() {
                    _photoPath = null;
                    _photoUrl = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final description = _descriptionController.text.trim();
    final item = MenuItem(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      priceCdf: price,
      description: description.isEmpty ? null : description,
      photoPath: _photoPath,
      photoUrl: _photoUrl,
      course: _course,
      available: widget.existing?.available ?? true,
      modifierGroups: _groups,
    );
    await widget.repo.upsert(item);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  /// Ouvre le sous-formulaire d'un groupe d'options en DIALOG (modal desktop)
  /// et répercute le résultat dans [_groups].
  Future<void> _editGroup({ModifierGroup? existing, int? index}) async {
    final result = await showDialog<ModifierGroup>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GroupEditorDialog(existing: existing),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index != null && index >= 0 && index < _groups.length) {
        _groups[index] = result;
      } else {
        _groups.add(result);
      }
    });
  }

  /// Résumé lisible d'un groupe : mode de choix + surcoûts éventuels.
  String _groupSummary(ModifierGroup g) {
    final mode = g.isSingleChoice ? 'Choix unique' : 'Choix multiple';
    final req = g.required ? ' · Obligatoire' : ' · Facultatif';
    final n = g.options.length;
    return '$mode$req · $n option${n > 1 ? 's' : ''}';
  }

  /// Section « Options / modificateurs » : liste des groupes définis (avec
  /// édition/suppression) + bouton d'ajout. Optionnelle et discrète — un plat
  /// sans groupe s'ajoute directement à la commande.
  Widget _buildModifiersSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune,
                size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text('Options / modificateurs',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Ce qu\'on demande au client (cuisson, suppléments…). Facultatif.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < _groups.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              title: Text(_groups[i].name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_groupSummary(_groups[i])),
              onTap: () => _editGroup(existing: _groups[i], index: i),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Modifier',
                    icon: const Icon(Icons.edit_outlined),
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        _editGroup(existing: _groups[i], index: i),
                  ),
                  IconButton(
                    tooltip: 'Supprimer',
                    icon: Icon(Icons.delete_outline,
                        color: theme.colorScheme.error),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _groups.removeAt(i)),
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _editGroup(),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un groupe d\'options'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;
    final hasPhoto =
        SmartImage.hasImage(imageUrl: _photoUrl, imagePath: _photoPath);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEditing ? 'Modifier le plat' : 'Nouveau plat',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  shrinkWrap: true,
                  children: [
                    // Photo (optionnelle).
                    GestureDetector(
                      onTap: _showImageSourceSheet,
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.4)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: hasPhoto
                            ? SmartImage(
                                imageUrl: _photoUrl,
                                imagePath: _photoPath,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 160,
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo,
                                      size: 36,
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                  const SizedBox(height: 8),
                                  Text('Ajouter une photo (optionnel)',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Nom *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.restaurant_menu),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Le nom est requis'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Prix (CDF) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.sell),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Le prix est requis';
                        }
                        final price = double.tryParse(v.trim());
                        if (price == null || price <= 0) {
                          return 'Prix invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<MenuCourse>(
                      value: _course,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: [
                        for (final c in MenuCourse.values)
                          DropdownMenuItem(value: c, child: Text(c.label)),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _course = v);
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildModifiersSection(theme),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                          isEditing ? 'Enregistrer' : 'Ajouter à la carte'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Brouillon éditable d'une option (nom + surcoût), avec contrôleurs stables
/// pendant l'édition du groupe.
class _OptionDraft {
  final TextEditingController name;
  final TextEditingController delta;
  _OptionDraft({String name = '', double delta = 0})
      : name = TextEditingController(text: name),
        delta = TextEditingController(
            text: delta == 0 ? '' : delta.toStringAsFixed(0));

  void dispose() {
    name.dispose();
    delta.dispose();
  }
}

/// Sous-formulaire d'un GROUPE de modificateurs, présenté en DIALOG (modal
/// desktop) — pas une feuille basse. Renvoie via `Navigator.pop` un
/// [ModifierGroup] validé, ou `null` si annulé.
class _GroupEditorDialog extends StatefulWidget {
  final ModifierGroup? existing;
  const _GroupEditorDialog({this.existing});

  @override
  State<_GroupEditorDialog> createState() => _GroupEditorDialogState();
}

class _GroupEditorDialogState extends State<_GroupEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _required = false;
  bool _singleChoice = true;
  late final List<_OptionDraft> _options;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    _nameController = TextEditingController(text: g?.name ?? '');
    _required = g?.required ?? false;
    _singleChoice = g?.isSingleChoice ?? true;
    _options = [
      if (g != null)
        for (final o in g.options)
          _OptionDraft(name: o.name, delta: o.priceDeltaCdf),
    ];
    if (_options.isEmpty) {
      _options.add(_OptionDraft());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final options = <ModifierOption>[];
    for (final o in _options) {
      final name = o.name.text.trim();
      if (name.isEmpty) continue; // Ligne d'option vide → ignorée.
      options.add(ModifierOption(
        name: name,
        priceDeltaCdf: double.tryParse(o.delta.text.trim()) ?? 0,
      ));
    }
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins une option.')),
      );
      return;
    }
    final group = ModifierGroup(
      name: _nameController.text.trim(),
      required: _required,
      // Choix unique → max 1 ; obligatoire → au moins 1.
      minSelect: _required ? 1 : null,
      maxSelect: _singleChoice ? 1 : null,
      options: options,
    );
    Navigator.pop(context, group);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEditing
                            ? 'Modifier le groupe'
                            : 'Nouveau groupe d\'options',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  shrinkWrap: true,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Nom du groupe *',
                        hintText: 'Ex. Cuisson, Suppléments…',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.tune),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Le nom est requis'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Obligatoire'),
                      subtitle: const Text(
                          'Le client doit choisir avant de commander.'),
                      value: _required,
                      onChanged: (v) => setState(() => _required = v),
                    ),
                    const SizedBox(height: 4),
                    Text('Type de choix',
                        style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('Choix unique'),
                          icon: Icon(Icons.radio_button_checked),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('Choix multiple'),
                          icon: Icon(Icons.check_box),
                        ),
                      ],
                      selected: {_singleChoice},
                      onSelectionChanged: (s) =>
                          setState(() => _singleChoice = s.first),
                    ),
                    const SizedBox(height: 20),
                    Text('Options',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    for (int i = 0; i < _options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _options[i].name,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  labelText: 'Option',
                                  hintText: 'Ex. Bien cuit',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _options[i].delta,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d+\.?\d{0,2}')),
                                ],
                                decoration: const InputDecoration(
                                  labelText: '+ CDF',
                                  hintText: '0',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Retirer',
                              icon: Icon(Icons.remove_circle_outline,
                                  color: theme.colorScheme.error),
                              visualDensity: VisualDensity.compact,
                              onPressed: _options.length == 1
                                  ? null
                                  : () => setState(() {
                                        _options.removeAt(i).dispose();
                                      }),
                            ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => _options.add(_OptionDraft())),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une option'),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check),
                      label: Text(isEditing
                          ? 'Enregistrer le groupe'
                          : 'Ajouter le groupe'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
