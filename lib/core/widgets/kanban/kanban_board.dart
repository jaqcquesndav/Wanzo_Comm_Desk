import 'package:flutter/material.dart';

/// Une colonne du board = un statut du workflow.
///
/// Générique sur le type d'élément [T] (commande restaurant, commande atelier,
/// vente…). Le board ne connaît rien du métier : il reçoit des colonnes et des
/// builders, et notifie les déplacements. Réutilisable par tous les modes.
class KanbanColumnData<T extends Object> {
  /// Identifiant stable de la colonne (= valeur de statut, ex. `open`).
  final String id;
  final String title;

  /// Couleur d'accent (bandeau + puce). Doit rester lisible en clair et sombre.
  final Color color;
  final List<T> items;

  /// Le board autorise-t-il le dépôt d'une carte dans cette colonne ?
  /// (ex. on n'autorise pas à re-glisser une commande vers « Annulée »).
  final bool acceptsDrops;

  /// Bouton « + » optionnel en tête de colonne (ex. « Nouvelle commande »).
  final VoidCallback? onAdd;

  const KanbanColumnData({
    required this.id,
    required this.title,
    required this.color,
    required this.items,
    this.acceptsDrops = true,
    this.onAdd,
  });
}

/// Board Kanban responsive et générique (façon Trello/Asana).
///
/// - **Grand écran** : colonnes côte à côte, défilement horizontal, cartes
///   déplaçables par glisser-déposer (`LongPressDraggable` → `DragTarget`).
///   Déplacer une carte dans une autre colonne appelle [onMoveItem].
/// - **Mobile / étroit** : un onglet par colonne (le glisser-déposer n'est pas
///   ergonomique au doigt) ; taper une carte appelle [onTapItem] (l'appelant
///   ouvre alors une feuille de changement de statut).
///
/// Aucune dépendance à un package externe : `Draggable`/`DragTarget` natifs.
class KanbanBoard<T extends Object> extends StatelessWidget {
  final List<KanbanColumnData<T>> columns;

  /// Identifiant stable d'un élément (pour les clés et le suivi du drag).
  final String Function(T item) itemId;

  /// Construit la carte d'un élément.
  final Widget Function(BuildContext context, T item) cardBuilder;

  /// Appelé quand une carte est déposée dans une colonne différente.
  final void Function(T item, String toColumnId)? onMoveItem;

  /// Appelé quand on tape une carte (ouvre le détail / le menu de statut).
  final void Function(T item)? onTapItem;

  /// Largeur d'une colonne sur grand écran.
  final double columnWidth;

  /// Autoriser le glisser-déposer (désactivable, ex. lecture seule).
  final bool enableDragAndDrop;

