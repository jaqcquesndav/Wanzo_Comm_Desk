import 'package:flutter/material.dart';
import '../../auth/read_only.dart';

/// Une action de ligne présentée dans un [RowActionsMenu].
///
/// [destructive] rend l'entrée dans la couleur d'erreur du thème (ex. suppression).
class RowAction {
  const RowAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
    this.write,
  });

  /// L'action écrit-elle ? null : déduit du libellé (core/auth/read_only).
  final bool? write;

  /// Libellé affiché dans le menu.
  final String label;

  /// Icône affichée à gauche du libellé.
  final IconData icon;

  /// Callback exécuté lorsque l'utilisateur choisit l'action.
  final VoidCallback onSelected;

  /// `true` pour une action destructive (rendue en couleur d'erreur).
  final bool destructive;
}

/// Menu d'actions de ligne pour les tables desktop.
///
/// Remplace le groupe de boutons d'action inline (éditer / supprimer / voir…)
/// dans une cellule de tableau par un unique bouton `⋮` ([PopupMenuButton])
/// qui déroule la liste des actions. Comportement identique aux anciens
/// boutons : chaque [RowAction.onSelected] est appelé tel quel.
class RowActionsMenu extends StatelessWidget {
  const RowActionsMenu({
    super.key,
    required this.actions,
    this.tooltip = 'Actions',
    this.icon = Icons.more_vert,
  });

  /// Les actions proposées, dans l'ordre d'affichage.
  final List<RowAction> actions;

  /// Tooltip du bouton déclencheur.
  final String tooltip;

  /// Icône du bouton déclencheur (par défaut `⋮`).
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    // Lecteur : ni modifier, ni annuler, ni supprimer (core/auth/read_only).
    final actions = this.actions.where((a) => ReadOnlyAccess.allows(label: a.label, write: a.write)).toList();
    if (actions.isEmpty) return const SizedBox.shrink();

    final errorColor = Theme.of(context).colorScheme.error;

    return PopupMenuButton<int>(
      icon: Icon(icon),
      tooltip: tooltip,
      onSelected: (index) => actions[index].onSelected(),
      itemBuilder: (context) {
        return [
          for (var i = 0; i < actions.length; i++)
            PopupMenuItem<int>(
              value: i,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    actions[i].icon,
                    size: 18,
                    color: actions[i].destructive ? errorColor : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    actions[i].label,
                    style: actions[i].destructive
                        ? TextStyle(color: errorColor)
                        : null,
                  ),
                ],
              ),
            ),
        ];
      },
    );
  }
}
