import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:wanzo/core/enums/currency_enum.dart';
import 'package:wanzo/features/expenses/bloc/expense_bloc.dart';
import 'package:wanzo/features/expenses/models/expense.dart';
import 'package:wanzo/features/expenses/widgets/cash_out_voucher_sheet.dart';
import 'package:wanzo/features/settings/bloc/settings_bloc.dart';
import 'package:wanzo/features/settings/bloc/settings_state.dart';
import 'package:wanzo/features/settings/models/settings.dart';
import 'package:wanzo/features/settings/presentation/cubit/currency_settings_cubit.dart';

import '../models/stylist.dart';

/// Ce que le formulaire rapporte : la dépense telle qu'elle a été enregistrée,
/// et si elle est déjà partie au serveur ou seulement posée en local.
class _AdvanceResult {
  const _AdvanceResult(
    this.expense,
    this.reference, {
    required this.synchronise,
    required this.montantCdf,
  });

  final Expense expense;
  final String reference;
  final bool synchronise;

  /// Montant verse ramene en CDF au taux fige : c'est ce qui vient en
  /// deduction du solde du coiffeur, et ce que l'ecran applique aussitot.
  final double montantCdf;
}

/// Ce que l'ecran appelant recoit apres un versement confirme.
class VersementCoiffeur {
  const VersementCoiffeur({required this.montantCdf, required this.synchronise});

  final double montantCdf;
  final bool synchronise;
}

/// Verser une AVANCE à un coiffeur.
///
/// Une avance est de l'argent qui sort de la caisse : c'est une dépense, pas
/// une écriture à part. Elle est rattachée au coiffeur par `performerId`, ce
/// qui la fait venir en déduction de ses commissions dans son relevé. Le
/// formulaire reste court : un montant, une date, un motif, parce que c'est un
/// geste de comptoir. À la validation, la caisse sort une pièce signée par le
/// bénéficiaire, comme pour toute sortie d'espèces.
///
/// Avec [soldeDu], le formulaire sert a REGLER les commissions : montant
/// propose egal au reste a verser, motif et nature adaptes. La mecanique est
/// la meme (une sortie de caisse rattachee au coiffeur), le serveur retranche
/// toute somme versee, avance comme reglement.
Future<VersementCoiffeur?> showAdvanceForm(
  BuildContext context,
  Stylist stylist, {
  double? soldeDu,
}) async {
  final resultat = await showDialog<_AdvanceResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AdvanceDialog(stylist: stylist, soldeDu: soldeDu),
  );
  if (resultat == null) return null;
  final versement = VersementCoiffeur(
    montantCdf: resultat.montantCdf,
    synchronise: resultat.synchronise,
  );
  if (!context.mounted) return versement;

  // Le bon s'affiche depuis l'écran appelant, une fois la boîte refermée :
  // une feuille par-dessus une boîte de dialogue se ferme mal.
  final settings = _settingsCourants(context);
  if (settings != null) {
    final ok = await showCashOutVoucher(
      context,
      CashOutVoucher(
        reference: resultat.reference,
        date: resultat.expense.date,
        beneficiary: stylist.name,
        motif: resultat.expense.motif,
        amount: resultat.expense.amount,
        currencyCode: resultat.expense.currencyCode ?? Currency.CDF.code,
        paymentMethod: 'Espèces',
        note: (soldeDu != null
                ? 'Règlement des commissions de ${stylist.name}.'
                : 'Avance à déduire des commissions de ${stylist.name}.') +
            (resultat.synchronise
                ? ''
                : ' Enregistrée hors ligne, envoi au retour du réseau.'),
      ),
      settings,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Avance enregistrée. Le bon de caisse n\'a pas pu être produit.',
          ),
        ),
      );
    }
  }
  return versement;
}

Settings? _settingsCourants(BuildContext context) {
  final etat = context.read<SettingsBloc>().state;
  if (etat is SettingsLoaded) return etat.settings;
  if (etat is SettingsUpdated) return etat.settings;
  return null;
}

class _AdvanceDialog extends StatefulWidget {
  const _AdvanceDialog({required this.stylist, this.soldeDu});

  final Stylist stylist;

  /// Renseigne en mode reglement : le reste a verser, en CDF.
  final double? soldeDu;

  bool get _reglement => soldeDu != null;

  @override
  State<_AdvanceDialog> createState() => _AdvanceDialogState();
}

