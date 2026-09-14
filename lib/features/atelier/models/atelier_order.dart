import 'package:equatable/equatable.dart';

/// Statuts de fabrication d'une commande d'atelier (miroir du backend
/// `AtelierOrderStatus`). C'est le mode Atelier qui donne du sens à ce workflow
/// de production ; le board Kanban affiche une colonne par statut.
enum AtelierOrderStatus {
  draft, // Enregistrée
  measured, // Mesures prises
  cutting, // Coupe
  sewing, // Couture / assemblage
  ready, // Prête
  delivered, // Livrée
  paid, // Réglée (facturation auto → une Sale existe)
  cancelled, // Annulée
}

extension AtelierOrderStatusX on AtelierOrderStatus {
  String get apiValue => name;

  String get label {
    switch (this) {
      case AtelierOrderStatus.draft:
        return 'Enregistrée';
      case AtelierOrderStatus.measured:
        return 'Mesures prises';
      case AtelierOrderStatus.cutting:
        return 'Coupe';
      case AtelierOrderStatus.sewing:
        return 'Couture';
      case AtelierOrderStatus.ready:
        return 'Prête';
      case AtelierOrderStatus.delivered:
        return 'Livrée';
      case AtelierOrderStatus.paid:
        return 'Réglée';
      case AtelierOrderStatus.cancelled:
        return 'Annulée';
    }
  }

  static AtelierOrderStatus fromApiValue(String? value) {
    return AtelierOrderStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => AtelierOrderStatus.draft,
    );
  }

  /// Une commande active est en cours de production (pas encore réglée/annulée).
  bool get isActive =>
      this != AtelierOrderStatus.paid && this != AtelierOrderStatus.cancelled;

  /// Libellé du statut ADAPTÉ AU MÉTIER : un atelier de maintenance ne parle pas
  /// de « coupe/couture » mais de « diagnostic/réparation/test » ; une imprimerie
  /// parle de « bon à tirer / impression / façonnage ». Les valeurs internes
  /// restent les mêmes (le board Kanban ne change pas), seul le vocabulaire
  /// affiché change — pour ne pas dérouter l'utilisateur.
  String labelFor(AtelierMetier metier) {
    switch (metier) {
      case AtelierMetier.maintenance:
      case AtelierMetier.garage:
        return _maintenanceLabel;
      case AtelierMetier.imprimerie:
        return _imprimerieLabel;
      case AtelierMetier.pressing:
        return _pressingLabel;
      case AtelierMetier.couture:
      case AtelierMetier.cordonnerie:
        return label;
    }
  }

  String get _pressingLabel {
    switch (this) {
      case AtelierOrderStatus.draft:
        return 'Reçu';
      case AtelierOrderStatus.measured:
        return 'Trié';
      case AtelierOrderStatus.cutting:
        return 'Nettoyage';
      case AtelierOrderStatus.sewing:
        return 'Repassage / finition';
      case AtelierOrderStatus.ready:
        return 'Prêt';
      case AtelierOrderStatus.delivered:
        return 'Retiré';
      case AtelierOrderStatus.paid:
        return 'Réglé';
      case AtelierOrderStatus.cancelled:
        return 'Annulé';
    }
  }

  String get _maintenanceLabel {
    switch (this) {
      case AtelierOrderStatus.draft:
        return 'Reçu';
      case AtelierOrderStatus.measured:
        return 'Diagnostiqué';
      case AtelierOrderStatus.cutting:
        return 'En réparation';
      case AtelierOrderStatus.sewing:
        return 'Test / contrôle';
      case AtelierOrderStatus.ready:
        return 'Prêt';
      case AtelierOrderStatus.delivered:
        return 'Livré';
      case AtelierOrderStatus.paid:
        return 'Réglé';
      case AtelierOrderStatus.cancelled:
        return 'Annulé';
    }
  }

  String get _imprimerieLabel {
    switch (this) {
      case AtelierOrderStatus.draft:
        return 'Reçu';
      case AtelierOrderStatus.measured:
        return 'Bon à tirer';
      case AtelierOrderStatus.cutting:
        return 'Impression';
      case AtelierOrderStatus.sewing:
        return 'Façonnage';
      case AtelierOrderStatus.ready:
        return 'Prêt';
      case AtelierOrderStatus.delivered:
        return 'Livré';
      case AtelierOrderStatus.paid:
        return 'Réglé';
      case AtelierOrderStatus.cancelled:
        return 'Annulé';
    }
  }
}

