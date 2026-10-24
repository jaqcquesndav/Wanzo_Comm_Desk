import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../../customer/widgets/customer_picker_field.dart';
import '../cubit/restaurant_orders_cubit.dart';
import '../models/restaurant_order.dart';
import '../services/restaurant_api_service.dart';
import '../services/restaurant_reservations_service.dart';

/// Ouverture d'une commande : UN SEUL parcours, quel que soit le point de
/// départ (tableau des commandes, liste, plan de salle, caisse).
///
/// Trois natures, choisies dans un sélecteur segmenté (icône et libellé) :
///  - « Sur place » : on choisit ensuite la table (plan de salle), ou un
///    libellé libre quand aucune table n'est configurée ;
///  - « À emporter » : le client (fiche existante ou client de passage) ;
///  - « Réservation » : onglets « Chambres » (chambres occupées) et « Salles »
///    (salles réservées aujourd'hui et dans les 7 jours : événement,
///    formation, traiteur), avec client et dates. Proposé seulement si
///    l'établissement a des chambres ou des salles. La commande est rattachée
///    à la réservation ; à l'encaissement elle rejoint sa facture (folio).
///
/// Renvoie la commande ouverte (ou celle déjà ouverte sur la table choisie),
/// `null` si l'utilisateur renonce.
Future<RestaurantOrder?> showNewRestaurantOrderDialog(
  BuildContext context,
  RestaurantOrdersCubit cubit, {
  RestaurantOrderType initialType = RestaurantOrderType.dineIn,
  bool? reservationsByDefault,
  VoidCallback? onNewReservation,
}) async {
  final result = await showDialog<_NewOrderResult>(
    context: context,
    builder: (_) => _NewOrderDialog(
      initialType: initialType,
      reservationsByDefault: reservationsByDefault ?? _reservationsByDefault(),
      activeOrders: cubit.state.active,
      onNewReservation: onNewReservation,
    ),
  );
  if (result == null) return null;
  if (result.existing != null) return result.existing;
  return cubit.openOrder(
    result.label,
    tableId: result.tableId,
    type: result.type,
    customerId: result.customerId,
    customerName: result.customerName,
    reservationId: result.reservationId,
    spaceId: result.spaceId,
    spaceKind: result.spaceKind,
  );
}

/// « Réservation » proposé tant qu'on ne sait pas encore si l'établissement a
/// des chambres ou des salles (premier usage, hors ligne sans liste connue).
/// L'hôtellerie vit dans Wanzo Assets : sans liste connue, on ne propose pas
/// la réservation par défaut (elle apparaît dès que des réservations existent).
bool _reservationsByDefault() => false;

/// Tables gardées sur l'appareil (même boîte que le plan de salle).
const _boiteTables = 'restaurant_tables_cache';

Future<Box<String>> _boite() async => Hive.isBoxOpen(_boiteTables)
    ? Hive.box<String>(_boiteTables)
    : await Hive.openBox<String>(_boiteTables);

Future<List<RestaurantTable>> _tablesGardees() async {
  try {
    final brut = (await _boite()).get('tables');
    if (brut == null) return const [];
    return (jsonDecode(brut) as List)
        .whereType<Map>()
        .map((e) => RestaurantTable.fromJson(Map<String, dynamic>.from(e)))
        .where((t) => t.active)
        .toList();
  } catch (_) {
    return const [];
  }
}

Future<List<RestaurantTable>?> _tablesServeur() async {
  try {
    final tables = (await RestaurantApiService().getTables())
        .where((t) => t.active)
        .toList();
    try {
      await (await _boite()).put(
          'tables', jsonEncode(tables.map((t) => t.toJson()).toList()));
    } catch (_) {}
    return tables;
  } catch (_) {
    return null; // Hors ligne : les tables gardées restent affichées.
  }
}

String _norm(String s) => s.trim().toLowerCase();

/// Commande active déjà ouverte sur [table] (lien fort, puis libellé). Une
/// commande à emporter ou sur réservation n'occupe jamais une table.
RestaurantOrder? commandeOuverteSurTable(
  RestaurantTable table,
  List<RestaurantOrder> actives,
) {
  RestaurantOrder? parId;
  RestaurantOrder? parLibelle;
  final cle = _norm(table.label);
  for (final o in actives) {
    if (o.type != RestaurantOrderType.dineIn) continue;
    if (o.tableId != null && o.tableId == table.id) {
      if (parId == null || o.createdAt.isAfter(parId.createdAt)) parId = o;
    } else if (o.tableId == null && _norm(o.label) == cle) {
      if (parLibelle == null || o.createdAt.isAfter(parLibelle.createdAt)) {
        parLibelle = o;
      }
    }
  }
  return parId ?? parLibelle;
}

