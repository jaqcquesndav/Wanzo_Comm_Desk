import 'package:flutter/material.dart';
import 'package:wanzo/core/utils/adaptive_pull_up.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';

import '../models/service_item.dart';

/// Suggestions de services dans la recherche rapide du point de vente.
/// Un service à plusieurs paliers (Basic, Premium, Spéciaux...) ouvre un
/// choix de palier avant d'être ajouté à la vente.
class ServiceSearchResults extends StatelessWidget {
  final List<ServiceItem> services;

  /// Devise de la transaction et son taux vers le CDF (prix stockés en CDF).
  final String currencyCode;
  final double exchangeRate;
  final void Function(ServiceItem service, ServicePriceTier tier) onPick;

  /// Catégorie du véhicule concerné (garage). Quand elle est connue, le palier
  /// correspondant est choisi d'office : le caissier n'a pas à retrouver la
  /// bonne colonne du barème.
  final String? vehicleCategoryCode;

  const ServiceSearchResults({
    super.key,
    required this.services,
    required this.currencyCode,
    required this.exchangeRate,
    required this.onPick,
    this.vehicleCategoryCode,
  });

  String _price(double priceCdf) =>
      formatCurrency(priceCdf / (exchangeRate == 0 ? 1.0 : exchangeRate), currencyCode);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withAlpha((0.6 * 255).round());
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < services.length; i++) ...[
          if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
          InkWell(
            onTap: () => _pick(context, services[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.design_services_outlined,
                        color: theme.colorScheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          services[i].name,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _subtitle(services[i]),
                          style: TextStyle(fontSize: 12, color: muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    services[i].hasMultipleTiers
                        ? 'dès ${_price(services[i].minPriceCdf)}'
                        : _price((services[i].defaultTier ?? services[i].priceTiers.first).priceCdf),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        Divider(height: 1, color: Colors.grey.shade200),
      ],
    );
  }

  String _subtitle(ServiceItem s) {
    final parts = <String>[
      'Service',
      if ((s.category ?? '').isNotEmpty) s.category!,
      if (s.hasMultipleTiers) '${s.priceTiers.length} paliers',
      if (s.durationMinutes != null) '${s.durationMinutes} min',
    ];
    return parts.join(' · ');
  }

  Future<void> _pick(BuildContext context, ServiceItem service) async {
    if (!service.hasMultipleTiers) {
      final tier = service.defaultTier ?? service.priceTiers.first;
      onPick(service, tier);
      return;
    }
    // Véhicule connu : sa catégorie désigne la colonne du barème.
    final code = vehicleCategoryCode;
    if (code != null && code.isNotEmpty) {
      final match = service.tierByCode(code);
      if (match != null) {
        onPick(service, match);
        return;
      }
    }
    final tier = await showAdaptivePullUp<ServicePriceTier>(
      context,
      title: service.name,
      icon: Icons.design_services_outlined,
      maxWidth: 420,
      // La marge du conteneur suffit : la liste n'ajoute pas la sienne.
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final t in service.priceTiers)
            ListTile(
              leading: Icon(
                t.isDefault ? Icons.star : Icons.star_border,
                color: Theme.of(ctx).colorScheme.primary,
              ),
              title: Text(t.label),
              subtitle: (t.description ?? '').isEmpty ? null : Text(t.description!),
              trailing: Text(
                _price(t.priceCdf),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.of(ctx).pop(t),
            ),
        ],
      ),
    );
    if (tier != null) onPick(service, tier);
  }
}
