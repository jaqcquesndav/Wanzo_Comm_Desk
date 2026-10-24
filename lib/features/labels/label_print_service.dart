import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';

import 'label_codes.dart';
import 'label_format.dart';
import 'label_item.dart';
import 'label_renderers.dart';

/// Voie d'impression, déduite de l'imprimante configurée dans les réglages
/// (voir `label_printer_bridge.dart`, propre à chaque app).
enum LabelTargetKind {
  /// Aucune imprimante dédiée : boîte d'impression du système.
  none,
  bluetooth,
  network,
  epos,
  system,

  /// Imprimante intégrée en port série (terminaux POS, ESC/POS).
  serial,

  /// Imprimante intégrée Qunsuo (SDK fabricant, image).
  qunsuo,
}

class LabelTarget {
  final LabelTargetKind kind;
  final String address;
  final String name;
  const LabelTarget(this.kind, {this.address = '', this.name = ''});

  static const LabelTarget systemDialog = LabelTarget(LabelTargetKind.none);

  /// Vrai si la voie parle un langage d'imprimante (ESC/POS, TSPL, ZPL).
  bool get speaksRaw =>
      kind == LabelTargetKind.bluetooth ||
      kind == LabelTargetKind.network ||
      kind == LabelTargetKind.serial;

  String get displayName => switch (kind) {
        LabelTargetKind.none => 'Impression par le système',
        LabelTargetKind.system =>
          name.isNotEmpty ? name : 'Imprimante du système',
        _ => name.isNotEmpty ? name : address,
      };
}

class LabelPrintResult {
  final bool ok;
  final String message;

  /// Étiquettes entièrement envoyées à l'imprimante.
  final int printed;

  /// Étiquettes demandées.
  final int total;

  /// Vrai si l'utilisateur a arrêté l'impression en cours.
  final bool cancelled;

  /// Échec dû à l'imprimante (non configurée, injoignable) : l'écran propose
  /// les réglages de l'imprimante et le PDF en repli.
  final bool printerProblem;

  const LabelPrintResult(
    this.ok,
    this.message, {
    this.printed = 0,
    this.total = 0,
    this.cancelled = false,
    this.printerProblem = false,
  });
}

/// Jeton d'arrêt d'une impression en cours. L'arrêt est coopératif : il est
/// vérifié entre deux étiquettes (ou deux pages), jamais au milieu d'un envoi.
class LabelPrintCancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Progression : [done] étiquettes envoyées sur [total].
typedef LabelPrintProgress = void Function(int done, int total);

/// Bilan d'un envoi par lots.
class LabelSendOutcome {
  final int sent;
  final bool ok;
  final bool cancelled;
  const LabelSendOutcome(this.sent, {this.ok = true, this.cancelled = false});
}

/// « 1 étiquette », « 3 étiquettes ».
String labelCountText(int n) => '$n étiquette${n > 1 ? 's' : ''}';

/// Message affiché quand l'utilisateur arrête l'impression.
String labelStoppedMessage(int sent) => sent == 0
    ? 'Impression arrêtée, aucune étiquette envoyée.'
    : 'Impression arrêtée après ${labelCountText(sent)}.';

/// Lots prêts à envoyer à une imprimante « brute » : un lot par étiquette,
/// plus la fin de travail (avance et coupe) à envoyer une seule fois, même
/// après un arrêt.
class LabelRawChunks {
  final List<List<int>> labels;
  final List<int> tail;
  const LabelRawChunks(this.labels, this.tail);
}

/// Impression des étiquettes selon le mode d'imprimante configuré.
///
/// - Planche A4 et imprimante « système » : PDF par le pilote.
/// - Bluetooth, réseau, intégrée série : ESC/POS natif (code-barres et QR
///   générés par l'imprimante) ou TSPL / ZPL pour une imprimante
///   d'étiquettes.
/// - ePOS-Print : XML natif Epson.
/// - Intégrée Qunsuo : PDF rendu en image.
class LabelPrintService {
  static const MethodChannel _builtin = MethodChannel('wanzo/builtin_printer');

