import 'package:flutter/material.dart';

import '../../auth/models/join_request.dart';
import '../../auth/services/join_request_service.dart';

/// Demandes de rattachement par code (administrateur ou propriétaire).
///
/// Liste paginée filtrée par statut (en attente par défaut). Les actions
/// passent par le menu 3 points : Accepter (choix du rôle) ou Refuser (motif).
/// Tout exige le réseau : un échec affiche le message du serveur, rien n'est
/// mis en file hors ligne.
class JoinRequestsScreen extends StatefulWidget {
  final JoinRequestService? service;
  final int pageSize;

  const JoinRequestsScreen({super.key, this.service, this.pageSize = 20});

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  late final JoinRequestService _service = widget.service ?? JoinRequestService();

  String _status = JoinRequestStatus.pending;
  int _page = 1;
  JoinRequestPage? _data;
  bool _loading = false;
  String? _error;
  final Set<String> _working = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? page}) async {
    final target = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.list(
        status: _status,
        page: target,
        limit: widget.pageSize,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _page = data.page;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = joinRequestErrorMessage(e);
      });
    }
  }

  void _setStatus(String status) {
    if (status == _status) return;
    setState(() {
      _status = status;
      _page = 1;
      _data = null;
    });
    _load(page: 1);
  }

  void _toast(String text, {bool error = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _accept(JoinRequest request) async {
    final role = await showAcceptJoinRequestSheet(context, request);
    if (role == null || !mounted) return;
    setState(() => _working.add(request.id));
    try {
      await _service.accept(request.id, role: role);
      if (!mounted) return;
      _toast(
        '${request.requester.displayName} a rejoint l\'entreprise '
        '(${grantableRoleLabel(role)}).',
      );
      await _load();
    } catch (e) {
      if (mounted) _toast(joinRequestErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _working.remove(request.id));
    }
  }

  Future<void> _refuse(JoinRequest request) async {
    final reason = await showRefuseJoinRequestSheet(context, request);
    if (reason == null || !mounted) return;
    setState(() => _working.add(request.id));
    try {
      await _service.refuse(request.id, reason: reason);
      if (!mounted) return;
      _toast('Demande de ${request.requester.displayName} refusée.');
      await _load();
    } catch (e) {
      if (mounted) _toast(joinRequestErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _working.remove(request.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demandes de rattachement'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _load(),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final s in JoinRequestStatus.filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(JoinRequestStatus.label(s)),
                      selected: _status == s,
                      onSelected: (_) => _setStatus(s),
                    ),
                  ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _buildBody(data)),
          if (data != null && data.pageCount > 1) _buildPager(data),
        ],
      ),
    );
  }

  Widget _buildBody(JoinRequestPage? data) {
    if (_error != null && data == null) {
      return _Message(
        icon: Icons.cloud_off,
        text: _error!,
        action: TextButton(onPressed: () => _load(), child: const Text('Réessayer')),
      );
    }
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (data.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          children: [
            const SizedBox(height: 80),
            _Message(
              icon: Icons.inbox_outlined,
              text: _status == JoinRequestStatus.pending
                  ? 'Aucune demande en attente.'
                  : 'Aucune demande pour ce filtre.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: data.items.length + (_error != null ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (_error != null && index == 0) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            );
          }
          final request = data.items[index - (_error != null ? 1 : 0)];
          return _RequestTile(
            request: request,
            working: _working.contains(request.id),
            onAccept: () => _accept(request),
            onRefuse: () => _refuse(request),
          );
        },
      ),
    );
  }

  Widget _buildPager(JoinRequestPage data) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Page précédente',
              icon: const Icon(Icons.chevron_left),
              onPressed: !_loading && data.hasPrevious ? () => _load(page: _page - 1) : null,
            ),
            Expanded(
              child: Text(
                'Page ${data.page} sur ${data.pageCount}  ·  ${data.total} demandes',
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              tooltip: 'Page suivante',
              icon: const Icon(Icons.chevron_right),
              onPressed: !_loading && data.hasNext ? () => _load(page: _page + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

String _date(DateTime? d) {
  if (d == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

class _RequestTile extends StatelessWidget {
  final JoinRequest request;
  final bool working;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  const _RequestTile({
    required this.request,
    required this.working,
    required this.onAccept,
    required this.onRefuse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = request.businessUnitName ?? request.businessUnitCode ?? '';
    final lines = <String>[
      if ((request.requester.email ?? '').isNotEmpty &&
          request.requester.email != request.requester.displayName)
        request.requester.email!,
      [
        if (unit.isNotEmpty) 'Unité : $unit',
        if (request.createdAt != null) 'le ${_date(request.createdAt)}',
      ].join(', '),
      if (request.isAccepted && (request.grantedRole ?? '').isNotEmpty)
        'Rôle accordé : ${grantableRoleLabel(request.grantedRole)}',
      if (request.isRefused && (request.reason ?? '').isNotEmpty)
        'Motif : ${request.reason}',
      if (!request.isPending && (request.decidedByEmail ?? '').isNotEmpty)
        'Décidé par ${request.decidedByEmail}',
    ].where((l) => l.trim().isNotEmpty).toList();

    return ListTile(
      leading: CircleAvatar(
        child: Text(
          request.requester.displayName.characters.first.toUpperCase(),
        ),
      ),
      title: Text(request.requester.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines) Text(l),
          const SizedBox(height: 4),
          _StatusChip(status: request.status),
        ],
      ),
      isThreeLine: true,
      trailing: working
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : request.isPending
              ? PopupMenuButton<String>(
                  key: Key('join_request_menu_${request.id}'),
                  tooltip: 'Actions',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (v) => v == 'accept' ? onAccept() : onRefuse(),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'accept',
                      child: ListTile(
                        leading: Icon(Icons.check_circle_outline),
                        title: Text('Accepter'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'refuse',
                      child: ListTile(
                        leading: Icon(Icons.cancel_outlined, color: theme.colorScheme.error),
                        title: const Text('Refuser'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                )
              : null,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color color;
    switch (status) {
      case JoinRequestStatus.accepted:
        color = Colors.green.shade700;
        break;
      case JoinRequestStatus.refused:
        color = scheme.error;
        break;
      case JoinRequestStatus.pending:
        color = Colors.orange.shade800;
        break;
      default:
        color = scheme.outline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        JoinRequestStatus.label(status),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}

/// En-tête des feuilles montantes : titre et bouton fermer toujours visible.
class _SheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SheetHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Feuille montante « Accepter » : choix du rôle (Employé par défaut).
/// Renvoie la valeur du rôle, ou null si fermée.
Future<String?> showAcceptJoinRequestSheet(
  BuildContext context,
  JoinRequest request,
) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      var selected = kDefaultGrantedRole;
      return StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SheetHeader(
                  title: 'Accepter la demande',
                  subtitle:
                      '${request.requester.displayName} rejoindra l\'entreprise avec le rôle choisi.',
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final r in kGrantableRoles)
                        ListTile(
                          key: Key('role_${r.value}'),
                          leading: Icon(
                            selected == r.value
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: selected == r.value
                                ? Theme.of(ctx).colorScheme.primary
                                : null,
                          ),
                          title: Text(r.label),
                          subtitle: Text(r.description),
                          onTap: () => setSheetState(() => selected = r.value),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: FilledButton(
                    key: const Key('accept_confirm'),
                    onPressed: () => Navigator.of(ctx).pop(selected),
                    child: const Text('Accepter'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Feuille montante « Refuser » : motif dans une liste, plus une précision.
/// Renvoie le motif composé (éventuellement vide), ou null si fermée.
Future<String?> showRefuseJoinRequestSheet(
  BuildContext context,
  JoinRequest request,
) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _RefuseSheet(request: request),
  );
}

class _RefuseSheet extends StatefulWidget {
  final JoinRequest request;

  const _RefuseSheet({required this.request});

  @override
  State<_RefuseSheet> createState() => _RefuseSheetState();
}

class _RefuseSheetState extends State<_RefuseSheet> {
  String? _reason;
  final _detail = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  void _submit() {
    final detail = _detail.text.trim();
    final isOther = _reason == kRefusalReasons.last;
    if (_reason == null) {
      setState(() => _error = 'Choisissez un motif.');
      return;
    }
    if (isOther && detail.isEmpty) {
      setState(() => _error = 'Précisez le motif.');
      return;
    }
    final composed = isOther
        ? detail
        : (detail.isEmpty ? _reason! : '${_reason!}. $detail');
    Navigator.of(context).pop(composed);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetHeader(
                title: 'Refuser la demande',
                subtitle: 'Le motif sera montré à ${widget.request.requester.displayName}.',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final r in kRefusalReasons)
                      ChoiceChip(
                        label: Text(r),
                        selected: _reason == r,
                        onSelected: (_) => setState(() {
                          _reason = r;
                          _error = null;
                        }),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextField(
                  key: const Key('refuse_detail'),
                  controller: _detail,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: InputDecoration(
                    labelText: 'Précision (facultative sauf pour « Autre motif »)',
                    border: const OutlineInputBorder(),
                    errorText: _error,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: FilledButton(
                  key: const Key('refuse_confirm'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: _submit,
                  child: const Text('Refuser'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
