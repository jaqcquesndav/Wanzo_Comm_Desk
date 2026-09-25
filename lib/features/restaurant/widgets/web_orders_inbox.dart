import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';

import '../cubit/restaurant_orders_cubit.dart';
import '../models/restaurant_order.dart';
import '../services/restaurant_api_service.dart';

/// Commandes passées par les CLIENTS depuis le lien de table.
///
/// La page publique proposait « Commander » et répondait « commande envoyée »,
/// mais aucune app ne lisait ces commandes : personne en salle ni en cuisine
/// ne les voyait. Cette boîte les montre en tête du plan de salle et du
/// kanban. Accepter en fait une commande de salle ordinaire (ajoutée à la
/// commande déjà ouverte sur la table s'il y en a une) ; refuser la clôt.
///
/// Rien ne s'affiche tant qu'aucune commande client n'attend.
class WebOrdersInbox extends StatefulWidget {
  const WebOrdersInbox({super.key});

  @override
  State<WebOrdersInbox> createState() => _WebOrdersInboxState();
}

class _WebOrdersInboxState extends State<WebOrdersInbox> {
  final RestaurantApiService _api = RestaurantApiService();
  List<RestaurantWebOrder> _enAttente = const [];
  final Set<String> _enTraitement = {};
  Timer? _minuterie;

  @override
  void initState() {
    super.initState();
    _charger();
    _minuterie = Timer.periodic(const Duration(seconds: 20), (_) => _charger());
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final commandes = await _api.getPendingWebOrders();
      if (!mounted) return;
      setState(() => _enAttente = commandes);
    } catch (_) {
      // Hors ligne : on garde la derniere liste connue.
    }
  }

  Future<void> _accepter(RestaurantWebOrder w) async {
    final cubit = context.read<RestaurantOrdersCubit>();
    final messager = ScaffoldMessenger.of(context);
    setState(() => _enTraitement.add(w.id));
    try {
      // Un autre poste l'a peut-etre deja prise : on verifie juste avant.
      final encore = await _api.getPendingWebOrders();
      if (!encore.any((c) => c.id == w.id)) {
        messager.showSnackBar(const SnackBar(
          content: Text('Commande déjà prise en charge par un autre poste.'),
        ));
        await _charger();
        return;
      }

      final libelle = (w.tableLabel ?? '').trim().isNotEmpty
          ? w.tableLabel!.trim()
          : 'Commande client';
      RestaurantOrder? cible;
      if (w.tableId != null) {
        for (final o in cubit.state.active) {
          if (o.tableId == w.tableId &&
              o.type != RestaurantOrderType.takeaway) {
            cible = o;
            break;
          }
        }
      }
      cible ??= await cubit.openOrder(
        libelle,
        tableId: w.tableId,
        type: w.tableId != null
            ? RestaurantOrderType.dineIn
            : RestaurantOrderType.takeaway,
      );
      for (final l in w.lines) {
        await cubit.addLine(
          cible.id,
          RestaurantOrderLine(
            productId: l.menuItemId,
            productName: l.name,
            unitPriceCdf: l.unitPriceCdf,
            quantity: l.quantity,
            note: l.note,
          ),
        );
      }

      try {
        await _api.updateWebOrderStatus(w.id, 'open');
      } on OfflineQueuedException {
        // Partira au retour du reseau ; la commande de salle existe deja.
      }
      if (!mounted) return;
      setState(() => _enAttente = _enAttente.where((c) => c.id != w.id).toList());
      messager.showSnackBar(SnackBar(
        content: Text('Commande de $libelle prise en charge.'),
      ));
    } catch (e) {
      messager.showSnackBar(SnackBar(
        content: Text('Prise en charge impossible : $e'),
      ));
    } finally {
      if (mounted) setState(() => _enTraitement.remove(w.id));
    }
  }

  Future<void> _refuser(RestaurantWebOrder w) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser la commande'),
        content: Text(
          'Refuser la commande de ${w.tableLabel ?? 'ce client'} '
          '(${w.itemCount} article${w.itemCount > 1 ? 's' : ''}) ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    setState(() => _enTraitement.add(w.id));
    try {
      await _api.updateWebOrderStatus(w.id, 'cancelled');
      if (!mounted) return;
      setState(() => _enAttente = _enAttente.where((c) => c.id != w.id).toList());
    } on OfflineQueuedException {
      if (!mounted) return;
      setState(() => _enAttente = _enAttente.where((c) => c.id != w.id).toList());
    } catch (_) {
      // Echec : la commande reste affichee, on pourra reessayer.
    } finally {
      if (mounted) setState(() => _enTraitement.remove(w.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_enAttente.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_2, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Commandes des clients (${_enAttente.length})',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final w in _enAttente) _ligne(theme, w),
          ],
        ),
      ),
    );
  }

  Widget _ligne(ThemeData theme, RestaurantWebOrder w) {
    final occupe = _enTraitement.contains(w.id);
    final heure =
        '${w.createdAt.hour.toString().padLeft(2, '0')}:${w.createdAt.minute.toString().padLeft(2, '0')}';
    final resume = w.lines
        .map((l) => l.quantity > 1 ? '${l.quantity} × ${l.name}' : l.name)
        .join(', ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${w.tableLabel ?? 'Sans table'}  ·  $heure',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(resume,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall),
                Text(
                  formatCurrency(w.totalCdf, 'CDF'),
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (occupe)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            IconButton(
              tooltip: 'Refuser',
              icon: Icon(Icons.close, color: theme.colorScheme.error),
              onPressed: () => _refuser(w),
            ),
            FilledButton(
              onPressed: () => _accepter(w),
              child: const Text('Accepter'),
            ),
          ],
        ],
      ),
    );
  }
}
