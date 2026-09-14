import 'package:equatable/equatable.dart';

/// Véhicule d'un client (mode garage) : fabricant, modèle, année, puis le
/// véhicule spécifique (immatriculation, châssis, couleur, kilométrage).
/// Persisté côté serveur (`customer_vehicles`), pas de cache local : la fiche
/// de suivi doit être la même sur tous les appareils du garage.
class CustomerVehicle extends Equatable {
  final String id;
  final String customerId;
  final String? plate;
  final String? brand;
  final String? model;
  final int? year;
  final String? vin;
  final String? color;
  final String? fuel;
  final String? transmission;
  final String? bodyType;
  final int? mileage;
  final String? notes;
  final bool active;
  final DateTime? createdAt;

  const CustomerVehicle({
    required this.id,
    required this.customerId,
    this.plate,
    this.brand,
    this.model,
    this.year,
    this.vin,
    this.color,
    this.fuel,
    this.transmission,
    this.bodyType,
    this.mileage,
    this.notes,
    this.active = true,
    this.createdAt,
  });

  /// « Toyota Prado 2015 » (ce que le garagiste dit à l'oral).
  String get designation {
    final parts = [
      if ((brand ?? '').isNotEmpty) brand!,
      if ((model ?? '').isNotEmpty) model!,
      if (year != null) '$year',
    ];
    return parts.isEmpty ? 'Véhicule' : parts.join(' ');
  }

  /// « AB-123-CD · Toyota Prado 2015 » pour les listes et sélecteurs.
  String get displayLabel =>
      (plate ?? '').isNotEmpty ? '${plate!} · $designation' : designation;

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  factory CustomerVehicle.fromJson(Map<String, dynamic> json) => CustomerVehicle(
        id: json['id'] as String,
        customerId: json['customerId'] as String? ?? '',
        plate: json['plate'] as String?,
        brand: json['brand'] as String?,
        model: json['model'] as String?,
        year: _toInt(json['year']),
        vin: json['vin'] as String?,
        color: json['color'] as String?,
        fuel: json['fuel'] as String?,
        transmission: json['transmission'] as String?,
        bodyType: json['bodyType'] as String?,
        mileage: _toInt(json['mileage']),
        notes: json['notes'] as String?,
        active: json['active'] as bool? ?? true,
        createdAt: json['createdAt'] == null ? null : DateTime.tryParse(json['createdAt'].toString()),
      );

  /// Payload de création / mise à jour (les champs vides sont omis).
  Map<String, dynamic> toPayload() => {
        if ((plate ?? '').isNotEmpty) 'plate': plate,
        if ((brand ?? '').isNotEmpty) 'brand': brand,
        if ((model ?? '').isNotEmpty) 'model': model,
        if (year != null) 'year': year,
        if ((vin ?? '').isNotEmpty) 'vin': vin,
        if ((color ?? '').isNotEmpty) 'color': color,
        if ((fuel ?? '').isNotEmpty) 'fuel': fuel,
        if ((transmission ?? '').isNotEmpty) 'transmission': transmission,
        if ((bodyType ?? '').isNotEmpty) 'bodyType': bodyType,
        if (mileage != null) 'mileage': mileage,
        if ((notes ?? '').isNotEmpty) 'notes': notes,
      };

  @override
  List<Object?> get props => [
        id, customerId, plate, brand, model, year, vin, color, fuel, transmission,
        bodyType, mileage, notes, active, createdAt,
      ];
}
