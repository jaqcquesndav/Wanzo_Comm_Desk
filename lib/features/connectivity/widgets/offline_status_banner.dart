import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/services/api_client.dart';
import '../../../core/services/offline_write_queue.dart';
import '../../../core/utils/connectivity_service.dart';

/// Bandeau d'état hors ligne, commun à tous les écrans.
///
/// - Hors ligne : dit que l'application continue sur les dernières données
///   connues et que les saisies partiront au retour du réseau.
/// - En ligne avec des saisies encore en file (refus temporaire du serveur,
///   session à renouveler) : les signale et permet de relancer l'envoi.
///
/// Rien n'est affiché en ligne quand la file est vide.
class OfflineStatusBanner extends StatelessWidget {
  final Widget child;

  /// Sources injectables (tests). Par défaut : services de l'application.
  final ValueListenable<bool>? connectionStatus;
  final ValueListenable<int>? pendingWrites;
  final Future<void> Function()? onRetry;

  const OfflineStatusBanner({
    super.key,
    required this.child,
    this.connectionStatus,
    this.pendingWrites,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final connection =
        connectionStatus ?? ConnectivityService().connectionStatus;
    final pending = pendingWrites ?? OfflineWriteQueue.instance.pending;

    return Column(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: connection,
          builder: (context, isOnline, _) => ValueListenableBuilder<int>(
            valueListenable: pending,
            builder: (context, count, _) {
              if (isOnline && count == 0) return const SizedBox.shrink();
              return _Banner(
                isOnline: isOnline,
                pendingCount: count,
                onRetry: onRetry ?? _defaultRetry,
              );
            },
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  static Future<void> _defaultRetry() async {
    await ApiClient().replayPendingWrites();
  }
}

class _Banner extends StatefulWidget {
  final bool isOnline;
  final int pendingCount;
  final Future<void> Function() onRetry;

  const _Banner({
    required this.isOnline,
    required this.pendingCount,
    required this.onRetry,
  });

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> {
  bool _sending = false;

  Future<void> _retry() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await widget.onRetry();
    } catch (_) {
      // Les écritures restent en file : le bandeau reste affiché.
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = widget.pendingCount;
    final enAttente = count == 1
        ? '1 saisie en attente d\'envoi'
        : '$count saisies en attente d\'envoi';

    final String message;
    final Color background;
    final IconData icon;
    if (!widget.isOnline) {
      message = count > 0
          ? 'Hors ligne. Dernières données connues affichées, $enAttente : '
                'elles partiront au retour du réseau.'
          : 'Hors ligne. Dernières données connues affichées, vos saisies '
                'partiront au retour du réseau.';
      background = Colors.orange.shade800;
      icon = Icons.cloud_off_outlined;
    } else {
      message = '$enAttente.';
      background = theme.colorScheme.primary;
      icon = Icons.cloud_upload_outlined;
    }

    return Material(
      color: background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              if (widget.isOnline && count > 0)
                _sending
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : TextButton(
                        onPressed: _retry,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Envoyer'),
                      ),
            ],
          ),
        ),
      ),
    );
  }
}