  /// Imprime [jobs] étiquette par étiquette : [cancel] est vérifié entre deux
  /// envois et [onProgress] reçoit l'avancement.
  Future<LabelPrintResult> print({
    required List<LabelJob> jobs,
    required LabelSettings settings,
    required LabelOptions options,
    required LabelTarget target,
    LabelPrintCancelToken? cancel,
    LabelPrintProgress? onProgress,
  }) async {
    final format = settings.format;
    final choice = settings.codeChoice;
    final count = jobs.fold<int>(0, (s, j) => s + j.copies);
    if (count == 0) {
      return const LabelPrintResult(false, 'Aucune étiquette à imprimer.');
    }
    if (cancel?.isCancelled ?? false) {
      return LabelPrintResult(true, labelStoppedMessage(0),
          total: count, cancelled: true);
    }
    try {
      final LabelSendOutcome out;
      if (format.isSheet || target.kind == LabelTargetKind.none) {
        // Boîte d'impression du système : un seul travail, que l'utilisateur
        // peut annuler dans la boîte elle-même.
        onProgress?.call(0, count);
        final ok = await _printPdf(jobs, format, options, choice, null);
        if (ok) onProgress?.call(count, count);
        return LabelPrintResult(ok,
            ok ? '${labelCountText(count)} envoyée(s).' : 'Impression annulée.',
            printed: ok ? count : 0, total: count);
      }
      switch (target.kind) {
        case LabelTargetKind.system:
          out = await _printPdfPerLabel(
              jobs, format, options, choice, target, cancel, onProgress);
        case LabelTargetKind.epos:
          out = await _sendEpos(
              target.address,
              eposChunksFor(
                  jobs: jobs, format: format, options: options, choice: choice),
              cancel,
              onProgress);
        case LabelTargetKind.qunsuo:
          out = await _sendQunsuo(
              target.address,
              await buildLabelsPdf(
                  jobs: jobs, format: format, options: options, choice: choice),
              count,
              cancel,
              onProgress);
        default:
          out = await _sendRaw(
              target,
              rawChunksFor(
                  language: settings.language,
                  jobs: jobs,
                  format: format,
                  options: options,
                  choice: choice),
              cancel,
              onProgress);
      }
      if (out.cancelled) {
        return LabelPrintResult(true, labelStoppedMessage(out.sent),
            printed: out.sent, total: count, cancelled: true);
      }
      if (!out.ok) {
        return LabelPrintResult(
            false,
            'Imprimante injoignable : ${target.displayName}. '
            'Vérifiez qu\'elle est allumée et connectée'
            '${out.sent > 0 ? ' (${out.sent} sur $count imprimée(s))' : ''}.',
            printed: out.sent,
            total: count,
            printerProblem: true);
      }
      return LabelPrintResult(
          true, '${labelCountText(count)} envoyée(s) à ${target.displayName}.',
          printed: count, total: count);
    } catch (e) {
      debugPrint('[Labels] erreur $e');
      return LabelPrintResult(false, 'Impression impossible : $e',
          total: count, printerProblem: true);
    }
  }

  /// Envoie [chunks] un par un. L'arrêt est vérifié avant chaque lot : un lot
  /// commencé est toujours envoyé jusqu'au bout.
  static Future<LabelSendOutcome> sendChunks<T>(
    List<T> chunks,
    Future<bool> Function(T chunk) send, {
    LabelPrintCancelToken? cancel,
    LabelPrintProgress? onProgress,
  }) async {
    var sent = 0;
    onProgress?.call(0, chunks.length);
    for (final c in chunks) {
      if (cancel?.isCancelled ?? false) {
        return LabelSendOutcome(sent, cancelled: true);
      }
      if (!await send(c)) return LabelSendOutcome(sent, ok: false);
      sent++;
      onProgress?.call(sent, chunks.length);
    }
    return LabelSendOutcome(sent);
  }

