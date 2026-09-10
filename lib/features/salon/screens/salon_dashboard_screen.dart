import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:wanzo/core/modules/module_registry.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/shared_widgets/quick_actions_sheet.dart';
import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/features/dashboard/bloc/dashboard_bloc.dart';

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
      });
    } catch (_) {
      // Indisponible (réseau/backend) : on laisse `_commissionsMonth` à null →
      // état neutre « — » dans la grille (jamais de valeur fabriquée).
      if (!mounted) return;
      setState(() => _commissionsMonth = null);
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
          tooltip: 'Composer la carte',
          onPressed: () => context.push('/salon/prestations'),
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
                  onTap: () => context.push('/salon/sale'),
                ),
                _actionTile(
                  context,
                  icon: Icons.content_cut,
                  color: const Color(0xFF8B5CF6),
                  title: 'Composer la carte',
                  subtitle: 'Prestations, prix, durée, commission',
                  onTap: () => context.push('/salon/prestations'),
                ),
                _actionTile(
                  context,
                  icon: Icons.badge_outlined,
                  color: const Color(0xFF197CA8),
                  title: 'Coiffeurs',
                  subtitle: 'Équipe et taux de commission',
                  onTap: () => context.push('/salon/stylists'),
                ),
                _actionTile(
                  context,
                  icon: Icons.leaderboard_outlined,
                  color: const Color(0xFF16A34A),
                  title: 'Performances',
                  subtitle: 'Commissions par coiffeur (paie)',
                  onTap: () => context.push('/salon/performance'),
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
        QuickActionItem(
          icon: Icons.add_shopping_cart,
          label: 'Nouvelle prestation',
          color: const Color(0xFF0EA5E9),
          onTap: () => context.push('/salon/sale'),
        ),
        QuickActionItem(
          icon: Icons.content_cut,
          label: 'Carte',
          color: const Color(0xFF8B5CF6),
          onTap: () => context.push('/salon/prestations'),
        ),
        QuickActionItem(
          icon: Icons.badge_outlined,
          label: 'Coiffeurs',
          color: const Color(0xFF197CA8),
          onTap: () => context.push('/salon/stylists'),
        ),
        QuickActionItem(
          icon: Icons.leaderboard_outlined,
          label: 'Performances',
          color: const Color(0xFF16A34A),
          onTap: () => context.push('/salon/performance'),
        ),
        QuickActionItem(
          icon: Icons.money_off,
          label: 'Dépense',
          color: Colors.red,
          onTap: () => context.push('/expenses/add'),
        ),
      ],
    );
  }

  /// KPI métier RÉELS (aucune valeur fabriquée) : CA du jour (CDF/USD) et
  /// clients servis proviennent du KPI global (`DashboardBloc`, même source que
  /// le tableau de bord principal et restaurant) ; les commissions à payer du
  /// mois proviennent de `SalonApiService`. Une donnée non chargée affiche un
  /// état neutre (« — »).
  Widget _kpiRow(BuildContext context, SalonState state) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, dashState) {
        final bool loaded = dashState is DashboardLoaded;
        final String caCdf =
            loaded ? formatCurrency(dashState.salesTodayCdf, 'CDF') : '—';
        final String caUsd =
            loaded ? formatCurrency(dashState.salesTodayUsd, 'USD') : '—';
        // `clientsServedToday` : nombre réel de clients servis aujourd'hui (≈
        // tickets du jour). Il n'existe pas de compteur de tickets dédié dans le
        // KPI global, on l'utilise donc comme repère du nombre de tickets.
        final String clients =
            loaded ? '${dashState.clientsServedToday}' : '—';
        final String commissions = _commissionsMonth != null
            ? formatCurrency(_commissionsMonth!, 'CDF')
            : '—';
        final cards = [
          _KpiCard(
            icon: Icons.payments,
            color: const Color(0xFF16A34A),
            label: 'CA du jour (CDF)',
            value: caCdf,
          ),
          _KpiCard(
            icon: Icons.payments,
            color: const Color(0xFF16A34A),
            label: 'CA du jour (USD)',
            value: caUsd,
          ),
          _KpiCard(
            icon: Icons.groups_outlined,
            color: const Color(0xFF0EA5E9),
            label: 'Clients servis (jour)',
            value: clients,
          ),
          _KpiCard(
            icon: Icons.savings_outlined,
            color: const Color(0xFFF59E0B),
            label: 'Commissions (mois)',
            value: commissions,
          ),
          _KpiCard(
            icon: Icons.content_cut,
            color: const Color(0xFF8B5CF6),
            label: 'Prestations',
            value: '${state.activeServices.length}',
          ),
          _KpiCard(
            icon: Icons.badge_outlined,
            color: const Color(0xFF197CA8),
            label: 'Coiffeurs',
            value: '${state.activeStylists.length}',
          ),
        ];
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final card in cards) SizedBox(width: 220, child: card),
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

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _KpiCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.16),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
