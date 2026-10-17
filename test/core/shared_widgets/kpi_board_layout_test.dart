import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wanzo/core/shared_widgets/kpi_board.dart';

/// Le tableau d'indicateurs doit tenir sur tous les appareils visés :
/// petit téléphone d'entrée de gamme, téléphone courant, tablette, avec la
/// police système normale comme agrandie. Un débordement lève une erreur de
/// rendu, que `takeException` remonte : le test échoue au moindre pixel.
void main() {
  const appareils = <String, Size>{
    'petit telephone 320dp': Size(320, 568),
    'telephone courant 360dp': Size(360, 740),
    'grand telephone 411dp': Size(411, 914),
    'tablette portrait 800dp': Size(800, 1280),
    'tablette paysage 1280dp': Size(1280, 800),
    // Postes de travail (application desktop).
    'ordinateur portable 1366dp': Size(1366, 768),
    'ecran bureau 1920dp': Size(1920, 1080),
  };
  const echelles = <double>[1.0, 1.15, 1.3, 1.5, 2.0];

  final tuiles = <KpiTile>[
    const KpiTile(
      weight: KpiWeight.pilote,
      icon: Icons.payments,
      color: Color(0xFF16A34A),
      label: 'CA du jour',
      value: '12 345 678,00 FC',
      secondary: 'dont 1 234,00 \$',
      trend: [3, 5, 4, 8, 6, 9, 12],
      trendLabel: '7 derniers jours',
    ),
    const KpiTile(
      weight: KpiWeight.pilote,
      icon: Icons.savings_outlined,
      color: Color(0xFFF59E0B),
      label: 'Commissions du mois',
      value: '987 654,00 FC',
      trendLabel: "À verser à l'équipe",
    ),
    const KpiTile(
      icon: Icons.groups_outlined,
      color: Color(0xFF0EA5E9),
      label: 'Clients servis (jour)',
      value: '42',
    ),
    const KpiTile(
      icon: Icons.content_cut,
      color: Color(0xFF8B5CF6),
      label: 'Prestations',
      value: '18',
    ),
    const KpiTile(
      icon: Icons.badge_outlined,
      color: Color(0xFF197CA8),
      label: 'Coiffeurs',
      value: '6',
    ),
  ];

  for (final appareil in appareils.entries) {
    for (final echelle in echelles) {
      testWidgets('${appareil.key}, police x$echelle : aucun débordement',
          (tester) async {
        tester.view.physicalSize = appareil.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: appareil.value,
                textScaler: TextScaler.linear(echelle),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: KpiBoard(tiles: tuiles),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  }
}
