import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/settings/models/settings.dart';

/// Types de connexion pris en charge pour l'imprimante.
enum ThermalConnectionType {
  bluetooth, // Bluetooth classique (SPP/RFCOMM) — imprimantes 57–80 mm ESC/POS
  usb, // USB OTG brut (déprécié ici : couvert par l'impression système/pilote)
  network, // Réseau TCP/IP (port 9100 — standard ESC/POS)
  epos, // Epson ePOS-Print (XML sur HTTP) — imprimantes réseau Epson TM
  system, // Impression via le système/pilote OS (tout pilote installé : USB, WiFi, E-POS Printer Driver, Mopria…)
}

/// Représente une imprimante thermique découverte ou configurée.
class ThermalPrinterDevice {
  final String name;

  /// BT: adresse MAC  |  USB: "vendorId|productId"  |  Network: "ip:port"
  final String address;
  final ThermalConnectionType type;

  const ThermalPrinterDevice({
    required this.name,
    required this.address,
    required this.type,
  });

  String get displayName => name.isNotEmpty ? name : address;

  @override
  String toString() => 'ThermalPrinterDevice($type, $name, $address)';
}

/// Service d'impression de tickets de caisse sur imprimantes thermiques ESC/POS.
///
/// Supporte :
/// - **Bluetooth** : Classic BT (SPP) via `print_bluetooth_thermal`.
/// - **Réseau (TCP)** : Imprimantes POS en réseau local (port 9100) via `dart:io`.
/// - **USB OTG** : Non supporté dans cette version (stub retournant false).
///
/// Le ticket n'est généré que pour les paiements en espèces.
/// Seul le montant réellement reçu en cash est affiché.
class ReceiptPrinterService {
  static const _keyName = 'thermal_printer_name';
  static const _keyAddress = 'thermal_printer_address';
  static const _keyType = 'thermal_printer_type';
  static const _keyAutoPrint = 'thermal_auto_print_cash';

  static const String cashPaymentLabel = 'Espèces';

  // 58 mm paper: ~32 chars wide at font A (normal size)
  static const int _colWidth = 32;

  // ── Persistance des préférences ──────────────────────────────────────────

