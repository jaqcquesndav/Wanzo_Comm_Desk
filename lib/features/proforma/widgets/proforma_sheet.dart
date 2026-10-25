import 'package:wanzo/core/utils/desktop_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/exceptions/api_exceptions.dart';
import '../../../core/shared_widgets/show_more.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../invoice/services/invoice_service.dart';
import '../../sales/bloc/sales_bloc.dart';
import '../../sales/screens/add_sale_screen.dart';
import '../models/proforma.dart';
import '../services/proforma_document.dart';
import '../services/proforma_repository.dart';

/// Émet une proforma depuis une pièce (panier, commande, réservation) puis
/// l'affiche avec ses actions (imprimer, partager, convertir). Hors ligne,
/// elle part avec un numéro provisoire et reçoit son numéro définitif à la
/// synchronisation.
Future<Proforma?> issueProforma(
  BuildContext context, {
  required String sourceType,
  String? sourceId,
  String? customerId,
  String? customerName,
  String? contactName,
  required List<ProformaLine> lines,
  String currencyCode = 'CDF',
  double exchangeRate = 1,
  String? notes,
  VoidCallback? onCheckoutOrder,
}) async {
  if (lines.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ajoutez au moins une ligne avant la proforma.')));
    return null;
  }
  final validite = await _choisirValidite(context);
  if (validite == null || !context.mounted) return null;
  final p = await ProformaRepository().create(
    sourceType: sourceType,
    sourceId: sourceId,
    customerId: customerId,
    customerName: customerName,
    contactName: contactName,
    lines: lines,
    currencyCode: currencyCode,
    exchangeRate: exchangeRate,
    validityDays: validite,
    notes: notes,
  );
  if (!context.mounted) return p;
  await showProformaSheet(context, p, onCheckoutOrder: onCheckoutOrder);
  return p;
}

/// Durée de validité, choix rapide (30 jours par défaut).
Future<int?> _choisirValidite(BuildContext context) => showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Proforma valable'),
        children: [
          for (final j in const [7, 15, 30, 60])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, j),
              child: Row(
                children: [
                  Icon(j == 30 ? Icons.radio_button_checked : Icons.schedule,
                      size: 18),
                  const SizedBox(width: 12),
                  Text('$j jours${j == 30 ? ' (habituel)' : ''}'),
                ],
              ),
            ),
        ],
      ),
    );

/// Fiche d'une proforma : numéro (provisoire tant qu'elle n'est pas
/// synchronisée), client, total, validité, et actions.
Future<void> showProformaSheet(
  BuildContext context,
  Proforma proforma, {
  VoidCallback? onCheckoutOrder,
}) {
  final body = _ProformaSheet(
    proforma: proforma,
    onCheckoutOrder: onCheckoutOrder,
    hostContext: context,
  );
  return showDesktopModal<void>(
    context,
    title: 'Facture proforma',
    icon: Icons.request_quote_outlined,
    scrollable: false,
    contentPadding: EdgeInsets.zero,
    builder: (_) => body,
  );
}

class _ProformaSheet extends StatefulWidget {
  final Proforma proforma;
  final VoidCallback? onCheckoutOrder;
  final BuildContext hostContext;
  const _ProformaSheet({
    required this.proforma,
    required this.hostContext,
    this.onCheckoutOrder,
  });

  @override
  State<_ProformaSheet> createState() => _ProformaSheetState();
}

class _ProformaSheetState extends State<_ProformaSheet> {
  late Proforma _p = widget.proforma;
  bool _busy = false;
  final _repo = ProformaRepository();

