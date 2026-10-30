import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:wanzo/core/modules/module_registry.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/core/shared_widgets/kpi_board.dart';
import 'package:wanzo/core/shared_widgets/kpi_grid.dart';
import 'package:wanzo/core/utils/daily_series.dart';
import 'package:wanzo/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:wanzo/features/dashboard/widgets/dashboard_operations_journal.dart';
import 'package:wanzo/features/dashboard/widgets/dashboard_sales_expense_chart.dart';
import 'package:wanzo/features/dashboard/widgets/mode_dashboard_layout.dart';
import 'package:wanzo/features/sales/bloc/sales_bloc.dart';

import '../cubit/salon_cubit.dart';
import '../services/salon_api_service.dart';

/// Tableau de bord du mode SALON DE COIFFURE (desktop).
///
/// Même mise en page que le tableau de bord Général : les six vignettes du
/// salon, le graphique ventes et charges, puis le journal des opérations,
/// sur toute la largeur. Nouveau ticket et nouvelle prestation sont dans le
/// dock d'actions rapides du shell ; équipe et performances dans la barre
/// latérale. Les données du salon proviennent du `SalonCubit`.
class SalonDashboardScreen extends StatefulWidget {
  const SalonDashboardScreen({super.key});

  @override
  State<SalonDashboardScreen> createState() => _SalonDashboardScreenState();
}

class _SalonDashboardScreenState extends State<SalonDashboardScreen> {
  final SalonApiService _api = SalonApiService();

  // Commissions à payer sur le mois en cours (source réelle :
  // `SalonApiService.getCommissions`, comme l'écran Performances). Neutre
  // (`null`) tant que non chargé / indisponible — jamais de valeur fabriquée.
  double? _commissionsMonth;

  /// Ce qui reste a verser a l'equipe sur le mois : commissions gagnees moins
  /// avances et reglements deja faits. C'est lui qui bouge quand on paie ; le
  /// total gagne, seul affiche jusqu'ici, ne bougeait jamais.
  double? _resteAVerser;

  /// Vue agrandie du journal des opérations (« Voir tout »).
  bool _journalExpanded = false;

  @override
  void initState() {
    super.initState();
    // Le tableau de bord salon EST l'écran d'accueil du mode : personne d'autre
    // n'amorce le KPI global (CA du jour). On le déclenche si besoin.
    final dashState = context.read<DashboardBloc>().state;
    if (dashState is! DashboardLoaded) {
      context.read<DashboardBloc>().add(LoadDashboardData(date: DateTime.now()));
    }
    // Graphique et journal : mêmes données que le tableau de bord Général.
    loadDashboardFeeds(context);
    _loadCommissions();
  }

  /// Ouvre un ecran puis recharge le tableau au retour. Chaque ecran ouvert
  /// d'ici peut changer les chiffres (ticket, avance, depense) ; avec un simple
  /// `push`, le tableau restait fige tant qu'on ne changeait pas d'onglet.
  Future<void> _ouvrir(String route) async {
    await context.push(route);
    if (!mounted) return;
    _rafraichir();
  }

  Future<void> _rafraichir() async {
    context.read<DashboardBloc>().add(LoadDashboardData(date: DateTime.now()));
    loadDashboardFeeds(context);
    await _loadCommissions();
  }