  const KanbanBoard({
    super.key,
    required this.columns,
    required this.itemId,
    required this.cardBuilder,
    this.onMoveItem,
    this.onTapItem,
    this.columnWidth = 300,
    this.enableDragAndDrop = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Assez de place pour au moins ~1,5 colonne côte à côte → board glissé.
        // Sinon, vue par onglets (mobile / fenêtre étroite).
        final useBoard = constraints.maxWidth >= columnWidth * 1.6;
        return useBoard
            ? _buildBoard(context, constraints.maxHeight)
            : _buildTabbed(context);
      },
    );
  }

  // ── Grand écran : colonnes glissables (façon Trello) ────────────────────────
  // Les colonnes occupent TOUTE la hauteur disponible et défilent verticalement
  // chacune de leur côté (fini l'« IntrinsicHeight » qui figeait les colonnes en
  // petites boîtes flottant en haut). Défilement horizontal du board entier.
  Widget _buildBoard(BuildContext context, double availableHeight) {
    const outerPad = 16.0;
    final colHeight =
        availableHeight.isFinite ? (availableHeight - outerPad * 2) : 640.0;
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(outerPad),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final col in columns)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: columnWidth,
                  height: colHeight > 0 ? colHeight : null,
                  child: _BoardColumn<T>(
                    column: col,
                    itemId: itemId,
                    cardBuilder: cardBuilder,
                    onMoveItem: onMoveItem,
                    onTapItem: onTapItem,
                    enableDragAndDrop: enableDragAndDrop && onMoveItem != null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Mobile / étroit : un onglet par colonne ────────────────────────────────
  Widget _buildTabbed(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: columns.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            tabs: [
              for (final col in columns)
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: col.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text('${col.title} (${col.items.length})'),
                    ],
                  ),
                ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final col in columns)
                  _ColumnItemList<T>(
                    column: col,
                    itemId: itemId,
                    cardBuilder: cardBuilder,
                    onTapItem: onTapItem,
                    padding: const EdgeInsets.all(12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Une colonne du board (grand écran) : en-tête coloré + zone de dépôt + cartes.
class _BoardColumn<T extends Object> extends StatefulWidget {
  final KanbanColumnData<T> column;
  final String Function(T) itemId;
  final Widget Function(BuildContext, T) cardBuilder;
  final void Function(T item, String toColumnId)? onMoveItem;
  final void Function(T item)? onTapItem;
  final bool enableDragAndDrop;

  const _BoardColumn({
    super.key,
    required this.column,
    required this.itemId,
    required this.cardBuilder,
    required this.onMoveItem,
    required this.onTapItem,
    required this.enableDragAndDrop,
  });

  @override
  State<_BoardColumn<T>> createState() => _BoardColumnState<T>();
}

class _BoardColumnState<T extends Object> extends State<_BoardColumn<T>> {
  bool _dragOver = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final col = widget.column;

    Widget body = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        // Une seule bordure, discrète, qui s'illumine uniquement au survol d'un
        // glisser-déposer (plus d'empilement de traits « éclaté »).
        border: _dragOver
            ? Border.all(color: col.color, width: 2)
            : Border.all(color: Colors.transparent, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          Expanded(
            child: _ColumnItemList<T>(
              column: col,
              itemId: widget.itemId,
              cardBuilder: widget.cardBuilder,
              onTapItem: widget.onTapItem,
              draggable: widget.enableDragAndDrop,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            ),
          ),
        ],
      ),
    );

    if (!widget.enableDragAndDrop || !col.acceptsDrops) return body;

    return DragTarget<T>(
      onWillAcceptWithDetails: (details) {
        setState(() => _dragOver = true);
        return true;
      },
      onLeave: (_) => setState(() => _dragOver = false),
      onAcceptWithDetails: (details) {
        setState(() => _dragOver = false);
        widget.onMoveItem?.call(details.data, col.id);
      },
      builder: (context, candidate, rejected) => body,
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final col = widget.column;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: col.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              col.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: col.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${col.items.length}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: col.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (col.onAdd != null)
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: 'Ajouter',
              onPressed: col.onAdd,
            ),
        ],
      ),
    );
  }
}

/// Liste verticale des cartes d'une colonne (partagée board / onglets).
class _ColumnItemList<T extends Object> extends StatelessWidget {
  final KanbanColumnData<T> column;
  final String Function(T) itemId;
  final Widget Function(BuildContext, T) cardBuilder;
  final void Function(T item)? onTapItem;
  final bool draggable;
  final EdgeInsets padding;

  const _ColumnItemList({
    super.key,
    required this.column,
    required this.itemId,
    required this.cardBuilder,
    required this.onTapItem,
    this.draggable = false,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (column.items.isEmpty) {
      return Center(child: _EmptyColumn(color: column.color));
    }
    return ListView.separated(
      padding: padding,
      itemCount: column.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = column.items[index];
        final card = _TappableCard(
          onTap: onTapItem == null ? null : () => onTapItem!(item),
          child: cardBuilder(context, item),
        );
        if (!draggable) return card;
        return LongPressDraggable<T>(
          data: item,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: _DragFeedback(
            width: 280,
            child: cardBuilder(context, item),
          ),
          childWhenDragging: Opacity(opacity: 0.4, child: card),
          child: card,
        );
      },
    );
  }
}

class _TappableCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _TappableCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: child,
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  final Widget child;
  final double width;
  const _DragFeedback({required this.child, required this.width});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 8,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(width: width, child: child),
    );
  }
}

class _EmptyColumn extends StatelessWidget {
  final Color color;
  const _EmptyColumn({required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            color: color.withValues(alpha: 0.4),
            size: 28,
          ),
          const SizedBox(height: 6),
          Text(
            'Aucune carte',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
