import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:wanzo/core/utils/currency_formatter.dart';

import '../../sales/bloc/sales_bloc.dart';
import '../../sales/models/sale_item.dart';
import '../../sales/screens/add_sale_screen.dart';
import '../cubit/restaurant_orders_cubit.dart';
import '../models/restaurant_order.dart';

/// Ouvre la facturation UNIFIÉE ([AddSaleScreen]) pré-remplie avec les lignes de
/// la commande restaurant — MÊME page que la boutique et l'atelier (ticket de
/// caisse, facture et journal des opérations en découlent) plutôt qu'une caisse
/// « maison ». À la création de la vente, la commande est marquée réglée
/// (mécanisme identique à l'ancienne caisse : [RestaurantOrdersCubit.markPaid]).
Future<void> openRestaurantInvoice(
  BuildContext context,
  RestaurantOrdersCubit cubit,
  RestaurantOrder order,
) {
  final salesBloc = context.read<SalesBloc>();
  final items = [
    for (final l in order.lines)
      SaleItem.withCalculatedTotal(
        // L'id est celui d'un plat de la carte (MenuItem), PAS d'un produit du
        // stock → article de service : pas de décrément de stock côté backend.
        productId: l.productId,
        productName: l.productName,
        quantity: l.quantity,
        unitPrice: l.unitPriceCdf,
        currencyCode: 'CDF',
        exchangeRate: 1.0,
        itemType: SaleItemType.service,
        notes: l.note,
      ),
  ];
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: salesBloc,
        child: AddSaleScreen(
          initialCustomerName: order.label,
          initialItems: items,
          // Défaut « espèces » : paiement intégral pré-rempli (la caisse le
          // faisait aussi) ; l'utilisateur peut ajuster / changer la devise.
          initialPaidAmount: order.totalCdf,
          initialCurrencyCode: 'CDF',
          initialNotes: 'Commande restaurant « ${order.label} »',
          onSaleCreated: (_) => cubit.markPaid(order.id),
        ),
      ),
    ),
  );
}

/// Aperçu rapide d'une COMMANDE restaurant, en pull-up d'actions (façon atelier,
/// cf. `AtelierOrdersBoardScreen._showActions`).
///
/// Ouvert en tapant une carte de commande (board Kanban) ou une table occupée
/// (plan de salle), il RESTE au-dessus de l'app (le fond reste visible) : on ne
/// quitte donc pas l'écran courant pour consulter/agir sur une commande. Sur ce
/// desktop, c'est un `Dialog` centré et compact (branche « large » de l'atelier).
///
/// Actions proposées (commande active) :
///  • « Ouvrir la commande » → caisse ([RestaurantPosScreen]) en prise de
///    commande (ajout de plats depuis la carte) ;
///  • « Envoyer en cuisine » (statut `open` uniquement) ;
///  • « Encaisser » → ouvre la facturation UNIFIÉE ([AddSaleScreen], même page
///    que la boutique et l'atelier) pré-remplie avec les lignes de la commande,
///    puis marque la commande réglée à la création de la vente ;
///  • « Modifier le libellé » (renomme la table / le client) ;
///  • « Annuler la commande ».
/// Commande terminée (réglée / annulée) : « Supprimer de la liste ».
///
/// La caisse ([RestaurantPosScreen], route `/restaurant/orders`) sélectionne la
/// commande via le query param `orderId` : « Ouvrir » et « Encaisser » y mènent
/// tous deux (l'écran réunit menu + ticket + règlement), l'intention diffère.
void showRestaurantOrderQuickView(
  BuildContext context,
  RestaurantOrdersCubit cubit,
  RestaurantOrder order,
) {
  final isWide = MediaQuery.sizeOf(context).width >= 720;

  // Ouvre la caisse pré-sélectionnée sur la commande (prise de commande OU
  // règlement : c'est le même écran, la colonne de caisse y est intégrée).
  void openPos() => context.push('/restaurant/orders?orderId=${order.id}');

  List<Widget> actions(BuildContext ctx) => [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(order.label, style: Theme.of(ctx).textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${order.itemCount} article(s) · ${order.status.label}\n'
            'Total ${formatCurrency(order.totalCdf, 'CDF')}',
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
        ),
        const Divider(),
        if (order.status.isActive) ...[
          ListTile(
            leading: const Icon(Icons.restaurant_menu),
            title: const Text('Ouvrir la commande'),
            subtitle: const Text('Ajouter des plats depuis la carte'),
            onTap: () {
              Navigator.pop(ctx);
              openPos();
            },
          ),
          if (order.status == RestaurantOrderStatus.open)
            ListTile(
              leading: const Icon(Icons.send),
              title: const Text('Envoyer en cuisine'),
              onTap: order.isEmpty
                  ? null
                  : () {
                      cubit.updateStatus(order.id, RestaurantOrderStatus.sent);
                      Navigator.pop(ctx);
                    },
            ),
          ListTile(
            leading: Icon(Icons.point_of_sale, color: _accent[order.status]),
            title: const Text('Encaisser'),
            subtitle: const Text('Facturation unifiée (ticket + facture)'),
            onTap: order.isEmpty
                ? null
                : () {
                    Navigator.pop(ctx);
                    openRestaurantInvoice(context, cubit, order);
                  },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Modifier le libellé'),
            onTap: () {
              Navigator.pop(ctx);
              _promptRename(context, cubit, order);
            },
          ),
          ListTile(
            leading:
                Icon(Icons.cancel_outlined, color: Theme.of(ctx).colorScheme.error),
            title: const Text('Annuler la commande'),
            onTap: () {
              cubit.cancel(order.id);
              Navigator.pop(ctx);
            },
          ),
        ] else
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Supprimer de la liste'),
            onTap: () {
              cubit.deleteOrder(order.id);
              Navigator.pop(ctx);
            },
          ),
      ];

  if (isWide) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: actions(ctx),
              ),
            ),
          ),
        ),
      ),
    );
  } else {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: actions(ctx),
        ),
      ),
    );
  }
}

/// Renomme le libellé de la commande (table / client) via une saisie compacte.
Future<void> _promptRename(
  BuildContext context,
  RestaurantOrdersCubit cubit,
  RestaurantOrder order,
) async {
  final controller = TextEditingController(text: order.label);
  final label = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Modifier le libellé'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Libellé (Table 4, Emporter, nom du client…)',
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
  if (label != null) {
    await cubit.renameOrder(order.id, label);
  }
}

/// Accents de statut (cohérents avec le board / le plan de salle).
const _accent = <RestaurantOrderStatus, Color>{
  RestaurantOrderStatus.open: Color(0xFF64748B),
  RestaurantOrderStatus.sent: Color(0xFFF59E0B),
  RestaurantOrderStatus.served: Color(0xFF0EA5E9),
  RestaurantOrderStatus.paid: Color(0xFF16A34A),
  RestaurantOrderStatus.cancelled: Color(0xFFDC2626),
};
