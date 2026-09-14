import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wanzo/core/modules/activity_mode.dart';
import 'package:wanzo/core/platform/image_picker/image_picker_service_factory.dart';
import 'package:wanzo/core/platform/image_picker/image_picker_service_interface.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/services/image_upload_service.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/core/widgets/photo_gallery_viewer.dart';
import 'package:wanzo/core/widgets/smart_image.dart';
import 'package:wanzo/features/customer/widgets/customer_picker_field.dart';
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
  final _atelierApi = AtelierApiService();
  final _customerNameController = TextEditingController();

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
  String? _specialty; // Domaine : Informatique, Automobile, Thermique…
  final _devTypeCtrl = TextEditingController();
  final _devBrandCtrl = TextEditingController();
  final _devModelCtrl = TextEditingController();
  final _devSerialCtrl = TextEditingController();
  final _plateCtrl = TextEditingController(); // Immatriculation (auto)
  final _vinCtrl = TextEditingController(); // VIN / châssis (auto)
  final _mileageCtrl = TextEditingController(); // Kilométrage (auto)
  final _fuelCtrl = TextEditingController(); // Carburant (auto)
  final _faultCtrl = TextEditingController();
  final _diagnosticCtrl = TextEditingController();
  final _repairCtrl = TextEditingController();
  final _warrantyCtrl = TextEditingController();
  final _technicianCtrl = TextEditingController();
  String? _exitState;
  String? _testResult;
  // ── Fiche travail d'impression (atelier d'imprimerie) ──
  String? _printFormat;
  final _supportCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  String _printSides = 'recto'; // recto | recto-verso
  String? _colorMode; // Quadrichromie | Noir et blanc | Pantone
  String? _finishing;
  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  bool _batValidated = false;
  final _operatorCtrl = TextEditingController();
  final _machineCtrl = TextEditingController();
  final _printInstructionsCtrl = TextEditingController();
  List<String> _designPhotos = [];
  final ImagePickerServiceInterface _imagePicker =
      ImagePickerServiceFactory.getInstance();
  final _imageUpload = ImageUploadService();
  bool _uploadingPhotos = false;
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
        _specialty = m.specialty;
        _devTypeCtrl.text = m.deviceType ?? '';
        _devBrandCtrl.text = m.brand ?? '';
        _devModelCtrl.text = m.model ?? '';
        _devSerialCtrl.text = m.serialNumber ?? '';
        _plateCtrl.text = m.plate ?? '';
        _vinCtrl.text = m.vin ?? '';
        _mileageCtrl.text = m.mileage ?? '';
        _fuelCtrl.text = m.fuel ?? '';
        _faultCtrl.text = m.reportedFault ?? '';
        _diagnosticCtrl.text = m.diagnostic ?? '';
        _repairCtrl.text = m.repairDone ?? '';
        _warrantyCtrl.text = m.warrantyDays?.toString() ?? '';
        _technicianCtrl.text = m.technicianName ?? '';
        _exitState = m.exitState;
        _testResult = m.testResult;
      }
      final p = o.printDetails;
      if (p != null) {
        _printFormat = p.format;
        _supportCtrl.text = p.support ?? '';
        _quantityCtrl.text = p.quantity?.toString() ?? '';
        _printSides = p.printSides ?? 'recto';
        _colorMode = p.colorMode;
        _finishing = p.finishing;
        _widthCtrl.text = p.width ?? '';
        _heightCtrl.text = p.height ?? '';
        _batValidated = p.batValidated ?? false;
        _operatorCtrl.text = p.operatorName ?? '';
        _machineCtrl.text = p.machine ?? '';
        _printInstructionsCtrl.text = p.instructions ?? '';
        _designPhotos = List<String>.from(p.designPhotos);
      }
      if (o.metier.usesMeasurements) _checkMeasurements(o.customerId);
    } else {
      _entryDate = DateTime.now();
      // Défaut du métier selon le mode d'activité de l'entreprise.
      final mode = BusinessContextService().activityMode;
      if (mode == ActivityMode.atelierMaintenance) {
        _metier = AtelierMetier.maintenance;
      } else if (mode == ActivityMode.garage) {
        // Garage : fiche véhicule imposée (spécialité automobile).
        _metier = AtelierMetier.garage;
        _specialty = 'Automobile';
      } else if (mode == ActivityMode.imprimerie) {
        _metier = AtelierMetier.imprimerie;
      } else if (mode == ActivityMode.pressing) {
        _metier = AtelierMetier.pressing;
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
    _customerNameController.dispose();
    _labelCtrl.dispose();
    _modelCtrl.dispose();
    _totalCtrl.dispose();
    _advanceCtrl.dispose();
    _rateCtrl.dispose();
    _devTypeCtrl.dispose();
    _devBrandCtrl.dispose();
    _devModelCtrl.dispose();
    _devSerialCtrl.dispose();
    _plateCtrl.dispose();
    _vinCtrl.dispose();
    _mileageCtrl.dispose();
    _fuelCtrl.dispose();
    _faultCtrl.dispose();
    _diagnosticCtrl.dispose();
    _repairCtrl.dispose();
    _warrantyCtrl.dispose();
    _technicianCtrl.dispose();
    _supportCtrl.dispose();
    _quantityCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _operatorCtrl.dispose();
    _machineCtrl.dispose();
    _printInstructionsCtrl.dispose();
    super.dispose();
  }

  bool get _isMaintenance => _metier.isMaintenanceLike;
  bool get _isGarage => _metier == AtelierMetier.garage;
  bool get _isImprimerie => _metier == AtelierMetier.imprimerie;

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
                        : _isImprimerie
                            ? 'Ex. 500 cartes de visite, Banderole 3m…'
                            : 'Ex. Robe wax, Costume 3 pièces…',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 16),
                if (_isMaintenance)
                  _maintenanceSection()
                else if (_isImprimerie)
                  _printSection()
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
                          formatCurrency(_remaining, _currency),
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
                if (!_isMaintenance && !_isImprimerie) ...[
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
    // Picker client partagé : suggestions depuis le cache Hive (online et
    // offline) et création inline. L'atelier n'est plus bloqué quand le client
    // n'est pas encore synchronisé : on peut toujours le retrouver ou le créer.
    return CustomerPickerField(
      controller: _customerNameController,
      label: 'Client *',
      hint: 'Rechercher ou creer un client',
      validator: (_) => _customerId == null ? 'Sélectionnez un client' : null,
      onSelected: (c) {
        setState(() {
          _customerId = c?.id;
          _customerName = c?.name;
        });
        if (c != null) _checkMeasurements(c.id);
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

  /// En MAINTENANCE, le métier est fixé par le mode → on choisit la SPÉCIALITÉ
  /// (informatique, automobile, thermique…) qui adapte la fiche appareil.
  /// En couture, on choisit couture vs cordonnerie (le mode « atelier » regroupe
  /// les deux). Plus de sélecteur de métier redondant.
  Widget _metierSelector() {
    // Imprimerie : le métier est fixé par le mode, la fiche travail d'impression
    // porte toute la config → pas de sélecteur métier redondant.
    if (_isImprimerie) return const SizedBox.shrink();
    if (_isMaintenance) {
      return DropdownButtonFormField<String>(
        value: _specialty,
        isExpanded: true,
        decoration: const InputDecoration(
            labelText: 'Spécialité de maintenance',
            border: OutlineInputBorder()),
        items: [
          for (final s in kMaintenanceSpecialties)
            DropdownMenuItem(value: s, child: Text(s)),
        ],
        onChanged: (v) => setState(() => _specialty = v),
      );
    }
    if (_isEdit) {
      return InputDecorator(
        decoration: const InputDecoration(
            labelText: 'Type', border: OutlineInputBorder()),
        child: Text(_metier.label),
      );
    }
    return DropdownButtonFormField<AtelierMetier>(
      value: _metier.usesMeasurements ? _metier : AtelierMetier.couture,
      decoration: const InputDecoration(
          labelText: 'Type d\'atelier', border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(
            value: AtelierMetier.couture, child: Text('Couture')),
        DropdownMenuItem(
            value: AtelierMetier.cordonnerie, child: Text('Cordonnerie')),
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

  /// Noms de responsables déjà saisis sur des commandes du même métier
  /// (opérateurs pour l'imprimerie, techniciens pour la maintenance). Sert de
  /// suggestions à l'autocomplétion → saisie rapide des intervenants récurrents.
  List<String> _priorStaffNames({required bool imprimerie}) {
    final orders = context.read<AtelierOrdersCubit>().state.orders;
    final names = <String>{};
    for (final o in orders) {
      final n = imprimerie
          ? o.printDetails?.operatorName
          : o.maintenanceDetails?.technicianName;
      if (n != null && n.trim().isNotEmpty) names.add(n.trim());
    }
    final list = names.toList()..sort();
    return list;
  }

  /// Champ « responsable » (technicien / opérateur) : autocomplétion sur les
  /// intervenants déjà utilisés (réutilise le même motif que le sélecteur de
  /// client), tout en gardant la saisie libre pour un nouvel intervenant. Évite
  /// de retaper le même nom à chaque commande.
  Widget _staffAutocomplete(
    TextEditingController target,
    String label,
    List<String> suggestions, {
    String? hint,
  }) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: target.text),
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return suggestions;
        return suggestions.where((s) => s.toLowerCase().contains(q));
      },
      onSelected: (v) => target.text = v,
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          // Saisie libre reflétée dans le contrôleur cible (nouvel intervenant).
          onChanged: (v) => target.text = v,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.badge_outlined, size: 18),
          ),
        );
      },
    );
  }

  /// Fiche appareil/panne d'un atelier de MAINTENANCE (calquée sur la fiche de
  /// réception/réparation papier). Aucun vocabulaire couture ici.
  Widget _maintenanceSection() {
    // La fiche s'adapte au type d'engin/appareil selon la spécialité.
    final isVehicle = _isGarage || _specialty == 'Automobile';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(isVehicle ? 'Véhicule reçu' : 'Appareil reçu'),
        if (isVehicle) ...[
          Row(
            children: [
              Expanded(child: _tf(_devBrandCtrl, 'Marque')),
              const SizedBox(width: 12),
              Expanded(child: _tf(_devModelCtrl, 'Modèle')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _tf(_plateCtrl, 'Immatriculation')),
              const SizedBox(width: 12),
              Expanded(child: _tf(_mileageCtrl, 'Kilométrage',
                  keyboard: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _tf(_vinCtrl, 'N° de châssis (VIN)')),
              const SizedBox(width: 12),
              Expanded(
                  child: _tf(_fuelCtrl, 'Carburant', hint: 'Essence, diesel…')),
            ],
          ),
        ] else ...[
          _tf(_devTypeCtrl, 'Type d\'appareil',
              hint: 'TV, smartphone, PC, frigo…'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _tf(_devBrandCtrl, 'Marque')),
              const SizedBox(width: 12),
              Expanded(child: _tf(_devModelCtrl, 'Modèle')),
            ],
          ),
          const SizedBox(height: 12),
          _tf(_devSerialCtrl, 'N° de série / IMEI'),
        ],
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
            Expanded(
              child: _staffAutocomplete(_technicianCtrl, 'Technicien',
                  _priorStaffNames(imprimerie: false)),
            ),
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
      specialty: _specialty,
      deviceType: t(_devTypeCtrl),
      brand: t(_devBrandCtrl),
      model: t(_devModelCtrl),
      serialNumber: t(_devSerialCtrl),
      plate: t(_plateCtrl),
      vin: t(_vinCtrl),
      mileage: t(_mileageCtrl),
      fuel: t(_fuelCtrl),
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
    final hasSpecialty = _specialty != null && _specialty!.isNotEmpty;
    return (d.isEmpty && !hasSpecialty) ? null : d;
  }

  /// Fiche « travail d'impression » d'un atelier d'IMPRIMERIE. Aucun vocabulaire
  /// couture/maintenance : format, support, tirage, finition, BAT, design.
  Widget _printSection() {
    final isLargeFormat = _printFormat == 'Bâche' ||
        _printFormat == 'Banderole' ||
        _printFormat == 'Roll-up' ||
        _printFormat == 'Personnalisé';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Fiche travail d\'impression'),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _printFormat,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Format', border: OutlineInputBorder()),
                items: [
                  for (final f in kPrintFormats)
                    DropdownMenuItem(value: f, child: Text(f)),
                ],
                onChanged: (v) => setState(() => _printFormat = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _tf(_quantityCtrl, 'Quantité (tirage)',
                  keyboard: TextInputType.number),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _tf(_supportCtrl, 'Support / matière',
            hint: 'Couché 300g, adhésif, bâche 510g…'),
        if (isLargeFormat) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _tf(_widthCtrl, 'Largeur',
                      hint: 'cm / m', keyboard: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(
                  child: _tf(_heightCtrl, 'Hauteur',
                      hint: 'cm / m', keyboard: TextInputType.number)),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _colorMode,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Couleurs', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                      value: 'Quadrichromie', child: Text('Quadrichromie')),
                  DropdownMenuItem(
                      value: 'Noir et blanc', child: Text('Noir et blanc')),
                  DropdownMenuItem(value: 'Pantone', child: Text('Pantone')),
                ],
                onChanged: (v) => setState(() => _colorMode = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _printSides,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Impression', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'recto', child: Text('Recto')),
                  DropdownMenuItem(
                      value: 'recto-verso', child: Text('Recto-verso')),
                ],
                onChanged: (v) =>
                    setState(() => _printSides = v ?? 'recto'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _finishing,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Finition / façonnage', border: OutlineInputBorder()),
          items: [
            for (final f in kPrintFinishings)
              DropdownMenuItem(value: f, child: Text(f)),
          ],
          onChanged: (v) => setState(() => _finishing = v),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _staffAutocomplete(_operatorCtrl,
                  'Opérateur / infographiste', _priorStaffNames(imprimerie: true)),
            ),
            const SizedBox(width: 12),
            Expanded(child: _tf(_machineCtrl, 'Machine / presse')),
          ],
        ),
        const SizedBox(height: 12),
        _tf(_printInstructionsCtrl, 'Consignes',
            hint: 'Détails, couleurs de charte, délais…', min: 2, max: 3),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _batValidated,
          onChanged: (v) => setState(() => _batValidated = v),
          title: const Text('Bon à tirer (BAT) validé par le client'),
          dense: true,
        ),
        const SizedBox(height: 8),
        _designPhotosField(),
      ],
    );
  }

  /// Sélecteur multi-photos du design / bon à tirer : upload Cloudinary via le
  /// service partagé, miniatures et suppression. Les URLs sont persistées dans
  /// `printDetails.designPhotos` (affichées sur la carte Kanban).
  Widget _designPhotosField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Design / Bon à tirer'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _designPhotos.length; i++)
              Stack(
                children: [
                  GestureDetector(
                    onTap: () => PhotoGalleryViewer.open(
                      context,
                      photos: _designPhotos,
                      initialIndex: i,
                    ),
                    child: SmartImage(
                      imageUrl: _designPhotos[i],
                      width: 72,
                      height: 72,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: IconButton(
                      icon: const Icon(Icons.cancel, size: 20),
                      color: Colors.red,
                      onPressed: () =>
                          setState(() => _designPhotos.removeAt(i)),
                    ),
                  ),
                ],
              ),
            InkWell(
              onTap: _uploadingPhotos ? null : _pickDesignPhotos,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _uploadingPhotos
                    ? const Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2)))
                    : const Icon(Icons.add_a_photo_outlined),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDesignPhotos() async {
    try {
      final files = await _imagePicker.pickMultipleImages(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (files.isEmpty) return;
      setState(() => _uploadingPhotos = true);
      final urls = await _imageUpload.uploadImages(files);
      if (!mounted) return;
      setState(() {
        _designPhotos = [..._designPhotos, ...urls];
        _uploadingPhotos = false;
      });
      if (urls.length < files.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Certaines photos n\'ont pas pu être envoyées')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingPhotos = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ajouter les photos : $e')),
      );
    }
  }

  PrintJobDetails? _buildPrintDetails() {
    if (!_isImprimerie) return null;
    String? t(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final isLargeFormat = _printFormat == 'Bâche' ||
        _printFormat == 'Banderole' ||
        _printFormat == 'Roll-up' ||
        _printFormat == 'Personnalisé';
    final d = PrintJobDetails(
      format: _printFormat,
      support: t(_supportCtrl),
      quantity: _quantityCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_quantityCtrl.text.trim()),
      printSides: _printSides,
      colorMode: _colorMode,
      finishing: _finishing,
      width: isLargeFormat ? t(_widthCtrl) : null,
      height: isLargeFormat ? t(_heightCtrl) : null,
      batValidated: _batValidated,
      designPhotos: _designPhotos,
      operatorName: t(_operatorCtrl),
      machine: t(_machineCtrl),
      instructions: t(_printInstructionsCtrl),
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
      printDetails: _buildPrintDetails(),
      modelDetails: (_isMaintenance || _isImprimerie)
          ? null
          : (_modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim()),
      entryDate: _entryDate,
      exitDate: _exitDate,
      totalAmount: double.tryParse(_totalCtrl.text) ?? 0,
      advanceAmount: double.tryParse(_advanceCtrl.text) ?? 0,
      currencyCode: _currency,
      exchangeRate: _currency == 'CDF' ? 1 : (double.tryParse(_rateCtrl.text) ?? 1),
      fabricProvidedBy: (_isMaintenance || _isImprimerie) ? null : _fabric,
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
