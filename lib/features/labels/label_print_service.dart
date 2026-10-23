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
  const LabelPrintResult(this.ok, this.message);
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

  Future<LabelPrintResult> print({
    required List<LabelJob> jobs,
    required LabelSettings settings,
    required LabelOptions options,
    required LabelTarget target,
  }) async {
    final format = settings.format;
    final choice = settings.codeChoice;
    final count = jobs.fold<int>(0, (s, j) => s + j.copies);
    if (count == 0) {
      return const LabelPrintResult(false, 'Aucune étiquette à imprimer.');
    }
    try {
      if (format.isSheet ||
          target.kind == LabelTargetKind.none ||
          target.kind == LabelTargetKind.system) {
        final ok = await _printPdf(jobs, format, options, choice,
            target.kind == LabelTargetKind.system ? target : null);
        return LabelPrintResult(
            ok, ok ? '$count étiquette(s) envoyée(s).' : 'Impression annulée.');
      }
      final bool ok;
      switch (target.kind) {
        case LabelTargetKind.epos:
          ok = await _sendEpos(
              target.address,
              buildEposLabels(
                  jobs: jobs, format: format, options: options, choice: choice));
        case LabelTargetKind.qunsuo:
          ok = await _sendQunsuo(target.address,
              await buildLabelsPdf(
                  jobs: jobs, format: format, options: options, choice: choice));
        default:
          final bytes = rawBytesFor(
              language: settings.language,
              jobs: jobs,
              format: format,
              options: options,
              choice: choice);
          ok = await _sendRaw(target, bytes);
      }
      return LabelPrintResult(
          ok,
          ok
              ? '$count étiquette(s) envoyée(s) à ${target.displayName}.'
              : 'Imprimante injoignable : ${target.displayName}. '
                  'Vérifiez qu\'elle est allumée et connectée.');
    } catch (e) {
      debugPrint('[Labels] erreur $e');
      return LabelPrintResult(false, 'Impression impossible : $e');
    }
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

  Future<bool> _sendRaw(LabelTarget t, List<int> bytes) async {
    switch (t.kind) {
      case LabelTargetKind.bluetooth:
        try {
          if (await PrintBluetoothThermal.connectionStatus) {
            await PrintBluetoothThermal.disconnect;
          }
          final connected =
              await PrintBluetoothThermal.connect(macPrinterAddress: t.address);
          if (!connected || !await PrintBluetoothThermal.connectionStatus) {
            return false;
          }
          final ok = await PrintBluetoothThermal.writeBytes(bytes);
          await PrintBluetoothThermal.disconnect;
          return ok;
        } catch (e) {
          debugPrint('[Labels] BT: $e');
          try {
            await PrintBluetoothThermal.disconnect;
          } catch (_) {}
          return false;
        }
      case LabelTargetKind.network:
        final parts = t.address.split(':');
        final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;
        Socket? s;
        try {
          s = await Socket.connect(parts[0], port,
              timeout: const Duration(seconds: 10));
          s.add(bytes);
          await s.flush();
          return true;
        } catch (e) {
          debugPrint('[Labels] Réseau: $e');
          return false;
        } finally {
          s?.destroy();
        }
      case LabelTargetKind.serial:
        if (kIsWeb || !Platform.isAndroid) return false;
        final parts = t.address.split('|');
        final baud =
            parts.length > 1 ? int.tryParse(parts[1]) ?? 115200 : 115200;
        final ok = await _builtin.invokeMethod<bool>('print', {
          'path': parts.first,
          'baud': baud,
          'bytes': Uint8List.fromList(bytes),
        });
        return ok == true;
      default:
        return false;
    }
  }

  Future<bool> _sendEpos(String address, String xml) async {
    final parts = address.split(':');
    final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 80 : 80;
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final req = await client.postUrl(Uri.parse(
          'http://${parts[0]}:$port/cgi-bin/epos/service.cgi?devid=local_printer&timeout=10000'));
      req.headers.set(HttpHeaders.contentTypeHeader, 'text/xml; charset=utf-8');
      req.headers.set('SOAPAction', '""');
      req.add(utf8.encode(xml));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      return res.statusCode == 200 && body.contains('success="true"');
    } catch (e) {
      debugPrint('[Labels] ePOS: $e');
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  Future<bool> _sendQunsuo(String address, Uint8List pdf) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final parts = address.split('|');
    final density = parts.length > 1 ? int.tryParse(parts[1]) ?? 50 : 50;
    await for (final page in Printing.raster(pdf, dpi: 203)) {
      final png = await page.toPng();
      final err = await _builtin.invokeMethod<String>(
          'qunsuoPrint', {'png': png, 'density': density});
      if (err != null) {
        debugPrint('[Labels] Qunsuo: $err');
        return false;
      }
    }
    return true;
  }
}
