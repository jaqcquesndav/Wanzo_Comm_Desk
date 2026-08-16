import 'package:flutter/material.dart';

/// Puce d'attribution façon Trello : montre QUI a réalisé la dernière action sur
/// une commande (avatar + nom), avec le libellé de l'action et un temps relatif.
///
/// Multi-tenant / multi-BU : permet de savoir d'un coup d'œil qui a validé une
/// étape, sans ouvrir la commande.
class AtelierActorChip extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String? action;
  final DateTime? at;

  const AtelierActorChip({
    super.key,
    required this.name,
    this.avatarUrl,
    this.action,
    this.at,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUrl = avatarUrl != null && avatarUrl!.startsWith('http');
    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          foregroundImage: hasUrl ? NetworkImage(avatarUrl!) : null,
          child: hasUrl
              ? null
              : Text(
                  _initials,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _line(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _line() {
    final buf = StringBuffer();
    if (action != null && action!.isNotEmpty) {
      buf.write('$action · ');
    }
    buf.write(name);
    if (at != null) buf.write(' · ${_relative(at!)}');
    return buf.toString();
  }

  static String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }
}