  /// Une ligne d'impression par étiquette (exemplaires dépliés).
  static List<LabelJob> singleLabelJobs(List<LabelJob> jobs) => [
        for (final j in jobs)
          for (var i = 0; i < j.copies; i++) LabelJob(j.item, 1),
      ];

  /// Lots par étiquette pour une imprimante « brute ». En ESC/POS, l'en-tête
  /// d'initialisation n'est envoyé qu'une fois et l'avance avec coupe forme
  /// la fin de travail : bout à bout, les lots redonnent exactement
  /// [rawBytesFor].
  static LabelRawChunks rawChunksFor({
    required LabelPrinterLanguage language,
    required List<LabelJob> jobs,
    required LabelFormat format,
    required LabelOptions options,
    required LabelCodeChoice choice,
  }) {
    final singles = singleLabelJobs(jobs);
    if (language != LabelPrinterLanguage.escPos) {
      return LabelRawChunks([
        for (final j in singles)
          rawBytesFor(
              language: language,
              jobs: [j],
              format: format,
              options: options,
              choice: choice),
      ], const []);
    }
    final empty = buildEscPosLabels(
        jobs: const [], format: format, options: options, choice: choice);
    final labels = <List<int>>[];
    var head = 0;
    var tail = 0;
    for (final j in singles) {
      final one = buildEscPosLabels(
          jobs: [j], format: format, options: options, choice: choice);
      head = _commonPrefix(empty, one);
      tail = _commonSuffix(empty, one, head);
      labels.add(one.sublist(
          labels.isEmpty ? 0 : head, one.length - tail));
    }
    return LabelRawChunks(labels, empty.sublist(empty.length - tail));
  }

  static int _commonPrefix(List<int> a, List<int> b) {
    var i = 0;
    while (i < a.length && i < b.length && a[i] == b[i]) {
      i++;
    }
    return i;
  }

  static int _commonSuffix(List<int> a, List<int> b, int prefix) {
    var i = 0;
    while (i < a.length - prefix &&
        i < b.length - prefix &&
        a[a.length - 1 - i] == b[b.length - 1 - i]) {
      i++;
    }
    return i;
  }

  /// Une requête ePOS par étiquette, sans coupe : la coupe part seule à la
  /// fin (dernier élément), même après un arrêt.
  static List<String> eposChunksFor({
    required List<LabelJob> jobs,
    required LabelFormat format,
    required LabelOptions options,
    required LabelCodeChoice choice,
  }) {
    const cut = '<cut type="feed"/>';
    return [
      for (final j in singleLabelJobs(jobs))
        buildEposLabels(
                jobs: [j], format: format, options: options, choice: choice)
            .replaceFirst(cut, ''),
      buildEposLabels(
          jobs: const [], format: format, options: options, choice: choice),
    ];
  }

  /// Octets envoyés à une imprimante « brute » selon son langage.
  static List<int> rawBytesFor({
    required LabelPrinterLanguage language,
    required List<LabelJob> jobs,
    required LabelFormat format,
    required LabelOptions options,
    required LabelCodeChoice choice,
  }) {
    switch (language) {
      case LabelPrinterLanguage.tspl:
        return latin1.encode(buildTsplLabels(
            jobs: jobs, format: format, options: options, choice: choice));
      case LabelPrinterLanguage.zpl:
        return utf8.encode(buildZplLabels(
            jobs: jobs, format: format, options: options, choice: choice));
      case LabelPrinterLanguage.escPos:
        return buildEscPosLabels(
            jobs: jobs, format: format, options: options, choice: choice);
    }
  }

  /// PDF partagé ou enregistré (toujours disponible, même hors ligne).
  Future<void> sharePdf({
    required List<LabelJob> jobs,
    required LabelSettings settings,
    required LabelOptions options,
  }) async {
    final bytes = await buildLabelsPdf(
        jobs: jobs,
        format: settings.format,
        options: options,
        choice: settings.codeChoice);
    await Printing.sharePdf(bytes: bytes, filename: 'etiquettes.pdf');
  }

