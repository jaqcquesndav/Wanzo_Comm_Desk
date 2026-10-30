import 'package:flutter/material.dart';

import '../../sales/models/sale.dart';
import '../cash_access.dart';
import '../cash_session_hooks.dart';
import '../services/cash_reentry_flags.dart';

/// Bandeau d'une vente rétablie dont l'encaissement en espèces n'est dans
/// aucune caisse : « Encaissement à reprendre en caisse », avec l'action
/// qui le reprend dans la caisse ouverte.
class CashReentryBanner extends StatefulWidget {
  final Sale sale;

  const CashReentryBanner({super.key, required this.sale});

  @override
  State<CashReentryBanner> createState() => _CashReentryBannerState();
}

class _CashReentryBannerState extends State<CashReentryBanner> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    CashReentryFlags.instance.load();
  }

  Future<void> _reprendre() async {
    setState(() => _busy = true);
    final ok = await cashSessionOnSaleRestored(widget.sale);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Encaissement repris dans la caisse.'
              : 'Aucune caisse ouverte : ouvrez la caisse puis réessayez.',
        ),
        backgroundColor: ok ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: CashReentryFlags.instance.flagged,
      builder: (context, flagged, _) {
        if (widget.sale.isCancelled || !flagged.contains(widget.sale.id)) {
          return const SizedBox.shrink();
        }
        final scheme = Theme.of(context).colorScheme;
        return Container(
          key: const ValueKey('cash-reentry-banner'),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.point_of_sale, color: scheme.onTertiaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Encaissement à reprendre en caisse',
                  style: TextStyle(
                    color: scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (canSeeCash(context))
                TextButton(
                  onPressed: _busy ? null : _reprendre,
                  child: const Text('Reprendre'),
                ),
            ],
          ),
        );
      },
    );
  }
}
