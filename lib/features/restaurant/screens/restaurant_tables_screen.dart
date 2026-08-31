import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:wanzo/core/modules/module_registry.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/shared_widgets/empty_state_view.dart';
import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/widgets/smart_image.dart';
import 'package:wanzo/features/settings/models/settings.dart';
import 'package:wanzo/features/settings/repositories/settings_repository.dart';

import '../services/restaurant_api_service.dart';

/// Gestion des TABLES du restaurant : chaque table porte un QR public (menu +
/// commande en ligne). On liste, crée et supprime les tables ; pour chacune on
/// ouvre une vue QR (à afficher/imprimer sur la table). Les données viennent du
/// backend (module restaurant) — l'URL du QR est SIGNÉE côté serveur.
///
/// Version DESKTOP : la liste des tables est un [DataTable] (création par
/// dialog, suppression en ligne) ; « Voir le QR » ouvre la vue QR comme un
/// Dialog CENTRÉ (pas une page poussée façon mobile), avec export PDF et
/// impression directe (Printing).
class RestaurantTablesScreen extends StatefulWidget {
  const RestaurantTablesScreen({super.key});

  @override
  State<RestaurantTablesScreen> createState() => _RestaurantTablesScreenState();
}

class _RestaurantTablesScreenState extends State<RestaurantTablesScreen> {
  final RestaurantApiService _api = RestaurantApiService();
  List<RestaurantTable> _tables = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tables = await _api.getTables();
      if (!mounted) return;
      setState(() {
        _tables = tables;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            'Impossible de charger les tables. Vérifiez votre connexion.';
        _loading = false;
      });
    }
  }

  Future<void> _createTable() async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle table'),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Libellé (ex. Table 1, Terrasse A)',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (label == null || label.isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.createTable(label);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Table « $label » créée.'),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Création impossible. Vérifiez votre connexion.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _deleteTable(RestaurantTable table) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la table'),
        content: Text('Supprimer « ${table.label} » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.deleteTable(table.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Table supprimée.')),
      );
      await _load();
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Suppression impossible. Vérifiez votre connexion.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Ouvre la vue QR de la table en DIALOG CENTRÉ (convention desktop de
  /// l'app), et non en page poussée comme sur mobile.
  void _openQr(RestaurantTable table) {
    showDialog<void>(
      context: context,
      builder: (_) => _TableQrDialog(api: _api, table: table),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Conserve le shell de l'app (sidebar + header) : c'est un écran de nav
    // principal (« Tables » dans la sidebar), pas une page poussée. Même
    // approche que la cuisine / le board restaurant.
    final ctx = BusinessContextService();
    final index = ModuleRegistry.indexOfSidebarRoute(
      ctx.activityMode,
      ctx.currentContext?.userRole,
      '/restaurant/tables',
    );
    return WanzoScaffold(
      currentIndex: index < 0 ? 0 : index,
      title: 'Tables & QR',
      appBarActions: [
        IconButton(
          tooltip: 'Rafraîchir',
          icon: const Icon(Icons.refresh),
          onPressed: _loading ? null : _load,
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FilledButton.icon(
            onPressed: _createTable,
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle table'),
          ),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorRetry(message: _error!, onRetry: _load)
              : _tables.isEmpty
                  ? const EmptyStateView(
                      icon: Icons.table_restaurant,
                      message:
                          'Aucune table. Créez-en une pour générer son QR.',
                    )
                  : _buildTable(theme),
    );
  }

  Widget _buildTable(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth - 48),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(
                    theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                  ),
                  columns: const [
                    DataColumn(label: Text('Table')),
                    DataColumn(label: Text('Statut')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    for (final table in _tables)
                      DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.12),
                                  child: Icon(Icons.table_restaurant,
                                      size: 18,
                                      color: theme.colorScheme.primary),
                                ),
                                const SizedBox(width: 12),
                                Text(table.label,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          DataCell(
                            _StatusChip(active: table.active),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _openQr(table),
                                  icon: const Icon(Icons.qr_code_2, size: 20),
                                  label: const Text('Voir le QR'),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: 'Supprimer',
                                  icon: Icon(Icons.delete_outline,
                                      color: theme.colorScheme.error),
                                  onPressed: () => _deleteTable(table),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool active;
  const _StatusChip({required this.active});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active ? Colors.green : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// Vue QR d'une table présentée en DIALOG CENTRÉ (desktop) : récupère le lien
/// public signé, l'affiche en QR avec le nom du restaurant, le logo et le
/// libellé de la table, et propose export PDF / impression directe.
class _TableQrDialog extends StatefulWidget {
  final RestaurantApiService api;
  final RestaurantTable table;
  const _TableQrDialog({required this.api, required this.table});

  @override
  State<_TableQrDialog> createState() => _TableQrDialogState();
}

class _TableQrDialogState extends State<_TableQrDialog> {
  RestaurantTableLink? _link;
  bool _loading = true;
  String? _error;

  String _restaurantName = '';
  String _logo = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadLink();
  }

  Future<void> _loadSettings() async {
    try {
      final Settings settings = await SettingsRepository().getSettings();
      if (!mounted) return;
      setState(() {
        _restaurantName = settings.companyName;
        _logo = settings.companyLogo;
      });
    } catch (_) {
      // Réglages indisponibles : on affiche le QR sans nom/logo.
    }
  }

  Future<void> _loadLink() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final link = await widget.api.getTableLink(widget.table.id);
      if (!mounted) return;
      if (link.url.isEmpty) {
        setState(() {
          _error = 'Lien indisponible pour cette table.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _link = link;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            'Impossible d\'obtenir le lien du QR. Ce lien est généré par le '
            'serveur : connectez-vous à Internet puis réessayez.';
        _loading = false;
      });
    }
  }

  String get _title =>
      _restaurantName.isNotEmpty ? _restaurantName : 'Notre restaurant';

  Future<pw.Document> _buildPdf(String url) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(18),
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                _title,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Scannez pour voir le menu & commander',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 16),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: url,
                width: 180,
                height: 180,
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  widget.table.label,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return doc;
  }

  Future<void> _exportPdf() async {
    final url = _link?.url;
    if (url == null || url.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final doc = await _buildPdf(url);
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename:
            'qr-${_title.replaceAll(' ', '_')}-${widget.table.label.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Échec de l\'export PDF : $e')),
      );
    }
  }

  Future<void> _print() async {
    final url = _link?.url;
    if (url == null || url.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final doc = await _buildPdf(url);
      await Printing.layoutPdf(onLayout: (format) async => doc.save());
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Impression impossible : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLogo = SmartImage.hasImage(imageUrl: _logo, imagePath: _logo);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'QR — ${widget.table.label}',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: _ErrorRetry(
                              message: _error!, onRetry: _loadLink),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              if (hasLogo) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SmartImage(
                                    imageUrl: _logo,
                                    imagePath: _logo,
                                    width: 64,
                                    height: 64,
                                    placeholderIcon: Icons.storefront,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Text(
                                _title,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Scannez pour voir le menu & commander',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                color: Colors.white,
                                padding: const EdgeInsets.all(12),
                                child: QrImageView(
                                  data: _link!.url,
                                  version: QrVersions.auto,
                                  size: 240,
                                  gapless: false,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  widget.table.label,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
            if (!_loading && _error == null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exportPdf,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Exporter en PDF'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _print,
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Imprimer'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Petit bloc d'erreur + bouton « Réessayer » (utilisé pour l'offline).
class _ErrorRetry extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
