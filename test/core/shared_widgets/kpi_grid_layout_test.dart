import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wanzo/core/shared_widgets/kpi_board.dart';
import 'package:wanzo/core/shared_widgets/kpi_grid.dart';

/// Grille des six vignettes, telle que la posent les modes métier
/// (restaurant, salon) : libellés longs, écart sur le chiffre d'affaires,
/// vignettes cliquables. Elle doit tenir partout, portrait comme paysage,
/// police normale comme agrandie : un débordement lève une erreur de rendu.
void main() {
  final tuiles = <KpiTile>[
    const KpiTile(
      icon: Icons.payments,
      color: Color(0xFF16A34A),
      label: 'CA du jour (CDF)',
      value: '12 345 678,00 FC',
      secondary: '7 derniers jours',
      trend: [3, 5, 4, 8, 6, 9, 12],
    ),
    const KpiTile(
      icon: Icons.payments,
      color: Color(0xFF16A34A),
      label: 'CA du jour (USD)',
      value: '1 234,00 \$',
      secondary: 'Encaissé en dollars',
    ),
    KpiTile(
      icon: Icons.room_service,
      color: const Color(0xFF0EA5E9),
      label: 'En service',
      value: '14',
      secondary: 'Commandes ouvertes en salle',
      onTap: () {},
    ),
    const KpiTile(
      icon: Icons.soup_kitchen,
      color: Color(0xFFF59E0B),
      label: 'En cuisine',
      value: '6',
      secondary: 'En préparation',
    ),
    const KpiTile(
      icon: Icons.receipt_long,
      color: Color(0xFF64748B),
      label: 'Réglées (jour)',
      value: '42',
      secondary: 'Commandes encaissées',
    ),
    const KpiTile(
      icon: Icons.timer_outlined,
      color: Color(0xFF8B5CF6),
      label: 'Temps service moyen de la journée',
      value: 'Non mesuré',
      secondary: 'De la commande au service',
    ),
  ];

  const appareils = <String, Size>{
    'portrait 320dp': Size(320, 568),
    'portrait 360dp': Size(360, 740),
    'paysage telephone': Size(740, 360),
    'tablette portrait': Size(800, 1280),
    'terminal POS': Size(1024, 600),
    'desktop large': Size(1920, 1080),
  };

  for (final entry in appareils.entries) {
    for (final police in [1.0, 1.3, 2.0]) {
      testWidgets('mode métier, ${entry.key}, police x$police',
          (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: entry.value,
              textScaler: TextScaler.linear(police),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: KpiGrid(tiles: tuiles),
              ),
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
        expect(find.byType(Card), findsNWidgets(6));
        // L'écart du chiffre d'affaires reste visible sur la vignette.
        expect(find.text('33%'), findsOneWidget);
      });
    }
  }

  test('six vignettes forment toujours des rangées pleines', () {
    for (final w in [288.0, 328.0, 500.0, 708.0, 992.0, 1888.0]) {
      for (final o in Orientation.values) {
        final c = KpiGrid.columnsFor(w, o, 6);
        expect(6 % c, 0, reason: 'largeur $w, $o : $c colonnes');
      }
    }
  });
}