class _NewOrderResult {
  final String label;
  final RestaurantOrderType type;
  final String? tableId;
  final String? customerId;
  final String? customerName;
  final String? reservationId;
  final String? spaceId;
  final String? spaceKind;
  final RestaurantOrder? existing;

  const _NewOrderResult({
    required this.label,
    required this.type,
    this.tableId,
    this.customerId,
    this.customerName,
    this.reservationId,
    this.spaceId,
    this.spaceKind,
    this.existing,
  });
}

class _NewOrderDialog extends StatefulWidget {
  final RestaurantOrderType initialType;
  final bool reservationsByDefault;
  final List<RestaurantOrder> activeOrders;
  final VoidCallback? onNewReservation;

  const _NewOrderDialog({
    required this.initialType,
    required this.reservationsByDefault,
    required this.activeOrders,
    this.onNewReservation,
  });

  @override
  State<_NewOrderDialog> createState() => _NewOrderDialogState();
}

class _NewOrderDialogState extends State<_NewOrderDialog> {
  late RestaurantOrderType _type = widget.initialType;

  // Sur place
  List<RestaurantTable> _tables = const [];
  RestaurantTable? _table;
  final _libelle = TextEditingController();

  // À emporter
  final _client = TextEditingController();
  String? _customerId;
  String? _customerName;

  // Réservation
  final _service = RestaurantReservationsService();
  ReservationsSnapshot _snapshot = ReservationsSnapshot.unknown;
  bool _loading = true;
  ServableReservation? _choix;

