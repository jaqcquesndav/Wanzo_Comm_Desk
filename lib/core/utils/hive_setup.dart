import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart'; // Ajout pour debugPrint

// Auth models
import '../../features/auth/models/user.dart';
import '../../features/auth/models/business_sector.dart' as auth_bs;

// Customer models
import '../../features/customer/models/customer.dart'
    as customer_model; // Standardized import

// Inventory models
import '../../features/inventory/models/product.dart' as inventory_product;
import '../../features/inventory/models/stock_transaction.dart'
    as stock_tx_model;

// Sales models
import '../../features/sales/models/sale.dart';
import '../../features/sales/models/sale_item.dart'
    as sale_item_model; // Alias for SaleItemAdapter
import '../../features/sales/models/payment_method.dart';

// Supplier models
import '../../features/supplier/models/supplier.dart';

// Settings models
import '../../features/settings/models/settings.dart';
import '../../features/settings/models/financial_account.dart';
import '../enums/currency_enum.dart'; // Import for CurrencyAdapter

// Notifications models
import '../../features/notifications/models/notification_model.dart';

// Financing models
import '../../features/financing/models/financing_request.dart'
    as financing_model;

// Documents models
import '../../features/documents/models/document.dart' as document_model;

// Adha models
import '../../features/adha/models/adha_adapters.dart' as adha_adapters;

// Expense models
import '../../features/expenses/models/expense.dart'; // Added for Expense and ExpenseCategory

// Journal des opérations models
import '../../features/dashboard/models/operation_journal_entry.dart'; // Added for journal operations

// Business Unit enums - DOIT ÊTRE IMPORTÉ pour que les adapters soient disponibles
import '../enums/business_unit_enums.dart'; // BusinessUnitType (71), BusinessUnitStatus (72)

// Users module imports
import '../enums/user_role.dart'; // UserRole (74)
import '../../features/users/models/app_user.dart'; // AppUser (75), UserSettings (76), NotificationSettings (77)

// Business Unit model
import '../../features/business_unit/models/business_unit.dart'; // BusinessUnit (73)

void _registerAdapterIfNotExists<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter(adapter);
  }
}

