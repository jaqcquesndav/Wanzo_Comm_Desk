# API Ventes

Cette documentation détaille les endpoints disponibles pour la gestion des ventes dans l'application Wanzo.

## ✅ Implémentation Complète

**Architecture Hybride Offline-First + API Sync**

Le module Sales utilise une architecture **hybride** avec synchronisation optionnelle:

### Composants Implémentés

**Service API Backend**: `SalesService` (✅ Complet)
- ✅ `getSales()` - Récupération avec filtres (page, limit, dates, customerId, status, sort)
- ✅ `createSale()` - Création de vente
- ✅ `getSaleById()` - Récupération par ID
- ✅ `updateSale()` - Mise à jour
- ✅ `deleteSale()` - Suppression
- ✅ `completeSale()` - Marquer comme complétée
- ✅ `cancelSale()` - Annulation
- ✅ `syncSales()` - Synchronisation offline→online
- ✅ `getSalesStats()` - Statistiques avec filtres de dates

**Repository Mobile**: `SalesRepository` (✅ Intégration hybride)
- Stockage local Hive pour accès instantané
- Méthode `getAllSales({syncWithApi: bool})` avec fusion données API + locales
- `syncLocalSalesToBackend()` pour synchronisation manuelle
- `getSalesStats()` pour analytics depuis API
- Timeout 5s avec fallback local automatique

### Workflow Hybride
```
UI → SalesBloc → SalesRepository
                      ├─ Hive (lecture immédiate)
                      └─ SalesApiService (sync optionnel)
                            ↓
                      Backend API
```

## Statuts des Ventes

Les statuts de ventes sont représentés par des chaînes de caractères dans les requêtes et réponses API:

- `pending` - En attente
- `completed` - Terminée
- `cancelled` - Annulée
- `partiallyPaid` - Partiellement payée

## Types d'Articles de Vente

Chaque article (SaleItem) dans une vente peut être de deux types:

- `product` - Produit physique avec gestion de stock
- `service` - Service sans impact sur le stock

**Exemple**:
```json
{
  "items": [
    {
      "productId": "prod_123",
      "productName": "Ciment 50kg",
      "itemType": "product",
      "quantity": 10
    },
    {
      "productId": "serv_456",
      "productName": "Livraison",
      "itemType": "service",
      "quantity": 1
    }
  ]
}
```

## Gestion de la Synchronisation Offline

L'application supporte le mode offline avec synchronisation automatique:

### Champs de Synchronisation (Local Uniquement)

- `localId`: Identifiant temporaire généré localement avant synchronisation
- `syncStatus`: État de synchronisation
  - `synced`: Synchronisé avec le serveur
  - `pending`: En attente de synchronisation
  - `failed`: Échec de synchronisation
- `lastSyncAttempt`: Date de la dernière tentative de synchronisation
- `errorMessage`: Message d'erreur détaillé en cas d'échec

**Note**: Ces champs ne sont pas envoyés au serveur et servent uniquement à la gestion locale.

## Structure du modèle Vente

