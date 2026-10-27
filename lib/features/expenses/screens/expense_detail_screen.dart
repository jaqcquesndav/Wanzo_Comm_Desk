import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wanzo/features/expenses/bloc/expense_bloc.dart';
import 'package:wanzo/features/expenses/models/expense.dart';
import 'package:wanzo/features/expenses/repositories/expense_repository.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/core/shared_widgets/payment_history_section.dart';
import 'package:wanzo/core/shared_widgets/record_payment_dialog.dart';
import 'package:wanzo/core/shared_widgets/responsive_action_bar.dart';
import 'package:wanzo/core/shared_widgets/wanzo_app_bar.dart';
import 'package:wanzo/core/shared_widgets/smart_attachment.dart';
import 'package:wanzo/core/services/form_navigation_service.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart'; // Pour les permissions
import 'package:wanzo/core/cancellation/cancel_document_dialog.dart';
import 'package:wanzo/core/cancellation/cancellation_banner.dart';
import 'package:wanzo/core/cancellation/document_cancellation.dart';
import 'package:wanzo/core/cancellation/pending_cancellations.dart';
import 'package:wanzo/features/auth/bloc/auth_bloc.dart';
import 'package:wanzo/features/cash_session/cash_access.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final String expenseId;

  // Constante pour le breakpoint desktop
  static const double desktopBreakpoint = 900.0;

  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  /// Dernière dépense connue. Le bloc est partagé avec les écrans de liste :
  /// après une opération il émet `ExpensesLoaded`, que cet écran ne sait pas
  /// afficher. On conserve donc la dépense pour continuer à l'afficher au lieu
  /// de tomber sur « Veuillez charger une dépense » (écran blanc).
  Expense? _expense;

  /// Un règlement est en cours d'envoi (voile de chargement).
  bool _submitting = false;


  /// Change à chaque règlement pour recharger l'historique des tranches.
  int _paymentsToken = 0;

  @override
  void initState() {
    super.initState();
    context.read<ExpenseBloc>().add(LoadExpenseById(widget.expenseId));
    _checkPermissions();
  }

  // Obtenir la couleur selon le statut de paiement
  Color _getStatusColor(ExpensePaymentStatus? status) {
    switch (status) {
      case ExpensePaymentStatus.paid:
        return Colors.green;
      case ExpensePaymentStatus.partial:
        return Colors.orange;
      case ExpensePaymentStatus.unpaid:
      case null:
        return Colors.red;
      case ExpensePaymentStatus.credit:
        return Colors.blue;
    }
  }

  /// Dialogue « Enregistrer un paiement » : montant (plafonné au reste à
  /// payer), mode de règlement, date et référence.
  ///
  /// Le cumul n'est PLUS calculé côté client : la tranche part telle quelle
  /// vers `POST expenses/:id/payments` et le serveur recalcule `paidAmount`
  /// et `paymentStatus`.
  Future<void> _showRecordPaymentDialog(Expense expense) async {
    final draft = await showRecordPaymentDialog(
      context,
      remainingAmount: expense.remainingAmount,
      currencyCode: expense.effectiveCurrencyCode,
      exchangeRate: expense.exchangeRate,
      defaultMethod: expense.paymentMethod,
    );
    if (draft == null || !mounted) return;
    setState(() => _submitting = true);
    context.read<ExpenseBloc>().add(
      RecordExpensePayment(expense: expense, payment: draft),
    );
  }

  /// Solde la dette : le dialogue de paiement, prérempli avec le reste à
  /// payer, demande TOUJOURS le mode de règlement (jamais « N/A »).
  Future<void> _settleInFull(Expense expense) async {
    final remaining = expense.remainingAmount;
    if (remaining <= 0) return;
    final draft = await showRecordPaymentDialog(
      context,
      title: 'Solder la dette',
      remainingAmount: remaining,
      currencyCode: expense.effectiveCurrencyCode,
      exchangeRate: expense.exchangeRate,
      defaultMethod: expense.paymentMethod,
    );
    if (draft == null || !mounted) return;
    setState(() => _submitting = true);
    context.read<ExpenseBloc>().add(
      RecordExpensePayment(expense: expense, payment: draft),
    );
  }

  /// Réactions du bloc : on reste sur l'écran, on rafraîchit la dépense et on
  /// informe l'utilisateur en cas d'échec.
  void _onExpenseState(BuildContext context, ExpenseState state) {
    if (!mounted) return;
    if (state is ExpenseCancellationDone) {
      setState(() {
        _expense = state.expense;
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: state.synced ? Colors.green : Colors.orange,
        ),
      );
      return;
    }
    if (state is ExpenseLoaded) {
      setState(() => _expense = state.expense);
    } else if (state is ExpensePaymentRecorded) {
      setState(() {
        _expense = state.expense;
        _submitting = false;
        _paymentsToken++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: state.synced ? Colors.green : Colors.orange,
        ),
      );
      // La liste des dépenses doit refléter le nouveau solde.
      context.read<ExpenseBloc>().add(const LoadExpenses());
    } else if (state is ExpenseOperationSuccess) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message), backgroundColor: Colors.green),
      );

      // `ExpenseOperationSuccess` est suivi d'un `LoadExpenses` (état de
      // liste) que cet écran ne sait pas afficher : on redemande la dépense.
      context.read<ExpenseBloc>().add(LoadExpenseById(widget.expenseId));
    } else if (state is ExpenseError) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message.replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Retour sûr : pile vide (lien direct) => liste des dépenses.
  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/expenses');
    }
  }

  /// Modifier : même formulaire que la création (dialogue sur grand écran).
  Future<void> _edit(Expense expense) async {
    await FormNavigationService.instance.openExpenseForm(
      context,
      expense: expense,
    );
    if (mounted) {
      context.read<ExpenseBloc>().add(LoadExpenseById(widget.expenseId));
    }
  }

  /// Administrateur, gérant ou comptable : seuls à annuler une dépense.
  bool get _canCancel => canCancelDocument(currentUserRole(context));

  /// Administrateur ou comptable : seuls à rétablir une dépense annulée.
  bool get _canRestore => canRestoreDocument(currentUserRole(context));

  /// Annule la dépense (jamais de suppression) : motif obligatoire, elle
  /// reste visible au statut annulé et peut être rétablie.
  Future<void> _cancelExpense(Expense expense) async {
    final reason = await showCancelDocumentDialog(
      context,
      doc: CancellableDocument.expense,
    );
    if (reason == null || !mounted) return;
    final auth = context.read<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user : null;
    setState(() => _submitting = true);
    context.read<ExpenseBloc>().add(
      CancelExpense(
        expense: expense,
        reason: reason,
        actorName: user?.name.isNotEmpty == true ? user!.name : user?.email,
        actorId: user?.id,
      ),
    );
  }

  /// Rétablit une dépense annulée (administrateur et comptable).
  Future<void> _restoreExpense(Expense expense) async {
    final reason = await showRestoreDocumentDialog(
      context,
      doc: CancellableDocument.expense,
    );
    if (reason == null || !mounted) return;
    setState(() => _submitting = true);
    context.read<ExpenseBloc>().add(
      RestoreExpense(expense: expense, reason: reason.isEmpty ? null : reason),
    );
  }

  /// Bandeau « Annulée le ... par ... : motif », avec « Rétablir ».
  Widget _cancellationBanner(Expense expense) => CancellationBanner(
    info: expense.cancellation,
    pendingSync: PendingCancellations.instance.isPending(
      CancellableDocument.expense,
      expense.id.isNotEmpty ? expense.id : (expense.localId ?? ''),
    ),
    onRestore:
        _canRestore && !_submitting ? () => _restoreExpense(expense) : null,
  );

  // Vérifier et demander les permissions nécessaires au démarrage
  Future<void> _checkPermissions() async {
    // Vérifier les permissions de stockage
    final storageStatus = await Permission.storage.status;
    if (!storageStatus.isGranted) {
      // Ne pas demander immédiatement, attendre l'action de l'utilisateur
      // La permission sera demandée lors de la première utilisation
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop =
            constraints.maxWidth >= ExpenseDetailScreen.desktopBreakpoint;

        return Scaffold(
          appBar: WanzoAppBar(
            title: 'Détails de la Dépense',
            onBackPressed: _leave,
            additionalActions: [
              if (_expense != null)
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    final current = _expense;
                    if (current == null) return;
                    if (value == 'edit') _edit(current);
                    if (value == 'cancel') _cancelExpense(current);
                    if (value == 'restore') _restoreExpense(current);
                  },
                  itemBuilder: (_) => [
                    if (!_expense!.isCancelled)
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Modifier'),
                        ),
                      ),
                    // Une dépense ne se supprime pas : elle s'annule (motif,
                    // trace) et peut être rétablie, selon le rôle.
                    if (!_expense!.isCancelled && _canCancel)
                      const PopupMenuItem(
                        value: 'cancel',
                        child: ListTile(
                          leading: Icon(Icons.block, color: Colors.red),
                          title: Text('Annuler la dépense'),
                        ),
                      ),
                    if (_expense!.isCancelled && _canRestore)
                      const PopupMenuItem(
                        value: 'restore',
                        child: ListTile(
                          leading: Icon(Icons.restore),
                          title: Text('Rétablir la dépense'),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          body: Stack(
            children: [
              BlocConsumer<ExpenseBloc, ExpenseState>(
                listener: _onExpenseState,
                builder: (context, state) {
                  // Source d'affichage : l'état s'il porte bien une dépense
                  // unitaire, sinon la dernière dépense connue (états de
                  // liste, succès d'opération...). Évite l'écran blanc
                  // « Veuillez charger une dépense » après un règlement.
                  final expense =
                      state is ExpenseLoaded
                          ? state.expense
                          : (state is ExpensePaymentRecorded
                              ? state.expense
                              : (state is ExpenseCancellationDone
                                  ? state.expense
                                  : _expense));

                  if (expense == null) {
                    if (state is ExpenseError) {
                      return Center(child: Text('Erreur: ${state.message}'));
                    }
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Devise propre a la depense (per-record), avec repli CDF.
                  final currencyCode = expense.effectiveCurrencyCode;
                  return isDesktop
                      ? _buildDesktopLayout(context, expense, currencyCode)
                      : _buildMobileLayout(context, expense, currencyCode);
                },
              ),
              // Voile de chargement pendant l'envoi d'un règlement.
              if (_submitting)
                Container(
                  color: Colors.black.withAlpha(128),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text(
                          'Enregistrement du paiement...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Layout desktop: 2 colonnes
  Widget _buildDesktopLayout(
    BuildContext context,
    Expense expense,
    String currencyCode,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colonne principale (détails)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (expense.isCancelled) _cancellationBanner(expense),
                _buildMainCard(context, expense, currencyCode),
                const SizedBox(height: 24),
                _buildPaymentStatusCard(context, expense, currencyCode),
                const SizedBox(height: 24),
                _buildPaymentHistory(expense),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Sidebar (pièces jointes + actions)
          SizedBox(
            width: 350,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAttachmentsCard(context, expense),
                const SizedBox(height: 16),
                if (!expense.isCancelled &&
                    expense.paymentStatus != ExpensePaymentStatus.paid)
                  _buildDesktopActionsCard(context, expense),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Layout mobile: colonne verticale
  Widget _buildMobileLayout(
    BuildContext context,
    Expense expense,
    String currencyCode,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (expense.isCancelled) _cancellationBanner(expense),
          _buildMainCard(context, expense, currencyCode),
          const SizedBox(height: 24),
          _buildPaymentStatusCard(context, expense, currencyCode),
          const SizedBox(height: 24),
          _buildPaymentHistory(expense),
          const SizedBox(height: 24),
          _buildAttachmentsCard(context, expense),
        ],
      ),
    );
  }

  /// Carte principale avec informations de base
  Widget _buildMainCard(
    BuildContext context,
    Expense expense,
    String currencyCode,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icône pour la catégorie
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getCategoryIcon(expense.category),
                    color: Theme.of(context).primaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                // Détails principaux
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.motif,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat(
                          'dd MMMM yyyy',
                          'fr_FR',
                        ).format(expense.date),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Montant avec devise
                      Text(
                        formatCurrency(expense.amount, currencyCode),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            // Informations détaillées
            _buildDetailItem(
              context,
              'Catégorie',
              expense.category.displayName,
              Icons.category,
            ),
            if ((expense.supplierName ?? '').isNotEmpty ||
                (expense.supplierId ?? '').isNotEmpty)
              _buildDetailItem(
                context,
                'Fournisseur',
                (expense.supplierName ?? '').isNotEmpty
                    ? expense.supplierName!
                    : 'Fournisseur lié',
                Icons.local_shipping_outlined,
                onTap: (expense.supplierId ?? '').isEmpty
                    ? null
                    : () => context.push(
                          '/suppliers/detail/${expense.supplierId}',
                        ),
              ),
            // Le mode n'existe que pour une part réellement payée.
            if ((expense.paidAmount ?? 0) > 0 ||
                expense.paymentStatus == ExpensePaymentStatus.paid)
              _buildDetailItem(
                context,
                'Méthode de paiement',
                expense.paymentMethod ?? 'Non spécifiée',
                Icons.payment,
              ),
            if (expense.beneficiary != null && expense.beneficiary!.isNotEmpty)
              _buildDetailItem(
                context,
                'Bénéficiaire',
                expense.beneficiary!,
                Icons.person,
              ),
            if (expense.notes != null && expense.notes!.isNotEmpty)
              _buildDetailItem(context, 'Notes', expense.notes!, Icons.note),
          ],
        ),
      ),
    );
  }

  /// Carte état du paiement
  Widget _buildPaymentStatusCard(
    BuildContext context,
    Expense expense,
    String currencyCode,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section État du paiement
            Row(
              children: [
                Icon(Icons.payment, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Text(
                  'État du paiement',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      expense.paymentStatus,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(expense.paymentStatus),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    expense.paymentStatusText,
                    style: TextStyle(
                      color: _getStatusColor(expense.paymentStatus),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Montants détaillés
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Montant total:',
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        formatCurrency(expense.amount, currencyCode),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Montant payé:',
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        formatCurrency(expense.paidAmount ?? 0.0, currencyCode),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  if (expense.remainingAmount > 0) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Reste à payer:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          formatCurrency(expense.remainingAmount, currencyCode),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Boutons d'action de règlement.
            // ResponsiveActionBar au lieu d'une Row d'Expanded : deux boutons
            // libellés ne tiennent pas côte à côte sur un écran étroit.
            if (!expense.isCancelled &&
                expense.paymentStatus != ExpensePaymentStatus.paid &&
                expense.remainingAmount > 0) ...[
              const SizedBox(height: 20),
              ResponsiveActionBar(
                items: [
                  ActionBarItem(
                    icon: Icons.payments,
                    label: 'Régler',
                    background: Theme.of(context).primaryColor,
                    onPressed:
                        _submitting
                            ? null
                            : () => _showRecordPaymentDialog(expense),
                  ),
                  ActionBarItem(
                    icon: Icons.check_circle,
                    label: 'Solder',
                    background: Colors.green,
                    onPressed:
                        _submitting ? null : () => _settleInFull(expense),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Carte pièces jointes
  Widget _buildAttachmentsCard(BuildContext context, Expense expense) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_file, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Pièces Jointes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SmartAttachmentGrid(
              urls: expense.attachmentUrls ?? [],
              localPaths: expense.localAttachmentPaths ?? [],
            ),
          ],
        ),
      ),
    );
  }

  /// Actions card pour desktop
  Widget _buildDesktopActionsCard(BuildContext context, Expense expense) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Actions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (expense.remainingAmount > 0) ...[
              OutlinedButton.icon(
                onPressed:
                    _submitting
                        ? null
                        : () => _showRecordPaymentDialog(expense),
                icon: const Icon(Icons.payments),
                label: const Text('Régler'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ElevatedButton.icon(
              onPressed: _submitting ? null : () => _settleInFull(expense),
              icon: const Icon(Icons.check_circle),
              label: const Text('Solder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Historique des tranches de règlement (`GET expenses/:id/payments`).
  Widget _buildPaymentHistory(Expense expense) {
    return PaymentHistorySection(
      loader:
          () => context.read<ExpenseRepository>().getExpensePayments(
            expense.id,
          ),
      currencyCode: expense.effectiveCurrencyCode,
      fallbackPaidAmount: expense.paidAmount ?? 0.0,
      refreshToken: _paymentsToken,
    );
  }

  // Méthode pour obtenir l'icône correspondant à la catégorie
  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.rent:
        return Icons.home;
      case ExpenseCategory.utilities:
        return Icons.electrical_services;
      case ExpenseCategory.supplies:
        return Icons.shopping_basket;
      case ExpenseCategory.salaries:
        return Icons.people;
      case ExpenseCategory.marketing:
        return Icons.campaign;
      case ExpenseCategory.transport:
        return Icons.directions_car;
      case ExpenseCategory.maintenance:
        return Icons.build;
      case ExpenseCategory.inventory:
        return Icons.inventory_2;
      case ExpenseCategory.equipment:
        return Icons.construction;
      case ExpenseCategory.taxes:
        return Icons.receipt_long;
      case ExpenseCategory.insurance:
        return Icons.security;
      case ExpenseCategory.loan:
        return Icons.account_balance;
      case ExpenseCategory.office:
        return Icons.business_center;
      case ExpenseCategory.training:
        return Icons.school;
      case ExpenseCategory.travel:
        return Icons.flight;
      case ExpenseCategory.software:
        return Icons.computer;
      case ExpenseCategory.advertising:
        return Icons.ads_click;
      case ExpenseCategory.legal:
        return Icons.gavel;
      case ExpenseCategory.manufacturing:
        return Icons.precision_manufacturing;
      case ExpenseCategory.consulting:
        return Icons.support_agent;
      case ExpenseCategory.research:
        return Icons.science;
      case ExpenseCategory.fuel:
        return Icons.local_gas_station;
      case ExpenseCategory.entertainment:
        return Icons.card_giftcard;
      case ExpenseCategory.communication:
        return Icons.phone_in_talk;
      case ExpenseCategory.other:
        return Icons.more_horiz;
    }
  }

  // Méthode pour créer un élément détaillé
  Widget _buildDetailItem(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: onTap != null ? Theme.of(context).primaryColor : null,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null) Icon(Icons.chevron_right, color: Colors.grey[500]),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: onTap == null ? row : InkWell(onTap: onTap, child: row),
    );
  }
}
