import 'dart:convert'; // Added for jsonEncode/jsonDecode
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/expenses/models/expense.dart';
import 'package:wanzo/features/sales/models/sale_item.dart'; // Added import
// Import other necessary models if they have specific fields to store

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('wanzo_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE local_sales (
  id TEXT PRIMARY KEY,
  local_id TEXT UNIQUE NOT NULL, -- To distinguish from server ID if different
  customer_id TEXT,
  customer_name TEXT NOT NULL,
  date TEXT NOT NULL,
  due_date TEXT,
  total_amount_cdf REAL NOT NULL,
  total_amount_usd REAL,
  amount_paid_cdf REAL NOT NULL,
  amount_paid_usd REAL,
  payment_method TEXT,
  status TEXT NOT NULL,
  invoice_number TEXT,
  notes TEXT,
  user_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  sync_status TEXT NOT NULL, -- 'pending', 'synced', 'failed'
  last_sync_attempt TEXT,
  error_message TEXT,
  -- Add other sale fields as necessary
  -- For sale items, consider a separate table or JSON encoding if simple
  sale_items_json TEXT 
)
''');

    await db.execute('''
CREATE TABLE local_expenses (
  id TEXT PRIMARY KEY,
  local_id TEXT UNIQUE NOT NULL,
  motif TEXT NOT NULL,
  amount REAL NOT NULL,
  date TEXT NOT NULL,
  category_id TEXT,
  category_name TEXT, -- Denormalized for easier display offline
  payment_method TEXT,
  beneficiary TEXT,
  notes TEXT,
  user_id TEXT,
  supplier_id TEXT, -- Added supplier_id
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  attachments_json TEXT, -- Store list of local file paths or Cloudinary URLs if synced
  sync_status TEXT NOT NULL, -- 'pending', 'synced', 'failed'
  last_sync_attempt TEXT,
  error_message TEXT
  -- Add other expense fields as necessary
)
''');
  }

  // --- Sales Methods ---
  Future<int> createLocalSale(Sale sale, {String? localIdOverride}) async {
    final db = await instance.database;
    final localId = localIdOverride ?? Uuid().v4();
    
    final saleItemsJson = sale.items.isNotEmpty 
        ? jsonEncode(sale.items.map((item) => item.toJson()).toList())
        : null;

    final Map<String, dynamic> row = {
      'id': sale.id.isEmpty ? localId : sale.id, 
      'local_id': localId,
      'customer_id': sale.customerId,
      'customer_name': sale.customerName,
      'date': sale.date.toIso8601String(),
      'due_date': sale.dueDate?.toIso8601String(),
      'total_amount_cdf': sale.totalAmountInCdf,
      'total_amount_usd': sale.totalAmountInUsd,
      'amount_paid_cdf': sale.paidAmountInCdf, // Assuming this field exists on Sale model
      'amount_paid_usd': sale.paidAmountInUsd, // Assuming this field exists on Sale model
      'payment_method': sale.paymentMethod,
      'status': sale.status.toString().split('.').last,
      'invoice_number': sale.invoiceNumber,
      'notes': sale.notes,
      'user_id': sale.userId,
      'created_at': sale.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': sale.updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'sync_status': 'pending', // Default sync status
      'sale_items_json': saleItemsJson,
      'last_sync_attempt': null, // Initially null
      'error_message': null, // Initially null
    };
    return await db.insert('local_sales', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Helper to map DB row to Sale object
  Sale _saleFromDbMap(Map<String, dynamic> dbMap) {
    List<SaleItem> items = [];
    if (dbMap['sale_items_json'] != null) {
      try {
        final decodedItems = jsonDecode(dbMap['sale_items_json']) as List<dynamic>;
        items = decodedItems.map((itemJson) => SaleItem.fromJson(itemJson as Map<String, dynamic>)).toList();
      } catch (e) {
        // Consider logging this error to a more robust logging solution
        // print('Error decoding sale items: $e'); 
      }
    }
    return Sale(
      id: dbMap['id'] ?? '',
      localId: dbMap['local_id'],
      customerName: dbMap['customer_name'] ?? '',
      date: DateTime.parse(dbMap['date']),
      dueDate: dbMap['due_date'] != null ? DateTime.parse(dbMap['due_date']) : null,
      customerId: dbMap['customer_id'],
      items: items,
      totalAmountInCdf: dbMap['total_amount_cdf'] ?? 0.0,
      paidAmountInCdf: dbMap['amount_paid_cdf'] ?? 0.0, // Corrected key from DB
      totalAmountInUsd: dbMap['total_amount_usd'],
      paidAmountInUsd: dbMap['amount_paid_usd'], // Corrected key from DB
      paymentMethod: dbMap['payment_method'],
      status: SaleStatus.values.firstWhere((e) => e.toString().split('.').last == dbMap['status'], orElse: () => SaleStatus.pending),
      invoiceNumber: dbMap['invoice_number'],
      notes: dbMap['notes'],
      userId: dbMap['user_id'],
      createdAt: dbMap['created_at'] != null ? DateTime.parse(dbMap['created_at']) : null,
      updatedAt: dbMap['updated_at'] != null ? DateTime.parse(dbMap['updated_at']) : null,
      syncStatus: dbMap['sync_status'],
      lastSyncAttempt: dbMap['last_sync_attempt'] != null ? DateTime.parse(dbMap['last_sync_attempt']) : null,
      errorMessage: dbMap['error_message'],
      // transactionCurrencyCode, transactionExchangeRate, etc. need to be added if stored
    );
  }

  Future<Sale?> getLocalSaleById(String localId) async {
    final db = await instance.database;
    final maps = await db.query(
      'local_sales',
      columns: null, 
      where: 'local_id = ?',
      whereArgs: [localId],
    );

    if (maps.isNotEmpty) {
      return _saleFromDbMap(maps.first);
    } else {
      return null;
    }
  }
  
  Future<List<Sale>> getAllLocalSales() async {
    final db = await instance.database;
    final result = await db.query('local_sales', orderBy: 'date DESC');
    return result.map((json) => _saleFromDbMap(json)).toList(); 
  }

  Future<int> updateLocalSaleSyncStatus(String localId, String status, {String? serverId, String? errorMessage}) async {
    final db = await instance.database;
    Map<String, dynamic> valuesToUpdate = {
      'sync_status': status,
      'last_sync_attempt': DateTime.now().toIso8601String(),
      'error_message': errorMessage,
    };
    if (serverId != null) {
      valuesToUpdate['id'] = serverId;
    }
    return db.update(
      'local_sales',
      valuesToUpdate,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Map<String, dynamic>>> getPendingSales() async {
    final db = await instance.database;
    return await db.query('local_sales', where: 'sync_status = ?', whereArgs: ['pending']);
  }


  // --- Expenses Methods ---
  Future<int> createLocalExpense(Expense expense, {String? localIdOverride}) async {
    final db = await instance.database;
    final localId = localIdOverride ?? Uuid().v4();

    final attachmentsJson = expense.localAttachmentPaths != null && expense.localAttachmentPaths!.isNotEmpty
        ? jsonEncode(expense.localAttachmentPaths)
        : null;

    final Map<String, dynamic> row = {
      'id': expense.id.isEmpty ? localId : expense.id,
      'local_id': localId,
      'motif': expense.motif,
      'amount': expense.amount,
      'date': expense.date.toIso8601String(),
      'category_id': expense.category.name, // Storing enum name as category_id
      'category_name': expense.category.name,
      'payment_method': expense.paymentMethod,
      'beneficiary': expense.beneficiary,
      'notes': expense.notes,
      'user_id': expense.userId,
      'supplier_id': expense.supplierId, // Added supplier_id
      'created_at': expense.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': expense.updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'attachments_json': attachmentsJson,
      'sync_status': 'pending',
      'last_sync_attempt': null,
      'error_message': null,
    };
    return await db.insert('local_expenses', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Helper to map DB row to Expense object
  Expense _expenseFromDbMap(Map<String, dynamic> dbMap) {
    List<String>? localAttachmentPaths = [];
    if (dbMap['attachments_json'] != null) {
      try {
        final decodedAttachments = jsonDecode(dbMap['attachments_json']) as List<dynamic>;
        localAttachmentPaths = decodedAttachments.map((path) => path as String).toList();
      } catch (e) {
        // Consider logging this error to a more robust logging solution
        // print('Error decoding expense attachments: $e');
      }
    }
    // Note: If attachments_json could also store synced URLs, logic to differentiate would be needed here
    // or store them in separate columns / use sync_status to decide.

    return Expense(
      id: dbMap['id'] ?? '',
      localId: dbMap['local_id'],
      motif: dbMap['motif'] ?? '',
      amount: dbMap['amount'] ?? 0.0,
      date: DateTime.parse(dbMap['date']),
      category: ExpenseCategory.values.firstWhere((e) => e.name == dbMap['category_name'], orElse: () => ExpenseCategory.other),
      paymentMethod: dbMap['payment_method'],
      beneficiary: dbMap['beneficiary'],
      notes: dbMap['notes'],
      userId: dbMap['user_id'],
      createdAt: dbMap['created_at'] != null ? DateTime.parse(dbMap['created_at']) : null,
      updatedAt: dbMap['updated_at'] != null ? DateTime.parse(dbMap['updated_at']) : null,
      // Assuming attachments_json from DB currently stores local paths for pending items
      // or synced URLs if the item is synced (this part needs clarification on how synced URLs are stored)
      localAttachmentPaths: localAttachmentPaths, // Populated from attachments_json
      attachmentUrls: dbMap['sync_status'] == 'synced' && localAttachmentPaths != null && localAttachmentPaths.isNotEmpty ? List<String>.from(localAttachmentPaths) : null, // Simplistic assumption
      syncStatus: dbMap['sync_status'],
      lastSyncAttempt: dbMap['last_sync_attempt'] != null ? DateTime.parse(dbMap['last_sync_attempt']) : null,
      errorMessage: dbMap['error_message'],
      supplierId: dbMap['supplier_id'],
    );
  }

  Future<Expense?> getLocalExpenseById(String localId) async {
    final db = await instance.database;
    final maps = await db.query(
      'local_expenses',
      columns: null,
      where: 'local_id = ?',
      whereArgs: [localId],
    );

    if (maps.isNotEmpty) {
      return _expenseFromDbMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<Expense>> getAllLocalExpenses() async {
    final db = await instance.database;
    final result = await db.query('local_expenses', orderBy: 'date DESC');
    return result.map((json) => _expenseFromDbMap(json)).toList();
  }

  Future<int> updateLocalExpenseSyncStatus(String localId, String status, {String? serverId, List<String>? syncedAttachmentUrls, String? errorMessage}) async {
    final db = await instance.database;
    Map<String, dynamic> valuesToUpdate = {
      'sync_status': status,
      'last_sync_attempt': DateTime.now().toIso8601String(),
      'error_message': errorMessage,
    };
    if (serverId != null) {
      valuesToUpdate['id'] = serverId;
    }
    if (syncedAttachmentUrls != null) {
      // Assuming we overwrite attachments_json with synced URLs after successful sync
      valuesToUpdate['attachments_json'] = jsonEncode(syncedAttachmentUrls);
    }

    return db.update(
      'local_expenses',
      valuesToUpdate,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