  void _message(String m, {bool erreur = false}) {
    ScaffoldMessenger.of(widget.hostContext).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: erreur ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<String?> _pdf() async {
    final settings = ProformaDocument.settingsOf(widget.hostContext);
    if (settings == null) {
      _message("Paramètres de l'entreprise pas encore chargés. Réessayez.",
          erreur: true);
      return null;
    }
    return ProformaDocument.pdf(_p, settings);
  }

  String get _resume =>
      'Facture proforma ${_p.displayNumber}'
      '${_p.isProvisional ? ' (numéro provisoire)' : ''}'
      ' : ${formatCurrency(_p.totalInCurrency, _p.currencyCode)}'
      '${_p.validUntil != null ? ", valable jusqu'au ${DateFormat('dd/MM/yyyy').format(_p.validUntil!)}" : ''}.';

  Future<void> _imprimer() async {
    setState(() => _busy = true);
    try {
      final path = await _pdf();
      if (path != null) await InvoiceService().printDocument(path);
    } catch (e) {
      _message('Impression impossible : $e', erreur: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _partager() async {
    setState(() => _busy = true);
    try {
      final path = await _pdf();
      if (path != null) {
        // Feuille de partage du système : WhatsApp, e-mail, etc., PDF joint.
        await SharePlus.instance.share(ShareParams(
          files: [XFile(path)],
          subject: 'Facture proforma ${_p.displayNumber}',
          text: _resume,
        ));
      }
    } catch (e) {
      _message('Partage impossible : $e', erreur: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _whatsapp() async {
    final uri = Uri.parse(
        'https://wa.me/?text=${Uri.encodeComponent(_resume)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _annuler() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la proforma ?'),
        content: Text('${_p.displayNumber} ne pourra plus être convertie.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Garder')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Annuler la proforma')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final c = await _repo.cancel(_p);
      if (mounted) setState(() => _p = c);
    } catch (e) {
      _message(
          e is ApiException && e.message.isNotEmpty
              ? e.message
              : 'Annulation impossible hors ligne : réessayez avec le réseau.',
          erreur: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Convertir : en facture (formulaire de vente prérempli, hors ligne
  /// possible), en réservation confirmée, ou encaisser la commande.
  Future<void> _convertir() async {
    switch (_p.sourceType) {
      case ProformaSource.reservation:
        setState(() => _busy = true);
        try {
          final r = await _repo.convert(_p);
          if (!mounted) return;
          setState(() => _p = r.proforma);
          _message('Réservation confirmée. La facture sera établie avec son folio.');
        } catch (e) {
          _message(
              e is ApiException && e.message.isNotEmpty
                  ? e.message
                  : 'Conversion impossible. Vérifiez la connexion.',
              erreur: true);
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      case ProformaSource.restaurantOrder:
        Navigator.of(context).pop();
        widget.onCheckoutOrder?.call();
      default:
        _versFacture();
    }
  }

  /// Ouvre le formulaire de vente prérempli : la facture suit le parcours
  /// habituel (encaissement, stock, comptabilité, hors ligne compris) ; la
  /// proforma est marquée convertie avec la vente créée.
  void _versFacture() {
    SalesBloc bloc;
    try {
      bloc = widget.hostContext.read<SalesBloc>();
    } catch (_) {
      _message('Ventes indisponibles sur cet écran.', erreur: true);
      return;
    }
    final p = _p;
    final rate = p.currencyCode == 'CDF' ? 1.0 : p.exchangeRate;
    final items = [
      for (final l in p.lines) ProformaDocument.saleItemOf(p, l, rate),
    ];
    final nav = Navigator.of(widget.hostContext);
    Navigator.of(context).pop();
    nav.push(MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: AddSaleScreen(
          initialCustomerId: p.customerId,
          initialCustomerName: p.customerName,
          initialItems: items,
          initialCurrencyCode: p.currencyCode,
          initialNotes: 'Issue de la facture proforma ${p.displayNumber}',
          onSaleCreated: (sale) =>
              ProformaRepository().markConverted(p, saleId: sale.id),
        ),
      ),
    ));
  }

  String get _libelleConvertir => switch (_p.sourceType) {
        ProformaSource.reservation => 'Confirmer la réservation',
        ProformaSource.restaurantOrder => 'Encaisser la commande',
        _ => 'Convertir en facture',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = _p;
    final fmt = DateFormat('dd/MM/yyyy');
    final convertible = p.isOpen &&
        (p.sourceType != ProformaSource.restaurantOrder ||
            widget.onCheckoutOrder != null);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(p.displayNumber,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              if (p.isProvisional)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.cloud_off, size: 16),
                  label: const Text('Numéro provisoire'),
                  backgroundColor: theme.colorScheme.tertiaryContainer,
                ),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(p.statusLabel),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (p.customerName != null) Text(p.customerName!),
          if (p.contactName != null)
            Text("À l'attention de ${p.contactName}",
                style: theme.textTheme.bodySmall),
          Text(
            'Émise le ${fmt.format(p.issuedAt)}'
            '${p.validUntil != null ? ", valable jusqu'au ${fmt.format(p.validUntil!)}" : ''}',
            style: theme.textTheme.bodySmall,
          ),
          const Divider(height: 24),
          for (final l in p.lines.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${l.label}${l.quantity != 1 ? ' x ${l.quantityLabel}' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(formatCurrency(
                      p.currencyCode == 'CDF' || p.exchangeRate <= 0
                          ? l.totalCdf
                          : l.totalCdf / p.exchangeRate,
                      p.currencyCode)),
                ],
              ),
            ),
          if (p.lines.length > 8)
            Text('et ${p.lines.length - 8} autre(s) ligne(s)',
                style: theme.textTheme.bodySmall),
          const Divider(height: 24),
          Row(
            children: [
              const Expanded(child: Text('Total')),
              Text(formatCurrency(p.totalInCurrency, p.currencyCode),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Document sans écriture comptable ni mouvement de stock : seule la "
            'facture issue de sa conversion compte.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _imprimer,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Imprimer'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _partager,
                icon: const Icon(Icons.share_outlined),
                label: const Text('Partager le PDF'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _whatsapp,
                icon: const Icon(Icons.chat_outlined),
                label: const Text('WhatsApp'),
              ),
              if (p.isOpen)
                TextButton.icon(
                  onPressed: _busy ? null : _annuler,
                  icon: const Icon(Icons.block),
                  label: const Text('Annuler'),
                ),
            ],
          ),
          if (convertible) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _convertir,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(_libelleConvertir),
            ),
          ],
        ],
      ),
    );
  }
}

/// Liste des proformas, en onglets (en cours, converties, annulées). Les
/// proformas restées sur l'appareil partent au serveur à l'ouverture.
class ProformaListScreen extends StatefulWidget {
  const ProformaListScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const ProformaListScreen()));

  @override
  State<ProformaListScreen> createState() => _ProformaListScreenState();
}

class _ProformaListScreenState extends State<ProformaListScreen> {
  final _repo = ProformaRepository();
  List<Proforma> _all = const [];
  bool _loading = true;

