import 'package:equatable/equatable.dart';
import '../models/customer.dart';

/// Événements pour le bloc Customer
abstract class CustomerEvent extends Equatable {
  const CustomerEvent();

  @override
  List<Object?> get props => [];
}

/// Chargement de tous les clients
class LoadCustomers extends CustomerEvent {
  const LoadCustomers();
}

/// Chargement d'un client spécifique
class LoadCustomer extends CustomerEvent {
  /// ID du client à charger
  final String customerId;

  const LoadCustomer(this.customerId);

  @override
  List<Object?> get props => [customerId];
}

/// Ajout d'un nouveau client
class AddCustomer extends CustomerEvent {
  /// Client à ajouter
  final Customer customer;

  const AddCustomer(this.customer);

  @override
  List<Object?> get props => [customer];
}

/// Mise à jour d'un client existant
class UpdateCustomer extends CustomerEvent {
  /// Client mis à jour
  final Customer customer;

  const UpdateCustomer(this.customer);

  @override
  List<Object?> get props => [customer];
}

/// Suppression d'un client
class DeleteCustomer extends CustomerEvent {
  /// ID du client à supprimer
  final String customerId;

  const DeleteCustomer(this.customerId);

  @override
  List<Object?> get props => [customerId];
}

/// Recherche de clients
class SearchCustomers extends CustomerEvent {
  /// Terme de recherche
  final String searchTerm;

  const SearchCustomers(this.searchTerm);

  @override
  List<Object?> get props => [searchTerm];
}

/// Chargement des meilleurs clients
class LoadTopCustomers extends CustomerEvent {
  /// Nombre de clients à charger
  final int limit;

  const LoadTopCustomers({this.limit = 5});

  @override
  List<Object?> get props => [limit];
}

/// Chargement des clients récents
class LoadRecentCustomers extends CustomerEvent {
  /// Nombre de clients à charger
  final int limit;

  const LoadRecentCustomers({this.limit = 5});

  @override
  List<Object?> get props => [limit];
}

/// Mise à jour du total des achats d'un client
class UpdateCustomerPurchaseTotal extends CustomerEvent {
  /// ID du client
  final String customerId;
  
  /// Montant à ajouter au total
  final double amount;

  const UpdateCustomerPurchaseTotal({
    required this.customerId,
    required this.amount,
  });

  @override
  List<Object?> get props => [customerId, amount];
}
