import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../customer/models/customer.dart';
import '../../customer/services/customer_api_service.dart';
import '../cubit/atelier_orders_cubit.dart';
import '../models/atelier_order.dart';
import 'atelier_client_profile_screen.dart';

/// Formulaire de création / modification d'une commande de confection.
///
/// Sélecteur client avec recherche, détails de confection (modèle, dates),
/// montants multi-devises (avance/reste calculé), tissu fourni par. Les MESURES
/// ne sont PAS ici : elles vivent sur la fiche client (réutilisées).
class AtelierOrderFormScreen extends StatefulWidget {
  final AtelierOrder? order;
  const AtelierOrderFormScreen({super.key, this.order});

  @override
  State<AtelierOrderFormScreen> createState() => _AtelierOrderFormScreenState();
}

class _AtelierOrderFormScreenState extends State<AtelierOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerApi = CustomerApiService();

  String? _customerId;
  String? _customerName;
  final _labelCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _totalCtrl = TextEditingController(text: '0');
  final _advanceCtrl = TextEditingController(text: '0');
  final _rateCtrl = TextEditingController(text: '1');
  DateTime? _entryDate;
  DateTime? _exitDate;
  String _currency = 'CDF';
  FabricProvidedBy? _fabric;
  bool _saving = false;

  bool get _isEdit => widget.order != null;

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    if (o != null) {
      _customerId = o.customerId;
      _customerName = o.customerName;
      _labelCtrl.text = o.label;
      _modelCtrl.text = o.modelDetails ?? '';
      _totalCtrl.text = o.totalAmount.toString();
      _advanceCtrl.text = o.advanceAmount.toString();
      _rateCtrl.text = o.exchangeRate.toString();
      _entryDate = o.entryDate;
      _exitDate = o.exitDate;
      _currency = o.currencyCode;
      _fabric = o.fabricProvidedBy;
    } else {
      _entryDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _modelCtrl.dispose();
    _totalCtrl.dispose();
    _advanceCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  double get _remaining {
    final t = double.tryParse(_totalCtrl.text) ?? 0;
    final a = double.tryParse(_advanceCtrl.text) ?? 0;
    final r = t - a;
    return r > 0 ? r : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier la commande' : 'Nouvelle commande — Atelier'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Client ──
                _customerField(),
                if (_customerId != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.straighten, size: 18),
                      label: const Text('Mesures du client'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AtelierClientProfileScreen(
                            customerId: _customerId!,
                            customerName: _customerName,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Libellé *',
                    hintText: 'Ex. Robe wax, Costume 3 pièces…',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _modelCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Modèle et détails',
                    hintText: 'Modèle, finitions, tissu, remarques…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // ── Dates ──
                Row(
                  children: [
                    Expanded(child: _dateField('Date d\'entrée', _entryDate, (d) => setState(() => _entryDate = d))),
                    const SizedBox(width: 12),
                    Expanded(child: _dateField('Date de sortie', _exitDate, (d) => setState(() => _exitDate = d))),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Montants ──
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _totalCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Montant total', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _currencyDropdown()),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _advanceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Avance', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Reste', border: OutlineInputBorder()),
                        child: Text(
                          '${_remaining.toStringAsFixed(_currency == 'CDF' ? 0 : 2)} $_currency',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_currency != 'CDF') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Taux de change (1 $_currency = ? CDF)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // ── Tissu ──
                _fabricDropdown(),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: Text(_isEdit ? 'Enregistrer' : 'Créer la commande'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _customerField() {
    if (_isEdit) {
      // En édition, le client n'est pas modifiable (une commande = un client).
      return InputDecorator(
        decoration: const InputDecoration(labelText: 'Client', border: OutlineInputBorder()),
        child: Text(_customerName ?? _customerId ?? '—'),
      );
    }
    return Autocomplete<Customer>(
      displayStringForOption: (c) => c.name,
      optionsBuilder: (value) async {
        final q = value.text.trim();
        if (q.length < 2) return const Iterable<Customer>.empty();
        try {
          final res = await _customerApi.getCustomers(search: q, limit: 10);
          return res.data ?? const [];
        } catch (_) {
          return const Iterable<Customer>.empty();
        }
      },
      onSelected: (c) => setState(() {
        _customerId = c.id;
        _customerName = c.name;
      }),
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Client *',
            hintText: 'Rechercher un client (min. 2 lettres)…',
            border: const OutlineInputBorder(),
            suffixIcon: _customerId != null ? const Icon(Icons.check, color: Colors.green) : null,
          ),
          validator: (_) => _customerId == null ? 'Sélectionnez un client' : null,
        );
      },
    );
  }

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime?> onPick) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(
          value != null
              ? '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}'
              : '—',
        ),
      ),
    );
  }

  Widget _currencyDropdown() {
    return DropdownButtonFormField<String>(
      value: _currency,
      decoration: const InputDecoration(labelText: 'Devise', border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(value: 'CDF', child: Text('CDF')),
        DropdownMenuItem(value: 'USD', child: Text('USD')),
      ],
      onChanged: (v) => setState(() => _currency = v ?? 'CDF'),
    );
  }

  Widget _fabricDropdown() {
    return DropdownButtonFormField<FabricProvidedBy?>(
      value: _fabric,
      decoration: const InputDecoration(labelText: 'Tissu acheté par', border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(value: null, child: Text('—')),
        DropdownMenuItem(value: FabricProvidedBy.client, child: Text('Client')),
        DropdownMenuItem(value: FabricProvidedBy.atelier, child: Text('Atelier')),
      ],
      onChanged: (v) => setState(() => _fabric = v),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final cubit = context.read<AtelierOrdersCubit>();
    final draft = AtelierOrder(
      id: widget.order?.id ?? '',
      customerId: _customerId!,
      customerName: _customerName,
      label: _labelCtrl.text.trim(),
      modelDetails: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
      entryDate: _entryDate,
      exitDate: _exitDate,
      totalAmount: double.tryParse(_totalCtrl.text) ?? 0,
      advanceAmount: double.tryParse(_advanceCtrl.text) ?? 0,
      currencyCode: _currency,
      exchangeRate: _currency == 'CDF' ? 1 : (double.tryParse(_rateCtrl.text) ?? 1),
      fabricProvidedBy: _fabric,
    );

    final result = _isEdit
        ? await cubit.updateOrder(widget.order!.id, draft.toCreateJson())
        : await cubit.createOrder(draft);

    if (!mounted) return;
    setState(() => _saving = false);
    if (result != null) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de l\'enregistrement')),
      );
    }
  }
}
