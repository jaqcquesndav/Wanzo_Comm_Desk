import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wanzo/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../receivables/utils/receivables_utils.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/repositories/expense_repository.dart';
import '../../expenses/utils/expense_payment_flow.dart';
import 'package:wanzo/core/shared_widgets/responsive_action_bar.dart';
import '../bloc/supplier_bloc.dart';
import '../bloc/supplier_event.dart';
import '../bloc/supplier_state.dart';
import '../models/supplier.dart';
import '../utils/supplier_purchases.dart';
import '../repositories/supplier_repository.dart';
import 'package:wanzo/core/services/form_navigation_service.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';

/// Écran de détails d'un fournisseur
class SupplierDetailsScreen extends StatelessWidget {
  /// Fournisseur à afficher
  final Supplier? supplier;

  /// ID du fournisseur
  final String supplierId;

  /// Constante pour le breakpoint desktop
  static const double desktopBreakpoint = 900.0;

  const SupplierDetailsScreen({super.key, this.supplier, this.supplierId = ''});
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final targetId = supplier?.id ?? supplierId;
    if (supplier != null) {
      // On écoute le bloc : après une modification ou un règlement, la fiche
      // rechargée (LoadSupplier) remplace celle reçue en paramètre.
      return BlocBuilder<SupplierBloc, SupplierState>(
        buildWhen: (_, s) => s is SupplierLoaded && s.supplier.id == targetId,
        builder: (context, state) {
          final shown = state is SupplierLoaded && state.supplier.id == targetId
              ? state.supplier
              : supplier!;
          return _buildSupplierDetails(context, shown);
        },
      );
    }
    if (supplierId.isNotEmpty) {
      context.read<SupplierBloc>().add(LoadSupplier(supplierId));

      return Scaffold(
        appBar: AppBar(
          title: Text(localizations.supplierDetailsTitle),
          // Retour SÛR : pile vide (deep link) → repli sur Contacts.
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/contacts'),
          ),
        ),
        body: BlocBuilder<SupplierBloc, SupplierState>(
          builder: (context, state) {
            if (state is SupplierLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is SupplierLoaded) {
              return _buildSupplierDetails(context, state.supplier);
            } else if (state is SupplierError) {
              return Center(
                child: Text(localizations.supplierErrorLoading(state.message)),
              ); // Corrected
            }
            return Center(child: Text(localizations.supplierNotFound));
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(localizations.supplierDetailsTitle)),
      body: Center(child: Text(localizations.supplierNotFound)),
    );
  }

