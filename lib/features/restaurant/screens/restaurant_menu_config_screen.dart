import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wanzo/core/shared_widgets/empty_state_view.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/features/inventory/models/product.dart';
import 'package:wanzo/features/inventory/repositories/inventory_repository.dart';

import '../models/menu_course.dart';
import '../repositories/menu_config_repository.dart';

/// Configuration de la CARTE du restaurant : parmi les produits du catalogue,
/// désigner ceux qui sont servis (au menu) et leur catégorie (entrée, plat,
/// dessert, boisson…). Les produits sans catégorie restent du stock ordinaire
/// et n'apparaissent PAS lors de la prise de commande.
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
  String _search = '';

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

  Future<void> _assign(Product product, MenuCourse? course) async {
    if (course == null) {
      await _menuRepo.removeFromMenu(product.id);
      setState(() => _config.remove(product.id));
    } else {
      await _menuRepo.setCourse(product.id, course);
      setState(() => _config[product.id] = course);
    }
  }

  List<Product> get _filtered {
    if (_search.isEmpty) return _products;
    final q = _search.toLowerCase();
    return _products.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final onMenuCount = _config.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Composer la carte'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '$onMenuCount produit(s) à la carte',
              style: Theme.of(context).textTheme.bodySmall,
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
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher un produit…',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) =>
                            _tile(_filtered[i]),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _tile(Product product) {
    final current = _config[product.id];
    return ListTile(
      title: Text(product.name),
      subtitle: Text(formatCurrency(product.sellingPriceInCdf, 'CDF')),
      trailing: DropdownButton<MenuCourse?>(
        value: current,
        hint: const Text('Pas au menu'),
        underline: const SizedBox(),
        items: [
          const DropdownMenuItem<MenuCourse?>(
            value: null,
            child: Text('Pas au menu'),
          ),
          for (final c in MenuCourse.values)
            DropdownMenuItem<MenuCourse?>(value: c, child: Text(c.label)),
        ],
        onChanged: (course) => _assign(product, course),
      ),
    );
  }
}
