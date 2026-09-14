import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:wanzo/core/services/business_context_service.dart';
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

  @override
  void initState() {
    super.initState();
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
          price: t.priceCdf == 0 ? '' : _fmt(t.priceCdf),
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
        priceCdf: price,
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
    final metier = cubit.currentMetier;
    final item = ServiceItem(
      id: widget.service?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
      category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
      durationMinutes: int.tryParse(_durationCtrl.text.trim()),
      priceTiers: tiers,
      activityModes: widget.service?.activityModes ?? const [],
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
              TextButton.icon(
                onPressed: () => setState(() => _tiers.add(_TierRow())),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un palier'),
              ),
            ],
          ),
          Text(
            'Un même service peut avoir plusieurs prix (ex. Basic, Premium, Spéciaux). '
            'Le palier par défaut est proposé en premier à la facturation. Prix en CDF.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).round()),
            ),
          ),
          const SizedBox(height: 8),
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
                Radio<int>(
                  value: i,
                  groupValue: _defaultTier,
                  onChanged: (v) => setState(() => _defaultTier = v ?? 0),
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
                    decoration: const InputDecoration(labelText: 'Prix (CDF)', isDense: true, border: OutlineInputBorder()),
                    validator: (v) {
                      if ((v == null || v.trim().isEmpty) && row.label.text.trim().isNotEmpty) return 'Prix requis';
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
