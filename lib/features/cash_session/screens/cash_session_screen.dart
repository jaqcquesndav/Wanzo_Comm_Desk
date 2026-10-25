import 'package:wanzo/core/utils/desktop_modal.dart';
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
import '../../../core/services/currency_service.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../settings/models/financial_account.dart';
import '../../settings/repositories/financial_account_repository.dart';
import '../../business_unit/repositories/business_unit_repository.dart';
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

/// Clôture déjà enregistrée sur le serveur (par un responsable, ou avec un
/// autre comptage) : qui, quand, ce que le serveur a retenu et l'écart à
/// corriger entre les deux comptages.
String serverClosureMessage(CashSession s) {
  final srv = s.serverClosure ?? const {};
  final by = srv['closedByName'];
  final at = DateTime.tryParse('${srv['closedAt']}')?.toLocal();
  String fmt(dynamic raw) {
    final m = cashAmountsOf(raw);
    return m.isEmpty ? '0' : m.entries.map((e) => cashAmount(e.value, e.key)).join(', ');
  }

  final gap = cashAmountsOf(srv['countGap']).entries.where((e) => e.value.abs() >= 0.01);
  return 'Cette caisse était déjà clôturée sur le serveur'
      '${by != null ? ' par $by' : ''}'
      '${at != null ? ' le ${_dt.format(at)}' : ''}. '
      'Compté retenu : ${fmt(srv['counted'])}, écart ${fmt(srv['difference'])}. '
      '${gap.isEmpty ? 'Votre comptage est identique.' : 'Écart à corriger avec votre comptage : ${gap.map((e) => cashAmount(e.value, e.key)).join(', ')}.'}';
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
      // Envois restés en attente (réseau absent, serveur en panne) : rejoués.
      await _service.syncPending().catchError((_) {});
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
            // Refus du serveur (droits, validation) : affiche, jamais avale.
            ValueListenableBuilder<String?>(
              valueListenable: _service.serverRefusal,
              builder: (context, refus, _) => refus == null
                  ? const SizedBox.shrink()
                  : MaterialBanner(
                      content: Text('Refus du serveur : $refus'),
                      leading: Icon(Icons.block,
                          color: Theme.of(context).colorScheme.error),
                      actions: [
                        TextButton(
                          onPressed: () => _service.serverRefusal.value = null,
                          child: const Text('Fermer'),
                        ),
                      ],
                    ),
            ),
            // Clôture déjà faite sur le serveur par quelqu'un d'autre : dit
            // clairement, avec l'écart à corriger.
            ValueListenableBuilder<CashSession?>(
              valueListenable: _service.closedElsewhere,
              builder: (context, s, _) => s == null || s.serverClosure == null
                  ? const SizedBox.shrink()
                  : MaterialBanner(
                      content: Text(serverClosureMessage(s)),
                      leading: Icon(Icons.info_outline,
                          color: Theme.of(context).colorScheme.error),
                      actions: [
                        TextButton(
                          onPressed: () => _service.closedElsewhere.value = null,
                          child: const Text('Fermer'),
                        ),
                      ],
                    ),
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
            // Caissier d'unité : la caisse s'ouvre dans SON unité, sans choix.
            if (widget.service.unitScope.isLocked)
              Text(
                'Unité : ${BusinessContextService().businessUnitName ?? BusinessContextService().businessUnitCode ?? ''}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
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
    final slipCtrl = TextEditingController();
    String currency = kCashCurrencies.first;
    bool deposit = false;
    FinancialAccount? bank;
    // Comptes bancaires de l'entreprise (Réglages, comptes financiers) :
    // la destination d'un dépôt se CHOISIT, elle ne se saisit pas.
    List<FinancialAccount> banks = const [];
    if (!entry) {
      try {
        banks = context.read<FinancialAccountRepository>().getBankAccounts();
      } catch (_) {
        banks = const [];
      }
      bank = banks.where((a) => a.isDefault).firstOrNull ?? banks.firstOrNull;
    }
    final expected = widget.session.expectedCash();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(entry ? 'Entrée de caisse' : (deposit ? 'Dépôt en banque' : 'Sortie de caisse')),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!entry)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dépôt en banque'),
                      subtitle: Text(
                        deposit
                            ? 'Passé en comptabilité (caisse vers banque).'
                            : 'Simple sortie de caisse, notée avec son motif.',
                      ),
                      value: deposit,
                      onChanged: (v) => setLocal(() => deposit = v),
                    ),
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
                    decoration: InputDecoration(
                      labelText: 'Montant',
                      suffixText: currency,
                      helperText: deposit ? 'En caisse : ${cashAmount(expected[currency] ?? 0, currency)}' : null,
                    ),
                    validator: (v) {
                      final n = _parseAmount(v ?? '');
                      if (n == null || n <= 0) return 'Montant supérieur à zéro';
                      if (deposit && n > (expected[currency] ?? 0) + 0.004) {
                        return 'Plus que les espèces attendues en caisse';
                      }
                      return null;
                    },
                  ),
                  if (deposit) ...[
                    const SizedBox(height: 8),
                    if (banks.isEmpty)
                      const Text(
                        "Aucun compte bancaire : ajoutez-en un dans Réglages, comptes financiers.",
                      )
                    else
                      DropdownButtonFormField<FinancialAccount>(
                        value: bank,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Compte bancaire'),
                        items: [
                          for (final a in banks)
                            DropdownMenuItem(
                              value: a,
                              child: Text(a.accountName, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (a) => setLocal(() => bank = a),
                        validator: (a) => a == null ? 'Choisissez le compte' : null,
                      ),
                    TextFormField(
                      controller: slipCtrl,
                      decoration: const InputDecoration(labelText: 'N° de bordereau (facultatif)'),
                    ),
                  ] else
                    TextFormField(
                      controller: reasonCtrl,
                      decoration: InputDecoration(
                        labelText: 'Motif',
                        hintText: entry ? 'Apport, fonds complémentaire' : 'Retrait, avance',
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
              onPressed: deposit && banks.isEmpty
                  ? null
                  : () {
                      if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
                    },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (deposit) {
        double? rate;
        if (currency != 'CDF') {
          final cs = CurrencyService();
          await cs.loadSettings();
          rate = cs.usableRateToCdfForCode(currency);
        }
        await widget.service.addBankDeposit(
          amount: _parseAmount(amountCtrl.text)!,
          currency: currency,
          exchangeRate: rate,
          accountId: bank!.id,
          accountName: bank!.accountName,
          slipNumber: slipCtrl.text,
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('Dépôt enregistré. Il part en comptabilité (hors connexion : à la reconnexion).')),
        );
      } else {
        await widget.service.addManual(
          entry: entry,
          amount: _parseAmount(amountCtrl.text)!,
          currency: currency,
          reason: reasonCtrl.text,
        );
      }
    } on ArgumentError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${e.message}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _close() async {
    final closed = await showDesktopModal<CashSession>(
        context,
        title: 'Clôturer la caisse',
        subtitle: 'Comptez les espèces du tiroir, devise par devise.',
        scrollable: false,
        contentPadding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        builder: (_) => _CloseSheet(service: widget.service, session: widget.session),
      );
    if (closed == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Caisse clôturée'),
        content: Text(
          '${CashSession.hasDifference(closed.difference ?? const {})
              ? 'Écart enregistré avec son motif. Imprimez le rapport pour signature.'
              : 'Aucun écart. Imprimez le rapport pour signature.'}'
          '${closed.serverClosure != null ? '\n\n${serverClosureMessage(closed)}' : ''}'
          '${closed.hasPendingSync ? '\n\nHors connexion : la clôture partira au retour du réseau.' : ''}',
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
    final credit = s.creditGranted();
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
          // Ventes non encaissées : hors tiroir, jamais dans les espèces.
          if (credit.isNotEmpty)
            row('Crédit accordé (non encaissé)', credit.entries.map((e) => cashAmount(e.value, e.key)).join(' + ')),
        ]),
        if (s.hasPendingSync)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: Text('${s.pendingSync.length} envoi(s) en attente du réseau'),
              subtitle: const Text('Ils partent seuls au retour de la connexion.'),
              trailing: IconButton(
                tooltip: 'Réessayer',
                icon: const Icon(Icons.refresh),
                onPressed: () => widget.service.syncPending(),
              ),
            ),
          ),
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
            subtitle: Text(
              '${DateFormat('HH:mm').format(m.at)} · ${m.kind.label} · ${cashMethodGroupOf(m.method).label}'
              '${m.isNotPosted ? '\nNon comptabilisé : ${m.syncIssue}' : ''}'
              '${m.kind == CashMovementKind.bankDeposit && !m.isNotPosted && s.pendingSync.any((p) => p.ref == m.ref) ? '\nEn attente d\'envoi' : ''}',
              style: m.isNotPosted ? TextStyle(color: theme.colorScheme.error) : null,
            ),
            isThreeLine: m.isNotPosted,
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
    _loadServer();
    widget.service.current.addListener(_reload);
  }

  @override
  void dispose() {
    widget.service.current.removeListener(_reload);
    super.dispose();
  }

  /// Unité filtrée (null : toutes). Jamais proposé au caissier d'unité :
  /// son historique est déjà limité à son unité.
  String? _unitFilter;
  Set<String> _units = const {};
  Map<String, String> _unitNames = const {};

  Future<void> _reload() async {
    final items = await widget.service.history(unitFilter: _unitFilter);
    final units = widget.service.unitScope.isLocked ? <String>{} : await widget.service.historyUnits();
    if (mounted) {
      setState(() {
        _items = items;
        _units = units;
      });
    }
    if (units.length > 1 && _unitNames.isEmpty) await _loadUnitNames();
  }

  Future<void> _loadUnitNames() async {
    try {
      final all = await context.read<BusinessUnitRepository>().getAllLocalBusinessUnits();
      if (mounted) setState(() => _unitNames = {for (final u in all) u.id: u.name});
    } catch (_) {}
  }

  String _unitLabel(String id) =>
      id == kCashRootUnit ? 'Entreprise générale' : (_unitNames[id] ?? 'Unité ${id.length > 8 ? id.substring(0, 8) : id}');

  Widget? _unitFilterField() {
    if (_units.length < 2 && _unitFilter == null) return null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DropdownButtonFormField<String?>(
        value: _unitFilter,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Unité',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Toutes les unités')),
          for (final u in _units)
            DropdownMenuItem<String?>(
              value: u,
              child: Text(_unitLabel(u), overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) {
          setState(() {
            _unitFilter = v;
            _shown = _page;
          });
          _reload();
        },
      ),
    );
  }

  bool _serverLoaded = false;
  bool _loadingMore = false;

  /// Historique du serveur (autres appareils, réinstallation), fusionné.
  Future<void> _loadServer() async {
    try {
      await widget.service.refreshServerHistory();
    } catch (_) {}
    _serverLoaded = true;
    await _reload();
  }

  Future<void> _more(int localCount) async {
    if (localCount > _shown) {
      setState(() => _shown += _page);
      return;
    }
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      await widget.service.loadMoreServerHistory();
    } catch (_) {}
    await _reload();
    if (mounted) {
      setState(() {
        _loadingMore = false;
        _shown += _page;
      });
    }
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
    final filter = _unitFilterField();
    if (items.isEmpty) {
      return ListView(
        children: [
          if (filter != null) filter,
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Aucune clôture pour le moment.', textAlign: TextAlign.center),
          ),
        ],
      );
    }
    final visible = items.take(_shown).toList();
    return ListView(
      children: [
        if (filter != null) filter,
        for (final s in visible)
          ListTile(
            title: Text('Clôture du ${_dt.format(s.closedAt ?? s.openedAt)}'),
            subtitle: Text(
              '${s.salesCount} vente(s) · ${_diffLabel(s)}'
              '${s.closedByName != null ? ' · ${s.closedByName}' : ''}'
              '${s.fromServer ? ' · relue du serveur' : ''}'
              '${s.hasPendingSync ? ' · en attente d\'envoi' : ''}'
              '${s.notPostedDeposits.isNotEmpty ? ' · dépôt non comptabilisé' : ''}'
              '${s.serverClosure != null ? '\n${serverClosureMessage(s)}' : ''}',
            ),
            isThreeLine: s.serverClosure != null,
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
            onPressed: () => _more(items.length),
            child: Text('Voir plus (${items.length - _shown} restantes)'),
          )
        else if (_serverLoaded && widget.service.hasMoreServerHistory)
          TextButton(
            onPressed: _loadingMore ? null : () => _more(items.length),
            child: Text(_loadingMore ? 'Chargement…' : 'Voir plus'),
          ),
      ],
    );
  }
}
