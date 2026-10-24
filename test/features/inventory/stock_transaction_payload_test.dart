import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/inventory/models/stock_transaction.dart';
import 'package:wanzo/features/inventory/services/inventory_api_service.dart';

/// Corps envoyé à `POST stock-transactions` : uniquement les champs de la
/// liste blanche du serveur, avec le sens porté par le type.
void main() {
  StockTransaction mouvement(StockTransactionType type, double quantite) =>
      StockTransaction(
        id: 'local-1',
        productId: 'p1',
        type: type,
        quantity: quantite,
        date: DateTime.utc(2026, 10, 15, 8),
        referenceId: 'dep-1',
        notes: 'Réapprovisionnement',
        unitCostInCdf: 2500,
        totalValueInCdf: 25000,
        currencyCode: 'CDF',
        companyId: 'c1',
        businessUnitId: 'bu1',
      );

  const champsAutorises = {
    'localId',
    'productId',
    'type',
    'quantity',
    'date',
    'referenceId',
    'notes',
    'unitCostPrice',
    'locationId',
    'expenseId',
  };

  test('achat rattaché à sa dépense, champs de la liste blanche seulement', () {
    final corps = InventoryApiServiceImpl.stockTransactionPayload(
      mouvement(StockTransactionType.purchase, 10),
      expenseId: 'exp-1',
    );
    expect(champsAutorises.containsAll(corps.keys), isTrue, reason: '$corps');
    expect(corps['type'], 'purchase');
    expect(corps['quantity'], 10);
    expect(corps['unitCostPrice'], 2500);
    expect(corps['expenseId'], 'exp-1');
    // Identifiant de l'appareil : dédupliqué par le serveur au rejeu.
    expect(corps['localId'], 'local-1');
    expect(corps['date'], '2026-10-15T08:00:00.000Z');
  });

  test('perte : quantité envoyée positive, le type porte la sortie', () {
    final corps = InventoryApiServiceImpl.stockTransactionPayload(
      mouvement(StockTransactionType.lost, -3),
    );
    expect(corps['type'], 'lost');
    expect(corps['quantity'], 3);
    expect(corps.containsKey('expenseId'), isFalse);
  });

  test('ajustement : le signe est gardé (négatif = retrait)', () {
    final corps = InventoryApiServiceImpl.stockTransactionPayload(
      mouvement(StockTransactionType.adjustment, -2),
    );
    expect(corps['type'], 'adjustment');
    expect(corps['quantity'], -2);
  });
}
