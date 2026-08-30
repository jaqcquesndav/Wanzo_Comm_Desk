import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:wanzo/core/modules/activity_mode.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/features/atelier/models/atelier_order.dart';
import 'package:wanzo/features/atelier/screens/atelier_client_profile_screen.dart';
import 'package:wanzo/features/atelier/services/atelier_api_service.dart';

/// Section « Atelier » du détail client : mesures + historique des commandes,
/// accessibles DIRECTEMENT depuis la fiche client (plus besoin d'ouvrir une
/// commande pour retrouver les mesures). N'apparaît qu'en mode atelier et
/// n'expose que ce qui est pertinent au métier.
class CustomerAtelierSection extends StatefulWidget {
  final String customerId;
  final String? customerName;

  const CustomerAtelierSection({
    super.key,
    required this.customerId,
    this.customerName,
  });

  @override
  State<CustomerAtelierSection> createState() => _CustomerAtelierSectionState();
}

class _CustomerAtelierSectionState extends State<CustomerAtelierSection> {
  final _api = AtelierApiService();
  final _dateFmt = DateFormat('dd/MM/yyyy');
  List<AtelierOrder> _orders = const [];
  bool _loading = true;

  bool get _isAtelier =>
      BusinessContextService().activityMode == ActivityMode.atelier;

  @override
  void initState() {
    super.initState();
    if (_isAtelier && widget.customerId.isNotEmpty) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    try {
      final o = await _api.getOrders(customerId: widget.customerId);
      if (mounted) {
        setState(() {
          _orders = o;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Le bouton « Mesures » n'a de sens que pour couture/cordonnerie. On le
  /// masque si toutes les commandes du client relèvent de la maintenance.
  bool get _showMeasurements {
    if (_orders.isEmpty) return true;
    return _orders.any((o) => o.metier.usesMeasurements);
  }

  Future<void> _openMeasurements() async {
    // Métier déduit de l'historique (cordonnerie pur → pointure ; sinon couture).
    final metier = _orders.isNotEmpty &&
            _orders.every((o) => o.metier == AtelierMetier.cordonnerie)
        ? AtelierMetier.cordonnerie
        : (_orders.isNotEmpty &&
                _orders.every((o) => o.metier == AtelierMetier.couture)
            ? AtelierMetier.couture
            : null);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AtelierClientProfileScreen(
          customerId: widget.customerId,
          customerName: widget.customerName,
          metier: metier,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAtelier) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.content_cut, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Atelier',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_showMeasurements)
                  TextButton.icon(
                    onPressed: _openMeasurements,
                    icon: const Icon(Icons.straighten, size: 18),
                    label: const Text('Mesures'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_orders.isEmpty)
              Text('Aucune commande atelier pour ce client.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
            else
              ..._orders.map(_orderTile),
          ],
        ),
      ),
    );
  }

  Widget _orderTile(AtelierOrder o) {
    final money = NumberFormat.decimalPattern('fr');
    final subtitle = [
      o.status.labelFor(o.metier),
      if (o.createdAt != null) _dateFmt.format(o.createdAt!),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            o.metier == AtelierMetier.maintenance
                ? Icons.build_outlined
                : Icons.checkroom,
            size: 18,
            color: Colors.grey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.label,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(subtitle,
                    style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
              ],
            ),
          ),
          Text('${money.format(o.totalAmount)} ${o.currencyCode}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
        ],
      ),
    );
  }
}
