import 'package:flutter/material.dart';

/// Marques Mobile Money gérées en RDC (codes SerdiPay) avec leur logo.
///
/// Les logos sont des tuiles carrées arrondies prêtes à l'emploi : fond blanc
/// et liseré gris pour M-Pesa, Orange Money et Airtel Money, logo blanc
/// officiel sur le magenta de la marque pour Afrimoney. Elles restent lisibles
/// en mode clair comme en mode sombre ; ne jamais les recolorer ni les étirer.
enum OperatorBrand {
  mpesa('MP', 'M-Pesa', 'assets/images/operators/mpesa.png'),
  orangeMoney('OM', 'Orange Money', 'assets/images/operators/orange_money.png'),
  airtelMoney('AM', 'Airtel Money', 'assets/images/operators/airtel_money.png'),
  afrimoney('AF', 'Afrimoney', 'assets/images/operators/afrimoney.png');

  /// Code télécom SerdiPay (MP/OM/AM/AF).
  final String code;
  final String label;
  final String asset;

  const OperatorBrand(this.code, this.label, this.asset);

  /// Résout un opérateur depuis un code (« MP »), un nom (« M-Pesa (Vodacom) »,
  /// « Africell Money »), une valeur d'enum (`MobileMoneyProvider.mpesa`) ou
  /// une [OperatorBrand]. Retourne null si l'opérateur est inconnu.
  static OperatorBrand? resolve(Object? value) {
    if (value == null) return null;
    if (value is OperatorBrand) return value;
    final raw = value is Enum ? value.name : value.toString();
    final s = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (s.isEmpty) return null;
    switch (s) {
      case 'MP':
        return OperatorBrand.mpesa;
      case 'OM':
        return OperatorBrand.orangeMoney;
      case 'AM':
        return OperatorBrand.airtelMoney;
      case 'AF':
        return OperatorBrand.afrimoney;
    }
    if (s.contains('PESA') || s.contains('VODACOM')) return OperatorBrand.mpesa;
    if (s.contains('ORANGE')) return OperatorBrand.orangeMoney;
    if (s.contains('AIRTEL')) return OperatorBrand.airtelMoney;
    if (s.contains('AFRI')) return OperatorBrand.afrimoney;
    return null;
  }
}

/// Libellé à afficher pour un opérateur : nom de marque si reconnu, sinon la
/// valeur brute, sinon « Mobile Money ».
String operatorLabel(Object? operator) {
  final brand = OperatorBrand.resolve(operator);
  if (brand != null) return brand.label;
  final raw = operator is Enum ? operator.name : operator?.toString();
  return (raw == null || raw.trim().isEmpty) ? 'Mobile Money' : raw.trim();
}

/// Logo carré d'un opérateur Mobile Money. Opérateur inconnu : icône de
/// téléphone générique dans une tuile neutre de même taille.
class OperatorLogo extends StatelessWidget {
  const OperatorLogo(
    this.operator, {
    super.key,
    this.size = 32,
    this.excludeSemantics = false,
  });

  /// Code, nom, enum ou [OperatorBrand].
  final Object? operator;
  final double size;

  /// À activer quand le nom est déjà affiché à côté (évite une double lecture).
  final bool excludeSemantics;

  @override
  Widget build(BuildContext context) {
    final brand = OperatorBrand.resolve(operator);
    final label = operatorLabel(operator);
    final Widget tile = brand == null
        ? _GenericOperatorTile(size: size)
        : Image.asset(
            brand.asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
            errorBuilder: (_, __, ___) => _GenericOperatorTile(size: size),
          );
    if (excludeSemantics) return ExcludeSemantics(child: tile);
    return Semantics(image: true, label: label, child: tile);
  }
}

class _GenericOperatorTile extends StatelessWidget {
  const _GenericOperatorTile({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('operator-logo-generic'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Icon(
        Icons.phone_android,
        size: size * 0.6,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

/// Logo et nom côte à côte (récapitulatif, reçu, historique, détail).
class OperatorChip extends StatelessWidget {
  const OperatorChip(
    this.operator, {
    super.key,
    this.size = 20,
    this.label,
    this.style,
  });

  final Object? operator;
  final double size;

  /// Libellé imposé ; par défaut le nom de la marque.
  final String? label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final text = label ?? operatorLabel(operator);
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OperatorLogo(operator, size: size, excludeSemantics: true),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: style,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sélecteur d'opérateur : une tuile par opérateur, logo avec le nom en petit
/// dessous. Accessible (bouton sélectionnable annoncé par son nom) et souple :
/// les tuiles passent à la ligne sur petit écran ou en grande police.
class OperatorSelector<T> extends StatelessWidget {
  const OperatorSelector({
    super.key,
    required this.operators,
    required this.selected,
    required this.onSelected,
    this.labelOf,
    this.logoSize = 36,
  });

  final List<T> operators;
  final T? selected;
  final ValueChanged<T> onSelected;

  /// Libellé de chaque opérateur ; par défaut le nom de la marque.
  final String Function(T)? labelOf;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final op in operators)
          Builder(builder: (context) {
            final isSelected = op == selected;
            final label = labelOf?.call(op) ?? operatorLabel(op);
            return Semantics(
              button: true,
              selected: isSelected,
              label: label,
              excludeSemantics: true,
              child: InkWell(
                key: ValueKey('operator-option-${OperatorBrand.resolve(op)?.code ?? label}'),
                onTap: () => onSelected(op),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 72, maxWidth: 104),
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected
                        ? scheme.primaryContainer.withAlpha(90)
                        : null,
                    border: Border.all(
                      color: isSelected ? scheme.primary : scheme.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OperatorLogo(op, size: logoSize, excludeSemantics: true),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
