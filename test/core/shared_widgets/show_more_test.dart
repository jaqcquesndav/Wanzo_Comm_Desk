import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/shared_widgets/show_more.dart';

void main() {
  test('visibleSlice et nextVisibleCount restent bornes au total', () {
    final all = List.generate(120, (i) => i);
    expect(visibleSlice(all, 50).length, 50);
    expect(visibleSlice(all, 500).length, 120);
    expect(nextVisibleCount(50, 120), 100);
    expect(nextVisibleCount(100, 120), 120);
  });

  test('visibleGroups consomme le quota groupe apres groupe', () {
    final grouped = {
      'entrees': List.generate(3, (i) => 'e$i'),
      'plats': List.generate(4, (i) => 'p$i'),
      'desserts': List.generate(2, (i) => 'd$i'),
    };
    final out = visibleGroups(['entrees', 'plats', 'desserts'], grouped, 5);
    expect(out.map((e) => e.key), ['entrees', 'plats']);
    expect(out.last.value, ['p0', 'p1']);
  });

  testWidgets('ShowMoreFooter disparait quand tout est visible', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ShowMoreFooter(shown: 50, total: 80, onMore: () => taps++),
      ),
    ));
    await tester.tap(find.textContaining('Afficher plus'));
    expect(taps, 1);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ShowMoreFooter(shown: 80, total: 80, onMore: () => taps++),
      ),
    ));
    expect(find.textContaining('Afficher plus'), findsNothing);
  });
}
