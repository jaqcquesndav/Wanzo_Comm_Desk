import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wanzo/core/modules/activity_mode.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/features/customer/models/customer.dart';
import 'package:wanzo/features/customer/services/customer_api_service.dart';
import 'package:wanzo/features/atelier/cubit/atelier_orders_cubit.dart';
import 'package:wanzo/features/atelier/models/atelier_order.dart';
import 'package:wanzo/features/atelier/screens/atelier_client_profile_screen.dart';
import 'package:wanzo/features/atelier/services/atelier_api_service.dart';

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
  final _atelierApi = AtelierApiService();

  /// Dernier métier choisi dans la session : un atelier ne fait en général qu'un
  /// seul métier, on évite de reforcer « couture » à chaque commande.
  static AtelierMetier _lastMetier = AtelierMetier.couture;

  String? _customerId;
  String? _customerName;
  // null = vérification en cours ; true/false = mesures déjà saisies ou non.
  bool? _hasMeasurements;
  AtelierMetier _metier = _lastMetier;
  final _labelCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _totalCtrl = TextEditingController(text: '0');
  final _advanceCtrl = TextEditingController(text: '0');
  final _rateCtrl = TextEditingController(text: '1');
  // ── Fiche appareil (atelier de maintenance) ──
  final _devTypeCtrl = TextEditingController();
  final _devBrandCtrl = TextEditingController();
  final _devModelCtrl = TextEditingController();
  final _devSerialCtrl = TextEditingController();
  final _faultCtrl = TextEditingController();
  final _diagnosticCtrl = TextEditingController();
  final _repairCtrl = TextEditingController();
  final _warrantyCtrl = TextEditingController();
  final _technicianCtrl = TextEditingController();
  String? _exitState;
  String? _testResult;
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
      _metier = o.metier;
      _labelCtrl.text = o.label;
      _modelCtrl.text = o.modelDetails ?? '';
      _totalCtrl.text = o.totalAmount.toString();
      _advanceCtrl.text = o.advanceAmount.toString();
      _rateCtrl.text = o.exchangeRate.toString();
      _entryDate = o.entryDate;
      _exitDate = o.exitDate;
      _currency = o.currencyCode;
      _fabric = o.fabricProvidedBy;
      final m = o.maintenanceDetails;
      if (m != null) {
        _devTypeCtrl.text = m.deviceType ?? '';
        _devBrandCtrl.text = m.brand ?? '';
        _devModelCtrl.text = m.model ?? '';
        _devSerialCtrl.text = m.serialNumber ?? '';
        _faultCtrl.text = m.reportedFault ?? '';
        _diagnosticCtrl.text = m.diagnostic ?? '';
        _repairCtrl.text = m.repairDone ?? '';
        _warrantyCtrl.text = m.warrantyDays?.toString() ?? '';
        _technicianCtrl.text = m.technicianName ?? '';
        _exitState = m.exitState;
        _testResult = m.testResult;
      }
      if (o.metier.usesMeasurements) _checkMeasurements(o.customerId);
    } else {
      _entryDate = DateTime.now();
      // Défaut du métier selon le mode d'activité de l'entreprise.
      if (BusinessContextService().activityMode ==
          ActivityMode.atelierMaintenance) {
        _metier = AtelierMetier.maintenance;
      }
    }
  }

  /// Les mesures appartiennent au CLIENT (pas à la commande) : une fois saisies,
  /// elles sont réutilisées d'une commande à l'autre. On l'indique clairement.
  static const _measurementKeys = [
    'totalHeight', 'chestContour', 'sleeveHeight', 'shoulder', 'totalHeight2',
    'waistContour', 'thighContour', 'legContour', 'kneeContour', 'calfContour',
    'shoeSize', 'footLength',
  ];

  Future<void> _checkMeasurements(String customerId) async {
    if (mounted) setState(() => _hasMeasurements = null);
    try {
      final p = await _atelierApi.getProfile(customerId);
      final has = p != null && _measurementKeys.any((k) => p[k] != null);
      if (mounted) setState(() => _hasMeasurements = has);
    } catch (_) {
      if (mounted) setState(() => _hasMeasurements = false);
    }
  }

  Future<void> _openMeasurements() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AtelierClientProfileScreen(
          customerId: _customerId!,
          customerName: _customerName,
          metier: _metier,
        ),
      ),
    );
    // Rafraîchir l'indicateur au retour (des mesures ont pu être saisies).
    if (_customerId != null) _checkMeasurements(_customerId!);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _modelCtrl.dispose();
    _totalCtrl.dispose();
    _advanceCtrl.dispose();
    _rateCtrl.dispose();
    _devTypeCtrl.dispose();
    _devBrandCtrl.dispose();
    _devModelCtrl.dispose();
    _devSerialCtrl.dispose();
    _faultCtrl.dispose();
    _diagnosticCtrl.dispose();
    _repairCtrl.dispose();
    _warrantyCtrl.dispose();
    _technicianCtrl.dispose();
    super.dispose();
  }

  bool get _isMaintenance => _metier == AtelierMetier.maintenance;

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
                // ── Métier de l'atelier ──
                _metierSelector(),
                const SizedBox(height: 16),
                // ── Client ──
                _customerField(),
                if (_customerId != null && _metier.usesMeasurements) ...[
                  const SizedBox(height: 8),
                  _measurementsBanner(),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _labelCtrl,
                  decoration: InputDecoration(
                    labelText: 'Libellé *',
                    hintText: _isMaintenance
                        ? 'Ex. Réparation TV Samsung, Vidange moteur…'
                        : 'Ex. Robe wax, Costume 3 pièces…',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 16),
                if (_isMaintenance)
                  _maintenanceSection()
                else
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
                if (!_isMaintenance) ...[
                  const SizedBox(height: 16),
                  // ── Tissu (couture) ──
                  _fabricDropdown(),
                ],
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

  /// Indique si le client a déjà des mesures (réutilisées) ou non — pour lever
  /// le doute « faut-il reprendre les mesures à chaque commande ? » (non).
  Widget _measurementsBanner() {
    final has = _hasMeasurements;
    late final IconData icon;
    late final Color color;
    late final String text;
    if (has == null) {
      icon = Icons.hourglass_empty;
      color = Colors.grey;
      text = 'Vérification des mesures…';
    } else if (has) {
      icon = Icons.check_circle;
      color = const Color(0xFF16A34A);
      text = 'Mesures déjà enregistrées — réutilisées pour cette commande';
    } else {
      icon = Icons.straighten;
      color = const Color(0xFFF59E0B);
      text = 'Aucune mesure — à saisir une seule fois (réutilisée ensuite)';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          if (has != null)
            TextButton(
              onPressed: _openMeasurements,
              child: Text(has ? 'Voir / modifier' : 'Saisir'),
            ),
        ],
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
      onSelected: (c) {
        setState(() {
          _customerId = c.id;
          _customerName = c.name;
        });
        _checkMeasurements(c.id);
      },
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

  /// Sélecteur de métier. En édition, le métier est figé (une commande garde son
  /// métier). En création, il détermine tout le reste du formulaire.
  Widget _metierSelector() {
    if (_isEdit) {
      return InputDecorator(
        decoration: const InputDecoration(
            labelText: 'Métier', border: OutlineInputBorder()),
        child: Text(_metier.label),
      );
    }
    return DropdownButtonFormField<AtelierMetier>(
      value: _metier,
      decoration: const InputDecoration(
          labelText: 'Métier de l\'atelier', border: OutlineInputBorder()),
      items: [
        for (final m in AtelierMetier.values)
          DropdownMenuItem(value: m, child: Text(m.label)),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() => _metier = v);
        if (v.usesMeasurements && _customerId != null) {
          _checkMeasurements(_customerId!);
        }
      },
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );

  Widget _tf(TextEditingController c, String label,
      {String? hint, int min = 1, int max = 1, TextInputType? keyboard}) {
    return TextFormField(
      controller: c,
      minLines: min,
      maxLines: max,
      keyboardType: keyboard,
      decoration: InputDecoration(
          labelText: label, hintText: hint, border: const OutlineInputBorder()),
    );
  }

  /// Fiche appareil/panne d'un atelier de MAINTENANCE (calquée sur la fiche de
  /// réception/réparation papier). Aucun vocabulaire couture ici.
  Widget _maintenanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Appareil reçu'),
        _tf(_devTypeCtrl, 'Type d\'appareil',
            hint: 'TV, smartphone, moteur, frigo…'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _tf(_devBrandCtrl, 'Marque')),
            const SizedBox(width: 12),
            Expanded(child: _tf(_devModelCtrl, 'Modèle')),
          ],
        ),
        const SizedBox(height: 12),
        _tf(_devSerialCtrl, 'N° de série / IMEI / VIN'),
        const SizedBox(height: 12),
        _tf(_faultCtrl, 'Panne signalée par le client',
            hint: 'Symptômes, circonstances…', min: 2, max: 3),
        const SizedBox(height: 20),
        _sectionTitle('Diagnostic & réparation'),
        _tf(_diagnosticCtrl, 'Diagnostic technique', min: 2, max: 3),
        const SizedBox(height: 12),
        _tf(_repairCtrl, 'Réparation / réglage effectué', min: 2, max: 3),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _exitState,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'État de sortie', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'repaired', child: Text('Réparé')),
                  DropdownMenuItem(value: 'partial', child: Text('Partiel')),
                  DropdownMenuItem(
                      value: 'not_repaired', child: Text('Non réparé')),
                  DropdownMenuItem(
                      value: 'irreparable', child: Text('Irréparable')),
                ],
                onChanged: (v) => setState(() => _exitState = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _testResult,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Test final', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'conform', child: Text('Conforme')),
                  DropdownMenuItem(value: 'to_review', child: Text('À revoir')),
                  DropdownMenuItem(
                      value: 'not_tested', child: Text('Non testé')),
                ],
                onChanged: (v) => setState(() => _testResult = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _tf(_warrantyCtrl, 'Garantie (jours)',
                  keyboard: TextInputType.number),
            ),
            const SizedBox(width: 12),
            Expanded(child: _tf(_technicianCtrl, 'Technicien')),
          ],
        ),
      ],
    );
  }

  MaintenanceDetails? _buildMaintenanceDetails() {
    if (!_isMaintenance) return null;
    String? t(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final d = MaintenanceDetails(
      deviceType: t(_devTypeCtrl),
      brand: t(_devBrandCtrl),
      model: t(_devModelCtrl),
      serialNumber: t(_devSerialCtrl),
      reportedFault: t(_faultCtrl),
      diagnostic: t(_diagnosticCtrl),
      repairDone: t(_repairCtrl),
      exitState: _exitState,
      testResult: _testResult,
      warrantyDays: _warrantyCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_warrantyCtrl.text.trim()),
      technicianName: t(_technicianCtrl),
    );
    return d.isEmpty ? null : d;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    _lastMetier = _metier;
    final cubit = context.read<AtelierOrdersCubit>();
    final draft = AtelierOrder(
      id: widget.order?.id ?? '',
      customerId: _customerId!,
      customerName: _customerName,
      label: _labelCtrl.text.trim(),
      metier: _metier,
      maintenanceDetails: _buildMaintenanceDetails(),
      modelDetails: _isMaintenance
          ? null
          : (_modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim()),
      entryDate: _entryDate,
      exitDate: _exitDate,
      totalAmount: double.tryParse(_totalCtrl.text) ?? 0,
      advanceAmount: double.tryParse(_advanceCtrl.text) ?? 0,
      currencyCode: _currency,
      exchangeRate: _currency == 'CDF' ? 1 : (double.tryParse(_rateCtrl.text) ?? 1),
      fabricProvidedBy: _isMaintenance ? null : _fabric,
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
