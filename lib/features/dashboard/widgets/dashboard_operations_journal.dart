import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:wanzo/constants/border_radius.dart';
import 'package:wanzo/constants/spacing.dart';
import 'package:wanzo/core/enums/currency_enum.dart';
import 'package:wanzo/core/modules/mode_vocabulary.dart';
import 'package:wanzo/core/services/currency_service.dart';
import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/core/utils/desktop_modal.dart';
import 'package:wanzo/features/auth/bloc/auth_bloc.dart';
import 'package:wanzo/features/cash_session/cash_access.dart';
import 'package:wanzo/features/dashboard/bloc/operation_journal_bloc.dart';
import 'package:wanzo/features/dashboard/models/journal_filter.dart';
import 'package:wanzo/features/dashboard/models/operation_journal_entry.dart';
import 'package:wanzo/features/expenses/bloc/expense_bloc.dart';
import 'package:wanzo/features/inventory/bloc/inventory_bloc.dart';
import 'package:wanzo/features/inventory/bloc/inventory_event.dart';
import 'package:wanzo/features/sales/bloc/sales_bloc.dart';
import 'package:wanzo/features/settings/bloc/settings_bloc.dart';
import 'package:wanzo/features/settings/bloc/settings_state.dart';
import 'package:wanzo/l10n/app_localizations.dart';
import 'package:wanzo/services/journal_export_service.dart';

import '../utils/open_journal_operation.dart';

/// Sortie du PDF du journal : aperçu avant impression (usage desktop), fichier
/// enregistré à l'endroit choisi, ou partage système.
enum _JournalPdfAction { print, save, share }

/// Charge ce que le graphique et le journal du tableau de bord affichent :
/// ventes et dépenses des 365 derniers jours, journal du mois en cours, et
/// au besoin le stock. Mêmes plages que le tableau de bord Général, pour que
/// les écrans d'accueil des modes (salon, restaurant) montrent les mêmes
/// chiffres.
void loadDashboardFeeds(BuildContext context, {bool includeInventory = true}) {
  final now = DateTime.now();
  context.read<SalesBloc>().add(
    LoadSalesByDateRange(
      startDate: now.subtract(const Duration(days: 365)),
      endDate: now,
    ),
  );
  context.read<ExpenseBloc>().add(
    LoadExpensesByDateRange(now.subtract(const Duration(days: 365)), now),
  );
  context.read<OperationJournalBloc>().add(
    LoadOperations(
      startDate: DateTime(now.year, now.month, 1),
      endDate: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    ),
  );
  if (includeInventory) {
    context.read<InventoryBloc>().add(const LoadProducts());
  }
}

/// Devise d'affichage : la devise active des paramètres (CDF tant qu'ils ne
/// sont pas chargés). Reconstruit l'appelant quand elle change.
String dashboardDisplayCurrency(BuildContext context) {
  final s = context.watch<SettingsBloc>().state;
  if (s is SettingsLoaded) return s.settings.activeCurrency.code;
  if (s is SettingsUpdated) return s.settings.activeCurrency.code;
  return 'CDF';
}

/// Bloc « Journal des opérations » du tableau de bord : l'onglet, la table
/// des dix dernières opérations, les filtres rapides et l'accès à la vue
/// agrandie (« Voir tout »). Un seul code pour le mode Général et les modes
/// métier.
class DashboardOperationsJournal extends StatelessWidget {
  final String displayCurrencyCode;

  /// Ouvre la vue agrandie ([OperationsJournalExpandedView]).
  final VoidCallback onExpand;

