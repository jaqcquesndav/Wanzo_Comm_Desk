import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/services/business_context_service.dart';
import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../../../services/receipt_printer_service.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../models/cash_session.dart';
import '../services/cash_session_report.dart';
import '../services/cash_session_service.dart';

/// Devises tenues en caisse (billets physiques).
const kCashCurrencies = ['CDF', 'USD'];

final _dt = DateFormat('dd/MM/yyyy HH:mm');

double? _parseAmount(String raw) {
  final t = raw.trim().replaceAll(RegExp(r'[\s ]'), '').replaceAll(',', '.');
  if (t.isEmpty) return 0;
  return double.tryParse(t);
}

String? _currentUserName(BuildContext context) {
  try {
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated ? s.user.name : null;
  } catch (_) {
    return null;
  }
}

/// Imprime le rapport de clôture sur l'imprimante configurée ; sans
/// imprimante, ouvre l'impression système du PDF.
Future<void> printCashSessionReport(BuildContext context, CashSession s) async {
  final company = BusinessContextService().businessUnitName ?? BusinessContextService().companyName;
  final printed = await ReceiptPrinterService().printPlainTicket(
    zTicketLines(s, companyName: company, width: ReceiptPrinterService.ticketWidth),
    pdf: (f) => zTicketPdf(s, f, companyName: company),
  );
  if (printed) return;
  await Printing.layoutPdf(
    name: 'Cloture de caisse',
    format: PdfPageFormat.roll80,
    onLayout: (_) => zTicketPdf(s, PdfPageFormat.roll80, companyName: company).save(),
  );
}

Future<void> shareCashSessionReport(CashSession s) async {
  final company = BusinessContextService().businessUnitName ?? BusinessContextService().companyName;
  final bytes = await zTicketPdf(s, PdfPageFormat.a4, companyName: company).save();
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'cloture-caisse-${DateFormat('yyyyMMdd-HHmm').format(s.closedAt ?? s.openedAt)}.pdf',
  );
}

/// Caisse déjà ouverte côté serveur : message clair, jamais silencieux, et
/// « Reprendre » quand le serveur a renvoyé la session.
Future<void> showCashSessionConflict(
  BuildContext context,
  CashSessionService service,
  Map<String, dynamic>? serverSession,
) async {
  final opened = serverSession?['openedAt'] == null
      ? null
      : DateTime.tryParse(serverSession!['openedAt'].toString())?.toLocal();
  final resume = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Caisse déjà ouverte'),
      content: Text(
        const CashSessionConflict().message +
            (opened != null ? '\n\nOuverte le ${_dt.format(opened)}.' : ''),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Fermer')),
        if (serverSession != null)
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reprendre')),
      ],
    ),
  );
  if (resume != true || serverSession == null || !context.mounted) return;
  try {
    await service.resume(serverSession);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caisse reprise sur cet appareil.')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// Caisse : ouverture, suivi de la journée, clôture (onglet « Caisse du
/// jour ») et rapports passés (onglet « Historique »).
class CashSessionScreen extends StatefulWidget {
  const CashSessionScreen({super.key});

  @override
  State<CashSessionScreen> createState() => _CashSessionScreenState();
}

class _CashSessionScreenState extends State<CashSessionScreen> {
  final _service = CashSessionService.instance;
  bool _ready = false;
  Map<String, dynamic>? _conflict;

  @override
  void initState() {
    super.initState();
    _service.load().whenComplete(() async {
      if (mounted) setState(() => _ready = true);
      // Caisse ouverte sur le serveur mais pas ici (autre appareil, ouverture
      // refusée au rejeu hors ligne) : on le dit.
      final conflict = await _service.serverConflict();
      if (conflict != null && mounted) setState(() => _conflict = conflict);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: WanzoScaffold(
        currentIndex: 0,
        title: 'Caisse',
        onBackPressed: () => context.canPop() ? context.pop() : context.go('/dashboard'),
        body: Column(
          children: [
            const TabBar(
              tabs: [Tab(text: 'Caisse du jour'), Tab(text: 'Historique')],
            ),
            if (_conflict != null)
              MaterialBanner(
                content: Text(const CashSessionConflict().message),
                leading: const Icon(Icons.warning_amber_rounded),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => _conflict = null),
                    child: const Text('Fermer'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final server = _conflict;
                      setState(() => _conflict = null);
                      await showCashSessionConflict(context, _service, server);
                    },
                    child: const Text('Reprendre'),
                  ),
                ],
              ),
            Expanded(
              child: !_ready
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        ValueListenableBuilder<CashSession?>(
                          valueListenable: _service.current,
                          builder: (context, session, _) => session == null
                              ? _OpenForm(service: _service)
                              : _OpenSessionView(service: _service, session: session),
                        ),
                        _HistoryTab(service: _service),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountFields extends StatelessWidget {
  const _AmountFields({required this.controllers, this.onChanged, this.hints});
  final Map<String, TextEditingController> controllers;
  final VoidCallback? onChanged;
  final Map<String, String>? hints;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final code in controllers.keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: controllers[code],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 .,]'))],
              decoration: InputDecoration(
                labelText: 'Montant en $code',
                suffixText: code,
                helperText: hints?[code],
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final n = _parseAmount(v ?? '');
                if (n == null) return 'Montant invalide';
                if (n < 0) return 'Montant négatif';
                return null;
              },
              onChanged: (_) => onChanged?.call(),
            ),
          ),
      ],
    );
  }
}

