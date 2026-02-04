import 'package:hive/hive.dart';
import '../../features/auth/models/user.dart';
import '../../features/notifications/models/notification_model.dart';
// Import Adha models - adaptateurs générés automatiquement
import '../../features/adha/models/adha_message.dart';
import '../../features/adha/models/adha_stream_models.dart';
import '../../features/adha/models/adha_context_info.dart';
import '../../features/sales/models/sale.dart'; // Corrected: Import main model file
import '../../features/sales/models/sale_item.dart'; // Ensure SaleItemAdapter is available if defined separately or via sale_item.g.dart
import '../../features/financing/models/financing_request.dart'; // Corrected: Import main model file
import '../../features/customer/models/customer.dart'; // Added import for Customer model
import '../../features/supplier/models/supplier.dart'; // Added import for Supplier model
import '../../features/settings/models/settings.dart'; // Added import for Settings model
import '../../features/inventory/models/product.dart';
import '../../features/inventory/models/stock_transaction.dart';
import '../../features/dashboard/models/operation_journal_entry.dart'; // Ajout pour les entrées du journal
import '../../features/expenses/models/expense.dart'; // Ajout pour les modèles de dépenses
import '../enums/business_unit_enums.dart'; // Import Business Unit enums
import '../../features/business_unit/models/business_unit.dart'; // Import Business Unit model
import '../enums/currency_enum.dart'; // Import Currency enum
// Users module imports
import '../enums/user_role.dart'; // Import UserRole enum (typeId 74)
import '../../features/users/models/app_user.dart'; // Import AppUser, UserSettings, NotificationSettings (typeIds 75-77)
// Financial Transactions imports
import '../../features/transactions/models/financial_transaction.dart'; // Import TransactionType, TransactionStatus, PaymentMethod, FinancialTransaction (typeIds 78-81)
// Documents imports
import '../../features/documents/models/document.dart'; // Import Document (typeId 31)

