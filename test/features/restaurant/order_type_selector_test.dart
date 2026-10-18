import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/restaurant/models/restaurant_order.dart';
import 'package:wanzo/features/restaurant/widgets/new_order_dialog.dart';

/// Sélecteur de nature de commande et onglets Chambres / Salles sur un
/// téléphone de 320 dp : rien ne déborde, le choix reste lisible.
void main() {
  Future<void> pump(WidgetTester tester, Widget child, {double width = 320}) async {
    tester.view.physicalSize = Size(width, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          // Marges d'un dialogue (16 + 24 de chaque côté).
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(children: [child]),
        ),
      ),
    ));
  }

  testWidgets('320 dp : trois natures en icônes, libellé court dessous',
      (tester) async {
    var choix = RestaurantOrderType.dineIn;
    await pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => OrderTypeSelector(
          types: RestaurantOrderType.values,
          selected: choix,
          onChanged: (t) => setState(() => choix = t),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Sur place'), findsOneWidget); // libellé court sous le sélecteur
    expect(find.byIcon(Icons.event_available), findsOneWidget);
    await tester.tap(find.byIcon(Icons.event_available));
    await tester.pump();
    expect(choix, RestaurantOrderType.reservation);
    expect(find.text('Réservation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('écran large : libellés complets dans les segments', (tester) async {
    await pump(
      tester,
      OrderTypeSelector(
        types: RestaurantOrderType.values,
        selected: RestaurantOrderType.takeaway,
        onChanged: (_) {},
      ),
      width: 800,
    );
    expect(find.text('À emporter'), findsOneWidget);
    expect(find.text('Réservation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 dp : onglets Chambres et Salles sans débordement',
      (tester) async {
    await pump(
      tester,
      ReservationKindTabs(
        selected: ReservationSpaceKind.room,
        rooms: 12,
        halls: 3,
        onChanged: (_) {},
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });
}
