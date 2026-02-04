import 'package:flutter/material.dart';
import '../../platform/platform_service.dart';

/// Conteneur de liste adaptative pour desktop et mobile
/// Sur desktop: affiche un DataTable avec pagination
/// Sur mobile: affiche une ListView avec cards
class AdaptiveListContainer<T> extends StatefulWidget {
  /// Données à afficher
  final List<T> items;

  /// Builder pour les lignes du DataTable (desktop)
  final DataRow Function(T item, int index) rowBuilder;

  /// Builder pour les cards (mobile)
  final Widget Function(T item, int index) cardBuilder;

  /// Colonnes du DataTable
  final List<DataColumn> columns;

  /// Titre de la liste
  final String? title;

  /// Sous-titre / description
  final String? subtitle;

  /// Actions du header (boutons)
  final List<Widget>? headerActions;

  /// Callback de recherche
  final void Function(String)? onSearch;

  /// Hint de la barre de recherche
  final String? searchHint;

  /// Widget à afficher quand la liste est vide
  final Widget? emptyWidget;

  /// Nombre d'items par page (desktop)
  final int itemsPerPage;

  /// Trier par colonne
  final int? sortColumnIndex;
  final bool sortAscending;
  final void Function(int, bool)? onSort;

  /// Afficher la recherche
  final bool showSearch;

  /// Afficher les stats
  final bool showStats;

  /// Stats widgets
  final List<Widget>? statsWidgets;

  const AdaptiveListContainer({
    super.key,
    required this.items,
    required this.rowBuilder,
    required this.cardBuilder,
    required this.columns,
    this.title,
    this.subtitle,
    this.headerActions,
    this.onSearch,
    this.searchHint,
    this.emptyWidget,
    this.itemsPerPage = 15,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSort,
    this.showSearch = true,
    this.showStats = false,
    this.statsWidgets,
  });

  @override
  State<AdaptiveListContainer<T>> createState() =>
      _AdaptiveListContainerState<T>();
}

class _AdaptiveListContainerState<T> extends State<AdaptiveListContainer<T>> {
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final platform = PlatformService.instance;
    final isDesktop = screenWidth >= platform.desktopMinWidth;
    final isTablet = screenWidth >= platform.tabletMinWidth && !isDesktop;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header avec titre, recherche et actions
        if (widget.title != null ||
            widget.showSearch ||
            widget.headerActions != null)
          _buildHeader(context, isDesktop),

        // Stats (optionnel)
        if (widget.showStats && widget.statsWidgets != null)
          _buildStats(context, isDesktop),

        // Contenu principal
        Expanded(
          child:
              widget.items.isEmpty
                  ? widget.emptyWidget ?? _buildEmptyState(context)
                  : (isDesktop || isTablet)
                  ? _buildDesktopTable(context)
                  : _buildMobileList(context),
        ),

        // Pagination (desktop)
        if ((isDesktop || isTablet) &&
            widget.items.length > widget.itemsPerPage)
          _buildPagination(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre et actions
          Row(
            children: [
              if (widget.title != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title!,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (widget.headerActions != null) ...widget.headerActions!,
            ],
          ),

          // Barre de recherche
          if (widget.showSearch) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: isDesktop ? 2 : 1,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: widget.searchHint ?? 'Rechercher...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon:
                          _searchController.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  widget.onSearch?.call('');
                                },
                              )
                              : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                    ),
                    onChanged: (value) {
                      setState(() {});
                      widget.onSearch?.call(value);
                    },
                  ),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 16),
                  // Placeholder pour d'autres filtres si nécessaire
                  const Expanded(flex: 3, child: SizedBox()),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context, bool isDesktop) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 16,
        vertical: 8,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              widget.statsWidgets!
                  .map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: w,
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }

  Widget _buildDesktopTable(BuildContext context) {
    final theme = Theme.of(context);

    // Pagination
    final startIndex = _currentPage * widget.itemsPerPage;
    final endIndex = (startIndex + widget.itemsPerPage).clamp(
      0,
      widget.items.length,
    );
    final pageItems = widget.items.sublist(startIndex, endIndex);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
              ),
              dataRowMaxHeight: 72,
              columnSpacing: 24,
              horizontalMargin: 20,
              sortColumnIndex: widget.sortColumnIndex,
              sortAscending: widget.sortAscending,
              columns: widget.columns,
              rows:
                  pageItems
                      .asMap()
                      .entries
                      .map(
                        (entry) => widget.rowBuilder(
                          entry.value,
                          startIndex + entry.key,
                        ),
                      )
                      .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        return widget.cardBuilder(widget.items[index], index);
      },
    );
  }

  Widget _buildPagination(BuildContext context) {
    final theme = Theme.of(context);
    final totalPages = (widget.items.length / widget.itemsPerPage).ceil();
    final startItem = _currentPage * widget.itemsPerPage + 1;
    final endItem = ((_currentPage + 1) * widget.itemsPerPage).clamp(
      0,
      widget.items.length,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Affichage $startItem-$endItem sur ${widget.items.length}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.first_page),
                onPressed:
                    _currentPage > 0
                        ? () => setState(() => _currentPage = 0)
                        : null,
                tooltip: 'Première page',
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed:
                    _currentPage > 0
                        ? () => setState(() => _currentPage--)
                        : null,
                tooltip: 'Page précédente',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Page ${_currentPage + 1} / $totalPages',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed:
                    _currentPage < totalPages - 1
                        ? () => setState(() => _currentPage++)
                        : null,
                tooltip: 'Page suivante',
              ),
              IconButton(
                icon: const Icon(Icons.last_page),
                onPressed:
                    _currentPage < totalPages - 1
                        ? () => setState(() => _currentPage = totalPages - 1)
                        : null,
                tooltip: 'Dernière page',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune donnée',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les éléments apparaîtront ici',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget de statistique pour le header de liste
class ListStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const ListStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: effectiveColor, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: effectiveColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