  /// Onglet : chambres (`room`) ou salles (`hall`).
  String _onglet = ReservationSpaceKind.room;
  final _recherche = TextEditingController();

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final gardees = await _tablesGardees();
    final cache = await _service.cached();
    if (!mounted) return;
    setState(() {
      _tables = gardees;
      _snapshot = cache;
      _ajusterOnglet();
    });
    unawaited(_tablesServeur().then((t) {
      if (t != null && mounted) setState(() => _tables = t);
    }));
    final frais = await _service.load();
    if (!mounted) return;
    setState(() {
      _snapshot = frais;
      _loading = false;
      _ajusterOnglet();
      // La réservation choisie n'est plus servable : on la retire.
      final c = _choix;
      if (c != null &&
          ![...frais.rooms, ...frais.halls]
              .any((r) => r.reservationId == c.reservationId)) {
        _choix = null;
      }
    });
  }

  /// Sans chambres mais avec des salles, l'onglet « Salles » s'ouvre d'office.
  void _ajusterOnglet() {
    if (_snapshot.hasRooms == false && _snapshot.hasHalls == true) {
      _onglet = ReservationSpaceKind.hall;
    }
  }

  @override
  void dispose() {
    _libelle.dispose();
    _client.dispose();
    _recherche.dispose();
    super.dispose();
  }

  /// « Réservation » n'apparaît que si l'établissement a chambres ou salles.
  bool get _reservationsVisible =>
      _snapshot.hasAny ?? widget.reservationsByDefault;

  bool get _valide {
    switch (_type) {
      case RestaurantOrderType.dineIn:
        return _table != null || _libelle.text.trim().isNotEmpty;
      case RestaurantOrderType.takeaway:
        return true;
      case RestaurantOrderType.reservation:
        return _choix != null;
    }
  }

  void _valider() {
    if (!_valide) return;
    switch (_type) {
      case RestaurantOrderType.dineIn:
        var table = _table;
        final saisi = _libelle.text.trim();
        // Un libellé qui est le nom exact d'une table la rattache au plan.
        if (table == null) {
          for (final t in _tables) {
            if (_norm(t.label) == _norm(saisi)) table = t;
          }
        }
        if (table != null) {
          Navigator.of(context).pop(_NewOrderResult(
            label: table.label,
            type: RestaurantOrderType.dineIn,
            tableId: table.id,
            // Table déjà servie : on reprend sa commande, pas de doublon.
            existing: commandeOuverteSurTable(table, widget.activeOrders),
          ));
          return;
        }
        Navigator.of(context).pop(_NewOrderResult(
          label: saisi,
          type: RestaurantOrderType.dineIn,
        ));
      case RestaurantOrderType.takeaway:
        final saisi = _client.text.trim();
        Navigator.of(context).pop(_NewOrderResult(
          label: saisi.isNotEmpty ? saisi : 'À emporter',
          type: RestaurantOrderType.takeaway,
          customerId: _customerId,
          customerName: _customerId != null ? _customerName : null,
        ));
      case RestaurantOrderType.reservation:
        final r = _choix!;
        Navigator.of(context).pop(_NewOrderResult(
          label: r.spaceName,
          type: RestaurantOrderType.reservation,
          customerId: r.customerId,
          customerName: r.customerName,
          reservationId: r.reservationId,
          spaceId: r.spaceId,
          spaceKind: r.kind,
        ));
    }
  }

  String get _aide => switch (_type) {
        RestaurantOrderType.dineIn => 'Servie à une table de la salle.',
        RestaurantOrderType.takeaway => 'Le client emporte sa commande.',
        RestaurantOrderType.reservation => _onglet == ReservationSpaceKind.hall
            ? "Servie pendant l'événement, ajoutée à la facture de la location."
            : 'Servie en chambre, ajoutée à la facture du séjour.',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final largeur = MediaQuery.sizeOf(context).width;
    final types = [
      RestaurantOrderType.dineIn,
      RestaurantOrderType.takeaway,
      if (_reservationsVisible || _type == RestaurantOrderType.reservation)
        RestaurantOrderType.reservation,
    ];
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Row(
        children: [
          const Expanded(child: Text('Nouvelle commande')),
          IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: largeur < 480 ? largeur : 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OrderTypeSelector(
                types: types,
                selected: _type,
                onChanged: (t) => setState(() => _type = t),
              ),
              const SizedBox(height: 8),
              Text(
                _aide,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              switch (_type) {
                RestaurantOrderType.dineIn => _sectionTable(theme),
                RestaurantOrderType.takeaway => CustomerPickerField(
                    controller: _client,
                    label: 'Client (facultatif)',
                    hint: 'Client enregistré ou client de passage',
                    onSelected: (c) => setState(() {
                      _customerId = c?.id;
                      _customerName = c?.name;
                    }),
                  ),
                RestaurantOrderType.reservation => _sectionReservation(theme),
              },
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _valide ? _valider : null,
          child: const Text('Ouvrir la commande'),
        ),
      ],
    );
  }

  Widget _sectionTable(ThemeData theme) {
    final occupees = {
      for (final t in _tables)
        if (commandeOuverteSurTable(t, widget.activeOrders) != null) t.id,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_tables.isNotEmpty) ...[
          Text('Table', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in _tables)
                    ChoiceChip(
                      avatar: Icon(
                        occupees.contains(t.id)
                            ? Icons.receipt_long
                            : Icons.table_restaurant,
                        size: 16,
                      ),
                      label: Text(occupees.contains(t.id)
                          ? '${t.label} (occupée)'
                          : t.label),
                      tooltip: occupees.contains(t.id)
                          ? 'Reprendre la commande en cours de cette table'
                          : null,
                      selected: _table?.id == t.id,
                      onSelected: (on) => setState(() {
                        _table = on ? t : null;
                        if (on) _libelle.clear();
                      }),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _libelle,
          autofocus: _tables.isEmpty,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: _tables.isEmpty
                ? 'Table ou nom (ex. Table 4)'
                : 'Ou un autre libellé (terrasse, nom du client)',
            helperText: _tables.isEmpty
                ? 'Ajoutez vos tables dans Plan de salle pour les choisir ici.'
                : null,
          ),
          onChanged: (v) => setState(() {
            if (v.trim().isNotEmpty) _table = null;
          }),
          onSubmitted: (_) => _valider(),
        ),
      ],
    );
  }

  Widget _sectionReservation(ThemeData theme) {
    final salles = _onglet == ReservationSpaceKind.hall;
    final toutes = salles ? _snapshot.halls : _snapshot.rooms;
    final liste = toutes.where((r) => r.matches(_recherche.text)).toList();
    final fmt = DateFormat('dd/MM');
    final fmtHeure = DateFormat('dd/MM HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Onglets Chambres / Salles.
        ReservationKindTabs(
          selected: _onglet,
          rooms: _snapshot.rooms.length,
          halls: _snapshot.halls.length,
          onChanged: (k) => setState(() {
            _onglet = k;
            _recherche.clear();
          }),
        ),
        const SizedBox(height: 8),
        if (toutes.length > 4) ...[
          TextField(
            controller: _recherche,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: salles ? 'Salle ou client' : 'Chambre ou client',
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
        ],
        if (_snapshot.fromCache && _snapshot.fetchedAt != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Hors ligne : liste connue le '
              '${DateFormat('dd/MM à HH:mm').format(_snapshot.fetchedAt!)}.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.tertiary),
            ),
          ),
        if (_loading && toutes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (toutes.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                salles
                    ? "Aucune salle réservée aujourd'hui ni dans les 7 jours."
                    : "Aucune chambre occupée en ce moment. Enregistrez d'abord "
                        'la réservation du client (arrivée confirmée ou en cours).',
                style: theme.textTheme.bodyMedium,
              ),
              if (widget.onNewReservation != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Nouvelle réservation'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onNewReservation!();
                    },
                  ),
                ),
              ],
            ],
          )
        else if (liste.isEmpty)
          const Text('Aucune réservation ne correspond.')
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final r in liste)
                  Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    color: _choix?.reservationId == r.reservationId
                        ? theme.colorScheme.primaryContainer
                        : null,
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        _choix?.reservationId == r.reservationId
                            ? Icons.check_circle
                            : (r.isHall ? Icons.meeting_room : Icons.hotel),
                        color: _choix?.reservationId == r.reservationId
                            ? theme.colorScheme.primary
                            : null,
                      ),
                      title: Text(r.spaceName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        r.isHall
                            ? '${r.customerName ?? 'Client'}, '
                                '${fmtHeure.format(r.startAt)} au '
                                '${DateFormat('HH:mm').format(r.endAt)}'
                            : '${r.customerName ?? 'Client'}, du '
                                '${fmt.format(r.startAt)} au '
                                '${fmt.format(r.endAt)}',
                      ),
                      trailing: Text(
                        r.invoiced ? 'Facturée, complément' : r.statusLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: r.inProgress
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant),
                      ),
                      onTap: () => setState(() => _choix = r),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Libellé court d'une nature de commande (écran étroit).
