import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:wanzo/core/enums/currency_enum.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/services/currency_service.dart';
import 'package:wanzo/core/widgets/desktop/modal_form_shell.dart';

import '../config/service_suggestions.dart';
import '../cubit/services_cubit.dart';
import '../models/service_item.dart';
import '../repositories/service_repository.dart';

/// Création / modification d'un service et de ses paliers de prix.
///
/// Utilisable en page (mobile, `Navigator.pop(true)` au succès) ou en modal
/// desktop (`onSaved` appelé au succès). L'enregistrement passe par un
/// [ServicesCubit] propre : le cache Hive est partagé, le parent recharge sa
/// liste au retour. Métier et mode sont déduits du contexte, jamais saisis.
class ServiceFormScreen extends StatefulWidget {
  final ServiceItem? service;
  final VoidCallback? onSaved;

  const ServiceFormScreen({super.key, this.service, this.onSaved});

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _TierRow {
  final TextEditingController label;
  final TextEditingController price;
  final TextEditingController description;
  String? code;
  _TierRow({String label = '', String price = '', String description = '', this.code})
      : label = TextEditingController(text: label),
        price = TextEditingController(text: price),
        description = TextEditingController(text: description);
  void dispose() {
    label.dispose();
    price.dispose();
    description.dispose();
  }
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final List<_TierRow> _tiers = [];
  int _defaultTier = 0;
  bool _isPublic = false;
  bool _active = true;
  bool _saving = false;
  List<String> _existingCategories = const [];

  bool get _isEditing => widget.service != null;
  final _mode = BusinessContextService().activityMode;

  /// Devise de SAISIE des prix : la devise active de l'app (politique de
  /// devise commune à toute la plateforme) ; les paliers sont stockés en CDF
  /// via le taux central, comme les prix produits.
  late CurrencyService _currency;
  late Currency _inputCurrency;

  /// Paliers proposés en un tap : ceux du mode en premier, puis les usuels.
  List<ServicePriceTier> get _presets {
    final seen = <String>{};
    final out = <ServicePriceTier>[];
    for (final t in [
      ...ServiceSuggestions.defaultTiers(_mode),
      const ServicePriceTier(code: 'standard', label: 'Standard', priceCdf: 0),
      const ServicePriceTier(code: 'basic', label: 'Basic', priceCdf: 0),
      const ServicePriceTier(code: 'premium', label: 'Premium', priceCdf: 0),
      const ServicePriceTier(code: 'speciaux', label: 'Spéciaux', priceCdf: 0),
      const ServicePriceTier(code: 'express', label: 'Express', priceCdf: 0),
      const ServicePriceTier(code: 'vip', label: 'VIP', priceCdf: 0),
    ]) {
      if (seen.add(t.label.toLowerCase())) out.add(t);
    }
    return out;
  }

  int _tierIndexByLabel(String label) =>
      _tiers.indexWhere((r) => r.label.text.trim().toLowerCase() == label.toLowerCase());

  void _togglePreset(ServicePriceTier preset) {
    final idx = _tierIndexByLabel(preset.label);
    setState(() {
      if (idx >= 0) {
        if (_tiers.length <= 1) return; // au moins un palier
        _tiers.removeAt(idx).dispose();
        if (_defaultTier >= _tiers.length) _defaultTier = 0;
      } else {
        // Une ligne vide (palier « personnalisé » non rempli) est réutilisée.
        final empty = _tiers.indexWhere(
            (r) => r.label.text.trim().isEmpty && r.price.text.trim().isEmpty);
        if (empty >= 0) {
          _tiers[empty].label.text = preset.label;
          _tiers[empty].description.text = preset.description ?? '';
          _tiers[empty].code = preset.code;
        } else {
          _tiers.add(_TierRow(
              label: preset.label, description: preset.description ?? '', code: preset.code));
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _currency = context.read<CurrencyService>();
    _inputCurrency = _currency.currentSettings.activeCurrency;
    final s = widget.service;
    if (s != null) {
      _nameCtrl.text = s.name;
      _categoryCtrl.text = s.category ?? '';
      _descriptionCtrl.text = s.description ?? '';
      _durationCtrl.text = s.durationMinutes?.toString() ?? '';
      _isPublic = s.isPublic;
      _active = s.active;
      for (var i = 0; i < s.priceTiers.length; i++) {
        final t = s.priceTiers[i];
        _tiers.add(_TierRow(
          label: t.label,
          // Affiché dans la devise de saisie (converti depuis le CDF stocké).
          price: t.priceCdf == 0 ? '' : _fmt(_currency.convertFromCdf(t.priceCdf, _inputCurrency)),
          description: t.description ?? '',
          code: t.code,
        ));
        if (t.isDefault) _defaultTier = i;
      }
    }
    if (_tiers.isEmpty) {
      for (var i = 0; i < ServiceSuggestions.defaultTiers(_mode).length; i++) {
        final t = ServiceSuggestions.defaultTiers(_mode)[i];
        _tiers.add(_TierRow(label: t.label, description: t.description ?? '', code: t.code));
        if (t.isDefault) _defaultTier = i;
      }
    }
    ServiceRepository().loadAll().then((all) {
      if (!mounted) return;
      final set = <String>{};
      for (final it in all) {
        if ((it.category ?? '').trim().isNotEmpty) set.add(it.category!.trim());
      }
      setState(() => _existingCategories = set.toList()..sort());
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _descriptionCtrl.dispose();
    _durationCtrl.dispose();
    for (final t in _tiers) {
      t.dispose();
    }
    super.dispose();
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  double? _parsePrice(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final tiers = <ServicePriceTier>[];
    for (var i = 0; i < _tiers.length; i++) {
      final row = _tiers[i];
      final label = row.label.text.trim();
      final price = _parsePrice(row.price.text);
      if (label.isEmpty || price == null) continue;
      tiers.add(ServicePriceTier(
        code: row.code ?? ServicePriceTier.codeFromLabel(label),
        label: label,
        // Stockage en CDF (devise de base) via le taux central.
        priceCdf: _currency.convertToCdf(price, _inputCurrency),
        isDefault: i == _defaultTier,
        description: row.description.text.trim().isEmpty ? null : row.description.text.trim(),
      ));
    }
    if (tiers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Renseignez au moins un palier avec un libellé et un prix.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    if (!tiers.any((t) => t.isDefault)) {
      tiers[0] = tiers[0].copyWith(isDefault: true);
    }
    // Codes uniques : un doublon de libellé reçoit un suffixe.
    final seen = <String>{};
    for (var i = 0; i < tiers.length; i++) {
      var code = tiers[i].code;
      var n = 2;
      while (seen.contains(code)) {
        code = '${tiers[i].code}_$n';
        n++;
      }
      seen.add(code);
      if (code != tiers[i].code) tiers[i] = tiers[i].copyWith(code: code);
    }

    // Un seul cubit pour la sauvegarde : il porte aussi le métier courant
    // (isolation pressing / garage / couture) sans dépendre du modèle atelier.
    final cubit = ServicesCubit();
    final metier = cubit.metierToStamp;
    final item = ServiceItem(
      id: widget.service?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
      category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
      durationMinutes: int.tryParse(_durationCtrl.text.trim()),
      priceTiers: tiers,
      // Le service appartient au mode ou il est cree : sans cette marque, le
      // filtre par mode ne restreint rien et les catalogues se melangent.
      activityModes: widget.service?.activityModes.isNotEmpty == true
          ? widget.service!.activityModes
          : [cubit.currentModeCode],
      metier: widget.service?.metier ?? metier,
      taxRate: widget.service?.taxRate,
      commissionPct: widget.service?.commissionPct,
      imageUrl: widget.service?.imageUrl,
      isPublic: _isPublic,
      active: _active,
      position: widget.service?.position ?? 0,
    );

    setState(() => _saving = true);
    try {
      await cubit.save(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Service modifié' : 'Service ajouté')),
      );
      if (widget.onSaved != null) {
        widget.onSaved!();
      } else {
        Navigator.of(context).pop(true);
      }
    } finally {
      await cubit.close();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _suggestField(
            controller: _nameCtrl,
            label: 'Nom du service *',
            hint: 'Ex. ${ServiceSuggestions.serviceNames(_mode).first}',
            options: ServiceSuggestions.serviceNames(_mode),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Le nom est obligatoire' : null,
          ),
          const SizedBox(height: 12),
          _suggestField(
            controller: _categoryCtrl,
            label: 'Catégorie',
            hint: 'Ex. ${ServiceSuggestions.categories(_mode).first}',
            options: {..._existingCategories, ...ServiceSuggestions.categories(_mode)}.toList(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Ce que comprend le service (affiché au client)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _durationCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Durée estimée (minutes)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text('Paliers de prix', style: theme.textTheme.titleMedium),
              ),
              // Devise de saisie : politique de devise de la plateforme (CDF de
              // base, USD suivi). Les prix sont convertis et stockés en CDF.
              DropdownButton<Currency>(
                value: _inputCurrency,
                underline: const SizedBox.shrink(),
                items: [
                  for (final c in Currency.values)
                    DropdownMenuItem(value: c, child: Text('Prix en ${c.code}')),
                ],
                onChanged: (c) {
                  if (c == null || c == _inputCurrency) return;
                  setState(() {
                    // Reconvertit les montants déjà saisis dans la nouvelle devise.
                    for (final r in _tiers) {
                      final v = _parsePrice(r.price.text);
                      if (v == null) continue;
                      final cdf = _currency.convertToCdf(v, _inputCurrency);
                      r.price.text = _fmt(_currency.convertFromCdf(cdf, c));
                    }
                    _inputCurrency = c;
                  });
                },
              ),
            ],
          ),
          Text(
            '1. Cochez les paliers que vous proposez pour ce service. '
            '2. Indiquez le prix de chacun. '
            'Le palier marqué comme « par défaut » est proposé en premier à la facturation.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).round()),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final p in _presets)
                FilterChip(
                  label: Text(p.label),
                  selected: _tierIndexByLabel(p.label) >= 0,
                  onSelected: (_) => _togglePreset(p),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('Palier personnalisé'),
                onPressed: () => setState(() => _tiers.add(_TierRow())),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _tiers.length; i++) _tierCard(i, theme),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Visible sur le catalogue public'),
            subtitle: const Text('Affiché sur la vitrine en ligne de votre entreprise'),
            value: _isPublic,
            onChanged: (v) => setState(() => _isPublic = v),
          ),
          if (_isEditing)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Service actif'),
              subtitle: const Text('Un service inactif n\'est plus proposé à la facturation'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: Text(_isEditing ? 'Enregistrer' : 'Créer le service'),
          ),
        ],
      ),
    );

    // En modal (desktop) : en-tête léger avec fermeture, pas de seconde AppBar.
    if (widget.onSaved != null) {
      return ModalFormShell(
        title: _isEditing ? 'Modifier le service' : 'Nouveau service',
        icon: Icons.design_services_outlined,
        child: body,
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Modifier le service' : 'Nouveau service')),
      body: body,
    );
  }

  Widget _tierCard(int i, ThemeData theme) {
    final row = _tiers[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          children: [
            Row(
              children: [
                Tooltip(
                  message: i == _defaultTier ? 'Palier par défaut' : 'Définir comme palier par défaut',
                  child: Radio<int>(
                    value: i,
                    groupValue: _defaultTier,
                    onChanged: (v) => setState(() => _defaultTier = v ?? 0),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: row.label,
                    decoration: const InputDecoration(labelText: 'Palier', hintText: 'Basic', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: row.price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: 'Prix (${_inputCurrency.code})', isDense: true, border: const OutlineInputBorder()),
                    validator: (v) {
                      // Une colonne sans prix est une case vide du bareme : la
                      // prestation ne s'applique pas a cette categorie. Elle
                      // n'est simplement pas enregistree.
                      if (v != null && v.trim().isNotEmpty && _parsePrice(v) == null) return 'Nombre invalide';
                      return null;
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Retirer ce palier',
                  onPressed: _tiers.length <= 1
                      ? null
                      : () => setState(() {
                            _tiers.removeAt(i).dispose();
                            if (_defaultTier >= _tiers.length) _defaultTier = 0;
                          }),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 4, 40, 4),
              child: TextFormField(
                controller: row.description,
                decoration: const InputDecoration(
                  hintText: 'Ce que comprend ce palier (facultatif)',
                  isDense: true,
                  border: UnderlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Champ texte avec suggestions (saisie libre conservée).
  Widget _suggestField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required List<String> options,
    String? Function(String?)? validator,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => Autocomplete<String>(
        initialValue: TextEditingValue(text: controller.text),
        optionsBuilder: (value) {
          final q = value.text.trim().toLowerCase();
          if (q.isEmpty) return options.take(8);
          return options.where((o) => o.toLowerCase().contains(q)).take(8);
        },
        onSelected: (v) => controller.text = v,
        fieldViewBuilder: (context, textCtrl, focusNode, onSubmitted) {
          textCtrl.addListener(() => controller.text = textCtrl.text);
          return TextFormField(
            controller: textCtrl,
            focusNode: focusNode,
            validator: validator,
            decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
          );
        },
        optionsViewBuilder: (context, onSelected, opts) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 220, maxWidth: constraints.maxWidth),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [for (final o in opts) ListTile(dense: true, title: Text(o), onTap: () => onSelected(o))],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