Future<void> initializeHiveAdapters() async {
  // ============= ENUMS D'ABORD (utilisés par d'autres modèles) =============

  // Business Unit enums - DOIT ÊTRE ENREGISTRÉ EN PREMIER (utilisé par Settings, Customer, Supplier, Product, etc.)
  _registerAdapterIfNotExists(BusinessUnitTypeAdapter()); // typeId 71
  _registerAdapterIfNotExists(BusinessUnitStatusAdapter()); // typeId 72

  // UserRole enum - DOIT ÊTRE ENREGISTRÉ AVANT AppUser
  _registerAdapterIfNotExists(UserRoleAdapter()); // typeId 74

  // ============= AUTRES ENUMS =============

  // Register Adapters using the helper to avoid re-registration errors
  _registerAdapterIfNotExists(UserAdapter());
  _registerAdapterIfNotExists(IdStatusAdapter());
  _registerAdapterIfNotExists(auth_bs.BusinessSectorAdapter());

  // Customers - Standardized to use customer_model from features/customer/models/
  _registerAdapterIfNotExists(customer_model.CustomerAdapter());
  _registerAdapterIfNotExists(customer_model.CustomerCategoryAdapter());
  // Inventory
  _registerAdapterIfNotExists(inventory_product.ProductAdapter());
  _registerAdapterIfNotExists(inventory_product.ProductCategoryAdapter());
  _registerAdapterIfNotExists(inventory_product.ProductUnitAdapter());
  _registerAdapterIfNotExists(stock_tx_model.StockTransactionAdapter());
  _registerAdapterIfNotExists(stock_tx_model.StockTransactionTypeAdapter());

  // Sales
  _registerAdapterIfNotExists(SaleAdapter());
  _registerAdapterIfNotExists(
    sale_item_model.SaleItemAdapter(),
  ); // Use aliased import
  _registerAdapterIfNotExists(sale_item_model.SaleItemTypeAdapter()); // Added
  _registerAdapterIfNotExists(SaleStatusAdapter());
  _registerAdapterIfNotExists(PaymentMethodAdapter());

  // Supplier
  _registerAdapterIfNotExists(SupplierAdapter());
  _registerAdapterIfNotExists(SupplierCategoryAdapter());

  // Settings
  _registerAdapterIfNotExists(SettingsAdapter());
  _registerAdapterIfNotExists(AppThemeModeAdapter());
  _registerAdapterIfNotExists(
    CurrencyAdapter(),
  ); // Changed from CurrencyTypeAdapter

  // Notifications
  _registerAdapterIfNotExists(NotificationModelAdapter());
  _registerAdapterIfNotExists(NotificationTypeAdapter());

  // Financing
  _registerAdapterIfNotExists(financing_model.FinancingRequestAdapter());
  _registerAdapterIfNotExists(financing_model.FinancingTypeAdapter());
  _registerAdapterIfNotExists(financing_model.FinancialInstitutionAdapter());
  _registerAdapterIfNotExists(financing_model.FinancialProductAdapter());

  // Documents
  _registerAdapterIfNotExists(document_model.DocumentAdapter());

  // Adha
  _registerAdapterIfNotExists(adha_adapters.AdhaMessageAdapter());
  _registerAdapterIfNotExists(adha_adapters.AdhaConversationAdapter());

  // Register Expense adapters - Enum first, then class that uses it
  try {
    // Vérifions explicitement si l'adaptateur est déjà enregistré
    if (!Hive.isAdapterRegistered(202)) {
      // 202 est le typeId pour ExpenseCategoryAdapter (changé de 9 pour éviter les conflits)
      Hive.registerAdapter(ExpenseCategoryAdapter());
      debugPrint(
        "✅ ExpenseCategoryAdapter enregistré avec succès avec typeId 202",
      );
    } else {
      debugPrint("ℹ️ ExpenseCategoryAdapter déjà enregistré avec typeId 202");
    }

    // Enregistrons ExpensePaymentStatusAdapter (enum doit être enregistré avant la classe)
    if (!Hive.isAdapterRegistered(203)) {
      // 203 est le typeId pour ExpensePaymentStatusAdapter
      Hive.registerAdapter(ExpensePaymentStatusAdapter());
      debugPrint(
        "✅ ExpensePaymentStatusAdapter enregistré avec succès avec typeId 203",
      );
    } else {
      debugPrint(
        "ℹ️ ExpensePaymentStatusAdapter déjà enregistré avec typeId 203",
      );
    }

    // Ensuite, enregistrons l'adaptateur Expense
    if (!Hive.isAdapterRegistered(11)) {
      // 11 est le typeId pour ExpenseAdapter
      Hive.registerAdapter(ExpenseAdapter());
      debugPrint("✅ ExpenseAdapter enregistré avec succès avec typeId 11");
    } else {
      debugPrint("ℹ️ ExpenseAdapter déjà enregistré avec typeId 11");
    }
  } catch (e) {
    debugPrint("❌ ERREUR lors de l'enregistrement des adaptateurs Expense: $e");
  }

  // Register Operation Journal adapters - Enum first, then class that uses it
  _registerAdapterIfNotExists(OperationTypeAdapter()); // Register enum first
  _registerAdapterIfNotExists(
    OperationJournalEntryAdapter(),
  ); // Register class that uses the enum second

  // Register Financial Account adapters - Enums first
  _registerAdapterIfNotExists(FinancialAccountTypeAdapter());
  _registerAdapterIfNotExists(MobileMoneyProviderAdapter());
  _registerAdapterIfNotExists(FinancialAccountAdapter());

  // ============= BUSINESS UNIT & USERS MODELS =============

  // Business Unit model (utilise BusinessUnitType et BusinessUnitStatus déjà enregistrés)
  _registerAdapterIfNotExists(BusinessUnitAdapter()); // typeId 73

  // Users module models
  _registerAdapterIfNotExists(AppUserAdapter()); // typeId 75
  _registerAdapterIfNotExists(UserSettingsAdapter()); // typeId 76
  _registerAdapterIfNotExists(NotificationSettingsAdapter()); // typeId 77
}

// Helper function to open all necessary boxes
Future<void> openHiveBoxes() async {
  await Hive.openBox<User>('userBox');
  await Hive.openBox<auth_bs.BusinessSector>('authBusinessSectorsBox');
  await Hive.openBox<customer_model.Customer>(
    'customersBox',
  ); // Use customer_model.Customer
  // Ensure the correct Product type is used for 'productsBox' or use separate boxes.
  // For now, assuming 'productsBox' is for inventory_product.Product based on previous context.
  await Hive.openBox<inventory_product.Product>('productsBox');
  await Hive.openBox<stock_tx_model.StockTransaction>(
    'stock_transactions',
  ); // Added for InventoryRepository
  await Hive.openBox<Sale>('salesBox');
  await Hive.openBox<Supplier>('suppliersBox');
  await Hive.openBox<Settings>('settingsBox');
  await Hive.openBox<FinancialAccount>('financial_accounts');
  await Hive.openBox<NotificationModel>('notificationsBox');
  await Hive.openBox<String>('syncStatusBox');
  await Hive.openBox<Expense>('expenses'); // Added to open the expenses box
  await Hive.openBox<financing_model.FinancingRequest>(
    'financingRequestsBox',
  ); // Activé pour persister les demandes de financement
  await Hive.openBox<OperationJournalEntry>(
    'operation_journal_entries',
  ); // Ajouté pour persister le journal des opérations
  // Add other boxes if they were in main.dart and are not covered:
  // e.g. await Hive.openBox<global_product.Product>('globalProductsBox'); if needed
  // await Hive.openBox<document_model.Document>('documentsBox'); // Example if needed
  // await Hive.openBox<adha_adapters.AdhaConversation>('adhaConversationsBox'); // Example if needed
}
