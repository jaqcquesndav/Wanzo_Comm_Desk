import 'package:flutter/material.dart';

import '../../constants/spacing.dart';

/// Ouvre une feuille de sélection **recherchable** : champ de recherche + liste
/// PARESSEUSE (`ListView.builder`). Adaptée aux listes de plusieurs milliers
/// d'éléments — contrairement à `DropdownButtonFormField` (qui construit tous
/// les items d'un coup) ou aux filtres à défilement horizontal (illisibles au
/// delà de quelques items).
Future<T?> showSearchableSelect<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required String Function(T) itemLabel,
  String Function(T)? itemSubtitle,
  T? selected,
  String searchHint = 'Rechercher…',
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SearchableSelectSheet<T>(
      title: title,
      items: items,
      itemLabel: itemLabel,
      itemSubtitle: itemSubtitle,
      selected: selected,
      searchHint: searchHint,
    ),
  );
}

class _SearchableSelectSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) itemLabel;
  final String Function(T)? itemSubtitle;
  final T? selected;
  final String searchHint;

  const _SearchableSelectSheet({
    required this.title,
    required this.items,
    required this.itemLabel,
    required this.itemSubtitle,
    required this.selected,
    required this.searchHint,
  });

  @override
  State<_SearchableSelectSheet<T>> createState() =>
      _SearchableSelectSheetState<T>();
}

class _SearchableSelectSheetState<T> extends State<_SearchableSelectSheet<T>> {
  final _controller = TextEditingController();
  late List<T> _filtered = widget.items;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQuery(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? widget.items
          : widget.items.where((e) {
              final l = widget.itemLabel(e).toLowerCase();
              final s = widget.itemSubtitle?.call(e).toLowerCase() ?? '';
              return l.contains(query) || s.contains(query);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(WanzoSpacing.base,
                    WanzoSpacing.base, WanzoSpacing.base, WanzoSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: WanzoSpacing.sm),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onQuery,
                      decoration: InputDecoration(
                        hintText: widget.searchHint,
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(
                        child: Text('Aucun résultat',
                            style: TextStyle(color: Color(0xFF6B7280))))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filtered.length,
                        itemExtent: 56,
                        itemBuilder: (context, i) {
                          final item = _filtered[i];
                          final isSel = item == widget.selected;
                          final sub = widget.itemSubtitle?.call(item);
                          return ListTile(
                            dense: true,
                            title: Text(widget.itemLabel(item),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: (sub != null && sub.isNotEmpty)
                                ? Text(sub,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5))
                                : null,
                            trailing: isSel
                                ? const Icon(Icons.check, color: Color(0xFF197CA8))
                                : null,
                            onTap: () => Navigator.pop(context, item),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Champ de formulaire (façon `DropdownButtonFormField`) qui ouvre la feuille
/// recherchable au tap — mais tient à l'échelle de milliers d'éléments.
class SearchSelectField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final String Function(T)? itemSubtitle;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;
  final String sheetTitle;
  final String hint;

  const SearchSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.itemSubtitle,
    this.validator,
    String? sheetTitle,
    this.hint = 'Sélectionner…',
  }) : sheetTitle = sheetTitle ?? label;

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      initialValue: value,
      validator: validator,
      builder: (field) {
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final picked = await showSearchableSelect<T>(
              context,
              title: sheetTitle,
              items: items,
              itemLabel: itemLabel,
              itemSubtitle: itemSubtitle,
              selected: value,
            );
            if (picked != null) {
              field.didChange(picked);
              onChanged(picked);
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              errorText: field.errorText,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              value == null ? hint : itemLabel(value as T),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: value == null
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF111827),
              ),
            ),
          ),
        );
      },
    );
  }
}