/// Métier de l'atelier (miroir du backend `AtelierMetier`). Rend le mode
/// Atelier EXPLICITE : chaque métier n'expose que son vocabulaire et ses champs.
enum AtelierMetier { couture, cordonnerie, maintenance, imprimerie, pressing, garage }

extension AtelierMetierX on AtelierMetier {
  String get apiValue => name;

  String get label {
    switch (this) {
      case AtelierMetier.couture:
        return 'Couture';
      case AtelierMetier.cordonnerie:
        return 'Cordonnerie';
      case AtelierMetier.maintenance:
        return 'Maintenance / réparation';
      case AtelierMetier.imprimerie:
        return 'Imprimerie';
      case AtelierMetier.pressing:
        return 'Pressing / Blanchisserie';
      case AtelierMetier.garage:
        return 'Garage automobile';
    }
  }

  /// Vrai pour les métiers de réparation : fiche appareil (maintenance) ou
  /// fiche véhicule (garage) par commande.
  bool get isMaintenanceLike =>
      this == AtelierMetier.maintenance || this == AtelierMetier.garage;

  /// Vrai si ce métier prend des mesures corporelles/pied (profil client
  /// réutilisable). La maintenance travaille sur une fiche appareil par commande ;
  /// l'imprimerie sur une fiche travail d'impression par commande.
  bool get usesMeasurements =>
      this == AtelierMetier.couture || this == AtelierMetier.cordonnerie;

  static AtelierMetier fromApiValue(String? value) {
    return AtelierMetier.values.firstWhere(
      (m) => m.name == value,
      orElse: () => AtelierMetier.couture,
    );
  }
}

/// Fiche de réception/réparation d'un atelier de MAINTENANCE (miroir du jsonb
/// backend `maintenanceDetails`). Propre à chaque intervention.
/// Spécialités d'un atelier de maintenance — le métier étant « maintenance »
/// (choisi au niveau du mode), la commande précise le domaine. L'automobile
/// n'en fait plus partie : le garage est un mode à part (métier `garage`,
/// fiche véhicule et véhicules du client) ; les anciennes commandes
/// « Automobile » restent lisibles.
const List<String> kMaintenanceSpecialties = [
  'Informatique',
  'Électronique',
  'Téléphonie',
  'Électroménager',
  'Électromécanique',
  'Thermique / Froid & Clim',
  'Autre',
];

class MaintenanceDetails extends Equatable {
  final String? specialty; // Domaine : Informatique, Automobile, Thermique…
  final String? deviceType; // Type d'appareil (TV, smartphone, moteur…)
  final String? brand; // Marque
  final String? model; // Modèle
  final String? serialNumber; // N° de série / IMEI
  // ── Spécifiques automobile / engin ──
  final String? plate; // Immatriculation
  final String? vin; // N° de châssis (VIN)
  final String? mileage; // Kilométrage
  final String? fuel; // Carburant (essence/diesel/…)
  final String? color;
  final String? exteriorState; // État extérieur à la réception
  final String? accessories; // Accessoires reçus
  final String? reportedFault; // Panne signalée par le client
  final String? diagnostic; // Diagnostic technique
  final String? repairDone; // Réparation / réglage effectué
  final String? exitState; // repaired | partial | not_repaired | irreparable
  final String? testResult; // conform | to_review | not_tested
  final int? warrantyDays; // Garantie accordée (jours)
  final String? technicianName; // Technicien

  const MaintenanceDetails({
    this.specialty,
    this.deviceType,
    this.brand,
    this.model,
    this.serialNumber,
    this.plate,
    this.vin,
    this.mileage,
    this.fuel,
    this.color,
    this.exteriorState,
    this.accessories,
    this.reportedFault,
    this.diagnostic,
    this.repairDone,
    this.exitState,
    this.testResult,
    this.warrantyDays,
    this.technicianName,
  });

