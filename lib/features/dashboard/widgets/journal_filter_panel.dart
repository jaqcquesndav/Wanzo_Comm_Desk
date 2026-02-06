import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wanzo/l10n/app_localizations.dart';
import 'package:wanzo/utils/theme.dart';
import '../models/journal_filter.dart';
import '../models/operation_journal_entry.dart';

/// Widget pour les filtres du journal des opérations
class JournalFilterPanel extends StatefulWidget {
  final JournalFilter initialFilter;
  final Function(JournalFilter) onFilterChanged;
  final VoidCallback? onReset;

  const JournalFilterPanel({
    super.key,
    required this.initialFilter,
    required this.onFilterChanged,
    this.onReset,
  });

  @override
  State<JournalFilterPanel> createState() => _JournalFilterPanelState();
}

class _JournalFilterPanelState extends State<JournalFilterPanel> {
  late JournalFilter _currentFilter;
  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
    _initializeControllers();
  }

  void _initializeControllers() {
    _minAmountController.text = _currentFilter.minAmount?.toString() ?? '';
    _maxAmountController.text = _currentFilter.maxAmount?.toString() ?? '';
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  void _updateFilter(JournalFilter newFilter) {
    setState(() {
      _currentFilter = newFilter;
    });
    widget.onFilterChanged(newFilter);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(WanzoTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec bouton reset
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filtres du Journal',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.onReset != null)
                  TextButton.icon(
                    onPressed: () {
                      _resetFilters();
                      widget.onReset?.call();
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Réinitialiser'),
                  ),
              ],
            ),
            const SizedBox(height: WanzoTheme.spacingMd),

            // Filtres rapides
            _buildQuickFilters(l10n, theme),
            const SizedBox(height: WanzoTheme.spacingMd),

            // Types d'opérations
            _buildOperationTypeFilter(l10n, theme),
            const SizedBox(height: WanzoTheme.spacingMd),

            // Filtres de montant
            _buildAmountFilter(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilters(AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filtres Rapides',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: WanzoTheme.spacingSm),
        Wrap(
          spacing: WanzoTheme.spacingSm,
          children: [
            _buildQuickFilterChip('Toutes', JournalFilter.defaultFilter()),
            _buildQuickFilterChip('Ventes', JournalFilter.salesOnly()),
            _buildQuickFilterChip('Stock', JournalFilter.stockOnly()),
            _buildQuickFilterChip('Dépenses', JournalFilter.expensesOnly()),
            _buildQuickFilterChip('Dettes', JournalFilter.customerDebts()),
            // Nouveaux filtres pour distinguer comptabilité et trésorerie
            _buildQuickFilterChip(
              '💰 Trésorerie',
              JournalFilter.cashFlowOnly(),
            ),
            _buildQuickFilterChip(
              '📊 Comptabilité',
              JournalFilter.accountingOnly(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickFilterChip(String label, JournalFilter filter) {
    final isSelected =
        _currentFilter.selectedTypes.containsAll(filter.selectedTypes) &&
        filter.selectedTypes.containsAll(_currentFilter.selectedTypes);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _updateFilter(
            filter.copyWith(
              startDate: _currentFilter.startDate,
              endDate: _currentFilter.endDate,
            ),
          );
        }
      },
    );
  }

  Widget _buildOperationTypeFilter(AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Types d\'Opérations',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: WanzoTheme.spacingSm),
        Wrap(
          spacing: WanzoTheme.spacingXs,
          runSpacing: WanzoTheme.spacingXs,
          children:
              OperationType.values.map((type) {
                final isSelected = _currentFilter.selectedTypes.contains(type);
                return FilterChip(
                  label: Text(
                    type.displayName,
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    final newTypes = Set<OperationType>.from(
                      _currentFilter.selectedTypes,
                    );
                    if (selected) {
                      newTypes.add(type);
                    } else {
                      newTypes.remove(type);
                    }
                    _updateFilter(
                      _currentFilter.copyWith(selectedTypes: newTypes),
                    );
                  },
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildAmountFilter(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _minAmountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: const InputDecoration(
              labelText: 'Montant Min.',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.attach_money),
            ),
            onChanged: (value) {
              final amount = double.tryParse(value);
              _updateFilter(_currentFilter.copyWith(minAmount: amount));
            },
          ),
        ),
        const SizedBox(width: WanzoTheme.spacingSm),
        Expanded(
          child: TextField(
            controller: _maxAmountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: const InputDecoration(
              labelText: 'Montant Max.',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.attach_money),
            ),
            onChanged: (value) {
              final amount = double.tryParse(value);
              _updateFilter(_currentFilter.copyWith(maxAmount: amount));
            },
          ),
        ),
      ],
    );
  }

  void _resetFilters() {
    final defaultFilter = JournalFilter.defaultFilter();
    setState(() {
      _currentFilter = defaultFilter;
      _minAmountController.clear();
      _maxAmountController.clear();
    });
    _updateFilter(defaultFilter);
  }
}