String orderTypeShortLabel(RestaurantOrderType t) => switch (t) {
      RestaurantOrderType.dineIn => 'Sur place',
      RestaurantOrderType.takeaway => 'Emporter',
      RestaurantOrderType.reservation => 'Réservation',
    };

/// Sélecteur segmenté des natures de commande. Sous 340 dp de large, les
/// segments ne montrent que l'icône (libellé en infobulle) et le libellé
/// court du choix s'affiche dessous : rien ne déborde sur un petit écran.
class OrderTypeSelector extends StatelessWidget {
  final List<RestaurantOrderType> types;
  final RestaurantOrderType selected;
  final ValueChanged<RestaurantOrderType> onChanged;

  const OrderTypeSelector({
    super.key,
    required this.types,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final etroit = c.maxWidth < 340;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<RestaurantOrderType>(
            segments: [
              for (final t in types)
                ButtonSegment(
                  value: t,
                  icon: Icon(orderTypeIcon(t)),
                  tooltip: t.label,
                  label: etroit ? null : Text(t.label),
                ),
            ],
            selected: {selected},
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            onSelectionChanged: (s) => onChanged(s.first),
          ),
          if (etroit)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                orderTypeShortLabel(selected),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      );
    });
  }
}

/// Onglets Chambres / Salles d'une commande sur réservation. Écran étroit :
/// icône et nombre seulement.
class ReservationKindTabs extends StatelessWidget {
  final String selected;
  final int rooms;
  final int halls;
  final ValueChanged<String> onChanged;

  const ReservationKindTabs({
    super.key,
    required this.selected,
    required this.rooms,
    required this.halls,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final etroit = c.maxWidth < 340;
      return SegmentedButton<String>(
        segments: [
          ButtonSegment(
            value: ReservationSpaceKind.room,
            icon: const Icon(Icons.hotel),
            tooltip: 'Chambres',
            label: Text(etroit ? '$rooms' : 'Chambres ($rooms)'),
          ),
          ButtonSegment(
            value: ReservationSpaceKind.hall,
            icon: const Icon(Icons.meeting_room),
            tooltip: 'Salles',
            label: Text(etroit ? '$halls' : 'Salles ($halls)'),
          ),
        ],
        selected: {selected},
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        onSelectionChanged: (s) => onChanged(s.first),
      );
    });
  }
}

/// Icône de la nature d'une commande (sélecteur, badges).
IconData orderTypeIcon(RestaurantOrderType type) => switch (type) {
      RestaurantOrderType.dineIn => Icons.table_restaurant,
      RestaurantOrderType.takeaway => Icons.takeout_dining,
      RestaurantOrderType.reservation => Icons.event_available,
    };