  bool get isEmpty =>
      (deviceType == null || deviceType!.isEmpty) &&
      (brand == null || brand!.isEmpty) &&
      (model == null || model!.isEmpty) &&
      (serialNumber == null || serialNumber!.isEmpty) &&
      (reportedFault == null || reportedFault!.isEmpty) &&
      (diagnostic == null || diagnostic!.isEmpty) &&
      (repairDone == null || repairDone!.isEmpty);

  factory MaintenanceDetails.fromJson(Map<String, dynamic> json) =>
      MaintenanceDetails(
        specialty: json['specialty'] as String?,
        deviceType: json['deviceType'] as String?,
        brand: json['brand'] as String?,
        model: json['model'] as String?,
        serialNumber: json['serialNumber'] as String?,
        plate: json['plate'] as String?,
        vin: json['vin'] as String?,
        mileage: json['mileage'] as String?,
        fuel: json['fuel'] as String?,
        color: json['color'] as String?,
        exteriorState: json['exteriorState'] as String?,
        accessories: json['accessories'] as String?,
        reportedFault: json['reportedFault'] as String?,
        diagnostic: json['diagnostic'] as String?,
        repairDone: json['repairDone'] as String?,
        exitState: json['exitState'] as String?,
        testResult: json['testResult'] as String?,
        warrantyDays: json['warrantyDays'] == null
            ? null
            : int.tryParse('${json['warrantyDays']}'),
        technicianName: json['technicianName'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (specialty != null) 'specialty': specialty,
        if (deviceType != null) 'deviceType': deviceType,
        if (brand != null) 'brand': brand,
        if (model != null) 'model': model,
        if (serialNumber != null) 'serialNumber': serialNumber,
        if (plate != null) 'plate': plate,
        if (vin != null) 'vin': vin,
        if (mileage != null) 'mileage': mileage,
        if (fuel != null) 'fuel': fuel,
        if (color != null) 'color': color,
        if (exteriorState != null) 'exteriorState': exteriorState,
        if (accessories != null) 'accessories': accessories,
        if (reportedFault != null) 'reportedFault': reportedFault,
        if (diagnostic != null) 'diagnostic': diagnostic,
        if (repairDone != null) 'repairDone': repairDone,
        if (exitState != null) 'exitState': exitState,
        if (testResult != null) 'testResult': testResult,
        if (warrantyDays != null) 'warrantyDays': warrantyDays,
        if (technicianName != null) 'technicianName': technicianName,
      };

  @override
  List<Object?> get props => [
        specialty, deviceType, brand, model, serialNumber, plate, vin,
        mileage, fuel, color, exteriorState,
        accessories, reportedFault, diagnostic, repairDone, exitState,
        testResult, warrantyDays, technicianName,
      ];
}

/// Formats d'impression proposés (dropdown). Le dernier ouvre une saisie libre.
const List<String> kPrintFormats = [
  'A6',
  'A5',
  'A4',
  'A3',
  'A2',
  'A1',
  'A0',
  'Bâche',
  'Banderole',
  'Roll-up',
  'Personnalisé',
];

/// Finitions/façonnage courants (dropdown, saisie libre possible).
const List<String> kPrintFinishings = [
  'Pelliculage',
  'Vernis',
  'Découpe',
  'Pliage',
  'Reliure',
  'Plastification',
  'Œillets',
  'Ourlet',
];

/// Fiche « travail d'impression » d'un atelier d'IMPRIMERIE (miroir du jsonb
/// backend `printDetails`). Propre à chaque commande — l'équivalent de la fiche
/// appareil de la maintenance, mais pour un travail d'impression.
class PrintJobDetails extends Equatable {
  final String? format; // A6/A5/A4/A3/A2/A1/A0/Bâche/Banderole/Roll-up/Perso.
  final String? support; // Matière / grammage (couché 300g, adhésif…)
  final int? quantity; // Tirage
  final String? printSides; // recto | recto-verso
  final String? colorMode; // Quadrichromie | Noir et blanc | Pantone
  final String? finishing; // Pelliculage, vernis, découpe, pliage, reliure…
  final String? width; // Grand format : largeur
  final String? height; // Grand format : hauteur
  final bool? batValidated; // Bon à tirer validé par le client
  final List<String> designPhotos; // URLs Cloudinary du design / BAT
  final String? operatorName; // Opérateur / infographiste
  final String? machine; // Machine / presse
  final String? instructions; // Consignes libres