class _OpenForm extends StatefulWidget {
  const _OpenForm({required this.service});
  final CashSessionService service;

  @override
  State<_OpenForm> createState() => _OpenFormState();
}

class _OpenFormState extends State<_OpenForm> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl = {for (final c in kCashCurrencies) c: TextEditingController()};
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _open() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.service.open(
        {for (final e in _ctrl.entries) e.key: _parseAmount(e.value.text) ?? 0},
        openedByName: _currentUserName(context),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caisse ouverte. Les ventes de la journée y sont rattachées.')),
      );
    } on CashSessionConflict catch (e) {
      if (mounted) await showCashSessionConflict(context, widget.service, e.serverSession);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('La caisse est fermée', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Comptez les billets présents dans le tiroir : c\'est le fonds d\'ouverture. '
              'Laissez vide une devise absente.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _AmountFields(controllers: _ctrl),
            FilledButton.icon(
              onPressed: _busy ? null : _open,
              icon: const Icon(Icons.lock_open),
              label: const Text('Ouvrir la caisse'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenSessionView extends StatefulWidget {
  const _OpenSessionView({required this.service, required this.session});
  final CashSessionService service;
  final CashSession session;

  @override
  State<_OpenSessionView> createState() => _OpenSessionViewState();
}

class _OpenSessionViewState extends State<_OpenSessionView> {
  static const _page = 20;
  int _shown = _page;

  Future<void> _manual(bool entry) async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String currency = kCashCurrencies.first;
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(entry ? 'Entrée de caisse' : 'Sortie de caisse'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<String>(
                    segments: [for (final c in kCashCurrencies) ButtonSegment(value: c, label: Text(c))],
                    selected: {currency},
                    onSelectionChanged: (s) => setLocal(() => currency = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Montant', suffixText: currency),
                    validator: (v) {
                      final n = _parseAmount(v ?? '');
                      if (n == null || n <= 0) return 'Montant supérieur à zéro';
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: reasonCtrl,
                    decoration: InputDecoration(
                      labelText: 'Motif',
                      hintText: entry ? 'Apport, fonds complémentaire' : 'Dépôt en banque, retrait',
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Motif obligatoire' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await widget.service.addManual(
        entry: entry,
        amount: _parseAmount(amountCtrl.text)!,
        currency: currency,
        reason: reasonCtrl.text,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _close() async {
    final closed = await showModalBottomSheet<CashSession>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CloseSheet(service: widget.service, session: widget.session),
    );
    if (closed == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Caisse clôturée'),
        content: Text(
          CashSession.hasDifference(closed.difference ?? const {})
              ? 'Écart enregistré avec son motif. Imprimez le rapport pour signature.'
              : 'Aucun écart. Imprimez le rapport pour signature.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          TextButton(
            onPressed: () => shareCashSessionReport(closed),
            child: const Text('PDF'),
          ),
          FilledButton(
            onPressed: () => printCashSessionReport(ctx, closed),
            child: const Text('Imprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final theme = Theme.of(context);
    final expected = s.expectedCash();
    final receipts = s.receiptsByMethod();
    final moves = s.movements.reversed.toList();
    final visible = moves.take(_shown).toList();

    Widget section(String title, List<Widget> rows) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ...rows,
          ],
        ),
      ),
    );

    Widget row(String l, String r, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(l, overflow: TextOverflow.ellipsis)),
          Text(r, style: strong ? const TextStyle(fontWeight: FontWeight.bold) : null),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Ouverte le ${_dt.format(s.openedAt)}${s.openedByName != null ? ' par ${s.openedByName}' : ''}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        section('Espèces attendues dans le tiroir', [
          for (final e in expected.entries) row(e.key, cashAmount(e.value, e.key), strong: true),
          if (s.openingFloat.isNotEmpty)
            row('dont fonds d\'ouverture', s.openingFloat.entries.map((e) => cashAmount(e.value, e.key)).join(' + ')),
        ]),
        section('Encaissements (${s.salesCount} vente(s))', [
          if (receipts.isEmpty) const Text('Aucun encaissement pour le moment.'),
          for (final g in CashMethodGroup.values)
            if (receipts[g] != null)
              row(g.label, receipts[g]!.entries.map((e) => cashAmount(e.value, e.key)).join(' + ')),
        ]),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _manual(true),
              icon: const Icon(Icons.add),
              label: const Text('Entrée'),
            ),
            OutlinedButton.icon(
              onPressed: () => _manual(false),
              icon: const Icon(Icons.remove),
              label: const Text('Sortie'),
            ),
            FilledButton.icon(
              onPressed: _close,
              icon: const Icon(Icons.lock),
              label: const Text('Clôturer la caisse'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Mouvements', style: theme.textTheme.titleSmall),
        if (moves.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Aucun mouvement.'),
          ),
        for (final m in visible)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(m.amount >= 0 ? Icons.south_west : Icons.north_east,
                color: m.amount >= 0 ? Colors.green : Colors.red),
            title: Text(m.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${DateFormat('HH:mm').format(m.at)} · ${m.kind.label} · ${cashMethodGroupOf(m.method).label}'),
            trailing: Text(cashAmount(m.amount, m.currency)),
          ),
        if (moves.length > _shown)
          TextButton(
            onPressed: () => setState(() => _shown += _page),
            child: Text('Voir plus (${moves.length - _shown} restants)'),
          ),
      ],
    );
  }
}

class _CloseSheet extends StatefulWidget {
  const _CloseSheet({required this.service, required this.session});
  final CashSessionService service;
  final CashSession session;

  @override
  State<_CloseSheet> createState() => _CloseSheetState();
}

class _CloseSheetState extends State<_CloseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, double> _expected = widget.session.expectedCash();
  late final Map<String, TextEditingController> _ctrl = {
    for (final c in {...kCashCurrencies, ..._expected.keys}) c: TextEditingController(),
  };
  final _reason = TextEditingController();
  bool _busy = false;

  Map<String, double> get _counted => {
    for (final e in _ctrl.entries) e.key: _parseAmount(e.value.text) ?? 0,
  };

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final closed = await widget.service.close(
        _counted,
        reason: _reason.text,
        closedByName: _currentUserName(context),
      );
      if (mounted) Navigator.pop(context, closed);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diff = CashSession.differenceOf(_expected, _counted);
    final hasDiff = CashSession.hasDifference(diff);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Clôturer la caisse', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(
                'Comptez les espèces du tiroir, devise par devise.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _AmountFields(
                controllers: _ctrl,
                onChanged: () => setState(() {}),
                hints: {
                  for (final c in _ctrl.keys)
                    c: 'Théorique ${cashAmount(_expected[c] ?? 0, c)}'
                        '${(diff[c] ?? 0).abs() >= 0.01 ? ', écart ${cashAmount(diff[c]!, c)}' : ''}',
                },
              ),
              if (hasDiff)
                TextFormField(
                  controller: _reason,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Motif de l\'écart',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Motif obligatoire en cas d\'écart' : null,
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: const Icon(Icons.lock),
                label: const Text('Clôturer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTab extends StatefulWidget {
  const _HistoryTab({required this.service});
  final CashSessionService service;

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  static const _page = 20;
  int _shown = _page;
  List<CashSession>? _items;

  @override
  void initState() {
    super.initState();
    _reload();
    widget.service.current.addListener(_reload);
  }

  @override
  void dispose() {
    widget.service.current.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final items = await widget.service.history();
    if (mounted) setState(() => _items = items);
  }

  String _diffLabel(CashSession s) {
    final d = s.difference ?? const {};
    if (!CashSession.hasDifference(d)) return 'Sans écart';
    return 'Écart ${d.entries.where((e) => e.value.abs() >= 0.01).map((e) => cashAmount(e.value, e.key)).join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Aucune clôture pour le moment.', textAlign: TextAlign.center),
        ),
      );
    }
    final visible = items.take(_shown).toList();
    return ListView(
      children: [
        for (final s in visible)
          ListTile(
            title: Text('Clôture du ${_dt.format(s.closedAt ?? s.openedAt)}'),
            subtitle: Text(
              '${s.salesCount} vente(s) · ${_diffLabel(s)}'
              '${s.closedByName != null ? ' · ${s.closedByName}' : ''}',
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Actions',
              onSelected: (v) => v == 'print' ? printCashSessionReport(context, s) : shareCashSessionReport(s),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'print', child: Text('Imprimer le rapport')),
                PopupMenuItem(value: 'pdf', child: Text('Partager le PDF')),
              ],
            ),
          ),
        if (items.length > _shown)
          TextButton(
            onPressed: () => setState(() => _shown += _page),
            child: Text('Voir plus (${items.length - _shown} restantes)'),
          ),
      ],
    );
  }
}
