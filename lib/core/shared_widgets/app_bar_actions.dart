import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'adha_logo.dart';

/// Règles de l'en-tête, communes à toutes les apps Wanzo.
///
/// Lu depuis le bord droit : profil, notifications, Adha, menu 3 points, puis
/// au plus deux actions propres à la page. Ce qui dépasse passe dans le menu
/// 3 points, toujours dans cet ordre.
class HeaderRules {
  HeaderRules._();

  /// Actions de page visibles au plus dans l'en-tête.
  static const int maxPageActions = 2;

  /// Clé du menu 3 points de l'en-tête.
  static const ValueKey<String> overflowKey = ValueKey('app-bar-overflow');

  /// Infobulle du menu 3 points.
  static const String overflowTooltip = "Plus d'options";

  /// Infobulle du bouton Adha.
  static const String adhaTooltip = 'Adha IA';

  /// Infobulle du bouton des notifications.
  static const String notificationsTooltip = 'Notifications';
}

/// Une entrée du menu 3 points : action de page repliée, ou élément global
/// (notifications, Adha, mode) qui ne tient plus dans la barre.
class HeaderMenuEntry {
  final Widget icon;
  final String label;
  final VoidCallback? onTap;

  /// Variante qui a besoin d'un contexte (ouvrir un choix, une modale).
  final void Function(BuildContext context)? onTapIn;

  const HeaderMenuEntry({
    required this.icon,
    required this.label,
    this.onTap,
    this.onTapIn,
  });

  bool get enabled => onTap != null || onTapIn != null;

  void run(BuildContext context) {
    if (onTapIn != null) {
      onTapIn!(context);
    } else {
      onTap?.call();
    }
  }
}

/// Un widget d'en-tête qui sait se replier dans le menu 3 points (bouton
/// d'export, par exemple).
abstract interface class HeaderFoldable {
  HeaderMenuEntry get headerEntry;
}

/// Actions d'une page triées : celles qui restent dans la barre, celles qui
/// passent dans le menu 3 points, et le menu propre à la page s'il en avait
/// un (fusionné dans le menu 3 points de l'en-tête pour n'en garder qu'un).
class SplitPageActions {
  final List<Widget> visible;
  final List<HeaderMenuEntry> folded;
  final PopupMenuButton<dynamic>? pageMenu;

  const SplitPageActions(this.visible, this.folded, this.pageMenu);
}

/// Équivalent dans le menu 3 points d'un bouton-icône, qui porte une infobulle
/// devenue son libellé. Null si le widget ne se replie pas.
HeaderMenuEntry? headerEntryOf(Widget w) {
  if (w case final HeaderFoldable f) return f.headerEntry;
  if (w is IconButton && (w.tooltip ?? '').trim().isNotEmpty) {
    return HeaderMenuEntry(
      icon: w.icon,
      label: w.tooltip!.trim(),
      onTap: w.onPressed,
    );
  }
  if (w is Tooltip && w.child is IconButton) {
    final b = w.child as IconButton;
    final label = (w.message ?? b.tooltip ?? '').trim();
    if (label.isEmpty) return null;
    return HeaderMenuEntry(icon: b.icon, label: label, onTap: b.onPressed);
  }
  return null;
}

/// Menu 3 points générique d'une page (icône par défaut), à fusionner.
bool _isPlainMenu(Widget w) {
  if (w is! PopupMenuButton) return false;
  if (w.child != null) return false;
  final icon = w.icon;
  if (icon == null) return true;
  return icon is Icon &&
      (icon.icon == Icons.more_vert || icon.icon == Icons.more_horiz);
}

