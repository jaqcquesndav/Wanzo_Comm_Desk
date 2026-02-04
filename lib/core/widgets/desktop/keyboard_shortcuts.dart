import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget qui ajoute les raccourcis clavier pour la version desktop
class DesktopKeyboardShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback? onNewSale;
  final VoidCallback? onNewProduct;
  final VoidCallback? onSearch;
  final VoidCallback? onSettings;
  final VoidCallback? onHelp;
  final VoidCallback? onRefresh;

  const DesktopKeyboardShortcuts({
    super.key,
    required this.child,
    this.onNewSale,
    this.onNewProduct,
    this.onSearch,
    this.onSettings,
    this.onHelp,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        // Ctrl+N : Nouvelle vente
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN):
            const _NewSaleIntent(),

        // Ctrl+Shift+P : Nouveau produit
        LogicalKeySet(
              LogicalKeyboardKey.control,
              LogicalKeyboardKey.shift,
              LogicalKeyboardKey.keyP,
            ):
            const _NewProductIntent(),

        // Ctrl+K : Recherche
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
            const _SearchIntent(),

        // Ctrl+, : Paramètres
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.comma):
            const _SettingsIntent(),

        // F1 : Aide
        const SingleActivator(LogicalKeyboardKey.f1): const _HelpIntent(),

        // F5 : Actualiser
        const SingleActivator(LogicalKeyboardKey.f5): const _RefreshIntent(),

        // Ctrl+R : Actualiser
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR):
            const _RefreshIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NewSaleIntent: CallbackAction<_NewSaleIntent>(
            onInvoke: (_) {
              onNewSale?.call();
              return null;
            },
          ),
          _NewProductIntent: CallbackAction<_NewProductIntent>(
            onInvoke: (_) {
              onNewProduct?.call();
              return null;
            },
          ),
          _SearchIntent: CallbackAction<_SearchIntent>(
            onInvoke: (_) {
              onSearch?.call();
              return null;
            },
          ),
          _SettingsIntent: CallbackAction<_SettingsIntent>(
            onInvoke: (_) {
              onSettings?.call();
              return null;
            },
          ),
          _HelpIntent: CallbackAction<_HelpIntent>(
            onInvoke: (_) {
              onHelp?.call();
              return null;
            },
          ),
          _RefreshIntent: CallbackAction<_RefreshIntent>(
            onInvoke: (_) {
              onRefresh?.call();
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

// Intents personnalisés
class _NewSaleIntent extends Intent {
  const _NewSaleIntent();
}

class _NewProductIntent extends Intent {
  const _NewProductIntent();
}

class _SearchIntent extends Intent {
  const _SearchIntent();
}

class _SettingsIntent extends Intent {
  const _SettingsIntent();
}

class _HelpIntent extends Intent {
  const _HelpIntent();
}

class _RefreshIntent extends Intent {
  const _RefreshIntent();
}

/// Widget pour afficher les raccourcis clavier disponibles
class KeyboardShortcutsHelp extends StatelessWidget {
  const KeyboardShortcutsHelp({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.keyboard),
          const SizedBox(width: 8),
          const Text('Raccourcis clavier'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildShortcutRow('Ctrl + N', 'Nouvelle vente'),
            _buildShortcutRow('Ctrl + Shift + P', 'Nouveau produit'),
            _buildShortcutRow('Ctrl + K', 'Recherche globale'),
            _buildShortcutRow('Ctrl + ,', 'Paramètres'),
            _buildShortcutRow('F1', 'Aide'),
            _buildShortcutRow('F5 / Ctrl + R', 'Actualiser'),
            const Divider(),
            _buildShortcutRow('Tab', 'Champ suivant'),
            _buildShortcutRow('Shift + Tab', 'Champ précédent'),
            _buildShortcutRow('Entrée', 'Valider / Soumettre'),
            _buildShortcutRow('Échap', 'Annuler / Fermer'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  Widget _buildShortcutRow(String shortcut, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: Text(
              shortcut,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(description),
        ],
      ),
    );
  }
}