  const PrintJobDetails({
    this.format,
    this.support,
    this.quantity,
    this.printSides,
    this.colorMode,
    this.finishing,
    this.width,
    this.height,
    this.batValidated,
    this.designPhotos = const [],
    this.operatorName,
    this.machine,
    this.instructions,
  });

  bool get isEmpty =>
      (format == null || format!.isEmpty) &&
      (support == null || support!.isEmpty) &&
      quantity == null &&
      (printSides == null || printSides!.isEmpty) &&
      (colorMode == null || colorMode!.isEmpty) &&
      (finishing == null || finishing!.isEmpty) &&
      (width == null || width!.isEmpty) &&
      (height == null || height!.isEmpty) &&
      (batValidated == null || batValidated == false) &&
      designPhotos.isEmpty &&
      (operatorName == null || operatorName!.isEmpty) &&
      (machine == null || machine!.isEmpty) &&
      (instructions == null || instructions!.isEmpty);

  factory PrintJobDetails.fromJson(Map<String, dynamic> json) => PrintJobDetails(
        format: json['format'] as String?,
        support: json['support'] as String?,
        quantity: json['quantity'] == null
            ? null
            : int.tryParse('${json['quantity']}'),
        printSides: json['printSides'] as String?,
        colorMode: json['colorMode'] as String?,
        finishing: json['finishing'] as String?,
        width: json['width'] as String?,
        height: json['height'] as String?,
        batValidated: json['batValidated'] as bool?,
        designPhotos: (json['designPhotos'] is List)
            ? (json['designPhotos'] as List)
                .whereType<String>()
                .toList()
            : const [],
        operatorName: json['operatorName'] as String?,
        machine: json['machine'] as String?,
        instructions: json['instructions'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (format != null) 'format': format,
        if (support != null) 'support': support,
        if (quantity != null) 'quantity': quantity,
        if (printSides != null) 'printSides': printSides,
        if (colorMode != null) 'colorMode': colorMode,
        if (finishing != null) 'finishing': finishing,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (batValidated != null) 'batValidated': batValidated,
        if (designPhotos.isNotEmpty) 'designPhotos': designPhotos,
        if (operatorName != null) 'operatorName': operatorName,
        if (machine != null) 'machine': machine,
        if (instructions != null) 'instructions': instructions,
      };

  @override
  List<Object?> get props => [
        format, support, quantity, printSides, colorMode, finishing,
        width, height, batValidated, designPhotos, operatorName, machine,
        instructions,
      ];
}

/// Article déposé au pressing (une ligne de la fiche de dépôt).
class PressingItem extends Equatable {
  final String type; // Chemise, Costume 2 pièces, Couette…
  final int quantity;
  final String? treatment; // Nettoyage à sec, Lavage, Repassage, Détachage…
  final String? note; // Tache, bouton manquant, couleur…

  const PressingItem({required this.type, this.quantity = 1, this.treatment, this.note});

  factory PressingItem.fromJson(Map<String, dynamic> json) => PressingItem(
        type: json['type'] as String? ?? '',
        quantity: int.tryParse('${json['quantity'] ?? 1}') ?? 1,
        treatment: json['treatment'] as String?,
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'quantity': quantity,
        if (treatment != null && treatment!.isNotEmpty) 'treatment': treatment,
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  @override
  List<Object?> get props => [type, quantity, treatment, note];
}

/// Fiche de DÉPÔT d'un pressing (miroir du jsonb backend `pressingDetails`) :
/// articles déposés, niveau de service, poids, défauts signalés, consignes.
class PressingDetails extends Equatable {
  final List<PressingItem> items;
  final String? serviceLevel; // standard | express
  final double? totalWeightKg; // Linge au poids
  final String? bagNumber; // N° de sac / ticket de dépôt
  final String? stains; // Taches, défauts, boutons manquants signalés au dépôt
  final String? instructions; // Consignes (amidon, pliage, cintre…)
  final String? operatorName; // Réceptionnaire / opérateur

