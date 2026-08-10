import 'package:flutter/material.dart';

/// État vide partagé — présentation cohérente d'un « aucune donnée » à travers
/// l'app (icône estompée + message centré, action optionnelle).
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: scheme.onSurface.withAlpha((0.4 * 255).round()),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: scheme.onSurface.withAlpha((0.7 * 255).round()),
              ),
              textAlign: TextAlign.center,
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
