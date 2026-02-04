import 'package:flutter/material.dart';
import '../../config/desktop_config.dart';

/// DataTable amélioré pour la version desktop avec pagination, tri et recherche
class DesktopDataTable<T> extends StatefulWidget {
  final List<T> data;
  final List<DataColumn> columns;
  final DataRow Function(T item) rowBuilder;
  final String? searchHint;
  final bool Function(T item, String query)? searchFilter;
  final VoidCallback? onAdd;
  final String? addButtonLabel;
  final List<Widget>? actions;
  final bool showPagination;
  final bool showSearch;
  final int? initialPageSize;
  final void Function(T item)? onRowTap;
  final void Function(T item)? onRowDoubleTap;
  final bool selectable;
  final void Function(List<T> selectedItems)? onSelectionChanged;

  const DesktopDataTable({
    super.key,
    required this.data,
    required this.columns,
    required this.rowBuilder,
    this.searchHint,
    this.searchFilter,
    this.onAdd,
    this.addButtonLabel,
    this.actions,
    this.showPagination = true,
    this.showSearch = true,
    this.initialPageSize,
    this.onRowTap,
    this.onRowDoubleTap,
    this.selectable = false,
    this.onSelectionChanged,
  });

  @override
  State<DesktopDataTable<T>> createState() => _DesktopDataTableState<T>();
}

class _DesktopDataTableState<T> extends State<DesktopDataTable<T>> {
  final TextEditingController _searchController = TextEditingController();
  late int _pageSize;
  int _currentPage = 0;
  String _searchQuery = '';
  final Set<T> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    _pageSize =
        widget.initialPageSize ?? DesktopConfig.dataTableDefaultPageSize;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<T> get _filteredData {
    if (_searchQuery.isEmpty || widget.searchFilter == null) {
      return widget.data;
    }
    return widget.data
        .where((item) => widget.searchFilter!(item, _searchQuery.toLowerCase()))
        .toList();
  }

  List<T> get _paginatedData {
    final startIndex = _currentPage * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, _filteredData.length);
    return _filteredData.sublist(startIndex, endIndex);
  }

  int get _totalPages => (_filteredData.length / _pageSize).ceil();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Toolbar
        _buildToolbar(theme),

        const Divider(height: 1),

        // Table
        Expanded(
          child:
              _filteredData.isEmpty
                  ? _buildEmptyState(theme)
                  : SingleChildScrollView(
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        headingRowHeight: DesktopConfig.dataTableHeaderHeight,
                        dataRowMinHeight: DesktopConfig.dataTableRowHeight,
                        dataRowMaxHeight: DesktopConfig.dataTableRowHeight,
                        showCheckboxColumn: widget.selectable,
                        columns: widget.columns,
                        rows:
                            _paginatedData.map((item) {
                              final row = widget.rowBuilder(item);
                              return DataRow(
                                selected: _selectedItems.contains(item),
                                onSelectChanged:
                                    widget.selectable
                                        ? (selected) {
                                          setState(() {
                                            if (selected ?? false) {
                                              _selectedItems.add(item);
                                            } else {
                                              _selectedItems.remove(item);
                                            }
                                          });
                                          widget.onSelectionChanged?.call(
                                            _selectedItems.toList(),
                                          );
                                        }
                                        : null,
                                onLongPress:
                                    () => widget.onRowDoubleTap?.call(item),
                                cells: row.cells,
                              );
                            }).toList(),
                      ),
                    ),
                  ),
        ),

        // Pagination
        if (widget.showPagination && _filteredData.isNotEmpty)
          _buildPagination(theme),
      ],
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Bouton d'ajout
          if (widget.onAdd != null)
            ElevatedButton.icon(
              onPressed: widget.onAdd,
              icon: const Icon(Icons.add),
              label: Text(widget.addButtonLabel ?? 'Ajouter'),
            ),

          if (widget.onAdd != null) const SizedBox(width: 16),

          // Actions personnalisées
          if (widget.actions != null) ...widget.actions!,

          const Spacer(),

          // Recherche
          if (widget.showSearch)
            SizedBox(
              width: 300,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.searchHint ?? 'Rechercher...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon:
                      _searchQuery.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _currentPage = 0;
                              });
                            },
                          )
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _currentPage = 0;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPagination(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          // Info sur les éléments affichés
          Text(
            'Affichage ${_currentPage * _pageSize + 1} - '
            '${((_currentPage + 1) * _pageSize).clamp(0, _filteredData.length)} '
            'sur ${_filteredData.length}',
            style: theme.textTheme.bodySmall,
          ),

          const Spacer(),

          // Sélecteur de taille de page
          Row(
            children: [
              Text('Lignes par page:', style: theme.textTheme.bodySmall),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _pageSize,
                underline: const SizedBox(),
                items:
                    DesktopConfig.dataTablePageSizeOptions
                        .map(
                          (size) => DropdownMenuItem(
                            value: size,
                            child: Text(size.toString()),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _pageSize = value;
                      _currentPage = 0;
                    });
                  }
                },
              ),
            ],
          ),

          const SizedBox(width: 24),

          // Navigation
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
                _currentPage > 0 ? () => setState(() => _currentPage--) : null,
            tooltip: 'Page précédente',
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Page ${_currentPage + 1} / $_totalPages',
              style: theme.textTheme.bodyMedium,
            ),
          ),

          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed:
                _currentPage < _totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
            tooltip: 'Page suivante',
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed:
                _currentPage < _totalPages - 1
                    ? () => setState(() => _currentPage = _totalPages - 1)
                    : null,
            tooltip: 'Dernière page',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Aucun résultat pour "$_searchQuery"'
                : 'Aucune donnée',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _currentPage = 0;
                });
              },
              child: const Text('Effacer la recherche'),
            ),
          ],
        ],
      ),
    );
  }
}