class _AdvanceDialogState extends State<_AdvanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _motifController = TextEditingController();
  DateTime _date = DateTime.now();
  Currency _currency = Currency.CDF;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _motifController.text = widget._reglement
        ? 'Règlement commissions ${widget.stylist.name}'
        : 'Avance ${widget.stylist.name}';
    if (widget._reglement && (widget.soldeDu ?? 0) > 0) {
      _amountController.text = widget.soldeDu!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _motifController.dispose();
    super.dispose();
  }

  /// Taux central devise -> CDF, ou `null` si la devise est le CDF ou si
  /// aucun taux reel n'est charge : le serveur retombe alors sur le taux
  /// central de la societe. Aucun taux n'est invente ici.
  double? _tauxVersCdf() {
    if (_currency == Currency.CDF) return null;
    try {
      final st = context.read<CurrencySettingsCubit>().state;
      if (st.status == CurrencySettingsStatus.loaded ||
          st.status == CurrencySettingsStatus.saved) {
        final r = _currency == Currency.USD
            ? st.settings.usdToCdfRate
            : st.settings.fcfaToCdfRate;
        if (r > 1) return r;
      }
    } catch (_) {
      // Cubit indisponible : le serveur resoudra le taux.
    }
    return null;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('fr', 'FR'),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) return;

    setState(() => _saving = true);
    final taux = _tauxVersCdf();
    final id = const Uuid().v4();
    final expense = Expense(
      id: id,
      date: _date,
      motif: _motifController.text.trim(),
      amount: amount,
      // Une avance relève de la masse salariale, précisée pour que les
      // rapports la distinguent d'une paie ou d'un journalier.
      category: ExpenseCategory.salaries,
      subCategory: widget._reglement
          ? 'Règlement commissions'
          : 'Avance prestataire',
      performerId: widget.stylist.id,
      performerName: widget.stylist.name,
      beneficiary: widget.stylist.name,
      paymentMethod: 'cash',
      currencyCode: _currency.code,
      // Taux fige au moment du versement : sans lui, le serveur devait deviner
      // et une avance en dollars etait comptee pour son montant brut.
      exchangeRate: taux,
      paidAmount: amount,
      paymentStatus: ExpensePaymentStatus.paid,
      attachmentUrls: const [],
    );

    // On attend le verdict du bloc au lieu de refermer aussitôt : sans cela une
    // avance refusée par le serveur passait pour versée, et la caisse ne
    // tombait plus juste.
    final bloc = context.read<ExpenseBloc>();
    final verdict = bloc.stream.firstWhere(
      (s) => s is ExpenseOperationSuccess || s is ExpenseError,
    );
    bloc.add(AddExpense(expense));

    ExpenseState etat;
    bool synchronise = true;
    try {
      etat = await verdict.timeout(const Duration(seconds: 25));
    } on TimeoutException {
      // La dépense est déjà écrite en local avant l'appel réseau : l'argent est
      // bien sorti, seul l'envoi traîne.
      etat = const ExpenseOperationSuccess('Enregistrée, envoi en cours.');
      synchronise = false;
    }

    if (!mounted) return;

    if (etat is ExpenseError) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Avance non enregistrée : ${etat.message}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      _AdvanceResult(
        expense,
        'BSC-${id.substring(0, 8).toUpperCase()}',
        synchronise: synchronise,
        montantCdf: amount * (taux ?? 1.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget._reglement
          ? 'Régler ${widget.stylist.name}'
          : 'Avance à ${widget.stylist.name}'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width.clamp(280.0, 420.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _amountController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Montant (${_currency.code}) *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.payments_outlined),
                      ),
                      validator: (v) {
                        final a = double.tryParse((v ?? '').trim());
                        if (a == null || a <= 0) return 'Montant invalide';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<Currency>(
                      value: _currency,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Devise',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: Currency.CDF, child: Text('CDF')),
                        DropdownMenuItem(
                            value: Currency.USD, child: Text('USD')),
                      ],
                      onChanged: (c) {
                        if (c != null) setState(() => _currency = c);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _motifController,
                decoration: const InputDecoration(
                  labelText: 'Motif',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event_outlined),
                  ),
                  child: Text(
                    '${_date.day.toString().padLeft(2, '0')}/'
                    '${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Enregistrée comme une dépense, retranchée des commissions "
                "de ${widget.stylist.name} dans son relevé. Un bon de sortie "
                "de caisse est produit à la validation.",
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(_saving ? 'Versement...' : 'Verser'),
        ),
      ],
    );
  }
}
