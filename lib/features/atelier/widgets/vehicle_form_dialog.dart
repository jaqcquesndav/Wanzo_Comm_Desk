import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/vehicle_catalog.dart';
import '../models/customer_vehicle.dart';
import '../services/atelier_api_service.dart';

/// Formulaire d'un véhicule client (création ou modification) en boîte de
/// dialogue, utilisable depuis la fiche client et depuis une commande garage.
/// Structure : Fabricant, Modèle, Année, puis le véhicule spécifique.
/// Retourne le véhicule enregistré, ou null si annulé.
Future<CustomerVehicle?> showVehicleFormDialog(
  BuildContext context, {
  required String customerId,
  CustomerVehicle? vehicle,
}) {
  return showDialog<CustomerVehicle>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _VehicleFormDialog(customerId: customerId, vehicle: vehicle),
  );
}

class _VehicleFormDialog extends StatefulWidget {
  final String customerId;
  final CustomerVehicle? vehicle;
  const _VehicleFormDialog({required this.customerId, this.vehicle});

  @override
  State<_VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<_VehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _api = AtelierApiService();
  late final _brand = TextEditingController(text: widget.vehicle?.brand ?? '');
  late final _model = TextEditingController(text: widget.vehicle?.model ?? '');
  late final _year = TextEditingController(text: widget.vehicle?.year?.toString() ?? '');
  late final _plate = TextEditingController(text: widget.vehicle?.plate ?? '');
  late final _vin = TextEditingController(text: widget.vehicle?.vin ?? '');
  late final _color = TextEditingController(text: widget.vehicle?.color ?? '');
  late final _fuel = TextEditingController(text: widget.vehicle?.fuel ?? '');
  late final _transmission = TextEditingController(text: widget.vehicle?.transmission ?? '');
  late final _bodyType = TextEditingController(text: widget.vehicle?.bodyType ?? '');
  late final _mileage = TextEditingController(text: widget.vehicle?.mileage?.toString() ?? '');
  late final _notes = TextEditingController(text: widget.vehicle?.notes ?? '');
  bool _saving = false;

  bool get _isEdit => widget.vehicle != null;

  /// Années proposées : de l'année en cours + 1 jusqu'à 1980.
  static List<String> get _years {
    final now = DateTime.now().year + 1;
    return [for (var y = now; y >= 1980; y--) '$y'];
  }

  @override
  void dispose() {
    for (final c in [_brand, _model, _year, _plate, _vin, _color, _fuel, _transmission, _bodyType, _mileage, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _auto(TextEditingController target, String label, List<String> Function() options,
      {String? hint, TextInputType? keyboard, IconData? icon}) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: target.text),
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        final all = options();
        if (q.isEmpty) return all;
        return all.where((s) => s.toLowerCase().contains(q));
      },
      onSelected: (v) => setState(() => target.text = v),
      fieldViewBuilder: (context, ctrl, focus, _) => TextFormField(
        controller: ctrl,
        focusNode: focus,
        keyboardType: keyboard,
        // Saisie libre : le référentiel n'est qu'une aide.
        onChanged: (v) => target.text = v,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          prefixIcon: icon == null ? null : Icon(icon, size: 18),
        ),
      ),
    );
  }

  Widget _tf(TextEditingController c, String label,
      {String? hint, TextInputType? keyboard, List<TextInputFormatter>? formatters, int lines = 1}) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      inputFormatters: formatters,
      maxLines: lines,
      decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_plate.text.trim().isEmpty && _brand.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indiquez au moins le fabricant ou l\'immatriculation.')),
      );
      return;
    }
    setState(() => _saving = true);
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final draft = CustomerVehicle(
      id: widget.vehicle?.id ?? '',
      customerId: widget.customerId,
      brand: t(_brand),
      model: t(_model),
      year: int.tryParse(_year.text.trim()),
      plate: t(_plate)?.toUpperCase(),
      vin: t(_vin)?.toUpperCase(),
      color: t(_color),
      fuel: t(_fuel),
      transmission: t(_transmission),
      bodyType: t(_bodyType),
      mileage: int.tryParse(_mileage.text.replaceAll(RegExp(r'[^0-9]'), '')),
      notes: t(_notes),
    );
    try {
      final saved = _isEdit
          ? await _api.updateVehicle(widget.vehicle!.id, draft.toPayload())
          : await _api.createVehicle(widget.customerId, draft.toPayload());
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enregistrement impossible : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(_isEdit ? 'Modifier le véhicule' : 'Nouveau véhicule'),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Fabricant, modèle, année',
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 8),
                _auto(_brand, 'Fabricant *', () => VehicleCatalog.brands,
                    hint: 'Toyota, Nissan, Mercedes-Benz...', icon: Icons.factory_outlined),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _auto(_model, 'Modèle', () {
                        final m = VehicleCatalog.modelsFor(_brand.text);
                        return m.isEmpty ? VehicleCatalog.models.values.expand((e) => e).toList() : m;
                      }, hint: 'Prado, Hilux, Patrol...'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _auto(_year, 'Année', () => _years, keyboard: TextInputType.number),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Véhicule spécifique',
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _tf(_plate, 'Immatriculation', hint: 'Plaque')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _tf(_mileage, 'Kilométrage',
                          keyboard: TextInputType.number,
                          formatters: [FilteringTextInputFormatter.digitsOnly]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _tf(_vin, 'Numéro de châssis (VIN)'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _auto(_color, 'Couleur', () => VehicleCatalog.colors)),
                    const SizedBox(width: 12),
                    Expanded(child: _auto(_fuel, 'Carburant', () => VehicleCatalog.fuelTypes)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _auto(_transmission, 'Boîte', () => VehicleCatalog.transmissions)),
                    const SizedBox(width: 12),
                    Expanded(child: _auto(_bodyType, 'Carrosserie', () => VehicleCatalog.bodyTypes)),
                  ],
                ),
                const SizedBox(height: 12),
                _tf(_notes, 'Remarques', hint: 'Particularités, accessoires, historique connu...', lines: 2),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined, size: 18),
          label: Text(_isEdit ? 'Enregistrer' : 'Ajouter'),
        ),
      ],
    );
  }
}
