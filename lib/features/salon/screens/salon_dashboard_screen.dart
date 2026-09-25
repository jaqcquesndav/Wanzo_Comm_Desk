import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:wanzo/core/modules/module_registry.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/shared_widgets/quick_actions_sheet.dart';
import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/core/shared_widgets/kpi_board.dart';
import 'package:wanzo/core/utils/daily_series.dart';
import 'package:wanzo/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:wanzo/features/sales/bloc/sales_bloc.dart';

import '../cubit/salon_cubit.dart';
import '../services/salon_api_service.dart';

/// Tableau de bord du mode SALON DE COIFFURE (desktop).
///
/// Volontairement épuré : les repères du salon (prestations à la carte, équipe)
/// et un accès direct aux actions clés — nouveau ticket, carte, coiffeurs,
/// performances. Les données proviennent du `SalonCubit` (carte locale + équipe
/// backend, offline-tolerant), sans dépendance supplémentaire. Les actions clés
/// passent par la feuille partagée d'actions rapides (un seul déclencheur).
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

  @override
  void initState() {
    super.initState();
    // Le tableau de bord salon EST l'écran d'accueil du mode : personne d'autre
    // n'amorce le KPI global (CA du jour). On le déclenche si besoin.
    final dashState = context.read<DashboardBloc>().state;
    if (dashState is! DashboardLoaded) {
      context.read<DashboardBloc>().add(LoadDashboardData(date: DateTime.now()));
    }
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

    return WanzoScaffold(
      currentIndex: index < 0 ? 0 : index,
      title: 'Tableau de bord',
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.content_cut),
          tooltip: 'Composer la tarification',
          onPressed: () => _ouvrir('/salon/prestations'),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        heroTag: 'salon_dashboard_fab',
        tooltip: 'Actions rapides',
        onPressed: () => _showQuickActions(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
      ),
      body: BlocBuilder<SalonCubit, SalonState>(
        builder: (context, state) {
          if (state.loading && state.services.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            // Sur grand écran, les tuiles d'action ne doivent pas s'étirer sur
            // toute la largeur : on borne la colonne et on la centre (comme le
            // reste des écrans desktop).
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _kpiRow(context, state),
                const SizedBox(height: 28),
                Text(
                  'Démarrer',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _actionTile(
                  context,
                  icon: Icons.add_shopping_cart,
                  color: const Color(0xFF0EA5E9),
                  title: 'Nouveau ticket',
                  subtitle: 'Prestations + produits, sur un même ticket',
                  onTap: () => _ouvrir('/salon/sale'),
                ),
                _actionTile(
                  context,
                  icon: Icons.content_cut,
                  color: const Color(0xFF8B5CF6),
                  title: 'Composer la tarification',
                  subtitle: 'Prestations, prix, durée, commission',
                  onTap: () => _ouvrir('/salon/prestations'),
                ),
                _actionTile(
                  context,
                  icon: Icons.badge_outlined,
                  color: const Color(0xFF197CA8),
                  title: 'Coiffeurs',
                  subtitle: 'Équipe et taux de commission',
                  onTap: () => _ouvrir('/salon/stylists'),
                ),
                _actionTile(
                  context,
                  icon: Icons.leaderboard_outlined,
                  color: const Color(0xFF16A34A),
                  title: 'Performances',
                  subtitle: 'Commissions par coiffeur (paie)',
                  onTap: () => _ouvrir('/salon/performance'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showQuickActions(BuildContext context) {
    showWanzoQuickActions(
      context,
      actions: [
        // Le raccourci porte le nom de l'écran qu'il ouvre : « Nouveau
        // ticket », pas « Nouvelle prestation » (un ticket peut contenir
        // plusieurs prestations et des produits).
        QuickActionItem(
          icon: Icons.receipt_long,
          label: 'Nouveau ticket',
          color: const Color(0xFF0EA5E9),
          onTap: () => _ouvrir('/salon/sale'),
        ),
        QuickActionItem(
          icon: Icons.content_cut,
          label: 'Tarification',
          color: const Color(0xFF8B5CF6),
          onTap: () => _ouvrir('/salon/prestations'),
        ),
        QuickActionItem(
          icon: Icons.badge_outlined,
          label: 'Coiffeurs',
          color: const Color(0xFF197CA8),
          onTap: () => _ouvrir('/salon/stylists'),
        ),
        QuickActionItem(
          icon: Icons.leaderboard_outlined,
          label: 'Performances',
          color: const Color(0xFF16A34A),
          onTap: () => _ouvrir('/salon/performance'),
        ),
        QuickActionItem(
          icon: Icons.money_off,
          label: 'Dépense',
          color: Colors.red,
          onTap: () => _ouvrir('/expenses/add'),
        ),
      ],
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
        final String caCdf =
            loaded ? formatCurrency(dashState.salesTodayCdf, 'CDF') : '—';
        final double caUsd = loaded ? dashState.salesTodayUsd : 0;
        // `clientsServedToday` : nombre réel de clients servis aujourd'hui (≈
        // tickets du jour). Il n'existe pas de compteur de tickets dédié dans
        // le KPI global, on l'utilise donc comme repère du nombre de tickets.
        final String clients =
            loaded ? '${dashState.clientsServedToday}' : '—';
        final String commissions = _resteAVerser != null
            ? formatCurrency(_resteAVerser!, 'CDF')
            : '—';

        // La courbe des vignettes de pilotage vient des ventes réellement
        // enregistrées ; sans elles, la vignette reste sans courbe.
        final ventes = context.watch<SalesBloc>().state;
        final serieCa =
            ventes is SalesLoaded ? DailySeries.revenue(ventes.sales) : null;

        return KpiBoard(
          spacing: 16,
          tiles: [
            KpiTile(
              weight: KpiWeight.pilote,
              icon: Icons.payments,
              color: const Color(0xFF16A34A),
              label: 'CA du jour',
              value: caCdf,
              secondary:
                  caUsd > 0 ? 'dont ${formatCurrency(caUsd, 'USD')}' : null,
              trend: serieCa,
              trendLabel: '7 derniers jours',
            ),
            KpiTile(
              weight: KpiWeight.pilote,
              icon: Icons.savings_outlined,
              color: const Color(0xFFF59E0B),
              label: 'Reste à verser (mois)',
              value: commissions,
              secondary: _commissionsMonth != null
                  ? 'sur ${formatCurrency(_commissionsMonth!, 'CDF')} gagnées'
                  : null,
              trendLabel: 'Commissions de l\'équipe',
              // On y va pour payer : l'ecran des coiffeurs, pas les statistiques.
              onTap: () => _ouvrir('/salon/stylists'),
            ),
            KpiTile(
              icon: Icons.groups_outlined,
              color: const Color(0xFF0EA5E9),
              label: 'Clients servis (jour)',
              value: clients,
            ),
            KpiTile(
              icon: Icons.content_cut,
              color: const Color(0xFF8B5CF6),
              label: 'Prestations',
              value: '${state.activeServices.length}',
              onTap: () => _ouvrir('/salon/prestations'),
            ),
            KpiTile(
              icon: Icons.badge_outlined,
              color: const Color(0xFF197CA8),
              label: 'Coiffeurs',
              value: '${state.activeStylists.length}',
              onTap: () => _ouvrir('/salon/stylists'),
            ),
          ],
        );
      },
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.16),
          child: Icon(icon, color: color),
        ),
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
