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
import 'package:wanzo/features/atelier/config/vehicle_catalog.dart';
import 'package:wanzo/features/atelier/models/atelier_order.dart';
import 'package:wanzo/features/atelier/models/customer_vehicle.dart';
import 'package:wanzo/features/atelier/widgets/vehicle_form_sheet.dart';
import 'package:wanzo/features/atelier/screens/atelier_client_profile_screen.dart';
import 'package:wanzo/features/atelier/services/atelier_api_service.dart';
import 'package:wanzo/features/services/config/service_suggestions.dart';
import '../../services/cubit/services_cubit.dart';
import '../../services/models/service_item.dart';
import '../../../core/utils/adaptive_pull_up.dart';

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
  // ── Véhicule du client (mode garage) : la commande référence un véhicule
  // de la fiche client, dont elle alimente la fiche de suivi. ──
  String? _vehicleId;

  /// Colonne du bareme correspondant au vehicule recu (garage).
  String? _vehicleCategory;
  List<CustomerVehicle> _vehicles = const [];
  bool _loadingVehicles = false;
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
  // ── Fiche de dépôt (pressing) ──
  String _pressingLevel = 'standard'; // standard | express
  final _bagCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _stainsCtrl = TextEditingController();
  final _pressingInstructionsCtrl = TextEditingController();
  final _pressingOperatorCtrl = TextEditingController();
  final List<_PressingItemRow> _pressingItems = [];
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
      _vehicleId = o.vehicleId;
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
      final pr = o.pressingDetails;
      if (pr != null) {
        _pressingLevel = pr.serviceLevel ?? 'standard';
        _bagCtrl.text = pr.bagNumber ?? '';
        _weightCtrl.text = pr.totalWeightKg?.toString() ?? '';
        _stainsCtrl.text = pr.stains ?? '';
        _pressingInstructionsCtrl.text = pr.instructions ?? '';
        _pressingOperatorCtrl.text = pr.operatorName ?? '';
        for (final it in pr.items) {
          _pressingItems.add(_PressingItemRow(
              type: it.type, quantity: it.quantity, treatment: it.treatment, note: it.note ?? ''));
        }
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
    if (_customerId != null && _isGarage) _loadVehicles(_customerId!);
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
    _bagCtrl.dispose();
    _weightCtrl.dispose();
    _stainsCtrl.dispose();
    _pressingInstructionsCtrl.dispose();
    _pressingOperatorCtrl.dispose();
    for (final r in _pressingItems) {
      r.dispose();
    }
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
  bool get _isPressing => _metier == AtelierMetier.pressing;

  /// Confection (couture / cordonnerie) : modèle, tissu, mesures.
  bool get _isConfection => !_isMaintenance && !_isImprimerie && !_isPressing;

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
        title: Text(_isEdit ? _metier.editWorkLabel : _metier.newWorkLabel),
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
                            : _isPressing
                                ? 'Ex. Dépôt Mme Kavira, 3 costumes et 5 chemises…'
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
                else if (_isPressing)
                  _pressingSection()
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
                        decoration: InputDecoration(
                          labelText: 'Montant total',
                          border: const OutlineInputBorder(),
                          // Le bareme connait le prix de cette prestation pour
                          // cette categorie de vehicule : inutile de le retaper.
                          suffixIcon: _metier == AtelierMetier.garage
                              ? IconButton(
                                  tooltip: 'Prendre au barème',
                                  icon: const Icon(Icons.price_change_outlined),
                                  onPressed: _pickFromPriceGrid,
                                )
                              : null,
                        ),
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
                if (_isConfection) ...[
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
                  label: Text(_isEdit ? 'Enregistrer' : _metier.createWorkLabel),
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
        // Nouveau client : on repart d'une liste de véhicules vierge.
        _vehicleId = null;
        _vehicles = const [];
        if (c != null && _isGarage) _loadVehicles(c.id);
      },
    );
  }

  Future<void> _loadVehicles(String customerId) async {
    if (mounted) setState(() => _loadingVehicles = true);
    try {
      final v = await _atelierApi.getVehicles(customerId);
      if (!mounted) return;
      setState(() {
        _vehicles = v;
        _loadingVehicles = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingVehicles = false);
    }
  }

  /// Pré-remplit la fiche « véhicule reçu » depuis le véhicule choisi ; le
  /// kilométrage du jour reste saisi à chaque intervention.
  void _applyVehicle(CustomerVehicle v) {
    setState(() {
      _vehicleId = v.id;
      // Categorie de tarification : elle designe la colonne du bareme.
      _vehicleCategory = v.pricingCategory;
      _devBrandCtrl.text = v.brand ?? '';
      _devModelCtrl.text = v.model ?? '';
      _plateCtrl.text = v.plate ?? '';
      _vinCtrl.text = v.vin ?? '';
      _fuelCtrl.text = v.fuel ?? '';
      if (_mileageCtrl.text.trim().isEmpty && v.mileage != null) {
        _mileageCtrl.text = '${v.mileage}';
      }
    });
  }

  /// Reprend le prix d'une prestation du bareme, dans la colonne du vehicule.
  ///
  /// Sans categorie sur le vehicule, on montre tous les paliers et l'operateur
  /// tranche : mieux vaut un choix eclaire qu'un montant tape de memoire.
  Future<void> _pickFromPriceGrid() async {
    final cubit = ServicesCubit()..load();
    final services = await cubit.stream
        .map((s) => s.items)
        .firstWhere((items) => items.isNotEmpty,
            orElse: () => const <ServiceItem>[])
        .timeout(const Duration(seconds: 6),
            onTimeout: () => const <ServiceItem>[]);
    if (!mounted) return;
    if (services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Aucune prestation au barème. Créez-le depuis Offre, onglet Services.'),
      ));
      return;
    }

    final picked = await showAdaptivePullUp<_GridPick>(
      context,
      title: 'Barème du garage',
      icon: Icons.price_change_outlined,
      maxWidth: 460,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final s in services)
            for (final t in s.priceTiers)
              if (_vehicleCategory == null || t.code == _vehicleCategory)
                ListTile(
                  dense: true,
                  title: Text(s.name),
                  subtitle: Text(t.label),
                  trailing: Text(_fmtTierPrice(t.priceCdf),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () =>
                      Navigator.of(ctx).pop(_GridPick(s.name, t.priceCdf)),
                ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _totalCtrl.text = picked.priceCdf == picked.priceCdf.roundToDouble()
          ? picked.priceCdf.toInt().toString()
          : picked.priceCdf.toString();
      if (_labelCtrl.text.trim().isEmpty) _labelCtrl.text = picked.name;
    });
  }

  String _fmtTierPrice(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  Future<void> _addVehicle() async {
    if (_customerId == null) return;
    final v = await showVehicleForm(context, customerId: _customerId!);
    if (v == null || !mounted) return;
    setState(() => _vehicles = [v, ..._vehicles]);
    _applyVehicle(v);
  }

  Widget _vehiclePicker() {
    if (_customerId == null) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Véhicule du client',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.directions_car_outlined, size: 18),
        ),
        child: Text('Sélectionnez d\'abord le client'),
      );
    }
    final selected = _vehicles.any((v) => v.id == _vehicleId) ? _vehicleId : null;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: selected,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Véhicule du client',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.directions_car_outlined, size: 18),
              suffixIcon: _loadingVehicles
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
            hint: Text(_vehicles.isEmpty ? 'Aucun véhicule enregistré' : 'Choisir un véhicule'),
            items: [
              for (final v in _vehicles)
                DropdownMenuItem(
                    value: v.id, child: Text(v.displayLabel, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (id) {
              for (final v in _vehicles) {
                if (v.id == id) {
                  _applyVehicle(v);
                  return;
                }
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Nouveau véhicule',
          onPressed: _addVehicle,
          icon: const Icon(Icons.add),
        ),
      ],
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
    // Le metier est FIXE par le mode partout sauf en atelier couture, ou il
    // reste un vrai choix entre couture et cordonnerie. Ailleurs (imprimerie,
    // pressing, garage, maintenance d'appareils) proposer ce choix n'a pas de
    // sens : le garage affichait « Type d'atelier : Couture ».
    if (_isImprimerie || _isPressing || _isGarage) {
      return const SizedBox.shrink();
    }
    // Specialite d'appareil : propre a la maintenance. Le garage travaille sur
    // un vehicule, pas sur une famille d'appareils.
    if (_metier == AtelierMetier.maintenance) {
      return DropdownButtonFormField<String>(
        value: _specialty,
        isExpanded: true,
        decoration: const InputDecoration(
            labelText: 'Spécialité de maintenance',
            border: OutlineInputBorder()),
        items: [
          // Une ancienne commande peut porter une spécialité retirée de la
          // liste (ex. « Automobile », désormais mode garage) : on la garde
          // sélectionnable pour ne pas casser son édition.
          for (final s in {
            ...kMaintenanceSpecialties,
            if (_specialty != null && _specialty!.isNotEmpty) _specialty!,
          })
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
  List<String> _priorStaffNames({required bool imprimerie, bool pressing = false}) {
    final orders = context.read<AtelierOrdersCubit>().state.orders;
    final names = <String>{};
    for (final o in orders) {
      final n = pressing
          ? o.pressingDetails?.operatorName
          : imprimerie
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
    IconData? icon,
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
            prefixIcon: Icon(icon ?? Icons.badge_outlined, size: 18),
          ),
        );
      },
    );
  }

  /// Fiche appareil/panne d'un atelier de MAINTENANCE (calquée sur la fiche de
  /// réception/réparation papier). Aucun vocabulaire couture ici.
  Widget _maintenanceSection() {
    // Fiche véhicule : mode garage, ou ancienne commande de maintenance saisie
    // en spécialité « Automobile » avant la création du mode garage.
    final isVehicle = _isGarage || _specialty == 'Automobile';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(isVehicle ? 'Véhicule reçu' : 'Appareil reçu'),
        if (isVehicle) ...[
          if (_isGarage) ...[
            _vehiclePicker(),
            const SizedBox(height: 12),
          ],
          // Référentiel (marques, modèles, carburants) proposé en saisie ; la
          // clé force le rafraîchissement quand un véhicule est choisi.
          Row(
            key: ValueKey('vehicle_identity_$_vehicleId'),
            children: [
              Expanded(
                child: _staffAutocomplete(_devBrandCtrl, 'Fabricant', VehicleCatalog.brands,
                    icon: Icons.factory_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _staffAutocomplete(
                    _devModelCtrl,
                    'Modèle',
                    VehicleCatalog.modelsFor(_devBrandCtrl.text).isEmpty
                        ? VehicleCatalog.models.values.expand((e) => e).toList()
                        : VehicleCatalog.modelsFor(_devBrandCtrl.text),
                    icon: Icons.directions_car_outlined),
              ),
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
                child: KeyedSubtree(
                  key: ValueKey('vehicle_fuel_$_vehicleId'),
                  child: _staffAutocomplete(_fuelCtrl, 'Carburant', VehicleCatalog.fuelTypes,
                      icon: Icons.local_gas_station_outlined),
                ),
              ),
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

  /// Fiche de DÉPÔT d'un pressing : articles, niveau de service, poids,
  /// défauts signalés, consignes. Aucun vocabulaire couture ni appareil.
  Widget _pressingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Fiche de dépôt'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'standard', icon: Icon(Icons.schedule), label: Text('Standard')),
            ButtonSegment(value: 'express', icon: Icon(Icons.bolt), label: Text('Express')),
          ],
          selected: {_pressingLevel},
          onSelectionChanged: (s) => setState(() => _pressingLevel = s.first),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _tf(_bagCtrl, 'N° de sac / ticket', hint: 'Ex. S-014')),
            const SizedBox(width: 12),
            Expanded(
              child: _tf(_weightCtrl, 'Poids total (kg)',
                  hint: 'Linge au poids', keyboard: const TextInputType.numberWithOptions(decimal: true)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _sectionTitle('Articles déposés')),
            TextButton.icon(
              onPressed: () => setState(() => _pressingItems.add(_PressingItemRow())),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter un article'),
            ),
          ],
        ),
        if (_pressingItems.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Ajoutez chaque article (chemise, costume, couette…) avec sa quantité et son traitement.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        for (var i = 0; i < _pressingItems.length; i++) _pressingItemCard(i),
        const SizedBox(height: 8),
        _tf(_stainsCtrl, 'Taches et défauts signalés au dépôt',
            hint: 'Tache de vin sur la manche, bouton manquant…', min: 2, max: 3),
        const SizedBox(height: 12),
        _tf(_pressingInstructionsCtrl, 'Consignes',
            hint: 'Amidon léger, sur cintre, pliage…', min: 1, max: 2),
        const SizedBox(height: 12),
        _staffAutocomplete(_pressingOperatorCtrl, 'Réceptionnaire',
            _priorStaffNames(imprimerie: false, pressing: true)),
      ],
    );
  }

  static const List<String> _pressingTreatments = [
    'Nettoyage à sec', 'Lavage', 'Lavage et repassage', 'Repassage seul', 'Détachage',
    'Cuir et daim', 'Teinture', 'Retouche',
  ];

  Widget _pressingItemCard(int i) {
    final row = _pressingItems[i];
    final articles = ServiceSuggestions.serviceNames(ActivityMode.pressing);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Autocomplete<String>(
                    initialValue: TextEditingValue(text: row.type.text),
                    optionsBuilder: (v) {
                      final q = v.text.trim().toLowerCase();
                      return q.isEmpty ? articles : articles.where((a) => a.toLowerCase().contains(q));
                    },
                    onSelected: (v) => row.type.text = v,
                    fieldViewBuilder: (context, ctrl, focus, _) => TextFormField(
                      controller: ctrl,
                      focusNode: focus,
                      onChanged: (v) => row.type.text = v,
                      decoration: const InputDecoration(
                          labelText: 'Article', hintText: 'Chemise, Costume…', isDense: true, border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: TextFormField(
                    controller: row.quantity,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: 'Qté', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                IconButton(
                  tooltip: 'Retirer',
                  onPressed: () => setState(() => _pressingItems.removeAt(i).dispose()),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _pressingTreatments.contains(row.treatment) ? row.treatment : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Traitement', isDense: true, border: OutlineInputBorder()),
                    items: [for (final t in _pressingTreatments) DropdownMenuItem(value: t, child: Text(t))],
                    onChanged: (v) => setState(() => row.treatment = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: row.note,
                    decoration: const InputDecoration(
                        labelText: 'Remarque', hintText: 'Couleur, tache…', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PressingDetails? _buildPressingDetails() {
    if (!_isPressing) return null;
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final d = PressingDetails(
      items: [
        for (final r in _pressingItems)
          if (r.type.text.trim().isNotEmpty)
            PressingItem(
              type: r.type.text.trim(),
              quantity: int.tryParse(r.quantity.text.trim()) ?? 1,
              treatment: r.treatment,
              note: t(r.note),
            ),
      ],
      serviceLevel: _pressingLevel,
      totalWeightKg: double.tryParse(_weightCtrl.text.trim().replaceAll(',', '.')),
      bagNumber: t(_bagCtrl),
      stains: t(_stainsCtrl),
      instructions: t(_pressingInstructionsCtrl),
      operatorName: t(_pressingOperatorCtrl),
    );
    return d.isEmpty ? null : d;
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
      vehicleId: _isGarage ? _vehicleId : null,
      label: _labelCtrl.text.trim(),
      metier: _metier,
      maintenanceDetails: _buildMaintenanceDetails(),
      printDetails: _buildPrintDetails(),
      pressingDetails: _buildPressingDetails(),
      modelDetails: _isConfection
          ? (_modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim())
          : null,
      entryDate: _entryDate,
      exitDate: _exitDate,
      totalAmount: double.tryParse(_totalCtrl.text) ?? 0,
      advanceAmount: double.tryParse(_advanceCtrl.text) ?? 0,
      currencyCode: _currency,
      exchangeRate: _currency == 'CDF' ? 1 : (double.tryParse(_rateCtrl.text) ?? 1),
      fabricProvidedBy: _isConfection ? _fabric : null,
    );

    final result = _isEdit
        ? await cubit.updateOrder(
            widget.order!.id,
            draft.toCreateJson(),
            // Le brouillon porte deja l identifiant de la fiche editee.
            local: draft,
          )
        : await cubit.createOrder(draft);

    if (!mounted) return;
    setState(() => _saving = false);

    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Echec de l enregistrement')),
      );
      return;
    }

    // Hors ligne, la fiche est conservee et sera envoyee au retour du
    // reseau. Le dire explicitement vaut mieux qu'un succes muet :
    // l'utilisateur sait que le serveur ne l'a pas encore, et ne ressaisit pas.
    if (result.horsLigne) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enregistré hors ligne, envoi au retour du réseau'),
        ),
      );
    }
    Navigator.of(context).pop();
  }
}

/// Ligne d'article de la fiche de dépôt pressing (contrôleurs par ligne).
class _PressingItemRow {
  final TextEditingController type;
  final TextEditingController quantity;
  final TextEditingController note;
  String? treatment;
  _PressingItemRow({String type = '', int quantity = 1, this.treatment, String note = ''})
      : type = TextEditingController(text: type),
        quantity = TextEditingController(text: '$quantity'),
        note = TextEditingController(text: note);
  void dispose() {
    type.dispose();
    quantity.dispose();
    note.dispose();
  }
}


/// Ce qu'on retient du barème : la prestation et son prix pour la catégorie.
class _GridPick {
  final String name;
  final double priceCdf;
  const _GridPick(this.name, this.priceCdf);
}
