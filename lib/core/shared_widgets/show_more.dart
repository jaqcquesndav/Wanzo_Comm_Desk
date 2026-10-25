import 'package:flutter/material.dart';

/// Nombre d'elements ajoutes a chaque « Afficher plus ».
const int kShowMoreStep = 50;

/// Pagination locale d'une liste deja chargee : on n'en dessine que le debut,
/// puis l'utilisateur demande la suite. Une carte de 400 plats ou une
/// tarification de 300 prestations ne se dessine plus d'un seul bloc.
List<T> visibleSlice<T>(List<T> all, int visible) =>
    all.length <= visible ? all : all.sublist(0, visible < 0 ? 0 : visible);

/// Prochain nombre d'elements visibles, borne au total.
int nextVisibleCount(int current, int total, {int step = kShowMoreStep}) {
  final next = current + step;
  return next > total ? total : next;
}

/// Meme pagination pour une liste rangee par groupes (plats par service,
/// prestations par categorie) : le quota d'elements visibles se consomme
/// groupe apres groupe, dans l'ordre des [keys]. Un groupe vide disparait.
List<MapEntry<K, List<T>>> visibleGroups<K, T>(
  List<K> keys,
  Map<K, List<T>> grouped,
  int visible,
) {
  final out = <MapEntry<K, List<T>>>[];
  var budget = visible;
  for (final k in keys) {
    if (budget <= 0) break;
    final items = grouped[k] ?? const [];
    if (items.isEmpty) continue;
    final slice = visibleSlice(items, budget);
    out.add(MapEntry(k, slice));
    budget -= slice.length;
  }
  return out;
}

/// Bouton « Afficher plus » en pied de liste ; rien quand tout est visible.
class ShowMoreFooter extends StatelessWidget {
  const ShowMoreFooter({
    super.key,
    required this.shown,
    required this.total,
    required this.onMore,
  });

  final int shown;
  final int total;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    if (shown >= total) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: onMore,
          icon: const Icon(Icons.expand_more),
          label: Text('Afficher plus ($shown sur $total)'),
        ),
      ),
    );
  }
}
