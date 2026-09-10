import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/services/form_navigation_service.dart';
import 'package:wanzo/core/platform/platform_service.dart';
import 'package:wanzo/features/customer/bloc/customer_bloc.dart';
import 'package:wanzo/features/customer/bloc/customer_event.dart';
import 'package:wanzo/features/customer/screens/customers_screen.dart';
import 'package:wanzo/features/supplier/bloc/supplier_bloc.dart';
import 'package:wanzo/features/supplier/bloc/supplier_event.dart';
import 'package:wanzo/features/supplier/screens/suppliers_screen.dart';
import 'package:wanzo/l10n/app_localizations.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  VoidCallback? _tabListener;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    context.read<CustomerBloc>().add(const LoadCustomers());
    context.read<SupplierBloc>().add(const LoadSuppliers());

    _tabListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    _tabController.addListener(_tabListener!);
  }

  @override
  void dispose() {
    if (_tabListener != null) {
      _tabController.removeListener(_tabListener!);
    }
    _tabController.dispose();
    super.dispose();
  }

  /// Ouvre le formulaire de création selon l'onglet actif (client / fournisseur).
  void _openCreateForm() {
    if (_tabController.index == 0) {
      FormNavigationService.instance.openCustomerForm(
        context,
        onSuccess: () {
          if (mounted) {
            context.read<CustomerBloc>().add(const LoadCustomers());
          }
        },
      );
    } else {
      FormNavigationService.instance.openSupplierForm(
        context,
        onSuccess: () {
          if (mounted) {
            context.read<SupplierBloc>().add(const LoadSuppliers());
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const int contactsPageIndex = 3;
    final localizations = AppLocalizations.of(context)!;

    // Sur desktop/tablette la barre latérale est affichée : la création passe
    // par un bouton de barre d'outils. Le FAB reste réservé au mobile étroit.
    final bool isNarrow =
        MediaQuery.sizeOf(context).width <
        PlatformService.instance.tabletMinWidth;
    final String createLabel =
        _tabController.index == 0
            ? localizations.contactsScreenAddClientTooltip
            : localizations.contactsScreenAddSupplierTooltip;

    return WanzoScaffold(
      currentIndex: contactsPageIndex,
      title: localizations.contactsScreenTitle,
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.request_quote_outlined),
          tooltip: 'Créances clients',
          onPressed: () => context.push('/receivables'),
        ),
      ],
      body: Column(
        children: [
          if (!isNarrow)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: _openCreateForm,
                    icon: const Icon(Icons.add),
                    label: Text(createLabel),
                  ),
                ],
              ),
            ),
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: localizations.contactsScreenClientsTab),
              Tab(text: localizations.contactsScreenSuppliersTab),
            ],
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                CustomersScreen(isEmbedded: true),
                SuppliersScreen(isEmbedded: true),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton:
          isNarrow
              ? FloatingActionButton(
                onPressed: _openCreateForm,
                tooltip: createLabel,
                child: const Icon(Icons.add),
              )
              : null,
    );
  }
}