  Future<ThermalPrinterDevice?> getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString(_keyAddress);
    if (address == null || address.isEmpty) return null;
    return ThermalPrinterDevice(
      name: prefs.getString(_keyName) ?? '',
      address: address,
      type: ThermalConnectionType.values[prefs.getInt(_keyType) ?? 0],
    );
  }

  Future<void> savePrinter(ThermalPrinterDevice printer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, printer.name);
    await prefs.setString(_keyAddress, printer.address);
    await prefs.setInt(_keyType, printer.type.index);
  }

  Future<void> clearSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAddress);
    await prefs.remove(_keyName);
    await prefs.remove(_keyType);
  }

  Future<bool> getAutoPrintOnCashSale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoPrint) ?? false;
  }

  Future<void> setAutoPrintOnCashSale(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoPrint, value);
  }

  // ── Découverte des imprimantes ───────────────────────────────────────────

  /// Retourne la liste des appareils Bluetooth déjà appairés au téléphone.
  ///
  /// **Note** : `pairedBluetooths` retourne silencieusement `[]` quand la
  /// permission OS est absente. On vérifie via `isPermissionBluetoothGranted`
  /// (méthode native du package) pour lever une exception explicite.
  Future<List<ThermalPrinterDevice>> scanBluetooth() async {
    if (Platform.isAndroid) {
      final granted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!granted) {
        throw Exception(
          'Permission BLUETOOTH_CONNECT refusée par le système.\n'
          'Autorisez Bluetooth dans Paramètres → Applications → Wanzo.',
        );
      }
    }

    final paired = await PrintBluetoothThermal.pairedBluetooths;

    // Filtre défensif : ignorer les entrées avec une adresse MAC vide qui
    // peuvent apparaître sur certains ROM si bondedDevices renvoie des
    // appareils mal initialisés.
    return paired
        .where((d) => d.macAdress.isNotEmpty)
        .map(
          (d) => ThermalPrinterDevice(
            name: d.name.isNotEmpty ? d.name : d.macAdress,
            address: d.macAdress,
            type: ThermalConnectionType.bluetooth,
          ),
        )
        .toList();
  }

  /// USB OTG non supporté dans cette version — retourne une liste vide.
  Future<List<ThermalPrinterDevice>> scanUsb() async => [];

  // ── Vérification paiement cash ───────────────────────────────────────────

  static bool isCashPayment(String? paymentMethod) {
    if (paymentMethod == null) return false;
    final pm = paymentMethod.toLowerCase();
    return pm == 'espèces' || pm == 'especes' || pm == 'cash' || pm == 'espece';
  }

  // ── Construction du ticket (ESC/POS bytes) ────────────────────────────────

  /// Construit les octets ESC/POS bruts du ticket de caisse.
  ///
  /// Mise en page compacte (économie de papier) :
  /// - En-tête : nom (gras), adresse, tél, NIF/RCCM (sur une ligne), ID NAT
  /// - Corps   : date+réf sur la même ligne, articles compacts
  /// - Pied    : "Merci", wanzzo.com, QR code → https://wanzzo.com/
  List<int> buildCashReceiptBytes(Sale sale, Settings settings) {
    final currency = sale.transactionCurrencyCode ?? 'CDF';
    final totalInTx =
        sale.totalAmountInTransactionCurrency ?? sale.totalAmountInCdf;
    final paidInTx =
        sale.paidAmountInTransactionCurrency ?? sale.paidAmountInCdf;
    final change = paidInTx - totalInTx;
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(sale.date);
    final bytes = <int>[];

    bytes.addAll(_escReset());

    // ── En-tête entreprise / unité (centré) ──────────────────────────────
    //
    // Quand l'utilisateur est rattaché à une BusinessUnit personne morale
    // (coopérant entreprise d'une coopérative, succursale immatriculée),
    // la pièce commerciale doit afficher l'identité légale de CETTE BU
    // — et non celle de l'entreprise parente.
    final ctx = BusinessContextService();
    final useBu = ctx.shouldUseBusinessUnitIdentity;
    final headerName = useBu
        ? (ctx.businessUnitName ?? settings.companyName)
        : settings.companyName;
    final headerAddress = useBu
        ? (ctx.businessUnitAddress ?? settings.companyAddress)
        : settings.companyAddress;
    final headerPhone = useBu
        ? (ctx.businessUnitPhone ?? settings.companyPhone)
        : settings.companyPhone;
    final headerTaxId = useBu
        ? (ctx.businessUnitTaxId ?? settings.taxIdentificationNumber)
        : settings.taxIdentificationNumber;
    final headerRccm = useBu
        ? (ctx.businessUnitRccm ?? settings.rccmNumber)
        : settings.rccmNumber;
    final headerIdNat = useBu
        ? (ctx.businessUnitIdNat ?? settings.idNatNumber)
        : settings.idNatNumber;

    bytes.addAll(_escAlign(1));

    // Nom en gras, taille normale (32 chars disponibles, pas 2× qui divise
    // la largeur utile par 2 et tronque les noms longs).
    bytes.addAll(_escBold(true));
    bytes.addAll(
      _escLine(_truncate(headerName.toUpperCase(), _colWidth)),
    );
    bytes.addAll(_escBold(false));

    // Adresse : wrap auto si trop longue
    if (headerAddress.isNotEmpty) {
      for (final ln in _wrapText(headerAddress, _colWidth)) {
        bytes.addAll(_escLine(ln));
      }
    }

    // Téléphone
    if (headerPhone.isNotEmpty) {
      bytes.addAll(_escLine('Tel: $headerPhone'));
    }

    // NIF et RCCM : sur la même ligne si ça tient (économie de papier)
    final hasNif = headerTaxId.isNotEmpty;
    final hasRccm = headerRccm.isNotEmpty;
    final hasIdNat = headerIdNat.isNotEmpty;

    if (hasNif && hasRccm) {
      final nifStr = 'NIF:$headerTaxId';
      final rccmStr = 'RCCM:${_truncate(headerRccm, 14)}';
      final combined = '$nifStr  $rccmStr';
      if (combined.length <= _colWidth) {
        bytes.addAll(_escLine(combined));
      } else {
        bytes.addAll(
          _escLine(_truncate('NIF: $headerTaxId', _colWidth)),
        );
        bytes.addAll(
          _escLine(_truncate('RCCM: $headerRccm', _colWidth)),
        );
      }
    } else if (hasNif) {
      bytes.addAll(
        _escLine(_truncate('NIF: $headerTaxId', _colWidth)),
      );
    } else if (hasRccm) {
      bytes.addAll(
        _escLine(_truncate('RCCM: $headerRccm', _colWidth)),
      );
    }
    if (hasIdNat) {
      bytes.addAll(
        _escLine(_truncate('ID NAT: $headerIdNat', _colWidth)),
      );
    }

    bytes.addAll(_escSeparatorDouble());
    bytes.addAll(_escBold(true));
    bytes.addAll(_escLine('TICKET DE CAISSE'));
    bytes.addAll(_escBold(false));
    bytes.addAll(_escSeparatorDouble());

    // ── Infos vente ──────────────────────────────────────────────────────
    bytes.addAll(_escAlign(0));

    // Date et référence sur la même ligne
    final shortId =
        sale.id.length > 8 ? sale.id.substring(sale.id.length - 8) : sale.id;
    bytes.addAll(
      _escLine(shortId.isNotEmpty ? _rowText(dateStr, '#$shortId') : dateStr),
    );

    if (sale.customerName.isNotEmpty && sale.customerName != 'Inconnu') {
      bytes.addAll(
        _escLine(_truncate('Client: ${sale.customerName}', _colWidth)),
      );
    }
    bytes.addAll(_escSeparator());

    // ── Articles ─────────────────────────────────────────────────────────
    for (final item in sale.items) {
      final itemTotal = item.quantity * item.unitPrice;
      final amtStr = _fmt(itemTotal, currency);
      // Nom du produit tronqué dynamiquement selon la largeur du montant
      bytes.addAll(_escLine(_rowText(item.productName, amtStr)));
      bytes.addAll(
        _escLine('  ${item.quantity} x ${_fmt(item.unitPrice, currency)}'),
      );
    }
    bytes.addAll(_escSeparator());

    // ── Remise ───────────────────────────────────────────────────────────
    if (sale.discountPercentage > 0) {
      final subtotalBefore = totalInTx / (1 - sale.discountPercentage / 100);
      final discountAmt = subtotalBefore - totalInTx;
      bytes.addAll(
        _escLine(_rowText('Sous-total', _fmt(subtotalBefore, currency))),
      );
      bytes.addAll(
        _escLine(
          _rowText(
            'Remise(${sale.discountPercentage.toStringAsFixed(0)}%)',
            '-${_fmt(discountAmt, currency)}',
          ),
        ),
      );
    }

    // ── TVA (si activée dans les paramètres) ─────────────────────────────
    if (settings.showTaxes && settings.defaultTaxRate > 0) {
      double totalTVA = 0.0;
      double rate = settings.defaultTaxRate;
      for (final item in sale.items) {
        final itemRate = item.taxRate ?? rate;
        if (itemRate > 0) {
          final itemTotal = item.quantity * item.unitPrice;
          totalTVA += itemTotal * itemRate / (100 + itemRate);
          rate = itemRate;
        }
      }
      if (totalTVA > 0) {
        final ht = totalInTx - totalTVA;
        bytes.addAll(_escLine(_rowText('Total HT', _fmt(ht, currency))));
        bytes.addAll(
          _escLine(
            _rowText(
              'TVA (${rate.toStringAsFixed(0)}%)',
              _fmt(totalTVA, currency),
            ),
          ),
        );
      }
    }

    // ── Total ────────────────────────────────────────────────────────────
    bytes.addAll(_escBold(true));
    bytes.addAll(_escLine(_rowText('TOTAL', _fmt(totalInTx, currency))));
    bytes.addAll(_escBold(false));
    bytes.addAll(_escSeparatorDouble());

    // ── Règlement ────────────────────────────────────────────────────────
    bytes.addAll(_escBold(true));
    bytes.addAll(_escLine(_rowText('Especes:', _fmt(paidInTx, currency))));
    bytes.addAll(_escBold(false));
    if (change > 0.005) {
      bytes.addAll(_escLine(_rowText('Monnaie:', _fmt(change, currency))));
    }
    bytes.addAll(_escSeparatorDouble());

    // ── Pied de page ─────────────────────────────────────────────────────
    bytes.addAll(_escAlign(1));
    bytes.addAll(_escBold(true));
    bytes.addAll(_escLine('Merci pour votre achat !'));
    bytes.addAll(_escBold(false));
    bytes.addAll(_escLine('wanzzo.com'));
    bytes.addAll(_escFeed(1));
    // QR code contenant toutes les infos de la vente (ID opération, client, montants)
    bytes.addAll(_escQrCode(_buildQrData(sale, settings)));
    bytes.addAll(_escFeed(3));
    bytes.addAll(_escCut());

    return bytes;
  }

  // ── Impression ───────────────────────────────────────────────────────────

  /// Imprime le ticket de caisse sur l'imprimante thermique configurée.
  /// Retourne `true` si l'envoi a réussi.
  Future<bool> printCashReceipt(Sale sale, Settings settings) async {
    final printer = await getSavedPrinter();
    if (printer == null) {
      debugPrint('[ReceiptPrinter] Aucune imprimante configurée.');
      return false;
    }
    try {
      return await _sendToPrinter(printer, sale, settings);
    } catch (e) {
      debugPrint('[ReceiptPrinter] Erreur impression: $e');
      return false;
    }
  }

  Future<bool> _sendToPrinter(
    ThermalPrinterDevice printer,
    Sale sale,
    Settings settings,
  ) {
    switch (printer.type) {
      case ThermalConnectionType.bluetooth:
        return _printBluetooth(printer, buildCashReceiptBytes(sale, settings));
      case ThermalConnectionType.usb:
        return _printUsb(printer);
      case ThermalConnectionType.network:
        return _printNetwork(printer, buildCashReceiptBytes(sale, settings));
      case ThermalConnectionType.epos:
        return _printEpos(printer, sale, settings);
      case ThermalConnectionType.system:
        return printReceiptViaSystem(
          sale,
          settings,
          printerUrl: printer.address,
          printerName: printer.name,
        );
    }
  }

  /// Impression Bluetooth classique/SPP via print_bluetooth_thermal.
  /// Envoie les octets ESC/POS directement (même format qu'en réseau).
  Future<bool> _printBluetooth(
    ThermalPrinterDevice printer,
    List<int> bytes,
  ) async {
    try {
      // Si une connexion précédente est encore ouverte (coroutine Kotlin
      // maintenue en vie), on déconnecte d'abord pour éviter les socket
      // orphelines qui font échouer le prochain connect().
      if (await PrintBluetoothThermal.connectionStatus) {
        await PrintBluetoothThermal.disconnect;
      }

      final connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: printer.address,
      );
      if (!connected) {
        debugPrint(
          '[ReceiptPrinter] BT: échec de connexion à ${printer.displayName}',
        );
        return false;
      }

      // Vérifier que la connexion BT est réellement stable avant d'écrire.
      // (connect() peut retourner true avant que la socket SPP soit prête.)
      if (!await PrintBluetoothThermal.connectionStatus) {
        debugPrint(
          '[ReceiptPrinter] BT: connexion instable après connect() — abandon',
        );
        return false;
      }

      final success = await PrintBluetoothThermal.writeBytes(bytes);
      await PrintBluetoothThermal.disconnect;
      debugPrint(
        '[ReceiptPrinter] BT: impression ${success ? "OK" : "échouée"} sur ${printer.displayName}',
      );
      return success;
    } catch (e) {
      debugPrint('[ReceiptPrinter] BT: erreur $e');
      // En cas d'exception, tenter la déconnexion propre sans planter.
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}
      return false;
    }
  }

  /// USB OTG non supporté dans cette version.
  Future<bool> _printUsb(ThermalPrinterDevice printer) async {
    debugPrint('[ReceiptPrinter] USB printing not supported in this version.');
    return false;
  }

  /// Impression réseau TCP/IP (port 9100 — standard ESC/POS).
  Future<bool> _printNetwork(
    ThermalPrinterDevice printer,
    List<int> bytes,
  ) async {
    final parts = printer.address.split(':');
    final ip = parts[0];
    final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;

    Socket? socket;
    try {
      socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 10),
      );
      socket.add(bytes);
      await socket.flush();
      debugPrint('[ReceiptPrinter] Network: ticket envoyé à $ip:$port');
      return true;
    } catch (e) {
      debugPrint('[ReceiptPrinter] Network: erreur $e');
      return false;
    } finally {
      socket?.destroy();
    }
  }

  // ── Epson ePOS-Print (XML sur HTTP) ───────────────────────────────────────

  /// Imprime via le protocole Epson ePOS-Print (XML sur HTTP) — imprimantes
  /// réseau Epson TM en mode ePOS-Print / « E-POS Printer Driver ».
  /// Adresse = `ip` ou `ip:port` (port 80 par défaut).
  Future<bool> _printEpos(
    ThermalPrinterDevice printer,
    Sale sale,
    Settings settings,
  ) async {
    final parts = printer.address.split(':');
    final ip = parts[0];
    final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 80 : 80;
    final xml = _buildEposXml(sale, settings);

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final uri = Uri.parse(
        'http://$ip:$port/cgi-bin/epos/service.cgi?devid=local_printer&timeout=10000',
      );
      final request = await client.postUrl(uri);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'text/xml; charset=utf-8',
      );
      request.headers.set('SOAPAction', '""');
      request.add(utf8.encode(xml));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      // ePOS-Print renvoie HTTP 200 + success="true" dans la réponse XML.
      final ok = response.statusCode == 200 && body.contains('success="true"');
      debugPrint(
        '[ReceiptPrinter] ePOS: ${ok ? "OK" : "échec"} ($ip:$port) HTTP ${response.statusCode}',
      );
      return ok;
    } catch (e) {
      debugPrint('[ReceiptPrinter] ePOS: erreur $e');
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  /// Construit le document ePOS-Print (enveloppe SOAP + epos-print) du ticket.
  String _buildEposXml(Sale sale, Settings settings) {
    final currency = sale.transactionCurrencyCode ?? 'CDF';
    final totalInTx =
        sale.totalAmountInTransactionCurrency ?? sale.totalAmountInCdf;
    final paidInTx =
        sale.paidAmountInTransactionCurrency ?? sale.paidAmountInCdf;
    final change = paidInTx - totalInTx;
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(sale.date);

    final ctx = BusinessContextService();
    final useBu = ctx.shouldUseBusinessUnitIdentity;
    final headerName = useBu
        ? (ctx.businessUnitName ?? settings.companyName)
        : settings.companyName;
    final headerAddress = useBu
        ? (ctx.businessUnitAddress ?? settings.companyAddress)
        : settings.companyAddress;
    final headerPhone = useBu
        ? (ctx.businessUnitPhone ?? settings.companyPhone)
        : settings.companyPhone;
    final headerTaxId = useBu
        ? (ctx.businessUnitTaxId ?? settings.taxIdentificationNumber)
        : settings.taxIdentificationNumber;
    final headerRccm = useBu
        ? (ctx.businessUnitRccm ?? settings.rccmNumber)
        : settings.rccmNumber;
    final headerIdNat = useBu
        ? (ctx.businessUnitIdNat ?? settings.idNatNumber)
        : settings.idNatNumber;

    final b = StringBuffer();
    void line(String s) => b.write('<text>${_xmlEscape(s)}&#10;</text>');
    void align(String a) => b.write('<text align="$a"/>');
    void bold(bool on) => b.write('<text em="${on ? 'true' : 'false'}"/>');

    align('center');
    bold(true);
    line(headerName.toUpperCase());
    bold(false);
    if (headerAddress.isNotEmpty) line(headerAddress);
    if (headerPhone.isNotEmpty) line('Tel: $headerPhone');
    if (headerTaxId.isNotEmpty) line('NIF: $headerTaxId');
    if (headerRccm.isNotEmpty) line('RCCM: $headerRccm');
    if (headerIdNat.isNotEmpty) line('ID NAT: $headerIdNat');
    line('=' * _colWidth);
    bold(true);
    line('TICKET DE CAISSE');
    bold(false);
    line('=' * _colWidth);

    align('left');
    final shortId =
        sale.id.length > 8 ? sale.id.substring(sale.id.length - 8) : sale.id;
    line(shortId.isNotEmpty ? _rowText(dateStr, '#$shortId') : dateStr);
    if (sale.customerName.isNotEmpty && sale.customerName != 'Inconnu') {
      line(_truncate('Client: ${sale.customerName}', _colWidth));
    }
    line('-' * _colWidth);
    for (final item in sale.items) {
      line(_rowText(item.productName, _fmt(item.quantity * item.unitPrice, currency)));
      line('  ${item.quantity} x ${_fmt(item.unitPrice, currency)}');
    }
    line('-' * _colWidth);
    bold(true);
    line(_rowText('TOTAL', _fmt(totalInTx, currency)));
    bold(false);
    line('=' * _colWidth);
    bold(true);
    line(_rowText('Especes:', _fmt(paidInTx, currency)));
    bold(false);
    if (change > 0.005) line(_rowText('Monnaie:', _fmt(change, currency)));
    line('=' * _colWidth);

    align('center');
    bold(true);
    line('Merci pour votre achat !');
    bold(false);
    line('wanzzo.com');
    b.write('<feed line="1"/>');
    b.write(
      '<symbol type="qrcode_model_2" level="level_l" width="4" height="4">'
      '${_xmlEscape(_buildQrData(sale, settings))}</symbol>',
    );
    b.write('<feed line="3"/>');
    b.write('<cut type="feed"/>');

    return '<?xml version="1.0" encoding="utf-8"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body>'
        '<epos-print xmlns="http://www.epson-pos.com/schemas/2011/03/epos-print">'
        '$b'
        '</epos-print></s:Body></s:Envelope>';
  }

  String _xmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  // ── Impression via le système / pilote OS (universel) ─────────────────────

  /// Liste les imprimantes connues du système d'exploitation (USB installée en
  /// pilote, réseau, etc.) — via le framework d'impression OS. Utilisé sur
  /// ordinateur (Windows/Linux/macOS) et Android pour choisir l'imprimante par
  /// défaut du point de vente.
  Future<List<Printer>> listSystemPrinters() async {
    try {
      return await Printing.listPrinters();
    } catch (e) {
      debugPrint('[ReceiptPrinter] listPrinters: $e');
      return [];
    }
  }

  /// Rend le ticket en PDF (rouleau 80 mm) et l'imprime via le système/pilote OS.
  ///
  /// - Si [printerUrl] désigne une imprimante précise (choisie dans les
  ///   paramètres), l'impression est **DIRECTE et SILENCIEUSE** (`directPrintPdf`)
  ///   → ticket automatique « comme au supermarché », sans boîte de dialogue.
  /// - Sinon (valeur `system`), on ouvre la boîte d'impression de l'OS
  ///   (`layoutPdf`) pour laisser l'utilisateur choisir.
  ///
  /// Route vers TOUT pilote installé : USB (Mopria / pilote constructeur), WiFi,
  /// « E-POS Printer Driver », imprimante A4/laser, etc.
  Future<bool> printReceiptViaSystem(
    Sale sale,
    Settings settings, {
    String? printerUrl,
    String? printerName,
  }) async {
    try {
      final bytes = await _buildReceiptPdf(sale, settings).save();
      final hasSpecificPrinter =
          printerUrl != null && printerUrl.isNotEmpty && printerUrl != 'system';
      if (hasSpecificPrinter) {
        // Impression directe silencieuse vers l'imprimante enregistrée.
        return await Printing.directPrintPdf(
          printer: Printer(url: printerUrl, name: printerName ?? printerUrl),
          name: 'Ticket ${sale.id}',
          format: PdfPageFormat.roll80,
          onLayout: (_) async => bytes,
        );
      }
      // Repli : boîte d'impression du système (choix manuel).
      return await Printing.layoutPdf(
        name: 'Ticket ${sale.id}',
        format: PdfPageFormat.roll80,
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      debugPrint('[ReceiptPrinter] Système: erreur $e');
      return false;
    }
  }

  pw.Document _buildReceiptPdf(Sale sale, Settings settings) {
    final currency = sale.transactionCurrencyCode ?? 'CDF';
    final totalInTx =
        sale.totalAmountInTransactionCurrency ?? sale.totalAmountInCdf;
    final paidInTx =
        sale.paidAmountInTransactionCurrency ?? sale.paidAmountInCdf;
    final change = paidInTx - totalInTx;
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(sale.date);

    final ctx = BusinessContextService();
    final useBu = ctx.shouldUseBusinessUnitIdentity;
    final headerName = useBu
        ? (ctx.businessUnitName ?? settings.companyName)
        : settings.companyName;
    final headerAddress = useBu
        ? (ctx.businessUnitAddress ?? settings.companyAddress)
        : settings.companyAddress;
    final headerPhone = useBu
        ? (ctx.businessUnitPhone ?? settings.companyPhone)
        : settings.companyPhone;
    final headerTaxId = useBu
        ? (ctx.businessUnitTaxId ?? settings.taxIdentificationNumber)
        : settings.taxIdentificationNumber;
    final headerRccm = useBu
        ? (ctx.businessUnitRccm ?? settings.rccmNumber)
        : settings.rccmNumber;
    final headerIdNat = useBu
        ? (ctx.businessUnitIdNat ?? settings.idNatNumber)
        : settings.idNatNumber;

    final doc = pw.Document();
    final mono = pw.Font.courier();
    final monoBold = pw.Font.courierBold();
    final shortId =
        sale.id.length > 8 ? sale.id.substring(sale.id.length - 8) : sale.id;

    pw.Widget rowLR(String l, String r, {bool strong = false}) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(l,
                  style: pw.TextStyle(font: strong ? monoBold : mono, fontSize: 8)),
            ),
            pw.Text(r,
                style: pw.TextStyle(font: strong ? monoBold : mono, fontSize: 8)),
          ],
        );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(headerName.toUpperCase(),
                  style: pw.TextStyle(font: monoBold, fontSize: 10)),
            ),
            if (headerAddress.isNotEmpty)
              pw.Center(
                  child: pw.Text(headerAddress,
                      style: pw.TextStyle(font: mono, fontSize: 8))),
            if (headerPhone.isNotEmpty)
              pw.Center(
                  child: pw.Text('Tel: $headerPhone',
                      style: pw.TextStyle(font: mono, fontSize: 8))),
            if (headerTaxId.isNotEmpty)
              pw.Center(
                  child: pw.Text('NIF: $headerTaxId',
                      style: pw.TextStyle(font: mono, fontSize: 8))),
            if (headerRccm.isNotEmpty)
              pw.Center(
                  child: pw.Text('RCCM: $headerRccm',
                      style: pw.TextStyle(font: mono, fontSize: 8))),
            if (headerIdNat.isNotEmpty)
              pw.Center(
                  child: pw.Text('ID NAT: $headerIdNat',
                      style: pw.TextStyle(font: mono, fontSize: 8))),
            pw.Divider(thickness: 0.5),
            pw.Center(
                child: pw.Text('TICKET DE CAISSE',
                    style: pw.TextStyle(font: monoBold, fontSize: 9))),
            pw.Divider(thickness: 0.5),
            rowLR(dateStr, '#$shortId'),
            if (sale.customerName.isNotEmpty && sale.customerName != 'Inconnu')
              pw.Text('Client: ${sale.customerName}',
                  style: pw.TextStyle(font: mono, fontSize: 8)),
            pw.Divider(thickness: 0.5),
            ...sale.items.map(
              (item) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  rowLR(item.productName,
                      _fmt(item.quantity * item.unitPrice, currency)),
                  pw.Text('  ${item.quantity} x ${_fmt(item.unitPrice, currency)}',
                      style: pw.TextStyle(font: mono, fontSize: 8)),
                ],
              ),
            ),
            pw.Divider(thickness: 0.5),
            rowLR('TOTAL', _fmt(totalInTx, currency), strong: true),
            rowLR('Especes', _fmt(paidInTx, currency)),
            if (change > 0.005) rowLR('Monnaie', _fmt(change, currency)),
            pw.SizedBox(height: 6),
            pw.Center(
                child: pw.Text('Merci pour votre achat !',
                    style: pw.TextStyle(font: monoBold, fontSize: 9))),
            pw.Center(
                child: pw.Text('wanzzo.com',
                    style: pw.TextStyle(font: mono, fontSize: 8))),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: _buildQrData(sale, settings),
                width: 80,
                height: 80,
                drawText: false,
              ),
            ),
          ],
        ),
      ),
    );
    return doc;
  }

  // ── Helpers ESC/POS ──────────────────────────────────────────────────────

  List<int> _escReset() => [
    0x1B, 0x40, // ESC @ — Initialise l'imprimante (reset complet)
    0x1B, 0x74, 0x10, // ESC t 16 — Sélectionne la table de caractères WPC1252
    // (Windows Latin-1) : é=0xE9, à=0xE0, ç=0xE7, è=0xE8, û=0xFB…
    // Sans cette commande, l'imprimante reste en CP437 (réglage usine) et
    // affiche des caractères incorrects pour le français.
  ];

  List<int> _escAlign(int n) => [0x1B, 0x61, n]; // ESC a n (0=L, 1=C, 2=R)

  List<int> _escBold(bool on) => [0x1B, 0x45, on ? 1 : 0]; // ESC E n

  List<int> _escFeed(int n) => List.filled(n, 0x0A); // LF x n

  List<int> _escCut() => [0x1D, 0x56, 0x41, 0x03]; // GS V A 3

  /// Encode une chaîne en octets WPC1252 puis ajoute un saut de ligne (LF).
  ///
  /// **Pourquoi pas `codeUnits` ?**
  /// `String.codeUnits` renvoie les valeurs UTF-16, qui pour les caractères
  /// Latin-1 (0x00–0xFF) sont identiques aux code points Unicode. Mais passés
  /// tels quels à une imprimante en mode CP437, les valeurs > 0x7F sont
  /// interprétées comme du CP437 : 'é' (0xE9) → 'Θ', 'à' (0xE0) → 'α', etc.
  /// En sélectionnant WPC1252 via `_escReset()` et en tronquant les chars
  /// hors Latin-1 à '?', l'impression française est correcte.
  List<int> _escLine(String text) {
    return [..._encodeWpc1252(text), 0x0A];
  }

  /// Convertit une chaîne en octets compatibles WPC1252.
  /// Les caractères hors Latin-1 (code point > 0xFF, quasi inexistants dans
  /// du texte commercial français) sont remplacés par '?'.
  List<int> _encodeWpc1252(String text) {
    final result = <int>[];
    for (final rune in text.runes) {
      result.add(rune < 0x100 ? rune : 0x3F); // '?' si hors Latin-1
    }
    return result;
  }

  List<int> _escSeparator() => _escLine('-' * _colWidth);

  List<int> _escSeparatorDouble() => _escLine('=' * _colWidth);

  /// Construit le contenu du QR code pour l'imprimante thermique.
  ///
  /// **Pourquoi aussi minimal ?**
  /// Les imprimantes thermiques low-cost (58 mm) ont une limite matérielle sur
  /// la version QR supportée par leur firmware. Au-delà de ~40 bytes de données,
  /// certains firmwares retournent "2QR CREAT ERR!" car ils ne savent générer
  /// que les QR version 1 (cap. 41 bytes en niveau L).
  ///
  /// On se limite donc à : ID court (8 derniers chars) + wanzzo.com ≈ 25 bytes.
  /// C'est QR version 1 — compatible 100 % des imprimantes thermiques.
  /// Les informations complètes sont disponibles sur le reçu PDF.
  String _buildQrData(Sale sale, Settings settings) {
    // Identifiant court : 8 derniers caractères de l'ID (suffit pour
    // identifier la transaction dans le système wanzzo).
    final shortId =
        sale.id.length > 8 ? sale.id.substring(sale.id.length - 8) : sale.id;
    return 'wanzzo.com|$shortId';
  }

  /// Génère un QR code ESC/POS (commandes GS ( k).
  /// Compatible imprimantes thermiques 58 mm et 80 mm standards.
  List<int> _escQrCode(String data) {
    // UTF-8 pour supporter les caractères accentués français dans le QR
    final dataBytes = utf8.encode(data);
    final storeLen = dataBytes.length + 3; // +3 : paramètres cn/fn/m
    final pL = storeLen & 0xFF;
    final pH = (storeLen >> 8) & 0xFF;
    return [
      // Sélectionner modèle QR Code 2 (le plus répandu)
      0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00,
      // Taille du module : 3 points — moins de pixels par module → QR plus
      // compact sur 58 mm, version QR plus basse nécessaire → plus compatible
      0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x03,
      // Niveau de correction d'erreurs : L (7 %) — version QR plus basse
      // nécessaire pour la même quantité de données → moins de modules →
      // image plus petite → compatible avec davantage de firmwares low-cost
      0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x30,
      // Stocker les données dans le buffer interne
      0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30,
      ...dataBytes,
      // Imprimer le QR code depuis le buffer
      0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30,
    ];
  }

  // ── Formatage texte ──────────────────────────────────────────────────────

  /// Formate deux colonnes sur _colWidth caractères (left-aligned + right-aligned).
  String _rowText(String left, String right) {
    final total = _colWidth;
    final available = total - right.length;
    if (available <= 0) return '$left $right';
    return left.padRight(available).substring(0, available) + right;
  }

  /// Formate un montant avec séparateur milliers.
  ///
  /// **Fix U+202F** : la locale `fr_FR` de `intl` utilise l'espace fine
  /// insécable (U+202F = 8239) comme séparateur de milliers. Ce caractère
  /// est > 0xFF → remplacé par '?' dans `_encodeWpc1252`. On le normalise
  /// en espace ordinaire avant encodage.
  String _fmt(double amount, String currency) {
    final formatter = NumberFormat('#,##0', 'fr_FR');
    final formatted = formatter
        .format(amount)
        .replaceAll('\u202F', ' ') // espace fine insécable → espace
        .replaceAll('\u00A0', ' '); // espace insécable → espace
    return '$formatted $currency';
  }

  /// Tronque un texte à maxLen caractères.
  String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen - 1)}…';
  }

  /// Découpe [text] en lignes de [maxWidth] chars maximum.
  /// Coupe de préférence aux espaces pour éviter de couper les mots.
  List<String> _wrapText(String text, int maxWidth) {
    if (text.length <= maxWidth) return [text];
    final lines = <String>[];
    var remaining = text.trim();
    while (remaining.length > maxWidth) {
      var split = maxWidth;
      final spaceIdx = remaining.lastIndexOf(' ', maxWidth);
      if (spaceIdx > maxWidth ~/ 2) split = spaceIdx;
      lines.add(remaining.substring(0, split).trim());
      remaining = remaining.substring(split).trim();
    }
    if (remaining.isNotEmpty) lines.add(remaining);
    return lines;
  }
}