  const DashboardOperationsJournal({
    super.key,
    required this.displayCurrencyCode,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 1, // Seulement 1 onglet maintenant
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(
              context,
            ).colorScheme.onSurface.withAlpha((0.7 * 255).round()),
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Tab(
                text: l10n.dashboardOperationsJournalTitle,
              ), // Seul onglet restant
            ],
          ),
          SizedBox(
            // Hauteur ajustée pour un seul onglet
            height: 420,
            child: TabBarView(
              children: [
                OperationsJournalCard(
                  isExpanded: false,
                  displayCurrencyCode: displayCurrencyCode,
                  onExpand: onExpand,
                ), // Seul contenu
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte du journal : en-tête, période en vigueur, puis la table. Réduite
/// (dix lignes, hauteur fixe) sur le tableau de bord, agrandie (pagination
/// « Charger plus ») dans [OperationsJournalExpandedView].
class OperationsJournalCard extends StatelessWidget {
  final bool isExpanded;
  final String displayCurrencyCode;
  final VoidCallback? onExpand;
  final VoidCallback? onCollapse;

  /// Lignes affichées en vue agrandie.
  final int journalLimit;

  /// « Charger plus » en vue agrandie.
  final VoidCallback? onLoadMore;

  const OperationsJournalCard({
    super.key,
    required this.isExpanded,
    required this.displayCurrencyCode,
    this.onExpand,
    this.onCollapse,
    this.journalLimit = 10,
    this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final DateFormat dateFormat = DateFormat.yMd(locale);
    final DateFormat timeFormat = DateFormat.Hm(locale);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WanzoBorderRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(WanzoSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Le titre cède la place aux boutons sur fenêtre étroite.
                Flexible(
                  child: Text(
                    l10n.dashboardOperationsJournalTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bouton de filtrage rapide
                    IconButton(
                      icon: const Icon(Icons.filter_list, size: 20),
                      onPressed: () => showJournalQuickFilters(context),
                      tooltip: 'Filtres rapides',
                    ),
                    // Bouton "Voir tout" / "Fermer" avec texte responsif
                    TextButton(
                      onPressed: isExpanded ? onCollapse : onExpand,
                      child: Text(
                        isExpanded
                            ? 'Fermer'
                            : (MediaQuery.of(context).size.width < 600
                                ? 'Tout'
                                : l10n.dashboardOperationsJournalViewAll),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Période et vue en vigueur : ce que l'export reprendra.
            BlocBuilder<OperationJournalBloc, OperationJournalState>(
              buildWhen: (_, s) => s is OperationJournalLoaded,
              builder: (context, journalState) {
                if (journalState is! OperationJournalLoaded) {
                  return const SizedBox.shrink();
                }
                final view = journalState.activeFilter?.view ?? JournalView.all;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${view.label} · ${dateFormat.format(journalState.startDate)} au ${dateFormat.format(journalState.endDate)}'
                    ' · ${journalState.operations.length} opération(s)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
            BlocBuilder<OperationJournalBloc, OperationJournalState>(
              builder: (context, journalState) {
                if (journalState is OperationJournalLoading) {
                  return Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: l10n.commonLoading,
                    ),
                  );
                } else if (journalState is OperationJournalError) {
                  return Center(
                    child: Text('${l10n.commonError}: ${journalState.message}'),
                  );
                } else if (journalState is OperationJournalLoaded) {
                  if (journalState.operations.isEmpty) {
                    return SizedBox(
                      height: isExpanded ? 200 : 100,
                      child: Center(
                        child: Text(
                          l10n.dashboardOperationsJournalNoData,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    );
                  }
                  // Plus récentes d'abord ; la vue agrandie se déroule par
                  // pages (« Charger plus »).
                  final sorted = [...journalState.operations]
                    ..sort((a, b) => b.date.compareTo(a.date));
                  final entriesToShow =
                      isExpanded
                          ? sorted.take(journalLimit).toList()
                          : sorted.take(10).toList();

                  final hasMoreEntries =
                      (!isExpanded && sorted.length > 10) ||
                      (isExpanded && sorted.length > journalLimit);

                  return isExpanded
                      ? SizedBox(
                        height: MediaQuery.of(context).size.height * 0.75,
                        child: Column(
                          children: [
                            Expanded(
                              child: _OperationsDataTable(
                                entries: entriesToShow,
                                dateFormat: dateFormat,
                                timeFormat: timeFormat,
                              ),
                            ),
                            if (hasMoreEntries)
                              TextButton.icon(
                                onPressed: onLoadMore,
                                icon: const Icon(Icons.expand_more),
                                label: Text(
                                  'Charger plus '
                                  '(${entriesToShow.length} sur ${sorted.length})',
                                ),
                              ),
                          ],
                        ),
                      )
                      : SizedBox(
                        height: 300,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: _OperationsDataTable(
                                entries: entriesToShow,
                                dateFormat: dateFormat,
                                timeFormat: timeFormat,
                              ),
                            ),
                            if (hasMoreEntries)
                              SizedBox(
                                height: 30,
                                child: InkWell(
                                  onTap: onExpand,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4.0,
                                    ),
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.expand_more,
                                          size: 14,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 2),
                                        Flexible(
                                          child: Text(
                                            'Voir plus d\'opérations',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.copyWith(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                }
                return Center(child: Text(l10n.commonErrorDataUnavailable));
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Table des opérations du journal (icône, description, type, date,
/// montant, solde) ; une ligne ouvre sa pièce.
class _OperationsDataTable extends StatelessWidget {
  final List<OperationJournalEntry> entries;
  final DateFormat dateFormat;
  final DateFormat timeFormat;

  const _OperationsDataTable({
    required this.entries,
    required this.dateFormat,
    required this.timeFormat,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                showCheckboxColumn: false,
                columnSpacing: isCompact ? 12 : 20,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 48,
                headingRowHeight: 40,
                headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                columns: [
                  const DataColumn(label: Text('')), // Icône
                  const DataColumn(label: Text('Description')),
                  if (!isCompact) const DataColumn(label: Text('Type')),
                  const DataColumn(label: Text('Date')),
                  const DataColumn(label: Text('Montant'), numeric: true),
                  if (!isCompact)
                    DataColumn(
                      label: Text(l10n.dashboardOperationsJournalBalanceLabel),
                      numeric: true,
                    ),
                ],
                rows:
                    entries.map((entry) {
                      final effectiveCurrencyCode =
                          entry.currencyCode ?? 'CDF'; // sans code : base CDF
                      String amountDisplay;
                      Color amountColor;

                      if (entry.isDebit) {
                        amountDisplay =
                            "- ${formatCurrency(entry.amount.abs(), effectiveCurrencyCode)}";
                        amountColor = Colors.redAccent;
                      } else if (entry.isCredit) {
                        amountDisplay =
                            "+ ${formatCurrency(entry.amount.abs(), effectiveCurrencyCode)}";
                        amountColor = Colors.green;
                      } else {
                        amountDisplay = formatCurrency(
                          entry.amount,
                          effectiveCurrencyCode,
                        );
                        amountColor = Theme.of(context).colorScheme.onSurface;
                      }

                      return DataRow(
                        // Une ligne du journal reflète un document : on l'ouvre
                        // (vente, dépense, produit) ; sans pièce, un message le
                        // dit, jamais de clic muet.
                        onSelectChanged: (_) {
                          openJournalOperationDocument(context, entry);
                        },
                        cells: [
                          DataCell(
                            Icon(
                              entry.type.icon,
                              size: 18,
                              color:
                                  entry.isDebit
                                      ? Colors.redAccent
                                      : Colors.green,
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: isCompact ? 120 : 200,
                              ),
                              child: Text(
                                entry.description,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                          if (!isCompact)
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: (entry.isDebit
                                          ? Colors.redAccent
                                          : Colors.green)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  entry.type.displayName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        entry.isDebit
                                            ? Colors.redAccent
                                            : Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          DataCell(
                            Text(
                              "${dateFormat.format(entry.date)} ${timeFormat.format(entry.date)}",
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          DataCell(
                            Text(
                              amountDisplay,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: amountColor,
                              ),
                            ),
                          ),
                          if (!isCompact)
                            DataCell(
                              // Solde de caisse tenu dans la devise de la
                              // ligne : jamais affiché sous un autre code.
                              Text(
                                entry.cashBalance == null
                                    ? '-'
                                    : formatCurrency(
                                      entry.cashBalance!,
                                      effectiveCurrencyCode,
                                    ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      );
                    }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Vue agrandie du journal, dans le shell de l'application (navigation,
/// barre) avec un retour vers le tableau de bord : filtres rapides, période,
/// export PDF et « Charger plus ».
class OperationsJournalExpandedView extends StatefulWidget {
  final String displayCurrencyCode;
  final VoidCallback onCollapse;

  /// Entrée de navigation active (celle du tableau de bord appelant).
  final int currentIndex;

  const OperationsJournalExpandedView({
    super.key,
    required this.displayCurrencyCode,
    required this.onCollapse,
    this.currentIndex = 0,
  });

  @override
  State<OperationsJournalExpandedView> createState() =>
      _OperationsJournalExpandedViewState();
}

class _OperationsJournalExpandedViewState
    extends State<OperationsJournalExpandedView> {
  /// Lignes affichées dans le journal agrandi, augmentées par « Charger plus ».
  static const int _journalPageSize = 100;
  int _journalLimit = _journalPageSize;

  // Dernière période personnalisée choisie : le sélecteur la repropose à la
  // réouverture de la vue agrandie.
  static DateTime? _selectedStartDate;
  static DateTime? _selectedEndDate;

  /// Exporte les opérations du journal (filtre actif) en PDF
  void _exportJournalOperations(
    BuildContext context,
    OperationJournalLoaded journalState,
    _JournalPdfAction action,
  ) async {
    try {
      // Affichage d'un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Génération du PDF en cours...'),
                ],
              ),
            ),
      );

      // Récupération de l'utilisateur actuel
      final authState = context.read<AuthBloc>().state;
      final currentUser =
          authState is AuthAuthenticated ? authState.user : null;

      // Utilisation du filtre actif ou filtre par défaut
      final activeFilter =
          journalState.activeFilter ?? JournalFilter.defaultFilter();

      final currencyService = _currencyServiceOf(context);
      String? successMessage;
      switch (action) {
        case _JournalPdfAction.print:
          await JournalExportService.exportAndPrint(
            operations: journalState.operations,
            filter: activeFilter,
            currentUser: currentUser,
            currencyService: currencyService,
          );
          break;
        case _JournalPdfAction.save:
          final path = await JournalExportService.exportAndSave(
            operations: journalState.operations,
            filter: activeFilter,
            currentUser: currentUser,
            currencyService: currencyService,
          );
          if (path != null) successMessage = 'Journal enregistré : $path';
          break;
        case _JournalPdfAction.share:
          await JournalExportService.exportAndShare(
            operations: journalState.operations,
            filter: activeFilter,
            currentUser: currentUser,
            currencyService: currencyService,
          );
          break;
      }

      // Fermeture de l'indicateur de chargement
      if (context.mounted) {
        Navigator.of(context).pop();
        if (successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Fermeture de l'indicateur de chargement en cas d'erreur
      if (context.mounted) {
        Navigator.of(context).pop();

        // Message d'erreur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération du PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _selectDateRangeInternal(
    BuildContext context,
    AppLocalizations l10n,
    Function(DateTime, DateTime) onRangeSelected,
  ) async {
    final locale = Localizations.localeOf(context);
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start:
            _selectedStartDate ??
            DateTime.now().subtract(const Duration(days: 7)),
        end: _selectedEndDate ?? DateTime.now(),
      ),
      helpText: l10n.dashboardJournalExportSelectDateRangeTitle,
      cancelText: l10n.commonCancel.toUpperCase(),
      confirmText: l10n.commonConfirm.toUpperCase(),
      locale: locale,
      builder: (context, child) {
        return Theme(data: Theme.of(context).copyWith(), child: child!);
      },
    );

    if (picked != null) {
      final endDate = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
      );
      setState(() {
        _selectedStartDate = picked.start;
        _selectedEndDate = endDate;
      });
      onRangeSelected(picked.start, endDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = l10n.dashboardOperationsJournalTitle;
    final settingsState = context.watch<SettingsBloc>().state;
    final journalBloc = context.read<OperationJournalBloc>();
    if (settingsState is! SettingsLoaded && settingsState is! SettingsUpdated) {
      return WanzoScaffold(
        currentIndex: widget.currentIndex,
        title: title,
        onBackPressed: widget.onCollapse,
        body: Center(child: Text(l10n.commonLoading)),
      );
    }

    final actions = <Widget>[
      // Bouton pour filtres rapides
      IconButton(
        icon: const Icon(Icons.filter_list),
        tooltip: 'Filtres rapides',
        onPressed: () => showJournalQuickFilters(context),
      ),
      // Bouton pour filtres de période
      PopupMenuButton<String>(
        icon: const Icon(Icons.calendar_month_rounded),
        tooltip: 'Filtrer par période',
        onSelected: (value) {
          DateTime now = DateTime.now();
          DateTime startDate = now;
          DateTime endDate = now;

          if (value == 'today') {
            startDate = DateTime(now.year, now.month, now.day);
            endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          } else if (value == 'this_month') {
            startDate = DateTime(now.year, now.month, 1);
            endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          } else if (value == 'this_year') {
            startDate = DateTime(now.year, 1, 1);
            endDate = DateTime(now.year, 12, 31, 23, 59, 59);
          } else if (value == 'custom') {
            _selectDateRangeInternal(context, l10n, (start, end) {
              if (!mounted) return;
              journalBloc.add(
                FilterPeriodChanged(newStartDate: start, newEndDate: end),
              );
            });
            return;
          } else {
            return;
          }
          journalBloc.add(
            FilterPeriodChanged(newStartDate: startDate, newEndDate: endDate),
          );
        },
        itemBuilder:
            (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'today',
                child: Text(l10n.commonToday),
              ),
              PopupMenuItem<String>(
                value: 'this_month',
                child: Text(l10n.commonThisMonth),
              ),
              PopupMenuItem<String>(
                value: 'this_year',
                child: Text(l10n.commonThisYear),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'custom',
                child: Text(l10n.commonCustom),
              ),
            ],
      ),
      // Un seul export : le PDF des opérations affichées (filtre actif).
      BlocBuilder<OperationJournalBloc, OperationJournalState>(
        builder: (context, journalState) {
          final hasData =
              journalState is OperationJournalLoaded &&
              journalState.operations.isNotEmpty;
          return PopupMenuButton<_JournalPdfAction>(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: l10n.dashboardJournalExportExportButton,
            enabled: hasData,
            onSelected: (action) {
              if (journalState is OperationJournalLoaded) {
                _exportJournalOperations(context, journalState, action);
              }
            },
            itemBuilder:
                (context) => const [
                  PopupMenuItem(
                    value: _JournalPdfAction.print,
                    child: ListTile(
                      leading: Icon(Icons.print_outlined),
                      title: Text('Aperçu et impression'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _JournalPdfAction.save,
                    child: ListTile(
                      leading: Icon(Icons.save_alt),
                      title: Text('Enregistrer le PDF'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _JournalPdfAction.share,
                    child: ListTile(
                      leading: Icon(Icons.share_outlined),
                      title: Text('Partager'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
          );
        },
      ),
    ];

    // Shell de l'application conservé (navigation, barre) avec un retour vers
    // le tableau de bord.
    return WanzoScaffold(
      currentIndex: widget.currentIndex,
      title: title,
      appBarActions: actions,
      onBackPressed: widget.onCollapse,
      body: Padding(
        padding: const EdgeInsets.all(WanzoSpacing.md),
        child: OperationsJournalCard(
          isExpanded: true,
          displayCurrencyCode: widget.displayCurrencyCode,
          onCollapse: widget.onCollapse,
          journalLimit: _journalLimit,
          onLoadMore: () => setState(() => _journalLimit += _journalPageSize),
        ),
      ),
    );
  }
}

/// Filtres rapides du journal des opérations (fenêtre modale desktop) : vue
/// (Tout, Caisse, Comptabilité) puis type. Le vocabulaire suit le mode.
void showJournalQuickFilters(BuildContext context) {
  final journalBloc = context.read<OperationJournalBloc>();
  final current = journalBloc.currentFilter;
  final showCash = canSeeCash(context);
  void apply(JournalFilter filter) {
    journalBloc.add(LoadOperationsWithFilter(filter: filter));
  }

  Widget chip(BuildContext ctx, String label, VoidCallback onPressed) {
    return ActionChip(
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
    );
  }

  showDesktopModal(
    context,
    title: 'Filtres du journal',
    contentPadding: EdgeInsets.zero,
    builder:
        (sheetContext) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(WanzoSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vue',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: WanzoSpacing.sm),
                // Tout, Caisse (espèces) ou Comptabilité : la période
                // affichée est conservée, l'export suit.
                Wrap(
                  spacing: WanzoSpacing.sm,
                  runSpacing: WanzoSpacing.sm,
                  children: [
                    for (final view in visibleJournalViews(showCash))
                      ChoiceChip(
                        label: Text(view.label),
                        tooltip: view.hint,
                        selected:
                            current.view == view &&
                            current.selectedTypes.isEmpty,
                        onSelected: (_) {
                          apply(JournalFilter.forView(view));
                          Navigator.pop(sheetContext);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: WanzoSpacing.md),
                Text(
                  'Type',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: WanzoSpacing.sm),
                Wrap(
                  spacing: WanzoSpacing.sm,
                  runSpacing: WanzoSpacing.sm,
                  children: [
                    chip(sheetContext, ModeVocabulary.current.sales, () {
                      apply(JournalFilter.salesOnly());
                      Navigator.pop(sheetContext);
                    }),
                    chip(sheetContext, ModeVocabulary.current.stock, () {
                      apply(JournalFilter.stockOnly());
                      Navigator.pop(sheetContext);
                    }),
                    chip(sheetContext, 'Dépenses', () {
                      apply(JournalFilter.expensesOnly());
                      Navigator.pop(sheetContext);
                    }),
                    chip(sheetContext, 'Dettes', () {
                      apply(JournalFilter.customerDebts());
                      Navigator.pop(sheetContext);
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
  );
}

/// Taux de la société fournis par l'application (null s'ils sont absents) :
/// les PDF du journal consolident leurs totaux en CDF avec ces taux.
CurrencyService? _currencyServiceOf(BuildContext context) {
  try {
    return context.read<CurrencyService>();
  } catch (_) {
    return null;
  }
}
