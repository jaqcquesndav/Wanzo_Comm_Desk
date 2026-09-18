import 'package:flutter/material.dart';

/// Conteneur de saisie ou de choix contextuel de Wanzo, identique dans les
/// deux apps : PULL-UP (feuille du bas, poignée, en-tête avec bouton fermer,
/// clavier respecté) sur écran étroit, et boîte de dialogue centrée sur écran
/// large (desktop, tablette). Un seul point d'entrée pour ne plus mélanger
/// modals et pull-ups selon les écrans.
Future<T?> showAdaptivePullUp<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  IconData? icon,
  double maxWidth = 520,
  bool isDismissible = true,

  /// Marge autour du contenu. Sans elle, les champs touchent les bords du
  /// cadre. Une liste qui porte déjà sa propre marge passe `EdgeInsets.zero`.
  EdgeInsets contentPadding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
}) {
  final isWide = MediaQuery.sizeOf(context).width >= 720;
  if (isWide) {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PullUpHeader(title: title, icon: icon, onClose: () => Navigator.of(ctx).pop()),
              const Divider(height: 1),
              Flexible(
                child: Padding(
                  padding: contentPadding,
                  child: builder(ctx),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      // Le clavier ne doit jamais masquer les champs du bas de la feuille.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PullUpHeader(title: title, icon: icon, onClose: () => Navigator.of(ctx).pop()),
              const Divider(height: 1),
              Flexible(
                child: Padding(
                  padding: contentPadding,
                  child: builder(ctx),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PullUpHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final VoidCallback onClose;
  const _PullUpHeader({required this.title, required this.onClose, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(tooltip: 'Fermer', icon: const Icon(Icons.close), onPressed: onClose),
        ],
      ),
    );
  }
}