/// Trie les actions d'une page : au plus [maxVisible] restent visibles, les
/// boutons-icônes en trop passent dans le menu 3 points. Un widget qui ne se
/// replie pas (bouton texte, compteur...) reste visible et compte dans la
/// limite. Un menu 3 points propre à la page est fusionné.
SplitPageActions splitPageActions(
  List<Widget>? actions, {
  int maxVisible = HeaderRules.maxPageActions,
}) {
  // Les espaceurs (SizedBox vide) ne sont pas des actions.
  final all = <Widget>[
    for (final w in actions ?? const <Widget>[])
      if (!(w is SizedBox && w.child == null)) w,
  ];
  final menus = all.where(_isPlainMenu).toList();
  final PopupMenuButton<dynamic>? pageMenu =
      menus.length == 1 ? menus.first as PopupMenuButton<dynamic> : null;
  if (pageMenu != null) all.remove(pageMenu);
  if (all.length <= maxVisible) {
    return SplitPageActions(all, const [], pageMenu);
  }
  final rigid = all.where((w) => headerEntryOf(w) == null).length;
  var slots = maxVisible - rigid;
  final visible = <Widget>[];
  final folded = <HeaderMenuEntry>[];
  for (final w in all) {
    final entry = headerEntryOf(w);
    if (entry == null) {
      visible.add(w);
    } else if (slots > 0) {
      visible.add(w);
      slots--;
    } else {
      folded.add(entry);
    }
  }
  return SplitPageActions(visible, folded, pageMenu);
}

/// Pour les en-têtes propres à un écran : au plus deux actions visibles, le
/// reste dans un menu 3 points placé à leur droite.
List<Widget> foldPageActions(
  List<Widget>? actions, {
  int maxVisible = HeaderRules.maxPageActions,
}) {
  final split = splitPageActions(actions, maxVisible: maxVisible);
  return [
    ...split.visible,
    if (split.folded.isNotEmpty || split.pageMenu != null)
      HeaderOverflowMenu(entries: split.folded, pageMenu: split.pageMenu),
  ];
}

class _Token {
  final int index;
  const _Token(this.index);
}

/// Le menu 3 points de l'en-tête, juste à gauche d'Adha. Les entrées
/// repliées viennent d'abord, puis celles du menu propre à la page.
class HeaderOverflowMenu extends StatelessWidget {
  final List<HeaderMenuEntry> entries;
  final PopupMenuButton<dynamic>? pageMenu;

  const HeaderOverflowMenu({
    super.key = HeaderRules.overflowKey,
    required this.entries,
    this.pageMenu,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return PopupMenuButton<Object?>(
      tooltip: HeaderRules.overflowTooltip,
      icon: const Icon(Icons.more_vert),
      itemBuilder: (ctx) {
        final items = <PopupMenuEntry<Object?>>[
          for (var i = 0; i < entries.length; i++)
            PopupMenuItem<Object?>(
              value: _Token(i),
              enabled: entries[i].enabled,
              child: Row(
                children: [
                  IconTheme.merge(
                    data: IconThemeData(color: color, size: 22),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Center(child: entries[i].icon),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      entries[i].label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ];
        final page = pageMenu;
        if (page != null) {
          final extra = page.itemBuilder(ctx);
          if (items.isNotEmpty && extra.isNotEmpty) {
            items.add(const PopupMenuDivider());
          }
          items.addAll(extra);
        }
        return items;
      },
      onSelected: (value) {
        if (value is _Token) {
          entries[value.index].run(context);
          return;
        }
        final onSelected = pageMenu?.onSelected;
        if (onSelected != null) (onSelected as dynamic)(value);
      },
    );
  }
}

/// Bouton Adha de l'en-tête : même icône, même infobulle, même taille dans
/// toutes les apps. Par défaut, ouvre l'écran Adha.
class AdhaHeaderButton extends StatelessWidget {
  final VoidCallback? onPressed;

  /// Logo blanc sur une barre colorée (cas des apps mobiles).
  final bool? onDark;

  const AdhaHeaderButton({super.key, this.onPressed, this.onDark = true});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('app-bar-adha'),
      tooltip: HeaderRules.adhaTooltip,
      icon: AdhaLogo(size: 24, dark: onDark),
      onPressed: onPressed ?? () => context.push('/adha'),
    );
  }
}
