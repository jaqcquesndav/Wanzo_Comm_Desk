import 'package:flutter/material.dart';

import '../../customer/widgets/customer_picker_field.dart';
import '../cubit/restaurant_orders_cubit.dart';
import '../models/restaurant_order.dart';

/// Ouverture d'une commande, parcours unique du desktop (caisse, board, plan
/// de salle) aligné sur le mobile :
///  - « Sur place » : un libellé de table ou de nom (« Table 4 ») ;
///  - « À emporter » : le libellé EST le client. On propose les fiches
///    existantes ([CustomerPickerField], création en ligne possible) ; la
///    saisie libre reste permise pour un client de passage.
///
/// Un client choisi est rattaché à la commande (`customerId`) : la vente aura
/// son vrai client (historique, créance), au lieu d'un nom sans fiche.
///
/// Renvoie la commande ouverte, ou `null` si l'utilisateur annule.
Future<RestaurantOrder?> showNewRestaurantOrderDialog(
  BuildContext context,
  RestaurantOrdersCubit cubit, {
  RestaurantOrderType initialType = RestaurantOrderType.dineIn,
}) async {
  final result = await showDialog<_NewOrderResult>(
    context: context,
    builder: (_) => _NewOrderDialog(initialType: initialType),
  );
  if (result == null) return null;
  return cubit.openOrder(
    result.label,
    type: result.type,
    customerId: result.customerId,
    customerName: result.customerName,
  );
}

class _NewOrderResult {
  final String label;
  final RestaurantOrderType type;
  final String? customerId;
  final String? customerName;
  const _NewOrderResult(this.label, this.type, this.customerId, this.customerName);
}

class _NewOrderDialog extends StatefulWidget {
  final RestaurantOrderType initialType;
  const _NewOrderDialog({required this.initialType});

  @override
  State<_NewOrderDialog> createState() => _NewOrderDialogState();
}

class _NewOrderDialogState extends State<_NewOrderDialog> {
  late RestaurantOrderType _type = widget.initialType;
  final _controller = TextEditingController();
  String? _customerId;
  String? _customerName;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _valider() {
    final saisi = _controller.text.trim();
    // Libellé vide : « Emporter » à emporter, sinon le cubit met « Sans nom ».
    final label = saisi.isNotEmpty
        ? saisi
        : (_type == RestaurantOrderType.takeaway ? 'Emporter' : '');
    final takeaway = _type == RestaurantOrderType.takeaway;
    Navigator.of(context).pop(_NewOrderResult(
      label,
      _type,
      takeaway ? _customerId : null,
      takeaway ? _customerName : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Nouvelle commande')),
          IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<RestaurantOrderType>(
              segments: const [
                ButtonSegment(
                  value: RestaurantOrderType.dineIn,
                  icon: Icon(Icons.restaurant),
                  label: Text('Sur place'),
                ),
                ButtonSegment(
                  value: RestaurantOrderType.takeaway,
                  icon: Icon(Icons.takeout_dining),
                  label: Text('À emporter'),
                ),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            if (_type == RestaurantOrderType.takeaway)
              CustomerPickerField(
                controller: _controller,
                label: 'Client',
                hint: 'Client enregistré ou client de passage',
                onSelected: (c) => setState(() {
                  _customerId = c?.id;
                  _customerName = c?.name;
                }),
              )
            else
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Libellé (Table 4, nom…)',
                ),
                onSubmitted: (_) => _valider(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _valider,
          child: const Text('Ouvrir'),
        ),
      ],
    );
  }
}
