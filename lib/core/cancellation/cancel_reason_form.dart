import 'package:flutter/material.dart';

import 'document_cancellation.dart';

/// Formulaire du motif d'annulation d'une pièce : choix rapides, texte
/// libre, explication de ce qui se passe. Le bouton de confirmation reste
/// grisé tant que le motif n'est pas valable (au moins 3 caractères, texte
/// obligatoire pour « Autre »).
///
/// Partagé par la feuille du bas (mobile) et la fenêtre modale (desktop).
class CancelReasonForm extends StatefulWidget {
  final CancellableDocument doc;

  /// Choix rapides proposés (« Doublon », « Erreur de saisie »...).
  final List<String> presets;

  /// Libellé du bouton de confirmation.
  final String confirmLabel;

  /// Motif obligatoire (annulation) ou facultatif (rétablissement).
  final bool reasonRequired;

  /// Texte d'explication affiché au-dessus du motif.
  final String explanation;

  final ValueChanged<String> onConfirm;
  final VoidCallback onCancel;

  const CancelReasonForm({
    super.key,
    required this.doc,
    required this.presets,
    required this.confirmLabel,
    required this.explanation,
    required this.onConfirm,
    required this.onCancel,
    this.reasonRequired = true,
  });

  @override
  State<CancelReasonForm> createState() => _CancelReasonFormState();
}

class _CancelReasonFormState extends State<CancelReasonForm> {
  final _details = TextEditingController();
  final _detailsFocus = FocusNode();
  String? _preset;
  bool _touched = false;

  @override
  void dispose() {
    _details.dispose();
    _detailsFocus.dispose();
    super.dispose();
  }

  String get _reason => composeCancelReason(_preset, _details.text);

  String? get _error {
    if (!widget.reasonRequired) {
      final r = _reason.trim();
      if (r.isEmpty) return null;
      return r.length < kMinCancelReasonLength
          ? 'Le motif doit compter au moins $kMinCancelReasonLength caractères.'
          : null;
    }
    if (_preset == kOtherCancelPreset && _details.text.trim().isEmpty) {
      return 'Précisez le motif.';
    }
    return validateCancelReason(_reason);
  }

  void _pick(String preset) {
    setState(() {
      _preset = _preset == preset ? null : preset;
      _touched = true;
    });
    if (_preset == kOtherCancelPreset) _detailsFocus.requestFocus();
  }

  void _submit() {
    setState(() => _touched = true);
    if (_error != null) return;
    widget.onConfirm(_reason.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = _error;
    final showError = _touched && error != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.explanation, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (widget.presets.isNotEmpty) ...[
          Text(
            widget.reasonRequired ? 'Motif' : 'Motif (facultatif)',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in widget.presets)
                ChoiceChip(
                  label: Text(p),
                  selected: _preset == p,
                  onSelected: (_) => _pick(p),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          key: const ValueKey('cancel-reason-details'),
          controller: _details,
          focusNode: _detailsFocus,
          minLines: 2,
          maxLines: 4,
          maxLength: 250,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() => _touched = true),
          decoration: InputDecoration(
            labelText:
                _preset == null || _preset == kOtherCancelPreset
                    ? (widget.reasonRequired ? 'Motif' : 'Motif (facultatif)')
                    : 'Précision (facultative)',
            hintText:
                widget.reasonRequired
                    ? 'Exemple : vente saisie deux fois'
                    : null,
            border: const OutlineInputBorder(),
            errorText: showError ? error : null,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: widget.onCancel, child: const Text('Fermer')),
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey('cancel-reason-confirm'),
              onPressed: error == null ? _submit : null,
              style:
                  widget.reasonRequired
                      ? FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                      )
                      : null,
              child: Text(widget.confirmLabel),
            ),
          ],
        ),
      ],
    );
  }
}
