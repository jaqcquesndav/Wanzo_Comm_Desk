# Synchronization API Documentation

## Overview

The Synchronization system in Wanzo provides a robust offline-first architecture that ensures data consistency between the local device storage and the remote backend. It manages the synchronization of various entities such as products, customers, sales, expenses, suppliers, financial transactions, and financial accounts.

## Core Components

### SyncService

The `SyncService` is the central component responsible for:

1. Periodic automatic synchronization (every 15 minutes when online)
2. Manual synchronization triggered by user actions
3. Connectivity monitoring to sync when connections are restored
4. Entity-specific or global synchronization operations
5. Pending operations queue management for offline changes

### SyncEntityType Enum

Defines the types of entities that can be synchronized:

- `products`: Product inventory items
- `customers`: Customer records
- `sales`: Sales transactions
- `expenses`: Business expenses
- `suppliers`: Supplier records
- `financialTransactions`: Financial transaction records
- `financialAccounts`: Financial account records
- `all`: All entity types (for full synchronization)

### SyncStatus Enum

Represents the current status of synchronization operations:

- `syncing`: Synchronization is in progress
- `completed`: Synchronization completed successfully
- `failed`: Synchronization failed

## Synchronization Process

### Upload Flow (Local to Remote)

1. When changes are made locally while offline:
   - Changes are saved to local Hive boxes
   - Pending operations are recorded with timestamps and operation types
   - Each operation is marked with a unique ID

2. When connectivity is restored:
   - Pending operations are processed in the order they were created
   - Each operation is sent to the appropriate API endpoint
   - Successfully synchronized operations are removed from the pending queue
   - Failed operations remain in the queue for future synchronization attempts

### Download Flow (Remote to Local)

1. During synchronization:
   - Latest data is fetched from the remote API for each entity type
   - Local data is updated with remote changes
   - Conflicts are resolved based on timestamp priority or server-wins strategy

2. Entity-specific synchronization handles:
   - Fetching paginated data when dealing with large datasets
   - Applying incremental updates when supported by the API
   - Handling deletions by comparing local and remote entity lists

## API Integration

While the Sync system itself doesn't expose traditional REST endpoints, it integrates with various entity-specific APIs:

### Product Synchronization

- Uses `ProductApiService` to fetch remote products and push local changes
- Handles product inventory adjustments, new products, and product updates

### Customer Synchronization

- Uses `CustomerApiService` to manage customer data between local and remote systems
- Handles customer creation, updates, and potentially deletion

### Sales Synchronization

- Uses `SaleApiService` to synchronize sales transactions
- Maintains consistency between local sales records and remote database

### Expense Synchronization

- Uses `ExpenseApiService` to sync expense records
- Ensures expense data is consistent across devices and the backend

### Supplier Synchronization

- Uses `SupplierApiService` to manage supplier records
- Synchronizes supplier creation, updates, and potentially deletion

### Financial Transaction Synchronization

- Uses `FinancialTransactionApiService` to sync financial transactions
- Maintains consistency for financial records

### Financial Account Synchronization

- Uses `FinancialAccountApiService` to sync financial accounts
- Ensures account data is consistent across devices and backend

## Usage Example

```dart
// Initialize the sync service
await syncService.init();

// Trigger manual synchronization for all entities
final bool success = await syncService.syncData();

// Trigger synchronization for specific entity type
final bool customerSyncSuccess = await syncService.syncData(
  entityType: SyncEntityType.customers
);

// Listen to sync status changes
syncService.syncStatus.listen((status) {
  switch (status) {
    case SyncStatus.syncing:
      // Show sync in progress UI
      break;
    case SyncStatus.completed:
      // Show sync success message
      break;
    case SyncStatus.failed:
      // Show sync failure message
      break;
  }
});
```

## Error Handling

The synchronization system handles various error scenarios:

1. Network connectivity issues:
   - Operations are queued when offline
   - Sync automatically retries when connectivity is restored

2. API errors:
   - Individual entity sync failures don't halt the entire process
   - Detailed error logging for troubleshooting
   - Failed operations remain in queue for future attempts

3. Conflict resolution:
   - Timestamp-based prioritization
   - Server-wins strategy for critical conflicts
   - Entity-specific conflict resolution when needed

## Implementation Notes

1. The system is designed to be resilient, ensuring data consistency even with intermittent connectivity
2. Synchronization is non-blocking and runs in the background
3. The service can be extended to support additional entity types
4. Optimistic updates are applied locally before confirmation from the server
5. The sync system respects data ownership and user permissions
