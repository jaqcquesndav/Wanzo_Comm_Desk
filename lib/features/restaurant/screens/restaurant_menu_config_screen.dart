import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wanzo/core/shared_widgets/empty_state_view.dart';
import 'package:wanzo/core/widgets/smart_image.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/features/inventory/models/product.dart';
import 'package:wanzo/features/inventory/repositories/inventory_repository.dart';

import '../models/menu_course.dart';
import '../repositories/menu_config_repository.dart';

/// Composition de la CARTE du restaurant : on construit un vrai menu, organisé
/// par service (Entrées, Plats, …). Chaque plat est une carte (photo, nom, prix,
/// description) ; on ajoute un plat via un sélecteur de produits du catalogue.
/// Les produits non ajoutés restent du stock ordinaire (invisibles à la carte).
class RestaurantMenuConfigScreen extends StatefulWidget {
  const RestaurantMenuConfigScreen({super.key});

  @override
  State<RestaurantMenuConfigScreen> createState() =>
      _RestaurantMenuConfigScreenState();
}

class _RestaurantMenuConfigScreenState
    extends State<RestaurantMenuConfigScreen> {
  final MenuConfigRepository _menuRepo = MenuConfigRepository();
  late final List<Product> _products;
  Map<String, MenuCourse> _config = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _products = context.read<InventoryRepository>().getAllProducts();
    _load();
  }

  Future<void> _load() async {
    final config = await _menuRepo.loadAll();
    if (!mounted) return;
    setState(() {
      _config = config;
      _loading = false;
    });
  }

  Product? _productById(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Plats de la carte pour un service donné.
  List<Product> _dishesFor(MenuCourse course) {
    final ids = _config.entries
        .where((e) => e.value == course)
        .map((e) => e.key)
        .toList();
    return ids
        .map(_productById)
        .whereType<Product>()
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> _setCourse(String productId, MenuCourse course) async {
    await _menuRepo.setCourse(productId, course);
    setState(() => _config[productId] = course);
  }

  Future<void> _removeFromMenu(String productId) async {
    await _menuRepo.removeFromMenu(productId);
    setState(() => _config.remove(productId));
  }

  @override
  Widget build(BuildContext context) {
    final onMenuCount = _config.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Composer la carte'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$onMenuCount plat(s) à la carte · ${_products.length} au catalogue',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const EmptyStateView(
                  icon: Icons.inventory_2,
                  message:
                      'Aucun produit au catalogue.\nAjoutez vos plats et boissons dans le Stock.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    // MenuCourse.values est déjà déclaré dans l'ordre de service.
                    for (final course in MenuCourse.values)
                      _courseSection(course),
                  ],
                ),
    );
  }

  Widget _courseSection(MenuCourse course) {
    final theme = Theme.of(context);
    final dishes = _dishesFor(course);
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
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddDish(course),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter un plat'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (dishes.isEmpty)
            _emptyCourse(course)
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [for (final p in dishes) _dishCard(p)],
            ),
        ],
      ),
    );
  }

  Widget _emptyCourse(MenuCourse course) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showAddDish(course),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.add_circle_outline,
                color: theme.colorScheme.outline, size: 22),
            const SizedBox(height: 4),
            Text('Aucun plat dans « ${course.label} » — ajouter',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }

  Widget _dishCard(Product p) {
    final theme = Theme.of(context);
    final description = p.description.trim();
    return SizedBox(
      width: 220,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SmartImage(
                  imageUrl: p.imageUrl,
                  imagePath: p.imagePath,
                  fit: BoxFit.cover,
                  width: 220,
                  height: 120,
                  placeholderIcon: p.category.icon,
                  placeholderColor: theme.colorScheme.surfaceContainerHighest,
                  placeholderIconSize: 34,
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Retirer de la carte',
                      icon: const Icon(Icons.close, size: 18, color: Colors.white),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _removeFromMenu(p.id),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(formatCurrency(p.sellingPriceInCdf, 'CDF'),
                      style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
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
          ],
        ),
      ),
    );
  }

  /// Sélecteur de produits à AJOUTER à un service : liste recherchable des
  /// produits pas encore à la carte (ou sur un autre service).
  Future<void> _showAddDish(MenuCourse course) async {
    final available = _products
        .where((p) => _config[p.id] != course)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final picked = await showDialog<Product>(
      context: context,
      builder: (ctx) => _AddDishDialog(course: course, products: available),
    );
    if (picked != null) {
      await _setCourse(picked.id, course);
    }
  }
}

/// Dialogue d'ajout d'un plat à un service : recherche + liste avec vignette.
class _AddDishDialog extends StatefulWidget {
  final MenuCourse course;
  final List<Product> products;
  const _AddDishDialog({required this.course, required this.products});

  @override
  State<_AddDishDialog> createState() => _AddDishDialogState();
}

class _AddDishDialogState extends State<_AddDishDialog> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? widget.products
        : widget.products
            .where((p) => p.name.toLowerCase().contains(q))
            .toList();
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ajouter à « ${widget.course.label} »',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    onChanged: (v) => setState(() => _q = v),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un produit…',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Aucun produit disponible',
                          style: TextStyle(color: Color(0xFF6B7280))),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final p = list[i];
                        return ListTile(
                          leading: SmartImage(
                            imageUrl: p.imageUrl,
                            imagePath: p.imagePath,
                            fit: BoxFit.cover,
                            width: 44,
                            height: 44,
                            borderRadius: BorderRadius.circular(8),
                            placeholderIcon: p.category.icon,
                            placeholderColor:
                                theme.colorScheme.surfaceContainerHighest,
                            placeholderIconSize: 20,
                          ),
                          title: Text(p.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle:
                              Text(formatCurrency(p.sellingPriceInCdf, 'CDF')),
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
