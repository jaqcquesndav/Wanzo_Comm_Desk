import 'package:flutter/material.dart';

import 'package:wanzo/constants/spacing.dart';

/// Clés des sections d'un tableau de bord de mode (tests d'ordre).
class ModeDashboardKeys {
  static const kpis = ValueKey('mode_dashboard_kpis');
  static const chart = ValueKey('mode_dashboard_chart');
  static const middle = ValueKey('mode_dashboard_middle');
  static const journal = ValueKey('mode_dashboard_journal');
  static const footer = ValueKey('mode_dashboard_footer');
}

/// Mise en page des écrans d'accueil des modes métier, calquée sur le
/// tableau de bord Général : vignettes, graphique, sections propres au
/// métier, puis journal des opérations, chacun sur toute la largeur.
class ModeDashboardLayout extends StatelessWidget {
  final Widget kpis;
  final Widget chart;

  /// Sections propres au métier, entre le graphique et le journal.
  final Widget? middle;
  final Widget journal;

  /// Ce qui reste sous le journal (liens compacts, indicateur d'exercice).
  final List<Widget> footer;

  /// Tirer pour actualiser.
  final Future<void> Function()? onRefresh;

  /// Espace libre en bas, sous le bouton flottant.
  final double bottomSpacing;

  const ModeDashboardLayout({
    super.key,
    required this.kpis,
    required this.chart,
    this.middle,
    required this.journal,
    this.footer = const [],
    this.onRefresh,
    this.bottomSpacing = WanzoSpacing.md,
  });

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(WanzoSpacing.md),
      children: [
        KeyedSubtree(key: ModeDashboardKeys.kpis, child: kpis),
        const SizedBox(height: WanzoSpacing.lg),
        KeyedSubtree(key: ModeDashboardKeys.chart, child: chart),
        if (middle != null) ...[
          const SizedBox(height: WanzoSpacing.lg),
          KeyedSubtree(key: ModeDashboardKeys.middle, child: middle!),
        ],
        const SizedBox(height: WanzoSpacing.lg),
        KeyedSubtree(key: ModeDashboardKeys.journal, child: journal),
        if (footer.isNotEmpty) ...[
          const SizedBox(height: WanzoSpacing.lg),
          KeyedSubtree(
            key: ModeDashboardKeys.footer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: footer,
            ),
          ),
        ],
        SizedBox(height: bottomSpacing),
      ],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

/// Une section titrée d'un tableau de bord de mode.
class DashboardSection {
  final String title;

  /// Libellé court de l'onglet (petit écran) ; le titre sinon.
  final String? tabLabel;
  final Widget child;

  const DashboardSection({
    required this.title,
    this.tabLabel,
    required this.child,
  });
}

/// Sections propres au métier, côte à côte sur grand écran (900 px et plus),
/// en onglets sinon : le journal reste à portée de pouce sur téléphone.
class DashboardSectionsGroup extends StatefulWidget {
  final List<DashboardSection> sections;

  /// Largeur à partir de laquelle les sections passent en colonnes.
  final double columnsBreakpoint;

  const DashboardSectionsGroup({
    super.key,
    required this.sections,
    this.columnsBreakpoint = 900,
  });

  @override
  State<DashboardSectionsGroup> createState() => _DashboardSectionsGroupState();
}

class _DashboardSectionsGroupState extends State<DashboardSectionsGroup> {
  int _index = 0;

  Widget _title(BuildContext context, String text) => Text(
    text,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
  );

  @override
  Widget build(BuildContext context) {
    final sections = widget.sections;
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= widget.columnsBreakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0) const SizedBox(width: WanzoSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _title(context, sections[i].title),
                      const SizedBox(height: WanzoSpacing.sm),
                      sections[i].child,
                    ],
                  ),
                ),
              ],
            ],
          );
        }
        final index = _index.clamp(0, sections.length - 1);
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DefaultTabController(
              length: sections.length,
              initialIndex: index,
              child: TabBar(
                isScrollable: false,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(
                  (0.7 * 255).round(),
                ),
                indicatorColor: theme.colorScheme.primary,
                onTap: (i) => setState(() => _index = i),
                tabs: [
                  for (final s in sections)
                    Tab(
                      child: Text(
                        s.tabLabel ?? s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: WanzoSpacing.sm),
            // Le contenu suit sa hauteur naturelle (pas de TabBarView à
            // hauteur fixe) : aucune coupure, aucun débordement.
            sections[index].child,
          ],
        );
      },
    );
  }
}