  /// Pagination locale par onglet (cle = message d'etat vide de l'onglet).
  final Map<String, int> _visible = {};

  @override
  void initState() {
    super.initState();
    ProformaRepository.changes.addListener(_relire);
    _charger();
  }

  @override
  void dispose() {
    ProformaRepository.changes.removeListener(_relire);
    super.dispose();
  }

  Future<void> _relire() async {
    final l = await _repo.local();
    if (mounted) setState(() => _all = l);
  }

  Future<void> _charger() async {
    final l = await _repo.local();
    if (mounted) setState(() => _all = l);
    final r = await _repo.refresh();
    if (mounted) {
      setState(() {
        _all = r;
        _loading = false;
      });
    }
  }

  Widget _liste(List<Proforma> items, String vide) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(vide, textAlign: TextAlign.center),
        ),
      );
    }
    final fmt = DateFormat('dd/MM/yyyy');
    final visibles = visibleSlice(items, _visible[vide] ?? kShowMoreStep);
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: visibles.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          if (i == visibles.length) {
            return ShowMoreFooter(
              shown: visibles.length,
              total: items.length,
              onMore: () => setState(() => _visible[vide] =
                  nextVisibleCount(visibles.length, items.length)),
            );
          }
          final p = visibles[i];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(p.isProvisional
                  ? Icons.cloud_off
                  : Icons.request_quote_outlined),
              title: Text(
                  '${p.displayNumber}${p.isProvisional ? ' (provisoire)' : ''}'),
              subtitle: Text(
                  '${p.customerName ?? 'Client'}, ${fmt.format(p.issuedAt)}, ${p.statusLabel}'),
              trailing: Text(formatCurrency(p.totalInCurrency, p.currencyCode)),
              onTap: () => showProformaSheet(context, p),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enCours = _all.where((p) => p.isOpen).toList();
    final converties =
        _all.where((p) => p.status == ProformaStatus.converted).toList();
    final annulees =
        _all.where((p) => p.status == ProformaStatus.cancelled).toList();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Factures proforma'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'En cours (${enCours.length})'),
              Tab(text: 'Converties (${converties.length})'),
              Tab(text: 'Annulées (${annulees.length})'),
            ],
          ),
          actions: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        ),
        body: TabBarView(
          children: [
            _liste(enCours,
                'Aucune proforma en cours. Émettez-en une depuis une vente, une commande ou une réservation.'),
            _liste(converties, 'Aucune proforma convertie.'),
            _liste(annulees, 'Aucune proforma annulée.'),
          ],
        ),
      ),
    );
  }
}
