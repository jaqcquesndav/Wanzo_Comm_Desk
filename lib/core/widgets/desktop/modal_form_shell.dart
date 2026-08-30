import 'package:flutter/material.dart';

/// Chrome d'un formulaire ouvert en MODAL (desktop/tablette) : un en-tête
/// léger (titre + fermer) au lieu d'une seconde `AppBar`.
///
/// Contexte : les gros formulaires (vente, dépense, produit) étaient rendus
/// comme un `Scaffold` + `AppBar` COMPLET à l'intérieur d'un `Dialog`, d'où
/// l'effet « double enveloppe » (une carte flottante avec une deuxième barre
/// d'application dedans). Ce shell reprend exactement le style d'en-tête des
/// modals client/fournisseur (`AdaptiveModal`) pour une UI/UX cohérente, tout
/// en conservant un `Scaffold` (sans `AppBar`) afin de borner la hauteur — les
/// corps de ces formulaires contiennent des `ListView` qui exigent une hauteur
/// finie.
class ModalFormShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  /// Barre d'action persistante (ex: bouton « Enregistrer »), affichée en pied
  /// de modal sous un séparateur — l'équivalent du `bottomNavigationBar` d'un
  /// `Scaffold`.
  final Widget? bottomBar;

  /// Appelé par le bouton fermer. Par défaut : `Navigator.pop()` (annule le
  /// Dialog).
  final VoidCallback? onClose;

  const ModalFormShell({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.bottomBar,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Fermer',
                  onPressed: onClose ?? () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          Expanded(child: child),
          if (bottomBar != null) ...[
            Divider(height: 1, color: theme.dividerColor),
            bottomBar!,
          ],
        ],
      ),
    );
  }
}

/// Choisit le chrome selon le contexte : en modal → [ModalFormShell] (en-tête
/// léger, pas d'`AppBar`) ; en page plein écran → `Scaffold` + `AppBar`
/// classique. Permet aux écrans de formulaire d'avoir la MÊME structure quel
/// que soit le point d'entrée.
class ModalOrPageScaffold extends StatelessWidget {
  final bool isModal;
  final String title;
  final IconData? icon;
  final Widget child;

  /// Barre d'action persistante (bouton d'enregistrement…). En page →
  /// `bottomNavigationBar` ; en modal → pied de [ModalFormShell].
  final Widget? bottomBar;

  const ModalOrPageScaffold({
    super.key,
    required this.isModal,
    required this.title,
    required this.child,
    this.icon,
    this.bottomBar,
  });

  @override
  Widget build(BuildContext context) {
    if (isModal) {
      return ModalFormShell(
        title: title,
        icon: icon,
        bottomBar: bottomBar,
        child: child,
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
      bottomNavigationBar: bottomBar,
    );
  }
}
