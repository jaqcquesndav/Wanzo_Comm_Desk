import 'package:flutter/material.dart';
import 'package:wanzo/features/atelier/models/atelier_order.dart';
import 'package:wanzo/features/atelier/services/atelier_api_service.dart';

/// Fiche de mesures d'un client d'atelier.
///
/// Les mesures sont un attribut STABLE du client (réutilisées à chaque
/// commande). L'écran n'affiche QUE les mesures pertinentes au métier :
/// mensurations corporelles pour la couture, pointure pour la cordonnerie
/// (les deux si le métier n'est pas précisé). Cette fiche n'est accessible
/// qu'en mode atelier — jamais pour la maintenance.
class AtelierClientProfileScreen extends StatefulWidget {
  final String customerId;
  final String? customerName;

  /// Métier de la commande d'origine : détermine quelles mesures afficher.
  /// `null` → on affiche couture + cordonnerie (accès générique).
  final AtelierMetier? metier;

  const AtelierClientProfileScreen({
    super.key,
    required this.customerId,
    this.customerName,
    this.metier,
  });

  @override
  State<AtelierClientProfileScreen> createState() =>
      _AtelierClientProfileScreenState();
}

class _AtelierClientProfileScreenState
    extends State<AtelierClientProfileScreen> {
  final _api = AtelierApiService();

  // Champs (clé backend → contrôleur).
  final Map<String, TextEditingController> _c = {
    for (final k in _fields.keys) k: TextEditingController(),
  };
  final _notesCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  // Libellés des mesures couture (corporelles).
  static const Map<String, String> _fields = {
    'totalHeight': 'Hauteur Totale (HT)',
    'chestContour': 'Contour Poitrine (CP)',
    'sleeveHeight': 'Hauteur Manche (HM)',
    'shoulder': 'Épaule (EP)',
    'totalHeight2': 'Hauteur Totale 2 (HT2)',
    'waistContour': 'Contour Taille (CT)',
    'thighContour': 'Contour Cuisse (CC)',
    'legContour': 'Contour Jambe (CJ)',
    'kneeContour': 'Contour Genoux (CG)',
    'calfContour': 'Contour Mollet (CM)',
  };
  static const Map<String, String> _shoeFields = {
    'shoeSize': 'Pointure',
    'footLength': 'Longueur du pied (cm)',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final ctrl in _c.values) {
      ctrl.dispose();
    }
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getProfile(widget.customerId);
      if (data != null) {
        for (final k in _fields.keys) {
          if (data[k] != null) _c[k]!.text = '${data[k]}';
        }
        if (data['shoeSize'] != null) _shoeCtrl['shoeSize']!.text = '${data['shoeSize']}';
        if (data['footLength'] != null) _shoeCtrl['footLength']!.text = '${data['footLength']}';
        _notesCtrl.text = data['notes'] as String? ?? '';
      }
    } catch (_) {
      // Pas de profil encore : formulaire vierge.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  final Map<String, TextEditingController> _shoeCtrl = {
    'shoeSize': TextEditingController(),
    'footLength': TextEditingController(),
  };

  // Sélection des sections selon le métier (couture / cordonnerie / les deux).
  bool get _showCouture => widget.metier != AtelierMetier.cordonnerie;
  bool get _showCordonnerie => widget.metier != AtelierMetier.couture;

  Future<void> _save() async {
    setState(() => _saving = true);
    // Les mesures sont FACULTATIVES : on n'envoie que les champs réellement
    // saisis (aucun n'est obligatoire, couture comme cordonnerie).
    final payload = <String, dynamic>{};
    _c.forEach((k, ctrl) {
      final v = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
      if (v != null) payload[k] = v;
    });
    _shoeCtrl.forEach((k, ctrl) {
      final v = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
      if (v != null) payload[k] = v;
    });
    if (_notesCtrl.text.trim().isNotEmpty) payload['notes'] = _notesCtrl.text.trim();
    debugPrint('🧵 [Atelier] _save mesures customer=${widget.customerId} '
        'payload=$payload');
    try {
      final saved = await _api.upsertProfile(widget.customerId, payload);
      debugPrint('🧵 [Atelier] mesures enregistrées OK: $saved');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesures enregistrées')),
      );
      Navigator.of(context).pop(true);
    } catch (e, st) {
      debugPrint('🧵 [Atelier] ÉCHEC save mesures: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec : $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mesures — ${widget.customerName ?? 'Client'}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_showCouture) ...[
                      _sectionTitle(context, 'Couture — mesures corporelles (cm)'),
                      _grid(_fields, _c),
                      const SizedBox(height: 20),
                    ],
                    if (_showCordonnerie) ...[
                      _sectionTitle(context, 'Cordonnerie'),
                      _grid(_shoeFields, _shoeCtrl),
                      const SizedBox(height: 20),
                    ],
                    TextField(
                      controller: _notesCtrl,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Notes / mensurations particulières',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: const Text('Enregistrer les mesures'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(BuildContext context, String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
  );

  Widget _grid(Map<String, String> fields, Map<String, TextEditingController> ctrls) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 520 ? 2 : 1;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final e in fields.entries)
              SizedBox(
                width: cols == 2 ? (c.maxWidth - 12) / 2 : c.maxWidth,
                child: TextField(
                  controller: ctrls[e.key],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: e.value,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
