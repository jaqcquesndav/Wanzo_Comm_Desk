import 'package:flutter/material.dart';

/// Choix du moyen de paiement (Espèces, Mobile Money, Crédit) à l'encaissement.
///
/// Remplace la rangée de puces : une puce porte son libellé en entier, donc
/// « Mobile Money » débordait dès que la colonne de caisse était étroite, et le
/// retour à la ligne collait les rangées faute d'espacement vertical. Ici les
/// tuiles se partagent la largeur à parts égales, passent à deux colonnes quand
/// la place manque, et le libellé est tronqué proprement plutôt que de pousser
/// sur son voisin.
class PaymentMethodSelector<T> extends StatelessWidget {
  const PaymentMethodSelector({
    super.key,
    required this.methods,
    required this.selected,
    required this.labelOf,
    required this.iconOf,
    required this.onChanged,
  });

  final List<T> methods;
  final T selected;
  final String Function(T) labelOf;
  final IconData Function(T) iconOf;
  final ValueChanged<T> onChanged;

  /// En dessous de cette largeur, une tuile n'affiche plus son libellé en
  /// entier : on préfère passer à deux colonnes.
  static const double _minTileWidth = 116;
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final int columns =
            ((c.maxWidth + _gap) / (_minTileWidth + _gap)).floor().clamp(1, methods.length);
        final double width =
            (c.maxWidth - _gap * (columns - 1)) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final m in methods)
              SizedBox(
                width: width,
                child: _MethodTile(
                  icon: iconOf(m),
                  label: labelOf(m),
                  selected: m == selected,
                  onTap: () => onChanged(m),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color border =
        selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant;
    final Color fg = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: selected ? 1.6 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
