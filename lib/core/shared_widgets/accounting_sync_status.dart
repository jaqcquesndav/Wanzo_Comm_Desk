import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// Devenir comptable d'une opération (vente, dépense, règlement, OF...) tel que
/// le backend le suit dans sa boîte d'envoi : publication vers Adha, écritures
/// proposées, validation par le comptable, rejet, attente de jetons.
///
/// Discret par construction : rien n'est affiché tant que le statut n'est pas
/// connu (hors ligne, opération ancienne non suivie, API indisponible). Les
/// libellés parlent au commerçant, pas à la technique.
class AccountingSyncStatusCard extends StatefulWidget {
  /// Identifiant de l'opération côté serveur (id de vente, référence d'OF...).
  final String sourceId;

  /// Route de statut : `accounting-sync` (gestion) ou `production-accounting-sync`.
  final String endpointBase;

  /// Marge extérieure basse (pour s'insérer dans une colonne existante).
  final double bottomSpacing;

  const AccountingSyncStatusCard({
    super.key,
    required this.sourceId,
    this.endpointBase = 'accounting-sync',
    this.bottomSpacing = 12,
  });

  @override
  State<AccountingSyncStatusCard> createState() => _AccountingSyncStatusCardState();
}

class _AccountingSyncStatusCardState extends State<AccountingSyncStatusCard> {
  final ApiClient _api = ApiClient();
  Map<String, dynamic>? _status;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AccountingSyncStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceId != widget.sourceId) _load();
  }

  Future<void> _load() async {
    if (widget.sourceId.isEmpty) return;
    try {
      final res = await _api.get(
        '${widget.endpointBase}/status',
        queryParameters: {'sourceIds': widget.sourceId},
        requiresAuth: true,
      );
      final list = res is Map && res['data'] is List
          ? res['data'] as List
          : (res is List ? res : const []);
      if (!mounted) return;
      setState(() {
        _status = list.isNotEmpty && list.first is Map
            ? Map<String, dynamic>.from(list.first as Map)
            : null;
      });
    } catch (_) {
      // Hors ligne ou API indisponible : on n'affiche rien plutôt qu'une erreur.
      if (mounted) setState(() => _status = null);
    }
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      await _api.post(
        '${widget.endpointBase}/${widget.sourceId}/retry',
        body: const <String, dynamic>{},
        requiresAuth: true,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nouvelle tentative de comptabilisation lancée')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Relance impossible pour le moment : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final view = _AccountingStatusView.of(status, theme);

    final detail = status['detail'];
    final adha = detail is Map ? detail['adha'] : null;
    final upgradeUrl = adha is Map ? adha['upgradeUrl'] : null;
    final lastError = detail is Map ? detail['lastError'] : status['lastError'];

    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomSpacing),
      child: Material(
        color: view.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(view.icon, size: 20, color: view.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      view.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: view.color,
                      ),
                    ),
                    if (view.hint != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        view.hint!,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      ),
                    ],
                    if (view.showError && lastError is String && lastError.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        lastError,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      ),
                    ],
                    if (upgradeUrl is String && upgradeUrl.isNotEmpty && view.key == 'deferred') ...[
                      const SizedBox(height: 2),
                      Text(
                        upgradeUrl,
                        style: theme.textTheme.bodySmall?.copyWith(color: view.color),
                      ),
                    ],
                  ],
                ),
              ),
              if (view.canRetry)
                _retrying
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        tooltip: 'Relancer la comptabilisation',
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: _retry,
                      ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountingStatusView {
  final String key;
  final String title;
  final String? hint;
  final IconData icon;
  final Color color;
  final bool canRetry;
  final bool showError;

  const _AccountingStatusView({
    required this.key,
    required this.title,
    this.hint,
    required this.icon,
    required this.color,
    this.canRetry = false,
    this.showError = false,
  });

  static _AccountingStatusView of(Map<String, dynamic> status, ThemeData theme) {
    final key = (status['accountingStatus'] ?? 'pending').toString();
    final muted = theme.colorScheme.onSurfaceVariant;
    switch (key) {
      case 'validated':
        return _AccountingStatusView(
          key: key,
          title: 'Comptabilisée',
          hint: 'Écritures validées par la comptabilité.',
          icon: Icons.verified_outlined,
          color: Colors.green.shade700,
        );
      case 'journalized':
        return _AccountingStatusView(
          key: key,
          title: 'Écritures proposées',
          hint: 'En attente de validation par le comptable.',
          icon: Icons.fact_check_outlined,
          color: theme.colorScheme.primary,
        );
      case 'deferred':
        return _AccountingStatusView(
          key: key,
          title: 'Comptabilisation en attente de jetons Adha',
          hint: 'Rechargez ou changez de plan dans Wanzo Land, la comptabilisation reprendra seule.',
          icon: Icons.hourglass_bottom_outlined,
          color: Colors.orange.shade800,
        );
      case 'rejected':
        return _AccountingStatusView(
          key: key,
          title: 'Écriture rejetée par la comptabilité',
          hint: 'Corrigez la cause côté comptabilité puis relancez.',
          icon: Icons.error_outline,
          color: Colors.red.shade700,
          canRetry: true,
          showError: true,
        );
      case 'failed':
        return _AccountingStatusView(
          key: key,
          title: 'Comptabilisation en échec technique',
          hint: 'Vous pouvez relancer. Si cela persiste, contactez le support.',
          icon: Icons.warning_amber_outlined,
          color: Colors.red.shade700,
          canRetry: true,
          showError: true,
        );
      case 'sent':
        return _AccountingStatusView(
          key: key,
          title: 'Écritures en cours de génération',
          hint: 'Adha prépare les écritures comptables.',
          icon: Icons.sync_outlined,
          color: muted,
        );
      default:
        return _AccountingStatusView(
          key: key,
          title: 'Comptabilisation en préparation',
          hint: 'Transmission à la comptabilité en cours.',
          icon: Icons.schedule_outlined,
          color: muted,
        );
    }
  }
}
