import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/widgets/desktop/desktop_data_table.dart';

void main() {
  testWidgets('un clic sur une ligne appelle onRowTap', (tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    String? ouvert;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesktopDataTable<String>(
            data: const ['Client A', 'Client B'],
            columns: const [DataColumn(label: Text('Nom'))],
            rowBuilder: (item) => DataRow(cells: [DataCell(Text(item))]),
            showSearch: false,
            onRowTap: (item) => ouvert = item,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Client B'));
    await tester.pumpAndSettle();

    expect(ouvert, 'Client B');
    // Pas de colonne de cases à cocher hors mode sélection.
    expect(find.byType(Checkbox), findsNothing);
  });
}
