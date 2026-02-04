import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/customer_repository.dart';
import 'customer_event.dart';
import 'customer_state.dart';

/// BLoC pour gérer les opérations sur les clients
class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  /// Repository pour accéder aux données des clients
  final CustomerRepository customerRepository;

  CustomerBloc({required this.customerRepository})
    : super(const CustomerInitial()) {
    on<LoadCustomers>(_onLoadCustomers);
    on<LoadCustomer>(_onLoadCustomer);
    on<AddCustomer>(_onAddCustomer);
    on<UpdateCustomer>(_onUpdateCustomer);
    on<DeleteCustomer>(_onDeleteCustomer);
    on<SearchCustomers>(_onSearchCustomers);
    on<LoadTopCustomers>(_onLoadTopCustomers);
    on<LoadRecentCustomers>(_onLoadRecentCustomers);
    on<UpdateCustomerPurchaseTotal>(_onUpdateCustomerPurchaseTotal);
  }

  /// Gère le chargement de tous les clients
  Future<void> _onLoadCustomers(
    LoadCustomers event,
    Emitter<CustomerState> emit,
  ) async {
    emit(const CustomerLoading());

    try {
      final customers = await customerRepository.getCustomers();
      emit(CustomersLoaded(customers));
    } catch (e) {
      emit(CustomerError('Erreur lors du chargement des clients: $e'));
    }
  }

  /// Gère le chargement d'un client spécifique
  Future<void> _onLoadCustomer(
    LoadCustomer event,
    Emitter<CustomerState> emit,
  ) async {
    emit(const CustomerLoading());

    try {
      final customer = await customerRepository.getCustomer(event.customerId);
      if (customer != null) {
        emit(CustomerLoaded(customer));
      } else {
        emit(const CustomerError('Client non trouvé'));
      }
    } catch (e) {
      emit(CustomerError('Erreur lors du chargement du client: $e'));
    }
  }

  /// Gère l'ajout d'un nouveau client
  Future<void> _onAddCustomer(
    AddCustomer event,
    Emitter<CustomerState> emit,
  ) async {
    emit(const CustomerLoading());

    try {
      final newCustomer = await customerRepository.addCustomer(event.customer);
      emit(
        CustomerOperationSuccess(
          message: 'Client ajouté avec succès',
          customer: newCustomer,
        ),
      );

      // Recharge la liste des clients après ajout
      add(const LoadCustomers());
    } catch (e) {
      emit(CustomerError('Erreur lors de l\'ajout du client: $e'));
    }
  }

  /// Gère la mise à jour d'un client existant
  Future<void> _onUpdateCustomer(
    UpdateCustomer event,
    Emitter<CustomerState> emit,
  ) async {
    emit(const CustomerLoading());

    try {
      final updatedCustomer = await customerRepository.updateCustomer(
        event.customer,
      );
      emit(
        CustomerOperationSuccess(
          message: 'Client mis à jour avec succès',
          customer: updatedCustomer,
        ),
      );

      // Recharge la liste des clients après mise à jour
      add(const LoadCustomers());
    } catch (e) {
      emit(CustomerError('Erreur lors de la mise à jour du client: $e'));
    }
  }

  /// Gère la suppression d'un client
  Future<void> _onDeleteCustomer(
    DeleteCustomer event,
    Emitter<CustomerState> emit,
  ) async {
    emit(const CustomerLoading());

    try {
      await customerRepository.deleteCustomer(event.customerId);
      emit(
        const CustomerOperationSuccess(message: 'Client supprimé avec succès'),
      );

      // Recharge la liste des clients après suppression
      add(const LoadCustomers());
    } catch (e) {
      emit(CustomerError('Erreur lors de la suppression du client: $e'));
    }
  }

  /// Gère la recherche de clients
  Future<void> _onSearchCustomers(
    SearchCustomers event,
    Emitter<CustomerState> emit,
  ) async {
    emit(const CustomerLoading());

    try {
      if (event.searchTerm.isEmpty) {
        final allCustomers = await customerRepository.getCustomers();
        emit(CustomersLoaded(allCustomers));
      } else {
        final searchResults = await customerRepository.searchCustomers(
          event.searchTerm,
        );
        emit(
          CustomerSearchResults(
            customers: searchResults,
            searchTerm: event.searchTerm,
          ),
        );
      }
    } catch (e) {
      emit(CustomerError('Erreur lors de la recherche de clients: $e'));
    }
  }

  /// Gère le chargement des meilleurs clients
  Future<void> _onLoadTopCustomers(
    LoadTopCustomers event,
    Emitter<CustomerState> emit,
  ) async {
    emit(const CustomerLoading());

    try {
      final topCustomers = await customerRepository.getTopCustomers(
        limit: event.limit,
      );
      emit(TopCustomersLoaded(topCustomers));
    } catch (e) {
      emit(
        CustomerError('Erreur lors du chargement des meilleurs clients: $e'),
      );
    }
  }

  /// Gère le chargement des clients récents
  Future<void> _onLoadRecentCustomers(
    LoadRecentCustomers event,
    Emitter<CustomerState> emit,
  ) async {
    emit(const CustomerLoading());

    try {
      final recentCustomers = await customerRepository.getRecentCustomers(
        limit: event.limit,
      );
      emit(RecentCustomersLoaded(recentCustomers));
    } catch (e) {
      emit(CustomerError('Erreur lors du chargement des clients récents: $e'));
    }
  }

  /// Gère la mise à jour du total des achats d'un client
  Future<void> _onUpdateCustomerPurchaseTotal(
    UpdateCustomerPurchaseTotal event,
    Emitter<CustomerState> emit,
  ) async {
    emit(const CustomerLoading());

    try {
      final updatedCustomer = await customerRepository
          .updateCustomerPurchaseTotal(event.customerId, event.amount);

      emit(
        CustomerOperationSuccess(
          message: 'Total des achats mis à jour avec succès',
          customer: updatedCustomer,
        ),
      );
    } catch (e) {
      emit(
        CustomerError('Erreur lors de la mise à jour du total des achats: $e'),
      );
    }
  }
}
