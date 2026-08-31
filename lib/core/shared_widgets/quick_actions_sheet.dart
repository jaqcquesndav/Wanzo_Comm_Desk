import 'package:flutter/material.dart';

/// Descriptif d'une action rapide présentée dans la feuille partagée.
///
/// Une seule source de vérité pour les « actions rapides » (retail, restaurant,
/// atelier…) : chaque écran fournit sa liste, la présentation reste identique.
class QuickActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
}

/// Ouvre la feuille partagée des actions rapides (un seul déclencheur par
/// écran, jamais une rangée de boutons dans le corps de la page).
///
/// - [title] : titre affiché en haut de la feuille (défaut « Actions rapides »).
/// - [actions] : actions présentées dans l'ordre fourni.
/// - [onSync] : action optionnelle de synchronisation (affichée à part).
Future<void> showWanzoQuickActions(
  BuildContext context, {
  String title = 'Actions rapides',
  required List<QuickActionItem> actions,
  VoidCallback? onSync,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (onSync != null)
                    IconButton(
                      tooltip: 'Synchroniser',
                      icon: const Icon(Icons.sync),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        onSync();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final action in actions)
                    SizedBox(
                      width: 150,
                      child: _QuickActionTile(
                        action: action,
                        onSelected: () {
                          Navigator.of(sheetContext).pop();
                          action.onTap();
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _QuickActionTile extends StatelessWidget {
  final QuickActionItem action;
  final VoidCallback onSelected;
  const _QuickActionTile({required this.action, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = action.color ?? theme.colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSelected,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.16),
                child: Icon(action.icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                action.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