  Future<bool> _printPdf(List<LabelJob> jobs, LabelFormat format,
      LabelOptions options, LabelCodeChoice choice, LabelTarget? printer) async {
    final bytes = await buildLabelsPdf(
        jobs: jobs, format: format, options: options, choice: choice);
    final pageFormat = labelPageFormat(format);
    if (printer != null &&
        printer.address.isNotEmpty &&
        printer.address != 'system' &&
        !format.isSheet) {
      return Printing.directPrintPdf(
        printer: Printer(url: printer.address, name: printer.name),
        name: 'Etiquettes',
        format: pageFormat,
        onLayout: (_) async => bytes,
      );
    }
    return Printing.layoutPdf(
      name: 'Etiquettes',
      format: pageFormat,
      onLayout: (_) async => bytes,
    );
  }

  /// Imprimante du système désignée : un travail PDF par étiquette, pour
  /// pouvoir s'arrêter entre deux. Sans imprimante désignée : boîte
  /// d'impression (un seul travail).
  Future<LabelSendOutcome> _printPdfPerLabel(
    List<LabelJob> jobs,
    LabelFormat format,
    LabelOptions options,
    LabelCodeChoice choice,
    LabelTarget printer,
    LabelPrintCancelToken? cancel,
    LabelPrintProgress? onProgress,
  ) async {
    final count = jobs.fold<int>(0, (s, j) => s + j.copies);
    if (printer.address.isEmpty || printer.address == 'system') {
      onProgress?.call(0, count);
      final ok = await _printPdf(jobs, format, options, choice, null);
      if (!ok) return const LabelSendOutcome(0, cancelled: true);
      onProgress?.call(count, count);
      return LabelSendOutcome(count);
    }
    final pageFormat = labelPageFormat(format);
    final p = Printer(url: printer.address, name: printer.name);
    return sendChunks<LabelJob>(singleLabelJobs(jobs), (j) async {
      final bytes = await buildLabelsPdf(
          jobs: [j], format: format, options: options, choice: choice);
      return Printing.directPrintPdf(
        printer: p,
        name: 'Etiquettes',
        format: pageFormat,
        onLayout: (_) async => bytes,
      );
    }, cancel: cancel, onProgress: onProgress);
  }

  /// Envoie les lots sur une seule connexion, ferme proprement la connexion
  /// après la dernière étiquette ou après l'arrêt, et termine le travail
  /// (avance et coupe) dès qu'au moins une étiquette est partie.
  Future<LabelSendOutcome> _sendRaw(
    LabelTarget t,
    LabelRawChunks chunks,
    LabelPrintCancelToken? cancel,
    LabelPrintProgress? onProgress,
  ) async {
    Future<LabelSendOutcome> run(Future<bool> Function(List<int>) write) async {
      final out = await sendChunks<List<int>>(chunks.labels, write,
          cancel: cancel, onProgress: onProgress);
      if (out.sent > 0 && chunks.tail.isNotEmpty) {
        try {
          await write(chunks.tail);
        } catch (e) {
          debugPrint('[Labels] fin de travail: $e');
        }
      }
      return out;
    }

    switch (t.kind) {
      case LabelTargetKind.bluetooth:
        try {
          if (await PrintBluetoothThermal.connectionStatus) {
            await PrintBluetoothThermal.disconnect;
          }
          final connected =
              await PrintBluetoothThermal.connect(macPrinterAddress: t.address);
          if (!connected || !await PrintBluetoothThermal.connectionStatus) {
            return const LabelSendOutcome(0, ok: false);
          }
          return await run((b) => PrintBluetoothThermal.writeBytes(b));
        } catch (e) {
          debugPrint('[Labels] BT: $e');
          return const LabelSendOutcome(0, ok: false);
        } finally {
          try {
            await PrintBluetoothThermal.disconnect;
          } catch (_) {}
        }
      case LabelTargetKind.network:
        final parts = t.address.split(':');
        final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;
        Socket? s;
        try {
          s = await Socket.connect(parts[0], port,
              timeout: const Duration(seconds: 10));
          final socket = s;
          return await run((b) async {
            socket.add(b);
            await socket.flush();
            return true;
          });
        } catch (e) {
          debugPrint('[Labels] Réseau: $e');
          return const LabelSendOutcome(0, ok: false);
        } finally {
          try {
            await s?.close();
          } catch (_) {}
          s?.destroy();
        }
      case LabelTargetKind.serial:
        if (kIsWeb || !Platform.isAndroid) {
          return const LabelSendOutcome(0, ok: false);
        }
        final parts = t.address.split('|');
        final baud =
            parts.length > 1 ? int.tryParse(parts[1]) ?? 115200 : 115200;
        return run((b) async {
          final ok = await _builtin.invokeMethod<bool>('print', {
            'path': parts.first,
            'baud': baud,
            'bytes': Uint8List.fromList(b),
          });
          return ok == true;
        });
      default:
        return const LabelSendOutcome(0, ok: false);
    }
  }

