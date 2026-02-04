import 'package:wanzo/features/customer/models/customer.dart';

/// Cette classe n'est plus nécessaire car le modèle Customer a été unifié.
/// Elle est conservée pour compatibilité temporaire mais devrait être supprimée.
@Deprecated('Cette classe n\'est plus nécessaire car le modèle Customer a été unifié')
class CustomerAdapter {
  /// Cette méthode n'est plus nécessaire car le modèle Customer a été unifié.
  @Deprecated('Cette méthode n\'est plus nécessaire')
  static Customer toCustomersModel(Customer model) {
    return model;
  }

  /// Cette méthode n'est plus nécessaire car le modèle Customer a été unifié.
  @Deprecated('Cette méthode n\'est plus nécessaire')
  static Customer toCustomerModel(Customer model) {
    return model;
  }

  /// Cette méthode n'est plus nécessaire car le modèle Customer a été unifié.
  @Deprecated('Cette méthode n\'est plus nécessaire')
  static List<Customer> toCustomersList(List<Customer> models) {
    return models;
  }

  /// Cette méthode n'est plus nécessaire car le modèle Customer a été unifié.
  @Deprecated('Cette méthode n\'est plus nécessaire')
  static List<Customer> toCustomerList(List<Customer> models) {
    return models;
  }
}
