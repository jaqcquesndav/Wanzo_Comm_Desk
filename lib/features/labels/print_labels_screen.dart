import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'label_codes.dart';
import 'label_format.dart';
import 'label_item.dart';
import 'label_layout.dart';
import 'label_preview.dart';
import 'label_print_service.dart';
import 'label_printer_bridge.dart';

/// Enregistre sur la fiche le code généré d'un article (API de mise à jour
/// du produit, file hors ligne comprise). Renvoie faux en cas d'échec.
typedef SaveLabelCode = Future<bool> Function(LabelItem item);

/// Ouvre l'écran d'impression d'étiquettes.
///
/// [items] : articles proposés (un seul depuis une carte ou une fiche, toute
/// la liste pour une impression en lot). [selectedIds] : articles cochés au
/// départ (tous si `null` et un seul article).
Future<bool?> openPrintLabels(
  BuildContext context, {
  required List<LabelItem> items,
  Set<String>? selectedIds,
  String? companyName,
  SaveLabelCode? saveCode,
}) {
  return Navigator.of(context).push<bool>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => PrintLabelsScreen(
      items: items,
      selectedIds: selectedIds,
      companyName: companyName,
      saveCode: saveCode,
    ),
  ));
}

class PrintLabelsScreen extends StatefulWidget {
  final List<LabelItem> items;
  final Set<String>? selectedIds;
  final String? companyName;
  final SaveLabelCode? saveCode;

  /// Voie d'impression imposée (tests) ; sinon celle des réglages.
  final LabelTarget? target;
  final LabelSettings? initialSettings;

  const PrintLabelsScreen({
    super.key,
    required this.items,
    this.selectedIds,
    this.companyName,
    this.saveCode,
    this.target,
    this.initialSettings,
  });

  @override
  State<PrintLabelsScreen> createState() => _PrintLabelsScreenState();
}

