import 'package:wanzo/services/receipt_printer_service.dart';

import 'label_print_service.dart';

/// Imprimante configurée dans Réglages > Imprimante, traduite en voie
/// d'impression d'étiquettes. Sans imprimante : boîte d'impression système.
Future<LabelTarget> resolveLabelTarget() async {
  ThermalPrinterDevice? p;
  try {
    p = await ReceiptPrinterService().getSavedPrinter();
  } catch (_) {
    p = null;
  }
  if (p == null) return LabelTarget.systemDialog;
  switch (p.type) {
    case ThermalConnectionType.bluetooth:
      return LabelTarget(LabelTargetKind.bluetooth,
          address: p.address, name: p.displayName);
    case ThermalConnectionType.network:
      return LabelTarget(LabelTargetKind.network,
          address: p.address, name: p.displayName);
    case ThermalConnectionType.epos:
      return LabelTarget(LabelTargetKind.epos,
          address: p.address, name: p.displayName);
    case ThermalConnectionType.system:
      return LabelTarget(LabelTargetKind.system,
          address: p.address, name: p.name);
    case ThermalConnectionType.usb:
      return LabelTarget.systemDialog;
  }
}
