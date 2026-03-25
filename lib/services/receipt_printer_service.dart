import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/settings/models/settings.dart';

/// Type de connexion pour l'imprimante thermique
enum ThermalConnectionType { bluetooth, usb, network }

/// Représente un périphérique imprimante thermique découvert
class ThermalPrinterDevice {
  final String name;
  final String address;
  final ThermalConnectionType type;

  const ThermalPrinterDevice({
    required this.name,
    required this.address,
    required this.type,
  });

  Map<String, String> toMap() => {
    'name': name,
    'address': address,
    'type': type.name,
  };

  factory ThermalPrinterDevice.fromMap(Map<String, String> map) {
    return ThermalPrinterDevice(
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      type: ThermalConnectionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ThermalConnectionType.bluetooth,
      ),
    );
  }
}

/// Service d'impression thermique de tickets de caisse
///
/// Gère la découverte, la connexion et l'impression vers des imprimantes
/// thermiques via Bluetooth Classic (SPP/RFCOMM) ou réseau TCP (port 9100).
class ReceiptPrinterService {
  // Largeur papier 58mm = 32 caractères en police A normale
  static const int _colWidth = 32;

  // Clés SharedPreferences
  static const String _keyPrinterName = 'thermal_printer_name';
  static const String _keyPrinterAddress = 'thermal_printer_address';
  static const String _keyPrinterType = 'thermal_printer_type';
  static const String _keyAutoPrint = 'thermal_auto_print_cash';

  // ─── Persistance ───────────────────────────────────────────────

