import 'package:equatable/equatable.dart';
import '../models/customer.dart';

/// États pour le bloc Customer
abstract class CustomerState extends Equatable {
  const CustomerState();

  @override
  List<Object?> get props => [];
}

/// État initial du bloc Customer
class CustomerInitial extends CustomerState {
  const CustomerInitial();
}

/// Chargement en cours
class CustomerLoading extends CustomerState {
  const CustomerLoading();
}

/// Chargement des clients réussi
class CustomersLoaded extends CustomerState {
  /// Liste des clients chargés
  final List<Customer> customers;

  const CustomersLoaded(this.customers);

  @override
  List<Object?> get props => [customers];
}

/// Chargement d'un client spécifique réussi
class CustomerLoaded extends CustomerState {
  /// Client chargé
  final Customer customer;

  const CustomerLoaded(this.customer);

  @override
  List<Object?> get props => [customer];
}

/// Opération sur un client réussie (création, mise à jour, suppression)
class CustomerOperationSuccess extends CustomerState {
  /// Message de succès
  final String message;
  
  /// Client concerné par l'opération (peut être null pour une suppression)
  final Customer? customer;

  const CustomerOperationSuccess({
    required this.message,
    this.customer,
  });

  @override
  List<Object?> get props => [message, customer];
}

/// Erreur lors d'une opération sur un client
class CustomerError extends CustomerState {
  /// Message d'erreur
  final String message;

  const CustomerError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Résultats de recherche de clients
class CustomerSearchResults extends CustomerState {
  /// Liste des clients correspondant à la recherche
  final List<Customer> customers;
  
  /// Terme de recherche utilisé
  final String searchTerm;

  const CustomerSearchResults({
    required this.customers,
    required this.searchTerm,
  });

  @override
  List<Object?> get props => [customers, searchTerm];
}

/// Chargement des meilleurs clients réussi
class TopCustomersLoaded extends CustomerState {
  /// Liste des meilleurs clients
  final List<Customer> customers;

  const TopCustomersLoaded(this.customers);

  @override
  List<Object?> get props => [customers];
}

/// Chargement des clients récents réussi
class RecentCustomersLoaded extends CustomerState {
  /// Liste des clients récents
  final List<Customer> customers;

  const RecentCustomersLoaded(this.customers);

  @override
  List<Object?> get props => [customers];
}
