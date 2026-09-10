import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/supplier_bloc.dart';
import '../models/supplier.dart';

/// Champ de sélection de fournisseur robuste et partagé entre les formulaires.
///
/// Pendant fournisseur de [CustomerPickerField] : liste amorcée depuis le cache
/// Hive (repository `forceLocal`) avec filtrage LOCAL instantané, recherche
/// serveur en complément (debounce ~300 ms) fusionnée dans la liste, repli hors
/// ligne silencieux, et création inline (« + Nouveau ») sans quitter le
/// formulaire.
class SupplierPickerField extends StatefulWidget {
  /// Contrôleur qui porte le NOM du fournisseur (source de vérité parent).
  final TextEditingController controller;

  /// Appelé avec le fournisseur choisi/créé, ou `null` en saisie libre.
  final ValueChanged<Supplier?> onSelected;

  /// Contrôleur optionnel du téléphone (renseigné à la sélection).
  final TextEditingController? phoneController;

  final String label;
  final String? hint;
  final String? Function(String?)? validator;

  final bool enableCreate;

  final Supplier? initialSupplier;

  const SupplierPickerField({
    super.key,
    required this.controller,
    required this.onSelected,
    this.phoneController,
    this.label = 'Fournisseur',
    this.hint,
    this.validator,
    this.enableCreate = true,
    this.initialSupplier,
  });

  @override
  State<SupplierPickerField> createState() => _SupplierPickerFieldState();
}

class _SupplierPickerFieldState extends State<SupplierPickerField> {
  final List<Supplier> _all = [];
  Supplier? _selected;
  Timer? _debounce;
  bool _searching = false;

  SupplierBloc get _bloc => context.read<SupplierBloc>();

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSupplier;
    _primeCache();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _primeCache() async {
    try {
      final local = await _bloc.supplierRepository.getSuppliers(
        forceLocal: true,
      );
      if (!mounted) return;
      _mergeInto(local);
    } catch (_) {}
    try {
      await _bloc.supplierRepository.getSuppliers();
      if (!mounted) return;
      final refreshed = await _bloc.supplierRepository.getSuppliers(
        forceLocal: true,
      );
      if (!mounted) return;
      _mergeInto(refreshed);
    } catch (_) {}
  }

  void _mergeInto(List<Supplier> incoming) {
    final byId = {for (final s in _all) s.id: s};
    for (final s in incoming) {
      byId[s.id] = s;
    }
    setState(() {
      _all
        ..clear()
        ..addAll(byId.values);
    });
  }

  void _onQueryChanged(String text) {
    widget.controller.text = text;
    if (_selected != null && _selected!.name != text) {
      setState(() => _selected = null);
      widget.onSelected(null);
    }
    final query = text.trim();
    _debounce?.cancel();
    if (query.length < 2 || _searching) return;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      _searching = true;
      try {
        final results = await _bloc.supplierRepository.searchSuppliers(query);
        if (mounted) _mergeInto(results);
      } catch (_) {
      } finally {
        _searching = false;
      }
    });
  }

  Iterable<Supplier> _localMatches(String query) {
    final q = query.toLowerCase();
    final digits = query.replaceAll(RegExp(r'\D'), '');
    return _all.where((s) {
      final byName = s.name.toLowerCase().contains(q);
      final byContact = s.contactPerson.toLowerCase().contains(q);
      final byPhone = s.phoneNumber.toLowerCase().contains(q) ||
          (digits.isNotEmpty &&
              s.phoneNumber.replaceAll(RegExp(r'\D'), '').contains(digits));
      return byName || byContact || byPhone;
    });
  }

  void _select(Supplier s) {
    setState(() => _selected = s);
    widget.controller.text = s.name;
    widget.phoneController?.text = s.phoneNumber;
    widget.onSelected(s);
    FocusScope.of(context).unfocus();
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<Supplier>(
      context: context,
      builder: (_) => _CreateSupplierDialog(
        bloc: _bloc,
        initialName: widget.controller.text.trim(),
        initialPhone: widget.phoneController?.text.trim() ?? '',
      ),
    );
    if (created != null && mounted) {
      _mergeInto([created]);
      _select(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Autocomplete<Supplier>(
            initialValue: TextEditingValue(text: widget.controller.text),
            optionsBuilder: (TextEditingValue value) {
              final query = value.text.trim();
              if (query.isEmpty) return const Iterable<Supplier>.empty();
              _onQueryChanged(value.text);
              return _localMatches(query);
            },
            displayStringForOption: (s) => s.name,
            onSelected: _select,
            fieldViewBuilder:
                (context, textController, focusNode, onFieldSubmitted) {
              if (textController.text != widget.controller.text) {
                textController.text = widget.controller.text;
              }
              return TextFormField(
                controller: textController,
                focusNode: focusNode,
                validator: widget.validator,
                decoration: InputDecoration(
                  labelText: widget.label,
                  hintText: widget.hint,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: _selected != null
                      ? const Icon(Icons.check_circle,
                          size: 18, color: Color(0xFF10B981))
                      : const Icon(Icons.store_mall_directory_outlined,
                          size: 18),
                ),
                onChanged: _onQueryChanged,
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxHeight: 260, maxWidth: 420),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      children: [
                        ...options.map(
                          (s) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.store, size: 20),
                            title: Text(s.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: s.phoneNumber.isNotEmpty
                                ? Text(s.phoneNumber)
                                : (s.contactPerson.isNotEmpty
                                    ? Text(s.contactPerson)
                                    : null),
                            onTap: () => onSelected(s),
                          ),
                        ),
                        if (widget.enableCreate)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.add_business,
                                size: 20, color: Color(0xFF2563EB)),
                            title: const Text('Nouveau fournisseur',
                                style: TextStyle(color: Color(0xFF2563EB))),
                            onTap: () => _openCreateDialog(),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.enableCreate) ...[
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: IconButton(
              tooltip: 'Nouveau fournisseur',
              icon: const Icon(Icons.add_business),
              onPressed: () => _openCreateDialog(),
            ),
          ),
        ],
      ],
    );
  }
}

class _CreateSupplierDialog extends StatefulWidget {
  final SupplierBloc bloc;
  final String initialName;
  final String initialPhone;

  const _CreateSupplierDialog({
    required this.bloc,
    required this.initialName,
    required this.initialPhone,
  });

  @override
  State<_CreateSupplierDialog> createState() => _CreateSupplierDialogState();
}

class _CreateSupplierDialogState extends State<_CreateSupplierDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);
  late final TextEditingController _phone =
      TextEditingController(text: widget.initialPhone);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final created = await widget.bloc.supplierRepository.addSupplier(
        Supplier(
          id: '',
          name: name,
          phoneNumber: _phone.text.trim(),
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) Navigator.of(context).pop(created);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Création impossible: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau fournisseur'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Téléphone'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