```json
{
  "id": "string",                      // Identifiant unique de la vente (UUID)
  "localId": "string",                 // Identifiant local pour offline (optionnel, local uniquement)
  "date": "2023-08-01T12:30:00.000Z",  // Date de la vente
  "dueDate": "2023-08-15T12:30:00.000Z", // Date d'échéance pour paiement (optionnel)
  "customerId": "string",              // Identifiant du client (optionnel)
  "customerName": "string",            // Nom du client
  "items": [                           // Liste des produits vendus
    {
      "id": "string",                  // Identifiant unique de l'article
      "productId": "string",           // Identifiant du produit
      "productName": "string",         // Nom du produit
      "itemType": "product",           // Type: "product" ou "service"
      "quantity": 5,                   // Quantité vendue
      "unitPrice": 10.00,              // Prix unitaire
      "discount": 0.00,                // Remise (optionnel)
      "totalPrice": 50.00,             // Prix total
      "currencyCode": "USD",           // Code de la devise (optionnel)
      "taxRate": 16.00,                // Taux de taxe en pourcentage (optionnel)
      "taxAmount": 8.00,               // Montant de la taxe (optionnel)
      "notes": "string"                // Notes additionnelles (optionnel)
    }
  ],
  "totalAmountInCdf": 50000.00,        // Montant total en Francs Congolais
  "paidAmountInCdf": 50000.00,         // Montant déjà payé en Francs Congolais
  "discountPercentage": 5.0,           // Pourcentage de réduction global (0-100, optionnel)
  "status": "completed",               // Statut de la vente
  "paymentMethod": "string",           // Méthode de paiement
  "paymentReference": "string",        // Référence de paiement (optionnel)
  "notes": "string",                   // Notes additionnelles (optionnel)
  "exchangeRate": 2000.00,             // Taux de change
  
  // === Champs d'Unité d'Affaires (Business Unit) ===
  "companyId": "uuid-company",         // Identifiant de l'entreprise principale (société mère)
  "businessUnitId": "uuid-bu",         // Identifiant de l'unité commerciale
  "businessUnitCode": "POS-KIN-001",   // Code unique de l'unité commerciale
  "businessUnitType": "pos",           // Type d'unité: "company", "branch" ou "pos"
  
  // === Métadonnées ===
  "userId": "uuid-user",               // Identifiant de l'utilisateur ayant créé la vente
  "createdAt": "2023-08-01T12:30:00.000Z", // Date de création
  "updatedAt": "2023-08-01T12:30:00.000Z", // Date de mise à jour
  "syncStatus": "synced",              // Statut de synchronisation: "synced", "pending", "failed" (local uniquement)
  "lastSyncAttempt": "2023-08-01T12:30:00.000Z", // Dernière tentative de sync (local uniquement, optionnel)
  "errorMessage": "string"             // Message d'erreur de synchronisation (local uniquement, optionnel)
}
```

### Types d'Unités d'Affaires (businessUnitType)

| Type | Description |
|------|-------------|
| `company` | Entreprise principale (niveau 0) |
| `branch` | Succursale/Agence (niveau 1) |
| `pos` | Point de Vente (niveau 2) |