  /// Récupère l'imprimante sauvegardée
  Future<ThermalPrinterDevice?> getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyPrinterName);
    final address = prefs.getString(_keyPrinterAddress);
    final type = prefs.getString(_keyPrinterType);
    if (name == null || address == null || type == null) return null;
    return ThermalPrinterDevice(
      name: name,
      address: address,
      type: ThermalConnectionType.values.firstWhere(
        (e) => e.name == type,
        orElse: () => ThermalConnectionType.bluetooth,
      ),
    );
  }

  /// Sauvegarde l'imprimante sélectionnée
  Future<void> savePrinter(ThermalPrinterDevice printer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPrinterName, printer.name);
    await prefs.setString(_keyPrinterAddress, printer.address);
    await prefs.setString(_keyPrinterType, printer.type.name);
  }

  /// Supprime l'imprimante sauvegardée
  Future<void> clearSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPrinterName);
    await prefs.remove(_keyPrinterAddress);
    await prefs.remove(_keyPrinterType);
  }

  /// Récupère le paramètre d'impression automatique après vente cash
  Future<bool> getAutoPrintOnCashSale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoPrint) ?? false;
  }

  /// Définit le paramètre d'impression automatique après vente cash
  Future<void> setAutoPrintOnCashSale(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoPrint, value);
  }

  // ─── Découverte ────────────────────────────────────────────────

  /// Scanne les appareils Bluetooth appairés
  Future<List<ThermalPrinterDevice>> scanBluetooth() async {
    try {
      // Sur Android uniquement, vérifier les permissions via permission_handler
      // Sur Windows/macOS/Linux, pas de permission runtime nécessaire
      if (Platform.isAndroid) {
        final permOk = await PrintBluetoothThermal.isPermissionBluetoothGranted;
        if (!permOk) {
          debugPrint(
            '[ReceiptPrinterService] Permission Bluetooth non accordée (Android)',
          );
          return [];
        }
      }

      final List<BluetoothInfo> paired =
          await PrintBluetoothThermal.pairedBluetooths;

      return paired
          .map(
            (bt) => ThermalPrinterDevice(
              name: bt.name,
              address: bt.macAdress, // Typo intentionnelle dans le package
              type: ThermalConnectionType.bluetooth,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('[ReceiptPrinterService] Erreur scan BT: $e');
      return [];
    }
  }

  /// Stub pour scan USB (non implémenté)
  Future<List<ThermalPrinterDevice>> scanUsb() async {
    // USB direct non supporté via print_bluetooth_thermal
    // Pour desktop : utiliser flutter_libserialport ou connexion réseau TCP
    return [];
  }

  // ─── Détection paiement ────────────────────────────────────────

  /// Vérifie si le mode de paiement est en espèces
  static bool isCashPayment(String? paymentMethod) {
    if (paymentMethod == null) return false;
    final lower = paymentMethod.toLowerCase().trim();
    return lower == 'espèces' ||
        lower == 'especes' ||
        lower == 'cash' ||
        lower == 'comptant';
  }

  // ─── Impression ────────────────────────────────────────────────

  /// Point d'entrée principal : imprime un ticket de caisse
  Future<bool> printCashReceipt(Sale sale, Settings settings) async {
    try {
      final printer = await getSavedPrinter();
      if (printer == null) {
        debugPrint('[ReceiptPrinterService] Aucune imprimante configurée');
        return false;
      }

      final bytes = buildCashReceiptBytes(sale, settings);

      switch (printer.type) {
        case ThermalConnectionType.bluetooth:
          return await _printBluetooth(printer, bytes);
        case ThermalConnectionType.network:
          return await _printNetwork(printer, bytes);
        case ThermalConnectionType.usb:
          debugPrint('[ReceiptPrinterService] USB non encore implémenté');
          return false;
      }
    } catch (e) {
      debugPrint('[ReceiptPrinterService] Erreur impression: $e');
      return false;
    }
  }

  /// Impression Bluetooth via print_bluetooth_thermal
  Future<bool> _printBluetooth(
    ThermalPrinterDevice printer,
    List<int> bytes,
  ) async {
    try {
      // Déconnecter si déjà connecté (évite le bug de socket SPP occupée)
      final alreadyConnected = await PrintBluetoothThermal.connectionStatus;
      if (alreadyConnected) {
        await PrintBluetoothThermal.disconnect;
      }

      final connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: printer.address,
      );
      if (!connected) {
        debugPrint(
          '[ReceiptPrinterService] Échec connexion BT ${printer.name}',
        );
        return false;
      }

      // Vérifier la connexion effective
      final status = await PrintBluetoothThermal.connectionStatus;
      if (!status) {
        debugPrint('[ReceiptPrinterService] Socket BT pas prête');
        return false;
      }

      final sent = await PrintBluetoothThermal.writeBytes(bytes);
      await PrintBluetoothThermal.disconnect;
      return sent;
    } catch (e) {
      debugPrint('[ReceiptPrinterService] Erreur BT: $e');
      return false;
    }
  }

  /// Impression réseau TCP (port 9100)
  Future<bool> _printNetwork(
    ThermalPrinterDevice printer,
    List<int> bytes,
  ) async {
    try {
      final parts = printer.address.split(':');
      final host = parts[0];
      final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;

      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      debugPrint('[ReceiptPrinterService] Erreur réseau: $e');
      return false;
    }
  }

  // ─── Construction du ticket ESC/POS ────────────────────────────

  /// Construit les bytes ESC/POS pour un ticket de caisse
  List<int> buildCashReceiptBytes(Sale sale, Settings settings) {
    final bytes = <int>[];

    // Reset + sélection WPC1252 pour les accents français
    bytes.addAll(_escReset());

    // ════ EN-TÊTE ENTREPRISE ════
    bytes.addAll(_escSeparatorDouble());
    bytes.addAll(_escAlign(1)); // Centre
    bytes.addAll(_escBold(true));
    bytes.addAll(
      _escLine(_truncate(settings.companyName.toUpperCase(), _colWidth)),
    );
    bytes.addAll(_escBold(false));

    // Adresse (avec word wrap)
    if (settings.companyAddress.isNotEmpty) {
      for (final line in _wrapText(settings.companyAddress, _colWidth)) {
        bytes.addAll(_escLine(line));
      }
    }

    // Téléphone
    if (settings.companyPhone.isNotEmpty) {
      bytes.addAll(_escLine('Tél: ${settings.companyPhone}'));
    }

    // Identifiants légaux
    if (settings.taxIdentificationNumber.isNotEmpty) {
      bytes.addAll(_escLine('NIF: ${settings.taxIdentificationNumber}'));
    }
    if (settings.rccmNumber.isNotEmpty) {
      bytes.addAll(_escLine('RCCM: ${settings.rccmNumber}'));
    }
    if (settings.idNatNumber.isNotEmpty) {
      bytes.addAll(_escLine('ID NAT: ${settings.idNatNumber}'));
    }

    bytes.addAll(_escSeparatorDouble());

    // ════ TITRE ════
    bytes.addAll(_escAlign(1));
    bytes.addAll(_escBold(true));
    bytes.addAll(_escLine('TICKET DE CAISSE'));
    bytes.addAll(_escBold(false));
    bytes.addAll(_escSeparatorDouble());

    // ════ RÉFÉRENCE & DATE ════
    bytes.addAll(_escAlign(0)); // Gauche
    final shortId =
        sale.id.length > 8 ? sale.id.substring(sale.id.length - 8) : sale.id;
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(sale.date);
    bytes.addAll(_escLine(_rowText(dateStr, '#$shortId')));

    // Client
    if (sale.customerName.isNotEmpty &&
        sale.customerName.toLowerCase() != 'inconnu') {
      bytes.addAll(
        _escLine('Client: ${_truncate(sale.customerName, _colWidth - 8)}'),
      );
    }

    bytes.addAll(_escSeparator());

    // ════ LIGNES D'ARTICLES ════
    final currencyCode = sale.transactionCurrencyCode ?? 'CDF';

    for (final item in sale.items) {
      final unitPrice =
          item.currencyCode == currencyCode
              ? item.unitPrice
              : item.unitPriceInCdf;
      final totalPrice =
          item.currencyCode == currencyCode
              ? item.totalPrice
              : item.totalPriceInCdf;

      final amountStr = _fmt(totalPrice, currencyCode);
      bytes.addAll(_escLine(_rowText(item.productName, amountStr)));

      // Détail quantité × prix unitaire
      if (item.quantity > 1) {
        final detail = '  ${item.quantity} x ${_fmt(unitPrice, currencyCode)}';
        bytes.addAll(_escLine(detail));
      }
    }

    bytes.addAll(_escSeparator());

    // ════ REMISE ════
    if (sale.discountPercentage > 0) {
      bytes.addAll(
        _escLine(
          _rowText(
            'Remise (${sale.discountPercentage.toStringAsFixed(0)}%)',
            '-${_fmt(_calculateDiscount(sale, currencyCode), currencyCode)}',
          ),
        ),
      );
    }

    // ════ TOTAL ════
    final totalAmount =
        sale.totalAmountInTransactionCurrency ?? sale.totalAmountInCdf;
    bytes.addAll(_escBold(true));
    bytes.addAll(_escLine(_rowText('TOTAL', _fmt(totalAmount, currencyCode))));
    bytes.addAll(_escBold(false));
    bytes.addAll(_escSeparatorDouble());

    // ════ PAIEMENT ════
    final paidAmount =
        sale.paidAmountInTransactionCurrency ?? sale.paidAmountInCdf;
    bytes.addAll(_escBold(true));
    bytes.addAll(
      _escLine(_rowText('Especes:', _fmt(paidAmount, currencyCode))),
    );
    bytes.addAll(_escBold(false));

    // Monnaie rendue
    final change = paidAmount - totalAmount;
    if (change > 0) {
      bytes.addAll(_escLine(_rowText('Monnaie:', _fmt(change, currencyCode))));
    }

    bytes.addAll(_escSeparatorDouble());

    // ════ PIED DE PAGE ════
    bytes.addAll(_escAlign(1));
    bytes.addAll(_escLine('Merci pour votre achat !'));
    bytes.addAll(_escFeed(3));
    bytes.addAll(_escCut());

    return bytes;
  }

  // ─── ESC/POS Commands ──────────────────────────────────────────

  /// Reset complet + sélection table de caractères WPC1252
  List<int> _escReset() => [
    0x1B, 0x40, // ESC @ — Reset
    0x1B, 0x74, 0x10, // ESC t 16 — WPC1252 (Windows Latin-1)
  ];

  /// Alignement : 0=gauche, 1=centre, 2=droite
  List<int> _escAlign(int n) => [0x1B, 0x61, n];

  /// Gras on/off
  List<int> _escBold(bool on) => [0x1B, 0x45, on ? 1 : 0];

  /// Saut de ligne (n fois)
  List<int> _escFeed(int n) => List.filled(n, 0x0A);

  /// Coupe partielle du papier
  List<int> _escCut() => [0x1D, 0x56, 0x41, 0x03];

  /// Ligne de texte (encodée WPC1252 + saut de ligne)
  List<int> _escLine(String text) => [..._encodeWpc1252(text), 0x0A];

  /// Séparateur simple (tirets)
  List<int> _escSeparator() => _escLine('-' * _colWidth);

  /// Séparateur double (signes égal)
  List<int> _escSeparatorDouble() => _escLine('=' * _colWidth);

  // ─── Encodage WPC1252 ─────────────────────────────────────────

  /// Encode une chaîne en WPC1252 (Latin-1 compatible)
  /// Les caractères hors 0x00–0xFF sont remplacés par '?'
  List<int> _encodeWpc1252(String text) {
    final result = <int>[];
    for (final rune in text.runes) {
      if (rune <= 0xFF) {
        result.add(rune);
      } else {
        result.add(0x3F); // '?'
      }
    }
    return result;
  }

  // ─── Formatage montants ────────────────────────────────────────

  /// Formate un montant avec séparateur de milliers
  /// Remplace U+202F (espace fine insécable fr_FR) par espace normal
  String _fmt(double amount, String currency) {
    final formatter = NumberFormat('#,##0', 'fr_FR');
    final formatted = formatter
        .format(amount)
        .replaceAll('\u202F', ' ')
        .replaceAll('\u00A0', ' ');
    return '$formatted $currency';
  }

  double _calculateDiscount(Sale sale, String currencyCode) {
    final total =
        sale.totalAmountInTransactionCurrency ?? sale.totalAmountInCdf;
    // Pour retrouver le montant avant remise, on inverse la formule
    // total = subtotal * (1 - discount/100)
    // subtotal = total / (1 - discount/100)
    // discount_amount = subtotal - total
    if (sale.discountPercentage <= 0 || sale.discountPercentage >= 100) {
      return 0;
    }
    final subtotal = total / (1 - sale.discountPercentage / 100);
    return subtotal - total;
  }

  // ─── Helpers de mise en page ───────────────────────────────────

  /// Deux colonnes : gauche aligné-gauche, droite aligné-droite
  String _rowText(String left, String right) {
    final available = _colWidth - right.length;
    if (available <= 0) return right;
    final truncLeft =
        left.length > available ? '${left.substring(0, available - 1)}.' : left;
    return truncLeft.padRight(available) + right;
  }

  /// Découpe un texte long aux espaces
  List<String> _wrapText(String text, int maxWidth) {
    if (text.length <= maxWidth) return [text];
    final words = text.split(' ');
    final lines = <String>[];
    var currentLine = '';

    for (final word in words) {
      if (currentLine.isEmpty) {
        currentLine = word;
      } else if (currentLine.length + 1 + word.length <= maxWidth) {
        currentLine += ' $word';
      } else {
        lines.add(currentLine);
        currentLine = word;
      }
    }
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }
    return lines;
  }

  /// Tronque une chaîne à maxLen caractères
  String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen - 1)}.';
  }
}
