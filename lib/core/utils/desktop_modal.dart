import 'package:flutter/material.dart';

/// Largeur d'une modale de formulaire ou de choix court.
const double kModalFormWidth = 560;

/// Largeur d'une modale de liste ou de contenu riche.
const double kModalListWidth = 720;

/// Ouvre une MODALE centrée : l'app desktop n'utilise plus de feuilles du bas
/// (pull-up). Remplace `showModalBottomSheet` partout dans l'app.
///
/// - en-tête avec le titre et un bouton Fermer toujours visible ;
/// - corps défilant (passer [scrollable] à false quand le contenu porte déjà
///   sa propre liste, il reçoit alors une hauteur bornée) ;
/// - pied collant optionnel ([footerBuilder]) pour les actions ;
/// - Échap ferme la modale (sauf si [isDismissible] vaut false) ;
/// - jamais de `Scaffold` dedans, donc pas de double enveloppe.
Future<T?> showDesktopModal<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  IconData? icon,
  String? subtitle,
  WidgetBuilder? footerBuilder,
  double maxWidth = kModalFormWidth,
  bool isDismissible = true,
  bool scrollable = true,
  // Comme une feuille du bas : le navigateur le plus proche, pour que les
  // blocs fournis par une route (ShellRoute) restent accessibles.
  bool useRootNavigator = false,
  EdgeInsetsGeometry contentPadding = const EdgeInsets.fromLTRB(20, 16, 20, 20),
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    useRootNavigator: useRootNavigator,
    builder: (ctx) => DesktopModalFrame(
      title: title,
      icon: icon,
      subtitle: subtitle,
      maxWidth: maxWidth,
      scrollable: scrollable,
      contentPadding: contentPadding,
      onClose: isDismissible ? () => Navigator.of(ctx).maybePop() : null,
      footer: footerBuilder?.call(ctx),
      child: Builder(builder: builder),
    ),
  );
}

/// Cadre d'une modale desktop : en-tête (titre, fermer), corps, pied collant.
class DesktopModalFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;
  final Widget? footer;
  final double maxWidth;
  final bool scrollable;
  final EdgeInsetsGeometry contentPadding;

  /// Bouton Fermer. Null : pas de bouton (modale à ne pas interrompre).
  final VoidCallback? onClose;

  const DesktopModalFrame({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.footer,
    this.maxWidth = kModalFormWidth,
    this.scrollable = true,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 16, 20, 20),
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final body = Padding(padding: contentPadding, child: child);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon,
                          size: 20, color: theme.colorScheme.primary),
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                  if (onClose != null)
                    IconButton(
                      key: const ValueKey('modal-close'),
                      icon: const Icon(Icons.close),
                      tooltip: 'Fermer',
                      onPressed: onClose,
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Flexible(
              child: scrollable ? SingleChildScrollView(child: body) : body,
            ),
            if (footer != null) ...[
              Divider(height: 1, color: theme.dividerColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: footer,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