class _PrintLabelsScreenState extends State<PrintLabelsScreen> {
  late LabelSettings _settings =
      widget.initialSettings ?? const LabelSettings();
  LabelTarget _target = LabelTarget.systemDialog;
  late final Map<String, int> _copies = {
    for (final i in widget.items) i.id: i.defaultCopies,
  };
  late final Set<String> _selected = widget.selectedIds != null
      ? {...widget.selectedIds!}
      : (widget.items.length == 1 ? {widget.items.first.id} : <String>{});
  late String? _previewId = _selected.isNotEmpty
      ? _selected.first
      : (widget.items.isNotEmpty ? widget.items.first.id : null);
  final _search = TextEditingController();
  late final _customW = TextEditingController(text: _fmt(_settings.customWidthMm));
  late final _customH =
      TextEditingController(text: _fmt(_settings.customHeightMm));
  bool _busy = false;
  final _service = LabelPrintService();

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  void initState() {
    super.initState();
    if (widget.initialSettings == null) {
      LabelSettings.load().then((s) {
        if (!mounted) return;
        setState(() {
          _settings = s;
          _customW.text = _fmt(s.customWidthMm);
          _customH.text = _fmt(s.customHeightMm);
        });
      });
    }
    if (widget.target != null) {
      _target = widget.target!;
    } else {
      resolveLabelTarget().then((t) {
        if (mounted) setState(() => _target = t);
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _customW.dispose();
    _customH.dispose();
    super.dispose();
  }

  bool get _single => widget.items.length == 1;
  bool get _hasCompany => (widget.companyName ?? '').trim().isNotEmpty;
  bool get _hasExtra =>
      widget.items.any((i) => (i.extra ?? '').trim().isNotEmpty);
  bool get _hasSecondary =>
      widget.items.any((i) => (i.secondaryPrice ?? '').trim().isNotEmpty);

  LabelOptions get _options => LabelOptions(
        showCompany: _settings.showCompany && _hasCompany,
        showUnit: _settings.showUnit,
        showExtra: _settings.showExtra,
        showSecondaryPrice: _settings.showSecondaryPrice,
        companyName: widget.companyName,
      );

  List<LabelJob> get _jobs => [
        for (final i in widget.items)
          if (_selected.contains(i.id) && (_copies[i.id] ?? 0) > 0)
            LabelJob(i, _copies[i.id]!),
      ];

  int get _total => _jobs.fold(0, (s, j) => s + j.copies);

  LabelItem? get _previewItem {
    for (final i in widget.items) {
      if (i.id == _previewId) return i;
    }
    return widget.items.isEmpty ? null : widget.items.first;
  }

  void _update(LabelSettings s) {
    setState(() => _settings = s);
    s.save();
  }

  void _setCopies(String id, int v) {
    setState(() {
      _copies[id] = v.clamp(0, 999);
      if (v > 0) _selected.add(id);
    });
  }

  Future<void> _editCopies(LabelItem item) async {
    final ctrl = TextEditingController(text: '${_copies[item.id] ?? 1}');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre d\'étiquettes'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            helperText: item.stockQuantity > 0
                ? 'En stock : ${_fmt(item.stockQuantity)}'
                : null,
          ),
          onSubmitted: (t) => Navigator.pop(ctx, int.tryParse(t)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
              child: const Text('Valider')),
        ],
      ),
    );
    ctrl.dispose();
    if (v != null) _setCopies(item.id, v);
  }

  Future<void> _saveGeneratedCodes() async {
    final save = widget.saveCode;
    if (save == null) return;
    final failed = <String>[];
    for (final j in _jobs.where((j) => j.item.codeIsGenerated)) {
      bool ok;
      try {
        ok = await save(j.item);
      } catch (_) {
        ok = false;
      }
      if (!ok) failed.add(j.item.name);
    }
    if (failed.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Code non enregistré pour : ${failed.join(', ')}. '
            'La caisse ne le reconnaîtra qu\'après enregistrement.'),
      ));
    }
  }

  Future<void> _print() async {
    if (_total == 0 || _busy) return;
    setState(() => _busy = true);
    await _settings.save();
    await _saveGeneratedCodes();
    final res = await _service.print(
      jobs: _jobs,
      settings: _settings,
      options: _options,
      target: _target,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.message),
      backgroundColor: res.ok ? null : Theme.of(context).colorScheme.error,
    ));
  }

  Future<void> _pdf() async {
    if (_total == 0 || _busy) return;
    setState(() => _busy = true);
    try {
      await _saveGeneratedCodes();
      await _service.sharePdf(
          jobs: _jobs, settings: _settings, options: _options);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF impossible : $e')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  // ── Construction ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Fermer',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Imprimer des étiquettes'),
      ),
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 840;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CustomScrollView(slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(child: _settingsSection()),
                  ),
                  ..._itemsSlivers(),
                ]),
              ),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _previewSection(),
                ),
              ),
            ],
          );
        }
        return CustomScrollView(slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(child: _previewSection()),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(child: _settingsSection()),
          ),
          ..._itemsSlivers(),
        ]);
      }),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _previewSection() {
    final item = _previewItem;
    final theme = Theme.of(context);
    if (item == null) return const SizedBox.shrink();
    final layout = LabelLayout.compute(
      format: _settings.format,
      item: item,
      options: _options,
      choice: _settings.codeChoice,
    );
    final f = _settings.format;
    final pages = f.isSheet ? (_total / f.perPage).ceil() : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: LabelPreview(layout: layout, maxHeight: 200),
        ),
        const SizedBox(height: 6),
        Text(
          f.isSheet
              ? '${f.perPage} étiquettes par page${pages > 0 ? ', $pages page(s)' : ''}'
              : f.description,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        if (item.codeIsGenerated)
          _hint(Icons.qr_code_2,
              'Code ${item.code} : il sera enregistré comme code-barres de '
              'l\'article, pour être reconnu à la caisse.'),
        for (final w in layout.warnings) _hint(Icons.info_outline, w, warn: true),
      ],
    );
  }

  Widget _hint(IconData icon, String text, {bool warn = false}) {
    final color = warn ? Colors.orange.shade800 : Theme.of(context).hintColor;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: color))),
      ]),
    );
  }

  Widget _settingsSection() {
    final theme = Theme.of(context);
    final f = _settings.format;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: const ValueKey('label-format'),
          value: _settings.formatId == LabelFormat.customId
              ? LabelFormat.customId
              : f.id,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Format',
            prefixIcon: Icon(Icons.straighten),
          ),
          items: [
            for (final p in LabelFormat.presets)
              DropdownMenuItem(
                value: p.id,
                child: Text(p.description, overflow: TextOverflow.ellipsis),
              ),
            const DropdownMenuItem(
              value: LabelFormat.customId,
              child: Text('Dimension personnalisée'),
            ),
          ],
          onChanged: (v) {
            if (v != null) _update(_settings.copyWith(formatId: v));
          },
        ),
        if (_settings.formatId == LabelFormat.customId) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _sideField(_customW, 'Largeur (mm)', true)),
            const SizedBox(width: 12),
            Expanded(child: _sideField(_customH, 'Hauteur (mm)', false)),
          ]),
        ],
        const SizedBox(height: 16),
        Text('Code', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        // Puces plutôt qu'un bouton segmenté : elles passent à la ligne sur
        // un écran étroit ou avec une grande police.
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final (choice, icon, label) in const [
            (LabelCodeChoice.barcode, Icons.view_week_outlined, 'Code-barres'),
            (LabelCodeChoice.qr, Icons.qr_code_2, 'QR code'),
          ])
            ChoiceChip(
              avatar: Icon(icon, size: 18),
              label: Text(label),
              selected: _settings.codeChoice == choice,
              showCheckmark: false,
              onSelected: (_) =>
                  _update(_settings.copyWith(codeChoice: choice)),
            ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 4, children: [
          if (_hasCompany)
            FilterChip(
              label: const Text('Nom de l\'entreprise'),
              selected: _settings.showCompany,
              onSelected: (v) => _update(_settings.copyWith(showCompany: v)),
            ),
          FilterChip(
            label: const Text('Unité'),
            selected: _settings.showUnit,
            onSelected: (v) => _update(_settings.copyWith(showUnit: v)),
          ),
          if (_hasExtra)
            FilterChip(
              label: const Text('Lot ou date'),
              selected: _settings.showExtra,
              onSelected: (v) => _update(_settings.copyWith(showExtra: v)),
            ),
          if (_hasSecondary)
            FilterChip(
              label: const Text('Prix en CDF et USD'),
              selected: _settings.showSecondaryPrice,
              onSelected: (v) =>
                  _update(_settings.copyWith(showSecondaryPrice: v)),
            ),
        ]),
        const SizedBox(height: 12),
        _printerRow(),
      ],
    );
  }

  Widget _sideField(TextEditingController ctrl, String label, bool width) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      autovalidateMode: AutovalidateMode.always,
      validator: LabelFormat.validateSide,
      decoration: InputDecoration(labelText: label, suffixText: 'mm'),
      onChanged: (t) {
        if (LabelFormat.validateSide(t) != null) return;
        final v = double.parse(t.trim().replaceAll(',', '.'));
        _update(width
            ? _settings.copyWith(customWidthMm: v)
            : _settings.copyWith(customHeightMm: v));
      },
    );
  }

  Widget _printerRow() {
    final theme = Theme.of(context);
    final sheet = _settings.format.isSheet;
    final viaSystem = sheet ||
        _target.kind == LabelTargetKind.none ||
        _target.kind == LabelTargetKind.system;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.print_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sheet ? 'Imprimante du système' : _target.displayName,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  sheet
                      ? 'Planche A4 : impression par le pilote (PDF)'
                      : viaSystem
                          ? 'Choix de l\'imprimante au moment d\'imprimer'
                          : 'Imprimante configurée dans les réglages',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ]),
        if (!sheet && _target.speaksRaw) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<LabelPrinterLanguage>(
            value: _settings.language,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Type d\'imprimante'),
            items: [
              for (final l in LabelPrinterLanguage.values)
                DropdownMenuItem(
                  value: l,
                  child: Text(l.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              if (v != null) _update(_settings.copyWith(language: v));
            },
          ),
        ],
      ]),
    );
  }

  List<Widget> _itemsSlivers() {
    if (_single) {
      final item = widget.items.first;
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          sliver: SliverToBoxAdapter(
            child: Row(children: [
              Expanded(
                child: Text('Nombre d\'étiquettes',
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              _stepper(item),
            ]),
          ),
        ),
      ];
    }
    final q = _search.text.trim().toLowerCase();
    final visible = q.isEmpty
        ? widget.items
        : widget.items
            .where((i) =>
                i.name.toLowerCase().contains(q) ||
                i.code.toLowerCase().contains(q))
            .toList();
    final allSelected =
        visible.isNotEmpty && visible.every((i) => _selected.contains(i.id));
    final noneSelected = visible.every((i) => !_selected.contains(i.id));
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        sliver: SliverToBoxAdapter(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Rechercher un article',
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              tristate: true,
              value: allSelected ? true : (noneSelected ? false : null),
              title: Text('Tout sélectionner (${visible.length})'),
              onChanged: (_) => setState(() {
                if (allSelected) {
                  _selected.removeAll(visible.map((i) => i.id));
                } else {
                  _selected.addAll(visible.map((i) => i.id));
                }
              }),
            ),
          ]),
        ),
      ),
      SliverList.builder(
        itemCount: visible.length,
        itemBuilder: (context, i) => _itemRow(visible[i]),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  Widget _itemRow(LabelItem item) {
    final theme = Theme.of(context);
    final selected = _selected.contains(item.id);
    return Material(
      color: item.id == _previewId
          ? theme.colorScheme.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _previewId = item.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 12, 2),
          child: Row(children: [
            Checkbox(
              value: selected,
              onChanged: (v) => setState(() {
                v == true ? _selected.add(item.id) : _selected.remove(item.id);
                _previewId = item.id;
              }),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    [
                      if (item.price != null) item.price!,
                      item.codeIsGenerated ? 'code à créer' : item.code,
                    ].join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (selected) _stepper(item),
          ]),
        ),
      ),
    );
  }

  Widget _stepper(LabelItem item) {
    final v = _copies[item.id] ?? 1;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        tooltip: 'Moins',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: v > 0 ? () => _setCopies(item.id, v - 1) : null,
      ),
      InkWell(
        onTap: () => _editCopies(item),
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 32),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text('$v',
                key: ValueKey('copies-${item.id}'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
      ),
      IconButton(
        tooltip: 'Plus',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.add_circle_outline),
        onPressed: v < 999 ? () => _setCopies(item.id, v + 1) : null,
      ),
    ]);
  }

  Widget _bottomBar() {
    final theme = Theme.of(context);
    final total = _total;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: LayoutBuilder(builder: (context, c) {
          final summary = Text(
            total == 0
                ? 'Aucune étiquette'
                : '$total étiquette${total > 1 ? 's' : ''}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          );
          final pdf = IconButton(
            tooltip: 'Enregistrer ou partager en PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: total == 0 || _busy ? null : _pdf,
          );
          final print = FilledButton.icon(
            key: const ValueKey('label-print'),
            onPressed: total == 0 || _busy ? null : _print,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.print),
            label: const Text('Imprimer', overflow: TextOverflow.ellipsis),
          );
          // Écran étroit ou grande police : le total passe au-dessus.
          final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
          if (c.maxWidth < 300 * scale) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Align(alignment: Alignment.centerLeft, child: summary),
              const SizedBox(height: 4),
              Row(children: [pdf, const SizedBox(width: 4), Expanded(child: print)]),
            ]);
          }
          return Row(children: [
            Expanded(child: summary),
            pdf,
            const SizedBox(width: 4),
            print,
          ]);
        }),
      ),
    );
  }
}