> **Note**: Les champs `companyId` et `businessUnitId` sont automatiquement définis selon le contexte utilisateur et permettent le filtrage multi-tenant des données.
```

## Endpoints

### 1. Récupérer toutes les ventes

**Endpoint:** `GET /commerce/api/v1/sales`

**Paramètres de requête:**
- `page` (optionnel): Numéro de page pour la pagination
- `limit` (optionnel): Nombre d'éléments par page
- `dateFrom` (optionnel): Date de début au format ISO8601 (YYYY-MM-DD)
- `dateTo` (optionnel): Date de fin au format ISO8601 (YYYY-MM-DD)
- `customerId` (optionnel): Filtrer par ID client
- `status` (optionnel): Filtrer par statut
- `minAmount` (optionnel): Montant minimal
- `maxAmount` (optionnel): Montant maximal
- `companyId` (optionnel): Filtrer par ID d'entreprise (défaut: entreprise de l'utilisateur)
- `businessUnitId` (optionnel): Filtrer par ID d'unité commerciale
- `businessUnitType` (optionnel): Filtrer par type d'unité (`company`, `branch`, `pos`)
- `sortBy` (optionnel): Champ sur lequel trier
- `sortOrder` (optionnel): Ordre de tri (`asc` ou `desc`)

**Note sur le filtrage Business Unit:**
- Si `businessUnitId` est fourni, seules les ventes de cette unité seront retournées
- Si non fourni, toutes les ventes de l'entreprise de l'utilisateur seront retournées
- Un utilisateur associé à une succursale (branch) verra également les ventes de ses points de vente enfants

**Réponse:**
```json
{
  "success": true,
  "message": "Sales fetched successfully.",
  "statusCode": 200,
  "data": [
    {
      // Objet vente (voir structure ci-dessus)
    },
    // ... autres ventes
  ]
}
```

### 2. Récupérer une vente par ID

**Endpoint:** `GET /commerce/api/v1/sales/{id}`

**Paramètres:**
- `id`: ID de la vente à récupérer

**Réponse:**
```json
{
  "success": true,
  "message": "Sale fetched successfully.",
  "statusCode": 200,
  "data": {
    // Objet vente (voir structure ci-dessus)
  }
}
```

### 3. Créer une nouvelle vente

**Endpoint:** `POST /commerce/api/v1/sales`

**Corps de la requête:**
```json
{
  "date": "2023-08-01T12:30:00.000Z",  // Obligatoire
  "dueDate": "2023-08-15T12:30:00.000Z", // Optionnel
  "customerId": "string",              // Optionnel
  "customerName": "string",            // Obligatoire
  "items": [                           // Obligatoire (au moins un élément)
    {
      "productId": "string",           // Obligatoire
      "productName": "string",         // Obligatoire
      "quantity": 5,                   // Obligatoire
      "unitPrice": 10.00,              // Obligatoire
      "discount": 0.00,                // Optionnel
      "currencyCode": "USD",           // Optionnel
      "taxRate": 16.00,                // Optionnel
      "notes": "string"                // Optionnel
    }
  ],
  "paymentMethod": "string",           // Obligatoire
  "paymentReference": "string",        // Optionnel
  "notes": "string",                   // Optionnel
  "exchangeRate": 2000.00,             // Obligatoire si devises différentes
  
  // === Champs d'Unité d'Affaires (optionnels, auto-définis si absents) ===
  "companyId": "uuid-company",         // Optionnel - Défaut: entreprise de l'utilisateur
  "businessUnitId": "uuid-bu",         // Optionnel - Défaut: unité de l'utilisateur
  "businessUnitCode": "POS-KIN-001",   // Optionnel - Défaut: code de l'unité de l'utilisateur
  "businessUnitType": "pos"            // Optionnel - "company", "branch" ou "pos"
}
      "quantity": 5,                   // Obligatoire
      "unitPrice": 10.00,              // Obligatoire
      "discount": 0.00,                // Optionnel
      "currencyCode": "USD",           // Optionnel
      "taxRate": 16.00,                // Optionnel
      "notes": "string"                // Optionnel
    }
  ],
  "paymentMethod": "string",           // Obligatoire
  "paymentReference": "string",        // Optionnel
  "notes": "string",                   // Optionnel
  "exchangeRate": 2000.00              // Obligatoire si devises différentes
}
```

**Réponse:**
```json
{
  "success": true,
  "message": "Sale created successfully.",
  "statusCode": 201,
  "data": {
    // Objet vente créé (voir structure ci-dessus)
  }
}
```

### 4. Mettre à jour une vente

**Endpoint:** `PATCH /commerce/api/v1/sales/{id}`

**Paramètres:**
- `id`: ID de la vente à mettre à jour

**Corps de la requête:**
```json
{
  "date": "2023-08-01T12:30:00.000Z",  // Optionnel
  "dueDate": "2023-08-15T12:30:00.000Z", // Optionnel
  "customerName": "string",            // Optionnel
  "items": [                           // Optionnel
    {
      "id": "string",                  // Obligatoire si l'article existe déjà
      "productId": "string",           // Obligatoire pour nouvel article
      "productName": "string",         // Obligatoire pour nouvel article
      "quantity": 5,                   // Obligatoire pour nouvel article
      "unitPrice": 10.00,              // Obligatoire pour nouvel article
      "discount": 0.00,                // Optionnel
      "notes": "string"                // Optionnel
    }
  ],
  "status": "completed",               // Optionnel
  "paymentMethod": "string",           // Optionnel
  "amountPaid": 50000.00,              // Optionnel - Montant payé
  "paymentReference": "string",        // Optionnel
  "notes": "string"                    // Optionnel
}
```

**Réponse:**
```json
{
  "success": true,
  "message": "Sale updated successfully.",
  "statusCode": 200,
  "data": {
    // Objet vente mis à jour (voir structure ci-dessus)
  }
}
```

### 5. Supprimer une vente

**Endpoint:** `DELETE /commerce/api/v1/sales/{id}`

**Paramètres:**
- `id`: ID de la vente à supprimer

**Réponse:**
```json
{
  "success": true,
  "message": "Sale deleted successfully.",
  "statusCode": 200,
  "data": null
}
```

### 6. Marquer une vente comme complétée

**Endpoint:** `PUT /commerce/api/v1/sales/{id}/complete`

**Paramètres:**
- `id`: ID de la vente à marquer comme complétée

**Corps de la requête:**
```json
{
  "amountPaid": 50000.00,              // Obligatoire - Montant payé
  "paymentMethod": "string",           // Obligatoire
  "paymentReference": "string"         // Optionnel
}
```

**Réponse:**
```json
{
  "success": true,
  "message": "Sale marked as completed successfully.",
  "statusCode": 200,
  "data": {
    // Objet vente mis à jour (voir structure ci-dessus)
  }
}
```

### 7. Annuler une vente

**Endpoint:** `PUT /commerce/api/v1/sales/{id}/cancel`

**Paramètres:**
- `id`: ID de la vente à annuler

**Corps de la requête:**
```json
{
  "reason": "string"                   // Optionnel
}
```

**Réponse:**
```json
{
  "success": true,
  "message": "Sale cancelled successfully.",
  "statusCode": 200,
  "data": {
    // Objet vente mis à jour (voir structure ci-dessus)
  }
}
```

### 8. Synchroniser des ventes offline

**Endpoint:** `POST /commerce/api/v1/sales/sync`

**Description:** Permet de synchroniser plusieurs ventes créées en mode offline vers le serveur.

**Corps de la requête:**
```json
[
  {
    "localId": "local-uuid-1",           // Identifiant local (optionnel)
    "date": "2025-01-04T12:30:00.000Z",
    "customerName": "Client Offline",
    "items": [
      {
        "productId": "uuid-prod",
        "productName": "Produit 1",
        "quantity": 5,
        "unitPrice": 10000.00
      }
    ],
    "paymentMethod": "cash",
    "exchangeRate": 2800.00
  }
]
```

**Réponse:**
```json
{
  "synced": [
    {
      "id": "uuid-server",
      "localId": "local-uuid-1",
      "date": "2025-01-04T12:30:00.000Z",
      "status": "pending"
    }
  ],
  "errors": [
    {
      "localId": "local-uuid-failed",
      "error": "Description de l'erreur de synchronisation"
    }
  ]
}
```

### 9. Obtenir les statistiques des ventes

**Endpoint:** `GET /commerce/api/v1/sales/stats`

**Description:** Récupère les statistiques agrégées des ventes pour une période donnée.

**Paramètres de requête:**
- `dateFrom` (optionnel): Date de début au format YYYY-MM-DD
- `dateTo` (optionnel): Date de fin au format YYYY-MM-DD

**Réponse:**
```json
{
  "totalSales": 150,
  "totalRevenue": 15000000.00,
  "totalRevenueUsd": 5357.14,
  "averageOrderValue": 100000.00,
  "salesByStatus": {
    "completed": 120,
    "pending": 20,
    "cancelled": 10
  },
  "salesByPaymentMethod": {
    "cash": 80,
    "mobile_money": 50,
    "bank_transfer": 20
  },
  "topProducts": [
    {
      "productId": "uuid-prod-1",
      "productName": "Produit populaire",
      "totalQuantity": 500,
      "totalRevenue": 5000000.00
    }
  ],
  "topCustomers": [
    {
      "customerId": "uuid-customer-1",
      "customerName": "Client fidèle",
      "totalPurchases": 10,
      "totalSpent": 2000000.00
    }
  ],
  "dailyTrend": [
    {
      "date": "2025-01-01",
      "totalSales": 10,
      "totalRevenue": 1000000.00
    }
  ]
}
```