  Future<void> _loadCommissions() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
    try {
      final rows = await _api.getCommissions(from: from, to: to);
      if (!mounted) return;
      setState(() {
        _commissionsMonth =
            rows.fold<double>(0, (sum, r) => sum + r.totalCommission);
        // Un coiffeur trop paye ne compense pas ce qui est du aux autres.
        _resteAVerser = rows.fold<double>(
            0, (sum, r) => sum + (r.balance > 0 ? r.balance : 0));
      });
    } catch (_) {
      // Indisponible (réseau/backend) : on laisse `_commissionsMonth` à null →
      // état neutre « — » dans la grille (jamais de valeur fabriquée).
      if (!mounted) return;
      setState(() {
        _commissionsMonth = null;
        _resteAVerser = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = BusinessContextService();
    final index = ModuleRegistry.indexOfSidebarRoute(
      ctx.activityMode,
      ctx.currentContext?.userRole,
      '/dashboard',
    );
    final displayCurrencyCode = dashboardDisplayCurrency(context);

    if (_journalExpanded) {
      return OperationsJournalExpandedView(
        displayCurrencyCode: displayCurrencyCode,
        currentIndex: index < 0 ? 0 : index,
        onCollapse: () => setState(() => _journalExpanded = false),
      );
    }

    return WanzoScaffold(
      currentIndex: index < 0 ? 0 : index,
      title: 'Tableau de bord',
      appBarActions: [
        // Pas de « tirer pour actualiser » au desktop : bouton explicite.
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualiser',
          onPressed: _rafraichir,
        ),
      ],
      body: BlocBuilder<SalonCubit, SalonState>(
        builder: (context, state) {
          if (state.loading && state.services.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          // Même ordre que le Général : vignettes, graphique, journal, sur
          // toute la largeur (plus de colonne bornée à 900 px).
          return ModeDashboardLayout(
            onRefresh: _rafraichir,
            kpis: _kpiRow(context, state),
            chart: const ModeDashboardChart(),
            journal: DashboardOperationsJournal(
              displayCurrencyCode: displayCurrencyCode,
              onExpand: () => setState(() => _journalExpanded = true),
            ),
          );
        },
      ),
    );
  }

  /// KPI métier RÉELS (aucune valeur fabriquée) : CA du jour (CDF/USD) et
  /// clients servis proviennent du KPI global (`DashboardBloc`, même source que
  /// le tableau de bord principal et restaurant) ; les commissions à payer du
  /// mois proviennent de `SalonApiService`. Une donnée non chargée affiche un
  /// état neutre (« — »).
  /// Indicateurs du salon, hiérarchisés.
  ///
  /// Deux chiffres de pilotage en tête (ce qui rentre, ce qu'il reste à
  /// verser à l'équipe), le reste en vignettes de contrôle. Les valeurs sont
  /// réelles : CA et clients servis viennent du KPI global (`DashboardBloc`),
  /// les commissions de `SalonApiService`. Une donnée non chargée affiche
  /// « — », jamais un zéro qui ferait croire à une journée blanche.
  Widget _kpiRow(BuildContext context, SalonState state) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, dashState) {
        final bool loaded = dashState is DashboardLoaded;
        // Donnée pas encore chargée : un état neutre, jamais un zéro.
        const enAttente = 'En attente';
        final String caCdf =
            loaded ? formatCurrency(dashState.salesTodayCdf, 'CDF') : enAttente;
        final String caUsd =
            loaded ? formatCurrency(dashState.salesTodayUsd, 'USD') : enAttente;
        // `clientsServedToday` : nombre réel de clients servis aujourd'hui (≈
        // tickets du jour). Il n'existe pas de compteur de tickets dédié dans
        // le KPI global, on l'utilise donc comme repère du nombre de tickets.
        final String clients =
            loaded ? '${dashState.clientsServedToday}' : enAttente;
        final String commissions = _resteAVerser != null
            ? formatCurrency(_resteAVerser!, 'CDF')
            : enAttente;

        // L'écart affiché sur le CA vient des ventes réellement enregistrées.
        final ventes = context.watch<SalesBloc>().state;
        final serieCa =
            ventes is SalesLoaded ? DailySeries.revenue(ventes.sales) : null;

        // Six vignettes, par paires : CA CDF | USD, commissions | clients,
        // prestations | coiffeurs. Même grille que le tableau de bord Général.
        return KpiGrid(
          tiles: [
            KpiTile(
              icon: Icons.payments,
              color: const Color(0xFF16A34A),
              label: 'CA du jour (CDF)',
              value: caCdf,
              secondary: '7 derniers jours',
              trend: serieCa,
            ),
            KpiTile(
              icon: Icons.payments,
              color: const Color(0xFF16A34A),
              label: 'CA du jour (USD)',
              value: caUsd,
              secondary: 'Encaissé en dollars',
            ),
            KpiTile(
              icon: Icons.savings_outlined,
              color: const Color(0xFFF59E0B),
              label: 'Reste à verser (mois)',
              value: commissions,
              secondary: _commissionsMonth != null
                  ? 'sur ${formatCurrency(_commissionsMonth!, 'CDF')} gagnées'
                  : 'Commissions de l\'équipe',
              // On y va pour payer : l'ecran des coiffeurs, pas les statistiques.
              onTap: () => _ouvrir('/salon/stylists'),
            ),
            KpiTile(
              icon: Icons.groups_outlined,
              color: const Color(0xFF0EA5E9),
              label: 'Clients servis (jour)',
              value: clients,
              secondary: 'Tickets du jour',
            ),
            KpiTile(
              icon: Icons.content_cut,
              color: const Color(0xFF8B5CF6),
              label: 'Prestations',
              value: '${state.activeServices.length}',
              secondary: 'Carte active',
              onTap: () => _ouvrir('/salon/prestations'),
            ),
            KpiTile(
              icon: Icons.badge_outlined,
              color: const Color(0xFF197CA8),
              label: 'Coiffeurs',
              value: '${state.activeStylists.length}',
              secondary: 'Équipe active',
              onTap: () => _ouvrir('/salon/stylists'),
            ),
          ],
        );
      },
    );
  }
}