  Widget _buildSupplierDetails(BuildContext context, Supplier supplier) {
    final localizations = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= desktopBreakpoint;

        return Scaffold(
          appBar: AppBar(
            title: Text(localizations.supplierDetailsTitle),
            // Retour SÛR : pile vide (deep link) → repli sur Contacts.
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/contacts'),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: localizations.edit,
                onPressed: () => _navigateToEditSupplier(context, supplier),
              ),
              if (isDesktop)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: localizations.deleteButtonLabel,
                  onPressed: () => _confirmDelete(context, supplier),
                ),
            ],
          ),
          body:
              isDesktop
                  ? _buildDesktopLayout(
                    context,
                    supplier,
                    localizations,
                  )
                  : _buildMobileLayout(
                    context,
                    supplier,
                    localizations,
                  ),
        );
      },
    );
  }

  /// Layout desktop: 2 colonnes
  Widget _buildDesktopLayout(
    BuildContext context,
    Supplier supplier,
    AppLocalizations localizations,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colonne principale (informations)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Carte contact
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.contactInformationSectionTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        if (supplier.contactPerson.isNotEmpty) ...[
                          _buildInfoRow(
                            Icons.person,
                            localizations.contactLabel,
                            supplier.contactPerson,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _buildInfoRow(
                          Icons.phone,
                          localizations.phoneLabel,
                          supplier.phoneNumber,
                          onTap:
                              () =>
                                  _makePhoneCall(context, supplier.phoneNumber),
                        ),
                        const SizedBox(height: 12),
                        if (supplier.email.isNotEmpty) ...[
                          _buildInfoRow(
                            Icons.email,
                            localizations.emailLabel,
                            supplier.email,
                            onTap: () => _sendEmail(context, supplier.email),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (supplier.address.isNotEmpty) ...[
                          _buildInfoRow(
                            Icons.location_on,
                            localizations.addressLabel,
                            supplier.address,
                            onTap: () => _openMap(context, supplier.address),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Actions de contact direct : Appeler / WhatsApp / Email.
                _buildContactActions(context, supplier),
                const SizedBox(height: 16),
                // Carte informations commerciales
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.commercialInformationSectionTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        _buildPurchasesRows(context, supplier, localizations),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.timer,
                          localizations.deliveryTimeLabel,
                          localizations.deliveryTimeInDays(
                            supplier.deliveryTimeInDays,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (supplier.paymentTerms.isNotEmpty) ...[
                          _buildInfoRow(
                            Icons.payment,
                            localizations.paymentTermsLabel,
                            supplier.paymentTerms,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _buildInfoRow(
                          Icons.access_time,
                          localizations.supplierSinceLabel,
                          _formatDate(supplier.createdAt, context),
                        ),
                      ],
                    ),
                  ),
                ),
                // Dettes fournisseur (solde impayé).
                _buildPayablesSection(context, supplier, localizations),
                if (supplier.notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.notesSectionTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text(supplier.notes),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Sidebar (profil + actions)
          SizedBox(
            width: 320,
            child: Column(
              children: [
                // Carte profil
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: _getCategoryColor(supplier.category),
                          child: Text(
                            supplier.name.isNotEmpty
                                ? supplier.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 36,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          supplier.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(
                              supplier.category,
                            ).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _getCategoryName(context, supplier.category),
                            style: TextStyle(
                              color: _getCategoryColor(supplier.category),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Carte actions
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _placeOrder(context, supplier),
                          icon: const Icon(Icons.shopping_cart),
                          label: Text(localizations.placeOrderButtonLabel),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed:
                              () =>
                                  _makePhoneCall(context, supplier.phoneNumber),
                          icon: const Icon(Icons.phone),
                          label: Text(localizations.callButtonLabel),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _confirmDelete(context, supplier),
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: Text(localizations.deleteButtonLabel),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
    Supplier supplier,
    AppLocalizations localizations,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: _getCategoryColor(supplier.category),
                  child: Text(
                    supplier.name.isNotEmpty
                        ? supplier.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 36, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  supplier.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(
                      supplier.category,
                    ).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getCategoryName(context, supplier.category),
                    style: TextStyle(
                      color: _getCategoryColor(supplier.category),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.contactInformationSectionTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  if (supplier.contactPerson.isNotEmpty) ...[
                    _buildInfoRow(
                      Icons.person,
                      localizations.contactLabel,
                      supplier.contactPerson,
                    ),
                    const SizedBox(height: 12),
                  ],

                  _buildInfoRow(
                    Icons.phone,
                    localizations.phoneLabel,
                    supplier.phoneNumber,
                    onTap: () => _makePhoneCall(context, supplier.phoneNumber),
                  ),
                  const SizedBox(height: 12),

                  if (supplier.email.isNotEmpty) ...[
                    _buildInfoRow(
                      Icons.email,
                      localizations.emailLabel,
                      supplier.email,
                      onTap: () => _sendEmail(context, supplier.email),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (supplier.address.isNotEmpty) ...[
                    _buildInfoRow(
                      Icons.location_on,
                      localizations.addressLabel,
                      supplier.address,
                      onTap: () => _openMap(context, supplier.address),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Actions de contact direct : Appeler / WhatsApp / Email.
          _buildContactActions(context, supplier),
          const SizedBox(height: 16),

          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.commercialInformationSectionTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  _buildPurchasesRows(context, supplier, localizations),
                  const SizedBox(height: 12),

                  _buildInfoRow(
                    Icons.timer,
                    localizations.deliveryTimeLabel,
                    localizations.deliveryTimeInDays(
                      supplier.deliveryTimeInDays,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (supplier.paymentTerms.isNotEmpty) ...[
                    _buildInfoRow(
                      Icons.payment,
                      localizations.paymentTermsLabel,
                      supplier.paymentTerms,
                    ),
                    const SizedBox(height: 12),
                  ],

                  _buildInfoRow(
                    Icons.access_time,
                    localizations.supplierSinceLabel,
                    _formatDate(supplier.createdAt, context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Dettes fournisseur : aussi sur fenêtre étroite.
          _buildPayablesSection(context, supplier, localizations),
          if (supplier.notes.isNotEmpty) ...[
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.notesSectionTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(supplier.notes),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ResponsiveActionBar : trois boutons libellés ne tenaient pas dans
          // une Row d'Expanded sur une fenêtre étroite (débordement).
          ResponsiveActionBar(
            items: [
              ActionBarItem(
                icon: Icons.shopping_cart,
                label: localizations.placeOrderButtonLabel,
                background: Theme.of(context).colorScheme.primaryContainer,
                foreground: Theme.of(context).colorScheme.onPrimaryContainer,
                onPressed: () => _placeOrder(context, supplier),
              ),
              ActionBarItem(
                icon: Icons.phone,
                label: localizations.callButtonLabel,
                background: Theme.of(context).colorScheme.primaryContainer,
                foreground: Theme.of(context).colorScheme.onPrimaryContainer,
                onPressed: () => _makePhoneCall(context, supplier.phoneNumber),
              ),
              ActionBarItem(
                icon: Icons.delete,
                label: localizations.deleteButtonLabel,
                background: Colors.red.withValues(alpha: 0.1),
                foreground: Colors.red,
                onPressed: () => _confirmDelete(context, supplier),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Total des achats (par devise) et dernier achat, tirés des dépenses du
  /// fournisseur (SupplierPurchases, même calcul que la liste).
  Widget _buildPurchasesRows(
    BuildContext context,
    Supplier supplier,
    AppLocalizations localizations,
  ) {
    return FutureBuilder<SupplierPurchases>(
      future: SupplierPurchases.load(
        context.read<ExpenseRepository>(),
        supplier.id,
      ),
      builder: (context, snapshot) {
        final achats = snapshot.data ?? const SupplierPurchases({}, null);
        final total = achats.totalLabel();
        final dernier = achats.dernierAchat;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              Icons.attach_money,
              localizations.totalPurchasesLabel,
              total,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.calendar_today,
              localizations.lastPurchaseLabel,
              dernier != null
                  ? _formatDate(dernier, context)
                  : localizations.noPurchaseRecorded,
            ),
          ],
        );
      },
    );
  }

  /// Dettes du fournisseur (dépenses non soldées) avec « Régler ».
  /// Chaque dette garde sa devise : les restes sont additionnés par devise,
  /// jamais mélangés. Rechargée à chaque reconstruction de la fiche.
  Widget _buildPayablesSection(
    BuildContext context,
    Supplier supplier,
    AppLocalizations localizations,
  ) {
    return FutureBuilder<List<Expense>>(
      future: context
          .read<ExpenseRepository>()
          .getExpensesBySupplier(supplier.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final unpaid = snapshot.data!
            .where((e) =>
                e.paymentStatus != ExpensePaymentStatus.paid &&
                e.remainingAmount > 0.0001)
            .toList();
        final dueByCurrency = <String, double>{};
        for (final e in unpaid) {
          final code = e.effectiveCurrencyCode;
          dueByCurrency[code] = (dueByCurrency[code] ?? 0) + e.remainingAmount;
        }
        if (dueByCurrency.isEmpty) return const SizedBox.shrink();
        final dueText = dueByCurrency.entries
            .map((entry) => formatCurrency(entry.value, entry.key))
            .join('\n');
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          child: Card(
            elevation: 2,
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.outstandingBalance,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.warning_amber_rounded,
                    localizations.payablesToPay,
                    dueText,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.receipt_long,
                    '',
                    localizations.unpaidExpensesCount(unpaid.length),
                  ),
                  const SizedBox(height: 12),
                  // Wrap : le bouton passe à la ligne au lieu de déborder sur
                  // une fenêtre étroite.
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.payments_outlined, size: 18),
                        label: const Text('Régler'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () =>
                            _settlePayable(context, unpaid, supplier),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Modifier : même porte que la liste (dialogue sur grand écran, page
  /// /suppliers/edit/:id sur fenêtre étroite), puis rechargement de la fiche.
  Future<void> _navigateToEditSupplier(
    BuildContext context,
    Supplier supplier,
  ) async {
    final bloc = context.read<SupplierBloc>();
    await FormNavigationService.instance.openSupplierForm(
      context,
      supplier: supplier,
    );
    bloc.add(LoadSupplier(supplier.id));
  }

  /// « Passer commande » : formulaire de dépense avec ce fournisseur choisi.
  Future<void> _placeOrder(BuildContext context, Supplier supplier) async {
    final bloc = context.read<SupplierBloc>();
    final saved = await FormNavigationService.instance.openExpenseForm(
      context,
      supplier: supplier,
    );
    if (saved == true) bloc.add(LoadSupplier(supplier.id));
  }

  /// Règle une dette fournisseur : choix de la pièce puis dialogue de
  /// paiement (montant, mode, date, référence). On attend la réponse de
  /// l'API avant d'informer l'utilisateur.
  Future<void> _settlePayable(
    BuildContext context,
    List<Expense> unpaidExpenses,
    Supplier supplier,
  ) async {
    final bloc = context.read<SupplierBloc>();
    final expense = await pickExpenseToSettle(context, unpaidExpenses);
    if (expense == null || !context.mounted) return;
    final updated = await startExpensePaymentFlow(context, expense);
    if (updated != null) {
      // Recharge la fiche pour rafraîchir le solde impayé affiché.
      bloc.add(LoadSupplier(supplier.id));
    }
  }

  /// Rangée d'actions de contact direct : Appeler / WhatsApp / Email.
  ///
  /// [ResponsiveActionBar] au lieu d'une `Row` de trois `Expanded` : les
  /// libellés débordaient sur les fenêtres étroites.
  Widget _buildContactActions(BuildContext context, Supplier supplier) {
    return ResponsiveActionBar(
      items: [
        ActionBarItem(
          icon: Icons.phone,
          label: 'Appeler',
          background: Theme.of(context).colorScheme.primaryContainer,
          foreground: Theme.of(context).colorScheme.onPrimaryContainer,
          onPressed: () => _makePhoneCall(context, supplier.phoneNumber),
        ),
        ActionBarItem(
          icon: Icons.chat,
          label: 'WhatsApp',
          background: Theme.of(context).colorScheme.primaryContainer,
          foreground: Theme.of(context).colorScheme.onPrimaryContainer,
          onPressed: () => _contactViaWhatsApp(context, supplier),
        ),
        ActionBarItem(
          icon: Icons.email,
          label: 'Email',
          background: Theme.of(context).colorScheme.primaryContainer,
          foreground: Theme.of(context).colorScheme.onPrimaryContainer,
          onPressed: () => _sendEmail(context, supplier.email),
        ),
      ],
    );
  }

  /// Lance un appel téléphonique réel vers le fournisseur (lien `tel:`).
  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    if (phoneNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun numéro de téléphone disponible.')),
      );
      return;
    }
    final ok = await launchPhoneCall(phoneNumber);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de lancer l\'appel.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Ouvre le client mail réel avec l'adresse du fournisseur pré-remplie.
  Future<void> _sendEmail(BuildContext context, String email) async {
    if (email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune adresse email disponible.')),
      );
      return;
    }
    final ok = await launchEmail(email);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir la messagerie.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Contacte le fournisseur via WhatsApp (repli SMS) sur son numéro enregistré.
  Future<void> _contactViaWhatsApp(
    BuildContext context,
    Supplier supplier,
  ) async {
    if (supplier.phoneNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun numéro de téléphone disponible.')),
      );
      return;
    }
    await launchWhatsAppOrSms(
      context,
      message: 'Bonjour ${supplier.name},',
      phone: supplier.phoneNumber,
    );
  }

  void _openMap(BuildContext context, String address) {
    final localizations = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(localizations.openingMapFor(address)),
      ), // Corrected
    );
  }

  Future<void> _confirmDelete(BuildContext context, Supplier supplier) async {
    final localizations = AppLocalizations.of(context)!;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(localizations.confirmDeleteSupplierTitle),
          content: Text(localizations.confirmDeleteSupplierMessage(supplier.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(localizations.cancelButtonLabel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(localizations.deleteButtonLabel),
            ),
          ],
        );
      },
    );
    if (confirme != true || !context.mounted) return;

    // Le serveur d'abord : la fiche ne se ferme qu'une fois la suppression
    // acceptée. Un fournisseur avec historique est refusé (409), on le dit.
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<SupplierRepository>().deleteSupplier(supplier.id);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!context.mounted) return;
    context.read<SupplierBloc>().add(const LoadSuppliers());
    messenger.showSnackBar(
      const SnackBar(content: Text('Fournisseur supprimé.')),
    );
    context.canPop() ? context.pop() : context.go('/contacts');
  }

  Color _getCategoryColor(SupplierCategory category) {
    switch (category) {
      case SupplierCategory.local:
        return Colors.green;
      case SupplierCategory.international:
        return Colors.blue;
      case SupplierCategory.online:
        return Colors.orange;
      case SupplierCategory.strategic:
        return Colors.purple;
      case SupplierCategory.regular:
        return Colors.teal;
      case SupplierCategory.newSupplier: // Changed from new to newSupplier
        return Colors.pink;
      case SupplierCategory.occasional:
        return Colors.brown;
    }
  }

  String _getCategoryName(BuildContext context, SupplierCategory category) {
    final localizations = AppLocalizations.of(context)!;
    switch (category) {
      case SupplierCategory.local:
        return localizations.supplierCategoryLocal;
      case SupplierCategory.international:
        return localizations.supplierCategoryInternational;
      case SupplierCategory.online:
        return localizations.supplierCategoryOnline;
      case SupplierCategory.strategic:
        return localizations.supplierCategoryStrategic;
      case SupplierCategory.regular:
        return localizations.supplierCategoryRegular;
      case SupplierCategory.newSupplier: // Changed from new to newSupplier
        return localizations.supplierCategoryNew;
      case SupplierCategory.occasional:
        return localizations.supplierCategoryOccasional;
    }
  }

  String _formatDate(DateTime date, BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMd(locale).format(date);
  }
}
