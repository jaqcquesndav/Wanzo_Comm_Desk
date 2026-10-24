import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanzo/features/labels/label_codes.dart';
import 'package:wanzo/features/labels/label_format.dart';
import 'package:wanzo/features/labels/label_item.dart';
import 'package:wanzo/features/labels/label_print_service.dart';
import 'package:wanzo/features/labels/print_labels_screen.dart';

const _item = LabelItem(
  id: 'p1',
  name: 'Savon de ménage',
  code: 'SKU-001',
  price: '1 250 CDF',
  stockQuantity: 40,
);
const _item2 = LabelItem(id: 'p2', name: 'Riz 5 kg', code: '6001234567892');

/// Service factice : une étiquette toutes les 10 ms, chaque envoi noté.
class _FakeService extends LabelPrintService {
  final sent = <int>[];
  final LabelPrintResult? failWith;
  _FakeService({this.failWith});

  @override
  Future<LabelPrintResult> print({
    required List<LabelJob> jobs,
    required LabelSettings settings,
    required LabelOptions options,
    required LabelTarget target,
    LabelPrintCancelToken? cancel,
    LabelPrintProgress? onProgress,
  }) async {
    if (failWith != null) return failWith!;
    final singles = LabelPrintService.singleLabelJobs(jobs);
    var i = 0;
    final out =
        await LabelPrintService.sendChunks<LabelJob>(singles, (_) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      sent.add(i++);
      return true;
    }, cancel: cancel, onProgress: onProgress);
    return out.cancelled
        ? LabelPrintResult(true, labelStoppedMessage(out.sent),
            printed: out.sent, total: singles.length, cancelled: true)
        : LabelPrintResult(true, '${singles.length} envoyées',
            printed: out.sent, total: singles.length);
  }
}

void main() {
  group('envoi par lots', () {
    test('arrêt au milieu d\'un lot : plus aucun envoi après l\'arrêt',
        () async {
      final token = LabelPrintCancelToken();
      final sent = <int>[];
      final progress = <int>[];
      final out = await LabelPrintService.sendChunks<int>(
        List.generate(40, (i) => i),
        (c) async {
          sent.add(c);
          if (sent.length == 3) token.cancel(); // pendant la 3e étiquette
          return true;
        },
        cancel: token,
        onProgress: (d, t) => progress.add(d),
      );
      expect(out.cancelled, isTrue);
      expect(out.sent, 3, reason: 'l\'étiquette en cours est terminée');
      expect(sent, [0, 1, 2]);
      expect(progress.last, 3);
      expect(labelStoppedMessage(out.sent),
          'Impression arrêtée après 3 étiquettes.');
      expect(labelStoppedMessage(1), 'Impression arrêtée après 1 étiquette.');
    });

    test('échec d\'envoi : on s\'arrête et on compte ce qui est parti',
        () async {
      final out = await LabelPrintService.sendChunks<int>(
          [1, 2, 3, 4], (c) async => c < 3);
      expect(out.ok, isFalse);
      expect(out.sent, 2);
    });

    test('ESC/POS : lots par étiquette, bout à bout identiques au bloc', () {
      const settings = LabelSettings();
      const options = LabelOptions();
      final jobs = [const LabelJob(_item, 3), const LabelJob(_item2, 2)];
      final chunks = LabelPrintService.rawChunksFor(
          language: LabelPrinterLanguage.escPos,
          jobs: jobs,
          format: settings.format,
          options: options,
          choice: LabelCodeChoice.barcode);
      expect(chunks.labels.length, 5);
      expect(chunks.tail, isNotEmpty);
      final joined = [for (final c in chunks.labels) ...c, ...chunks.tail];
      expect(
          joined,
          LabelPrintService.rawBytesFor(
              language: LabelPrinterLanguage.escPos,
              jobs: jobs,
              format: settings.format,
              options: options,
              choice: LabelCodeChoice.barcode));
    });

    test('TSPL, ZPL et ePOS : un lot par étiquette', () {
      const settings = LabelSettings();
      const options = LabelOptions();
      final jobs = [const LabelJob(_item, 4)];
      for (final lang in [
        LabelPrinterLanguage.tspl,
        LabelPrinterLanguage.zpl,
      ]) {
        final c = LabelPrintService.rawChunksFor(
            language: lang,
            jobs: jobs,
            format: settings.format,
            options: options,
            choice: LabelCodeChoice.barcode);
        expect(c.labels.length, 4);
      }
      final epos = LabelPrintService.eposChunksFor(
          jobs: jobs,
          format: settings.format,
          options: options,
          choice: LabelCodeChoice.barcode);
      expect(epos.length, 5, reason: '4 étiquettes puis la coupe seule');
      for (final x in epos.take(4)) {
        expect(x.contains('<cut'), isFalse);
      }
      expect(epos.last.contains('<cut'), isTrue);
    });

    test('arrêt demandé avant le début : rien n\'est envoyé', () async {
      final token = LabelPrintCancelToken()..cancel();
      final res = await LabelPrintService().print(
        jobs: [const LabelJob(_item, 5)],
        settings: const LabelSettings(),
        options: const LabelOptions(),
        target:
            const LabelTarget(LabelTargetKind.network, address: '0.0.0.0'),
        cancel: token,
      );
      expect(res.cancelled, isTrue);
      expect(res.printed, 0);
      expect(res.message, 'Impression arrêtée, aucune étiquette envoyée.');
    });
  });

  group('écran', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pumpScreen(WidgetTester tester, LabelPrintService service,
        {double width = 360}) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: PrintLabelsScreen(
          items: const [_item],
          target: const LabelTarget(LabelTargetKind.network,
              address: '192.168.1.50:9100', name: 'Étiqueteuse'),
          initialSettings: const LabelSettings(),
          service: service,
        ),
      ));
      await tester.pumpAndSettle();
    }

    for (final width in [320.0, 360.0]) {
      testWidgets(
          'progression, Arrêter toujours visible, message final '
          '(${width.toInt()} dp)', (tester) async {
        final service = _FakeService();
        await pumpScreen(tester, service, width: width);
        expect(find.text('40 étiquettes'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('label-print')));
        await tester.pump(); // démarrage
        await tester.pump(const Duration(milliseconds: 25));
        expect(find.byKey(const ValueKey('label-stop')), findsOneWidget);
        expect(find.text('Étiquette 3 sur 40'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const ValueKey('label-stop')));
        await tester.pump();
        expect(find.text('Arrêt après l\'étiquette en cours'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        final n = service.sent.length;
        expect(n, 3, reason: 'l\'étiquette en cours finit, puis plus rien');
        expect(find.text('Impression arrêtée après 3 étiquettes.'),
            findsOneWidget);
        expect(find.byKey(const ValueKey('label-stop')), findsNothing);
        expect(find.byKey(const ValueKey('label-print')), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        expect(service.sent.length, n);
      });
    }

    testWidgets('imprimante injoignable : réglages et PDF proposés',
        (tester) async {
      final service = _FakeService(
          failWith: const LabelPrintResult(
              false, 'Imprimante injoignable : Étiqueteuse.',
              total: 40, printerProblem: true));
      await pumpScreen(tester, service);
      await tester.tap(find.byKey(const ValueKey('label-print')));
      await tester.pumpAndSettle();
      expect(find.text('Impression impossible'), findsOneWidget);
      expect(
          find.text('Imprimante injoignable : Étiqueteuse.'), findsOneWidget);
      expect(find.byKey(const ValueKey('label-configure-printer')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('label-error-pdf')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
