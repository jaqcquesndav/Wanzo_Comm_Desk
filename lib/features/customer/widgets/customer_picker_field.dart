import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/customer_bloc.dart';
import '../models/customer.dart';

/// Champ de sélection de client robuste et partagé entre tous les formulaires.
///
/// Objectif : un client doit TOUJOURS être retrouvable, en ligne comme hors
/// ligne, et il doit être possible d'en créer un inexistant sans quitter le
/// formulaire.
///
/// Fonctionnement :
///  - au montage, on amorce la liste depuis le cache Hive (via le repository,
///    `forceLocal`) puis on rafraîchit en arrière-plan. Le filtrage est LOCAL et
///    instantané sur cette liste chargée (plus de course synchrone/asynchrone) ;
///  - une recherche serveur en complément (debounce ~300 ms) fusionne ses
///    résultats dans la liste locale (utile quand un contact récent n'est pas
///    encore en cache) ;
///  - hors ligne, l'échec de l'API est silencieux : on reste sur le cache ;
///  - un bouton « + Nouveau » crée le contact inline (repository -> API + Hive)
///    et le sélectionne, sans fermer le formulaire.
class CustomerPickerField extends StatefulWidget {
  /// Contrôleur qui porte le NOM du client (source de vérité pour le parent).
  final TextEditingController controller;

  /// Appelé avec le client existant/créé choisi, ou `null` quand la saisie
  /// redevient libre (client de passage / texte modifié après sélection).
  final ValueChanged<Customer?> onSelected;

  /// Contrôleur optionnel du téléphone : s'il est fourni, une sélection le
  /// renseigne et le pré-remplit dans la boîte de création inline.
  final TextEditingController? phoneController;

  final String label;
  final String? hint;
  final String? Function(String?)? validator;

  /// Autorise la création inline (bouton « + Nouveau »).
  final bool enableCreate;

  /// Client déjà sélectionné (édition / pré-remplissage).
  final Customer? initialCustomer;

  const CustomerPickerField({
    super.key,
    required this.controller,
    required this.onSelected,
    this.phoneController,
    this.label = 'Client',
    this.hint,
    this.validator,
    this.enableCreate = true,
    this.initialCustomer,
  });

  @override
  State<CustomerPickerField> createState() => _CustomerPickerFieldState();
}

class _CustomerPickerFieldState extends State<CustomerPickerField> {
  final List<Customer> _all = [];
  Customer? _selected;
  Timer? _debounce;
  bool _searching = false;

  CustomerBloc get _bloc => context.read<CustomerBloc>();

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCustomer;
    _primeCache();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Charge la liste depuis le cache Hive, puis rafraîchit en arrière-plan.
  Future<void> _primeCache() async {
    try {
      final local = await _bloc.customerRepository.getCustomers(
        forceLocal: true,
      );
      if (!mounted) return;
      _mergeInto(local);
    } catch (_) {
      // Cache indisponible : on continue, la recherche serveur prendra le relais.
    }
    // Rafraîchissement réseau non bloquant (met à jour la box puis la liste).
    try {
      await _bloc.customerRepository.getCustomers();
      if (!mounted) return;
      final refreshed = await _bloc.customerRepository.getCustomers(
        forceLocal: true,
      );
      if (!mounted) return;
      _mergeInto(refreshed);
    } catch (_) {
      // Hors ligne : on garde le cache déjà chargé.
    }
  }

  void _mergeInto(List<Customer> incoming) {
    final byId = {for (final c in _all) c.id: c};
    for (final c in incoming) {
      byId[c.id] = c;
    }
    setState(() {
      _all
        ..clear()
        ..addAll(byId.values);
    });
  }

  void _onQueryChanged(String text) {
    widget.controller.text = text;
    // Le texte ne correspond plus au client choisi -> saisie libre.
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
        final results = await _bloc.customerRepository.searchCustomers(query);
        if (mounted) _mergeInto(results);
      } catch (_) {
        // Recherche serveur indisponible : le filtrage local suffit.
      } finally {
        _searching = false;
      }
    });
  }

  Iterable<Customer> _localMatches(String query) {
    final q = query.toLowerCase();
    final digits = query.replaceAll(RegExp(r'\D'), '');
    return _all.where((c) {
      final byName = c.name.toLowerCase().contains(q);
      final byPhone = c.phoneNumber.toLowerCase().contains(q) ||
          (digits.isNotEmpty &&
              c.phoneNumber.replaceAll(RegExp(r'\D'), '').contains(digits));
      final byCode = (c.customerCode ?? '').toLowerCase().contains(q);
      return byName || byPhone || byCode;
    });
  }

  void _select(Customer c) {
    setState(() => _selected = c);
    widget.controller.text = c.name;
    widget.phoneController?.text = c.phoneNumber;
    widget.onSelected(c);
    FocusScope.of(context).unfocus();
  }

  Future<void> _openCreateDialog({String? prefillName}) async {
    final created = await showDialog<Customer>(
      context: context,
      builder: (_) => _CreateCustomerDialog(
        bloc: _bloc,
        initialName: prefillName ?? widget.controller.text.trim(),
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
          child: Autocomplete<Customer>(
            initialValue: TextEditingValue(text: widget.controller.text),
            optionsBuilder: (TextEditingValue value) {
              final query = value.text.trim();
              if (query.isEmpty) return const Iterable<Customer>.empty();
              _onQueryChanged(value.text);
              return _localMatches(query);
            },
            displayStringForOption: (c) => c.name,
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
                      : const Icon(Icons.person_search, size: 18),
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
                          (c) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.person, size: 20),
                            title: Text(c.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: c.phoneNumber.isNotEmpty
                                ? Text(c.phoneNumber)
                                : null,
                            onTap: () => onSelected(c),
                          ),
                        ),
                        if (widget.enableCreate)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.person_add,
                                size: 20, color: Color(0xFF2563EB)),
                            title: const Text('Nouveau client',
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
              tooltip: 'Nouveau client',
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: () => _openCreateDialog(),
            ),
          ),
        ],
      ],
    );
  }
}

/// Boîte de création inline d'un client (nom + téléphone), enregistré via le
/// repository (API + cache Hive) sans quitter le formulaire appelant.
class _CreateCustomerDialog extends StatefulWidget {
  final CustomerBloc bloc;
  final String initialName;
  final String initialPhone;

  const _CreateCustomerDialog({
    required this.bloc,
    required this.initialName,
    required this.initialPhone,
  });

  @override
  State<_CreateCustomerDialog> createState() => _CreateCustomerDialogState();
}

class _CreateCustomerDialogState extends State<_CreateCustomerDialog> {
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
      final created = await widget.bloc.customerRepository.addCustomer(
        Customer(
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
      title: const Text('Nouveau client'),
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