/// Enregistre tous les adaptateurs Hive nécessaires
void registerHiveAdapters() {
  // ============= ENUMS D'ABORD (utilisés par d'autres modèles) =============

  // Business Unit enums - DOIT ÊTRE ENREGISTRÉ EN PREMIER (utilisé par Settings, Customer, Supplier, Product, etc.)
  if (!Hive.isAdapterRegistered(71)) {
    // typeId 71 pour BusinessUnitType
    Hive.registerAdapter(BusinessUnitTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(72)) {
    // typeId 72 pour BusinessUnitStatus
    Hive.registerAdapter(BusinessUnitStatusAdapter());
  }

  // Currency enum
  if (!Hive.isAdapterRegistered(CurrencyAdapter().typeId)) {
    // typeId 70 pour Currency
    Hive.registerAdapter(CurrencyAdapter());
  }

  // UserRole enum
  if (!Hive.isAdapterRegistered(74)) {
    // typeId 74 pour UserRole
    Hive.registerAdapter(UserRoleAdapter());
  }

  // ============= USER MODELS =============

  // User models
  if (!Hive.isAdapterRegistered(UserAdapter().typeId)) {
    // Use .typeId for consistency
    Hive.registerAdapter(UserAdapter());
  }
  if (!Hive.isAdapterRegistered(IdStatusAdapter().typeId)) {
    // Use .typeId
    Hive.registerAdapter(IdStatusAdapter());
  }

  // Sale models
  // Assuming SaleAdapter and SaleStatusAdapter are generated in sale.g.dart and accessible via sale.dart
  // The typeId for Sale is 7 as per sale.dart
  // The typeId for SaleStatus is 6 as per sale.dart
  if (!Hive.isAdapterRegistered(7)) {
    // typeId for Sale from sale.dart
    Hive.registerAdapter(
      SaleAdapter(),
    ); // This should now refer to the generated adapter
  }
  if (!Hive.isAdapterRegistered(2)) {
    // typeId for SaleItem (assuming it's 2 from sale_item.dart or its .g.dart file)
    Hive.registerAdapter(SaleItemAdapter());
  }

  // Customer models
  if (!Hive.isAdapterRegistered(CustomerAdapter().typeId)) {
    // Use .typeId
    Hive.registerAdapter(CustomerAdapter());
  }
  if (!Hive.isAdapterRegistered(CustomerCategoryAdapter().typeId)) {
    // Use .typeId
    Hive.registerAdapter(CustomerCategoryAdapter());
  }

  // SaleStatus is typeId 6 from sale.dart
  if (!Hive.isAdapterRegistered(6)) {
    // typeId for SaleStatus from sale.dart
    Hive.registerAdapter(
      SaleStatusAdapter(),
    ); // This should now refer to the generated adapter
  }

  // Financing models - Adjusted TypeIDs
  if (!Hive.isAdapterRegistered(FinancingRequestAdapter().typeId)) {
    // Use .typeId
    Hive.registerAdapter(FinancingRequestAdapter());
  }
  if (!Hive.isAdapterRegistered(FinancingTypeAdapter().typeId)) {
    // Use .typeId
    Hive.registerAdapter(FinancingTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(FinancialInstitutionAdapter().typeId)) {
    // Use .typeId
    Hive.registerAdapter(FinancialInstitutionAdapter());
  }

  // Notification models - Adjusted TypeIDs
  if (!Hive.isAdapterRegistered(NotificationModelAdapter().typeId)) {
    // Use .typeId
    Hive.registerAdapter(NotificationModelAdapter());
  }

  if (!Hive.isAdapterRegistered(NotificationTypeAdapter().typeId)) {
    // Use .typeId
    Hive.registerAdapter(NotificationTypeAdapter());
  }

  // ============= ADHA MODELS (typeIds 100-113) =============
  // AdhaMessage models (typeIds 100-103)
  if (!Hive.isAdapterRegistered(AdhaMessageAdapter().typeId)) {
    Hive.registerAdapter(AdhaMessageAdapter());
  }
  if (!Hive.isAdapterRegistered(AdhaMessageTypeAdapter().typeId)) {
    Hive.registerAdapter(AdhaMessageTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(AdhaConversationAdapter().typeId)) {
    Hive.registerAdapter(AdhaConversationAdapter());
  }
  if (!Hive.isAdapterRegistered(AdhaMessageSenderAdapter().typeId)) {
    Hive.registerAdapter(AdhaMessageSenderAdapter());
  }

  // AdhaStreamModels (typeIds 104-106)
  if (!Hive.isAdapterRegistered(AdhaStreamTypeAdapter().typeId)) {
    Hive.registerAdapter(AdhaStreamTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(AdhaStreamMetadataAdapter().typeId)) {
    Hive.registerAdapter(AdhaStreamMetadataAdapter());
  }
  if (!Hive.isAdapterRegistered(AdhaStreamChunkEventAdapter().typeId)) {
    Hive.registerAdapter(AdhaStreamChunkEventAdapter());
  }

  // AdhaContextInfo models (typeIds 107-113)
  if (!Hive.isAdapterRegistered(AdhaInteractionTypeAdapter().typeId)) {
    Hive.registerAdapter(AdhaInteractionTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(AdhaOperationJournalEntryAdapter().typeId)) {
    Hive.registerAdapter(AdhaOperationJournalEntryAdapter());
  }
  if (!Hive.isAdapterRegistered(AdhaBusinessProfileAdapter().typeId)) {
    Hive.registerAdapter(AdhaBusinessProfileAdapter());
  }
  if (!Hive.isAdapterRegistered(AdhaOperationJournalSummaryAdapter().typeId)) {
    Hive.registerAdapter(AdhaOperationJournalSummaryAdapter());
  }
  if (!Hive.isAdapterRegistered(AdhaBaseContextAdapter().typeId)) {
    Hive.registerAdapter(AdhaBaseContextAdapter());
  }
  if (!Hive.isAdapterRegistered(AdhaInteractionContextAdapter().typeId)) {
    Hive.registerAdapter(AdhaInteractionContextAdapter());
  }
  if (!Hive.isAdapterRegistered(AdhaContextInfoAdapter().typeId)) {
    Hive.registerAdapter(AdhaContextInfoAdapter());
  }

  // Supplier models
  if (!Hive.isAdapterRegistered(SupplierAdapter().typeId)) {
    // Use .typeId
    Hive.registerAdapter(SupplierAdapter());
  }
  if (!Hive.isAdapterRegistered(SupplierCategoryAdapter().typeId)) {
    // Use .typeId
    Hive.registerAdapter(SupplierCategoryAdapter());
  }

  // Settings models
  if (!Hive.isAdapterRegistered(SettingsAdapter().typeId)) {
    // Use .typeId
    Hive.registerAdapter(SettingsAdapter());
  }
  if (!Hive.isAdapterRegistered(AppThemeModeAdapter().typeId)) {
    // Use .typeId
    Hive.registerAdapter(AppThemeModeAdapter());
  }

  // Inventory models
  if (!Hive.isAdapterRegistered(ProductCategoryAdapter().typeId)) {
    // Use .typeId
    Hive.registerAdapter(ProductCategoryAdapter());
  }
  if (!Hive.isAdapterRegistered(ProductUnitAdapter().typeId)) {
    // Use .typeId
    Hive.registerAdapter(ProductUnitAdapter());
  }
  if (!Hive.isAdapterRegistered(ProductAdapter().typeId)) {
    // Use .typeId
    Hive.registerAdapter(ProductAdapter());
  }
  if (!Hive.isAdapterRegistered(StockTransactionTypeAdapter().typeId)) {
    // Use .typeId
    Hive.registerAdapter(StockTransactionTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(StockTransactionAdapter().typeId)) {
    // Use .typeId
    Hive.registerAdapter(StockTransactionAdapter());
  }

  // Journal operation models
  if (!Hive.isAdapterRegistered(200)) {
    // typeId 200 pour OperationType
    Hive.registerAdapter(OperationTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(201)) {
    // typeId 201 pour OperationJournalEntry
    Hive.registerAdapter(OperationJournalEntryAdapter());
  }

  // Expense models
  if (!Hive.isAdapterRegistered(ExpensePaymentStatusAdapter().typeId)) {
    // typeId 203 pour ExpensePaymentStatus
    Hive.registerAdapter(ExpensePaymentStatusAdapter());
  }
  if (!Hive.isAdapterRegistered(ExpenseAdapter().typeId)) {
    // typeId 11 pour Expense
    Hive.registerAdapter(ExpenseAdapter());
  }
  if (!Hive.isAdapterRegistered(ExpenseCategoryAdapter().typeId)) {
    // ExpenseCategory enum
    Hive.registerAdapter(ExpenseCategoryAdapter());
  }

  // Business Unit model (le type enum est déjà enregistré au début)
  if (!Hive.isAdapterRegistered(73)) {
    // typeId 73 pour BusinessUnit
    Hive.registerAdapter(BusinessUnitAdapter());
  }

  // Users module adapters (typeIds 75-77) - UserRole (74) est déjà enregistré au début
  if (!Hive.isAdapterRegistered(75)) {
    // typeId 75 pour AppUser
    Hive.registerAdapter(AppUserAdapter());
  }
  if (!Hive.isAdapterRegistered(76)) {
    // typeId 76 pour UserSettings
    Hive.registerAdapter(UserSettingsAdapter());
  }
  if (!Hive.isAdapterRegistered(77)) {
    // typeId 77 pour NotificationSettings
    Hive.registerAdapter(NotificationSettingsAdapter());
  }

  // Financial Transaction adapters (typeIds 78-81)
  if (!Hive.isAdapterRegistered(78)) {
    // typeId 78 pour TransactionType
    Hive.registerAdapter(TransactionTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(79)) {
    // typeId 79 pour TransactionStatus
    Hive.registerAdapter(TransactionStatusAdapter());
  }
  if (!Hive.isAdapterRegistered(80)) {
    // typeId 80 pour PaymentMethod
    Hive.registerAdapter(PaymentMethodAdapter());
  }
  if (!Hive.isAdapterRegistered(81)) {
    // typeId 81 pour FinancialTransaction
    Hive.registerAdapter(FinancialTransactionAdapter());
  }

  // Document models
  if (!Hive.isAdapterRegistered(31)) {
    // typeId 31 pour Document
    Hive.registerAdapter(DocumentAdapter());
  }

  // Add other adapters here
}