  const PressingDetails({
    this.items = const [],
    this.serviceLevel,
    this.totalWeightKg,
    this.bagNumber,
    this.stains,
    this.instructions,
    this.operatorName,
  });

  int get itemsCount => items.fold(0, (s, i) => s + i.quantity);
  bool get isExpress => serviceLevel == 'express';

  bool get isEmpty =>
      items.isEmpty &&
      (serviceLevel == null || serviceLevel!.isEmpty) &&
      totalWeightKg == null &&
      (bagNumber == null || bagNumber!.isEmpty) &&
      (stains == null || stains!.isEmpty) &&
      (instructions == null || instructions!.isEmpty) &&
      (operatorName == null || operatorName!.isEmpty);

  factory PressingDetails.fromJson(Map<String, dynamic> json) => PressingDetails(
        items: (json['items'] is List)
            ? (json['items'] as List)
                .whereType<Map>()
                .map((e) => PressingItem.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
        serviceLevel: json['serviceLevel'] as String?,
        totalWeightKg: json['totalWeightKg'] == null ? null : double.tryParse('${json['totalWeightKg']}'),
        bagNumber: json['bagNumber'] as String?,
        stains: json['stains'] as String?,
        instructions: json['instructions'] as String?,
        operatorName: json['operatorName'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (items.isNotEmpty) 'items': items.map((e) => e.toJson()).toList(),
        if (serviceLevel != null) 'serviceLevel': serviceLevel,
        if (totalWeightKg != null) 'totalWeightKg': totalWeightKg,
        if (bagNumber != null) 'bagNumber': bagNumber,
        if (stains != null) 'stains': stains,
        if (instructions != null) 'instructions': instructions,
        if (operatorName != null) 'operatorName': operatorName,
      };

  @override
  List<Object?> get props => [items, serviceLevel, totalWeightKg, bagNumber, stains, instructions, operatorName];
}

/// Événement d'étape horodaté (miroir du backend `StageEvent`). Base des KPI de
/// performance de prestation (durée par étape, cycle) → future cote crédit.
class StageEvent {
  final String status;
  final DateTime? at;
  const StageEvent({required this.status, this.at});

  factory StageEvent.fromJson(Map<String, dynamic> j) => StageEvent(
        status: j['status'] as String? ?? '',
        at: j['at'] == null ? null : DateTime.tryParse('${j['at']}'),
      );

  Map<String, dynamic> toJson() => {
        'status': status,
        if (at != null) 'at': at!.toIso8601String(),
      };
}

/// Qui fournit le tissu de la confection.
enum FabricProvidedBy { client, atelier }

extension FabricProvidedByX on FabricProvidedBy {
  String get apiValue => name;
  String get label => this == FabricProvidedBy.client ? 'Client' : 'Atelier';
  static FabricProvidedBy? fromApiValue(String? v) {
    if (v == null) return null;
    return FabricProvidedBy.values.firstWhere(
      (e) => e.name == v,
      orElse: () => FabricProvidedBy.client,
    );
  }
}

/// Commande de confection (persistée côté backend, multi-appareils).
class AtelierOrder extends Equatable {
  final String id;
  final String customerId;
  final String? customerName;
  /// Véhicule du client concerné (mode garage), pour la fiche de suivi.
  final String? vehicleId;
  final String label;
  final String? modelDetails;
  final AtelierMetier metier;
  final MaintenanceDetails? maintenanceDetails;
  final PrintJobDetails? printDetails;
  final PressingDetails? pressingDetails;
  /// Historique horodaté des étapes (KPI de performance de prestation).
  final List<StageEvent> stageHistory;
  final DateTime? entryDate;
  final DateTime? exitDate;
  final double totalAmount;
  final double advanceAmount;
  final double remainingAmount;
  final String currencyCode;
  final double exchangeRate;
  final FabricProvidedBy? fabricProvidedBy;
  final AtelierOrderStatus status;
  final String? saleId;
  final String? notes;
  final DateTime? createdAt;
  // ── Attribution (façon Trello : qui a fait quoi) ──
  final String? createdByName;
  final String? lastAction;
  final String? lastActionByName;
  final String? lastActionByAvatar;
  final DateTime? lastActionAt;

  const AtelierOrder({
    required this.id,
    required this.customerId,
    this.customerName,
    this.vehicleId,
    required this.label,
    this.modelDetails,
    this.metier = AtelierMetier.couture,
    this.maintenanceDetails,
    this.printDetails,
    this.pressingDetails,
    this.stageHistory = const [],
    this.entryDate,
    this.exitDate,
    this.totalAmount = 0,
    this.advanceAmount = 0,
    this.remainingAmount = 0,
    this.currencyCode = 'CDF',
    this.exchangeRate = 1,
    this.fabricProvidedBy,
    this.status = AtelierOrderStatus.draft,
    this.saleId,
    this.notes,
    this.createdAt,
    this.createdByName,
    this.lastAction,
    this.lastActionByName,
    this.lastActionByAvatar,
    this.lastActionAt,
  });

  static double _toDouble(dynamic v) =>
      v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

  static DateTime? _toDate(dynamic v) =>
      v == null ? null : DateTime.tryParse('$v');

  factory AtelierOrder.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    return AtelierOrder(
      id: json['id'] as String,
      customerId: json['customerId'] as String? ?? '',
      customerName: (customer is Map<String, dynamic>)
          ? customer['fullName'] as String?
          : json['customerName'] as String?,
      vehicleId: json['vehicleId'] as String?,
      label: json['label'] as String? ?? '',
      modelDetails: json['modelDetails'] as String?,
      metier: AtelierMetierX.fromApiValue(json['metier'] as String?),
      maintenanceDetails: json['maintenanceDetails'] is Map<String, dynamic>
          ? MaintenanceDetails.fromJson(
              json['maintenanceDetails'] as Map<String, dynamic>)
          : null,
      printDetails: json['printDetails'] is Map<String, dynamic>
          ? PrintJobDetails.fromJson(
              json['printDetails'] as Map<String, dynamic>)
          : null,
      pressingDetails: json['pressingDetails'] is Map<String, dynamic>
          ? PressingDetails.fromJson(json['pressingDetails'] as Map<String, dynamic>)
          : null,
      stageHistory: (json['stageHistory'] is List)
          ? (json['stageHistory'] as List)
              .whereType<Map<String, dynamic>>()
              .map(StageEvent.fromJson)
              .toList()
          : const [],
      entryDate: _toDate(json['entryDate']),
      exitDate: _toDate(json['exitDate']),
      totalAmount: _toDouble(json['totalAmount']),
      advanceAmount: _toDouble(json['advanceAmount']),
      remainingAmount: _toDouble(json['remainingAmount']),
      currencyCode: json['currencyCode'] as String? ?? 'CDF',
      exchangeRate: json['exchangeRate'] == null ? 1 : _toDouble(json['exchangeRate']),
      fabricProvidedBy: FabricProvidedByX.fromApiValue(json['fabricProvidedBy'] as String?),
      status: AtelierOrderStatusX.fromApiValue(json['status'] as String?),
      saleId: json['saleId'] as String?,
      notes: json['notes'] as String?,
      createdAt: _toDate(json['createdAt']),
      createdByName: json['createdByName'] as String?,
      lastAction: json['lastAction'] as String?,
      lastActionByName: json['lastActionByName'] as String?,
      lastActionByAvatar: json['lastActionByAvatar'] as String?,
      lastActionAt: _toDate(json['lastActionAt']),
    );
  }

  /// Sérialisation COMPLÈTE (pour le cache local offline). Émet les mêmes clés
  /// que [fromJson] sait relire, afin d'un aller-retour fidèle.
  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    if (customerName != null) 'customerName': customerName,
    if (vehicleId != null) 'vehicleId': vehicleId,
    'label': label,
    if (modelDetails != null) 'modelDetails': modelDetails,
    'metier': metier.apiValue,
    if (maintenanceDetails != null)
      'maintenanceDetails': maintenanceDetails!.toJson(),
    if (printDetails != null) 'printDetails': printDetails!.toJson(),
    if (pressingDetails != null) 'pressingDetails': pressingDetails!.toJson(),
    if (entryDate != null) 'entryDate': entryDate!.toIso8601String(),
    if (exitDate != null) 'exitDate': exitDate!.toIso8601String(),
    'totalAmount': totalAmount,
    'advanceAmount': advanceAmount,
    'remainingAmount': remainingAmount,
    'currencyCode': currencyCode,
    'exchangeRate': exchangeRate,
    if (fabricProvidedBy != null) 'fabricProvidedBy': fabricProvidedBy!.apiValue,
    'status': status.apiValue,
    if (saleId != null) 'saleId': saleId,
    if (notes != null) 'notes': notes,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (createdByName != null) 'createdByName': createdByName,
    if (lastAction != null) 'lastAction': lastAction,
    if (lastActionByName != null) 'lastActionByName': lastActionByName,
    if (lastActionByAvatar != null) 'lastActionByAvatar': lastActionByAvatar,
    if (lastActionAt != null) 'lastActionAt': lastActionAt!.toIso8601String(),
    if (stageHistory.isNotEmpty)
      'stageHistory': stageHistory.map((e) => e.toJson()).toList(),
  };