  /// Une requête par étiquette ; la dernière requête (coupe seule) part
  /// aussi après un arrêt.
  Future<LabelSendOutcome> _sendEpos(
    String address,
    List<String> xmls,
    LabelPrintCancelToken? cancel,
    LabelPrintProgress? onProgress,
  ) async {
    final parts = address.split(':');
    final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 80 : 80;
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final http = client;
      Future<bool> post(String xml) async {
        final req = await http.postUrl(Uri.parse(
            'http://${parts[0]}:$port/cgi-bin/epos/service.cgi?devid=local_printer&timeout=10000'));
        req.headers
            .set(HttpHeaders.contentTypeHeader, 'text/xml; charset=utf-8');
        req.headers.set('SOAPAction', '""');
        req.add(utf8.encode(xml));
        final res = await req.close();
        final body = await res.transform(utf8.decoder).join();
        return res.statusCode == 200 && body.contains('success="true"');
      }

      final labels = xmls.sublist(0, xmls.length - 1);
      final out = await sendChunks<String>(labels, post,
          cancel: cancel, onProgress: onProgress);
      if (out.sent > 0) {
        try {
          await post(xmls.last);
        } catch (e) {
          debugPrint('[Labels] ePOS coupe: $e');
        }
      }
      return out;
    } catch (e) {
      debugPrint('[Labels] ePOS: $e');
      return const LabelSendOutcome(0, ok: false);
    } finally {
      client?.close(force: true);
    }
  }

  /// Une page (une étiquette) à la fois ; l'arrêt est vérifié entre deux.
  Future<LabelSendOutcome> _sendQunsuo(
    String address,
    Uint8List pdf,
    int total,
    LabelPrintCancelToken? cancel,
    LabelPrintProgress? onProgress,
  ) async {
    if (kIsWeb || !Platform.isAndroid) {
      return const LabelSendOutcome(0, ok: false);
    }
    final parts = address.split('|');
    final density = parts.length > 1 ? int.tryParse(parts[1]) ?? 50 : 50;
    var sent = 0;
    onProgress?.call(0, total);
    await for (final page in Printing.raster(pdf, dpi: 203)) {
      if (cancel?.isCancelled ?? false) {
        return LabelSendOutcome(sent, cancelled: true);
      }
      final png = await page.toPng();
      final err = await _builtin.invokeMethod<String>(
          'qunsuoPrint', {'png': png, 'density': density});
      if (err != null) {
        debugPrint('[Labels] Qunsuo: $err');
        return LabelSendOutcome(sent, ok: false);
      }
      sent++;
      onProgress?.call(sent, total < sent ? sent : total);
    }
    return LabelSendOutcome(sent);
  }
}
