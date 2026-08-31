import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:wanzo/core/modules/module_registry.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/shared_widgets/quick_actions_sheet.dart';
import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';

import '../cubit/salon_cubit.dart';

/// Tableau de bord du mode SALON DE COIFFURE (desktop).
///
/// Volontairement épuré : les repères du salon (prestations à la carte, équipe)
/// et un accès direct aux actions clés — nouveau ticket, carte, coiffeurs,
/// performances. Les données proviennent du `SalonCubit` (carte locale + équipe
/// backend, offline-tolerant), sans dépendance supplémentaire. Les actions clés
/// passent par la feuille partagée d'actions rapides (un seul déclencheur).
class SalonDashboardScreen extends StatelessWidget {
  const SalonDashboardScreen({super.key});

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

  Widget _kpiRow(BuildContext context, SalonState state) {
    final cards = [
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
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
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