  /// Payload de création/mise à jour (les champs null sont omis).
  Map<String, dynamic> toCreateJson() => {
    'customerId': customerId,
    if (vehicleId != null) 'vehicleId': vehicleId,
    'label': label,
    if (modelDetails != null) 'modelDetails': modelDetails,
    'metier': metier.apiValue,
    if (maintenanceDetails != null)
      'maintenanceDetails': maintenanceDetails!.toJson(),
    if (printDetails != null) 'printDetails': printDetails!.toJson(),
    if (pressingDetails != null) 'pressingDetails': pressingDetails!.toJson(),
    if (entryDate != null) 'entryDate': entryDate!.toIso8601String(),
    if (exitDate != null) 'exitDate': exitDate!.toIso8601String(),
    'totalAmount': totalAmount,
    'advanceAmount': advanceAmount,
    'currencyCode': currencyCode,
    'exchangeRate': exchangeRate,
    if (fabricProvidedBy != null) 'fabricProvidedBy': fabricProvidedBy!.apiValue,
    if (notes != null) 'notes': notes,
  };

  AtelierOrder copyWith({
    AtelierOrderStatus? status,
    double? remainingAmount,
    double? advanceAmount,
    String? saleId,
    AtelierMetier? metier,
    MaintenanceDetails? maintenanceDetails,
    PrintJobDetails? printDetails,
    PressingDetails? pressingDetails,
  }) {
    return AtelierOrder(
      id: id,
      customerId: customerId,
      customerName: customerName,
      vehicleId: vehicleId,
      label: label,
      modelDetails: modelDetails,
      metier: metier ?? this.metier,
      maintenanceDetails: maintenanceDetails ?? this.maintenanceDetails,
      printDetails: printDetails ?? this.printDetails,
      pressingDetails: pressingDetails ?? this.pressingDetails,
      stageHistory: stageHistory,
      entryDate: entryDate,
      exitDate: exitDate,
      totalAmount: totalAmount,
      advanceAmount: advanceAmount ?? this.advanceAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      currencyCode: currencyCode,
      exchangeRate: exchangeRate,
      fabricProvidedBy: fabricProvidedBy,
      status: status ?? this.status,
      saleId: saleId ?? this.saleId,
      notes: notes,
      createdAt: createdAt,
      createdByName: createdByName,
      lastAction: lastAction,
      lastActionByName: lastActionByName,
      lastActionByAvatar: lastActionByAvatar,
      lastActionAt: lastActionAt,
    );
  }

  @override
  List<Object?> get props => [
    id, customerId, label, status, totalAmount, advanceAmount,
    remainingAmount, currencyCode, saleId,
  ];
}
