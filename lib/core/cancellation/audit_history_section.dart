import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';

/// Une ligne du journal d'audit : qui a fait quoi, quand, pourquoi.
@immutable
class AuditEventView {
  final String action;
  final String? actor;
  final String? role;
  final String? reason;
  final DateTime? at;

  const AuditEventView({
    required this.action,
    this.actor,
    this.role,
    this.reason,
    this.at,
  });

  /// Libellé lisible de l'action du serveur.
  String get label {
    switch (action) {
      case 'cancel':
        return 'Annulation';
      case 'restore':
        return 'Rétablissement';
      case 'delete':
        return 'Suppression';
      case 'deactivate':
        return 'Désactivation';
      case 'create':
        return 'Création';
      case 'update':
        return 'Modification';
      default:
        return action;
    }
  }
}

/// Lit la réponse de `GET audit-events` : `{data, total, page, pageSize,
/// totalPages}`, éventuellement ré-enveloppée (`{success, data: {...}}`).
List<AuditEventView> parseAuditEvents(Object? response) {
  Object? data = response;
  for (var i = 0; i < 3 && data is Map && data['data'] != null; i++) {
    data = data['data'];
  }
  if (data is! List) return const [];
  String? text(Object? v) =>
      v is String && v.trim().isNotEmpty ? v.trim() : null;
  return [
    for (final raw in data)
      if (raw is Map)
        AuditEventView(
          action: text(raw['action']) ?? 'action',
          actor: text(raw['actorName']) ?? text(raw['actorEmail']),
          role: text(raw['actorRole']),
          reason: text(raw['reason']),
          at: switch (raw['createdAt']) {
            final String s => DateTime.tryParse(s)?.toLocal(),
            _ => null,
          },
        ),
  ];
}

/// Section repliée « Historique » d'une pièce (administrateur et comptable) :
/// le journal d'audit du serveur, chargé à l'ouverture.
class AuditHistorySection extends StatefulWidget {
  final String entityType;
  final String entityId;

  /// Lecteur injectable (tests) ; par défaut `GET audit-events`.
  final Future<Object?> Function(Map<String, String> query)? fetch;

  const AuditHistorySection({
    super.key,
    required this.entityType,
    required this.entityId,
    this.fetch,
  });

  @override
  State<AuditHistorySection> createState() => _AuditHistorySectionState();
}

class _AuditHistorySectionState extends State<AuditHistorySection> {
  Future<List<AuditEventView>>? _future;

  Future<List<AuditEventView>> _load() async {
    final query = {
      'entityType': widget.entityType,
      'entityId': widget.entityId,
      'pageSize': '50',
    };
    final fetch =
        widget.fetch ??
        (q) => ApiClient().get(
          'audit-events',
          queryParameters: q,
          requiresAuth: true,
        );
    return parseAuditEvents(await fetch(query));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('audit-history'),
      margin: const EdgeInsets.only(top: 12, bottom: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.history),
        title: const Text('Historique'),
        subtitle: const Text('Qui a fait quoi, et quand'),
        onExpansionChanged: (open) {
          if (open && _future == null) {
            final f = _load();
            setState(() {
              _future = f;
            });
          }
        },
        children: [
          FutureBuilder<List<AuditEventView>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return ListTile(
                  leading: const Icon(Icons.cloud_off),
                  title: const Text('Historique indisponible hors ligne.'),
                  trailing: TextButton(
                    onPressed: () {
                      final f = _load();
                      setState(() {
                        _future = f;
                      });
                    },
                    child: const Text('Réessayer'),
                  ),
                );
              }
              final events = snapshot.data ?? const <AuditEventView>[];
              if (events.isEmpty) {
                return const ListTile(title: Text('Aucune action enregistrée.'));
              }
              return Column(
                children: [
                  for (final e in events)
                    ListTile(
                      dense: true,
                      title: Text(
                        [
                          e.label,
                          if (e.actor != null) 'par ${e.actor}',
                        ].join(' '),
                      ),
                      subtitle: Text(
                        [
                          if (e.at != null)
                            DateFormat('dd/MM/yyyy à HH:mm').format(e.at!),
                          if (e.reason != null) 'Motif : ${e.reason}',
                        ].join('\n'),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
