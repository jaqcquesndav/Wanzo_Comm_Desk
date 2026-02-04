# Module Operations - Vue Agrégée Locale

Cette documentation détaille le module Operations dans l'application Wanzo.

> **✅ Conformité**: Aligné avec `business-operation.entity.ts`

## ✅ Implémentation Hybride

**Le module Operations combine AGRÉGATION LOCALE + API REST backend**

### Architecture Double Niveau

**Niveau 1 - Interface Utilisateur (Agrégateur Local)**
```
OperationsScreen (UI avec onglets)
        ↓
OperationsBloc
        ↓
┌───────┴────────┬──────────────┬───────────────┐
│                │              │               │
SalesRepository  ExpenseRepo    FinancingRepo  (Hive)
```

**Fonctionnalités UI** (✅ Implémenté):
- Interface utilisateur avec 4 onglets (Tout, Ventes, Dépenses, Financements)
- Filtrage local par dates et statut
- Affichage consolidé des opérations
- Gestion d'erreurs réseau
- 100% fonctionnel hors ligne

**Niveau 2 - API Backend (Endpoints Centralisés)**
```
UI/Reports → OperationsApiService → Backend
                                        ↓
                              Agrégation côté serveur
```

**Service API**: `OperationsApiService` (✅ Complet)
- ✅ `getOperations()` - Liste avec 11 filtres (type, dates, relatedPartyId, status, montants, tri, pagination)
- ✅ `getOperationsSummary()` - Résumé par période (day/week/month/year)
- ✅ `exportOperations()` - Export PDF/Excel avec options avancées
- ✅ `getOperationById()` - Détails d'une opération
- ✅ `getOperationsTimeline()` - Timeline des opérations récentes

**Services Complémentaires** (✅ Complet):
- `OperationExportService` - Export PDF multi-pages + Excel (CSV)
- `OperationFilter` - Modèle de filtrage avec 8 critères + factory methods

**Status actuel**: ✅ API complète | ✅ UI locale fonctionnelle | ✅ Export services

Le module Operations est un point d'entrée central qui regroupe différents types d'opérations financières et commerciales (ventes, dépenses, financements).

## Types d'Opérations (OperationType)

Les types d'opérations disponibles dans l'API (définis dans `operation-type.enum.ts`):

| Type | Valeur | Description |
|------|--------|-------------|
| Vente | `sale` | Opération de vente |
| Dépense | `expense` | Opération de dépense |
| Financement | `financing` | Demande de financement |
| Inventaire | `inventory` | Opération d'inventaire |
| Transaction | `transaction` | Transaction financière |

## Statuts d'Opération (OperationStatus)

| Statut | Valeur | Description |
|--------|--------|-------------|
| Complétée | `completed` | Opération terminée avec succès |
| En attente | `pending` | Opération en cours de traitement |
| Annulée | `cancelled` | Opération annulée |
| Échouée | `failed` | Opération échouée (erreur) |

## Méthodes de Paiement (PaymentMethod)

| Méthode | Valeur | Description |
|---------|--------|-------------|
| Espèces | `cash` | Paiement en espèces |
| Virement | `bank_transfer` | Virement bancaire |
| Mobile Money | `mobile_money` | Paiement mobile (M-Pesa, Airtel Money, Orange Money) |
| Crédit | `credit` | Paiement à crédit |
| Chèque | `check` | Paiement par chèque |
| Autre | `other` | Autre méthode |

## Structure du modèle Opération

```json
{
  "id": "string",                       // Identifiant unique de l'opération
  "type": "sale",                       // Type d'opération (voir OperationType)
  "date": "2023-08-01T12:30:00.000Z",   // Date de l'opération
  "description": "string",              // Description de l'opération
  "entityId": "string",                 // ID de l'entité associée (vente, dépense, etc.)
  "amountCdf": 150000.00,               // Montant en CDF
  "amountUsd": 75.00,                   // Montant en USD (si applicable)
  "relatedPartyId": "string",           // ID de la partie liée (client, fournisseur)
  "relatedPartyName": "string",         // Nom de la partie liée
  "status": "completed",                // Statut (completed, pending, cancelled, failed)
  "notes": "string",                    // Notes supplémentaires (optionnel)
  
  // Champs supplémentaires selon le type d'opération
  "paymentMethod": "cash",              // Méthode de paiement (pour les ventes/dépenses)
  "categoryId": "string",               // ID de la catégorie (pour les dépenses)
  "productCount": 5,                    // Nombre de produits (pour les ventes)
  
  // === Champs d'Unité d'Affaires (Business Unit) ===
  "companyId": "uuid-company",          // ID de l'entreprise (obligatoire pour isolation multi-tenant)
  "businessUnitId": "uuid-bu",          // ID de l'unité commerciale
  "businessUnitCode": "BRN-KIN-001",    // Code unique de l'unité commerciale
  "businessUnitType": "branch",         // Type d'unité: "company", "branch" ou "pos"
  
  // === Métadonnées ===
  "createdBy": "uuid-user",             // ID de l'utilisateur qui a créé l'opération
  "createdAt": "2023-08-01T12:30:00.000Z", // Date de création
  "updatedAt": "2023-08-01T12:30:00.000Z", // Date de mise à jour
  
  // Données additionnelles (JSONB)
  "additionalData": {                   // Métadonnées supplémentaires (format libre)
    "invoiceNumber": "INV-2023-001",
    "deliveryAddress": "123 Rue Exemple",
    "notes": "Livraison urgente",
    "customField": "valeur personnalisée"
  }
}
```

### Champ additionalData (JSONB)

Le champ `additionalData` permet de stocker des métadonnées supplémentaires spécifiques à chaque opération:

**Exemples d'utilisation**:

1. **Pour une vente**:
```json
{
  "additionalData": {
    "invoiceNumber": "INV-2023-001",
    "deliveryMethod": "pickup",
    "discountReason": "Client fidèle"
  }
}
```

2. **Pour une dépense**:
```json
{
  "additionalData": {
    "receiptNumber": "REC-456",
    "approvedBy": "manager@example.com",
    "budgetCode": "OPS-2023"
  }
}
```

3. **Pour un financement**:
```json
{
  "additionalData": {
    "guarantorId": "guarantor-123",
    "interestRate": 5.5,
    "collateralType": "property"
  }
}
```

## Implémentation Actuelle vs Roadmap API

### ✅ Fonctionnalités Implémentées (Local)

**Bloc**: `OperationsBloc`
- Event `LoadOperations` avec filtrage par dates
- Filtrage par `paymentStatus` (ventes)
- Filtrage par `financingType` (financements)
- States: Initial, Loading, Loaded(sales, expenses, financingRequests), Error
- Gestion erreurs réseau vs erreurs locales

**Interface Utilisateur**: `OperationsScreen`
- TabBar avec 4 onglets: Tout, Ventes, Dépenses, Financements
- Dialog de filtrage (`_showFilterDialog`)
- Bouton retry en cas d'erreur
- Support SaleStatus avec noms localisés

**Modèle**: `Operation`
- 16 champs conformes à la documentation
- Annotations Hive (@HiveType) pour cache local
- Annotations JSON (@JsonSerializable) pour future API
- Extension OperationType avec displayName

### ❌ Endpoints API (À Implémenter)

### 1. Récupérer la liste des opérations

**Status**: ✅ **Implémenté**

**Endpoint**: `GET /commerce/api/v1/operations`

**Service**: `OperationsApiService.getOperations()`

**Description**: Récupère la liste des opérations avec filtrage et pagination avancés.

**Paramètres de requête (Query Params)**:
- `type` (optionnel): Filtrer par type d'opération (voir liste ci-dessus)
- `dateFrom` (optionnel): Date de début (format: YYYY-MM-DD)
- `dateTo` (optionnel): Date de fin (format: YYYY-MM-DD)
- `relatedPartyId` (optionnel): ID du client ou fournisseur lié
- `status` (optionnel): Statut de l'opération
- `minAmount` (optionnel): Montant minimum
- `maxAmount` (optionnel): Montant maximum
- `sortBy` (optionnel): Champ de tri (date, amount, relatedPartyName)
- `sortOrder` (optionnel): Ordre de tri (asc, desc)
- `page` (optionnel): Numéro de page pour la pagination
- `limit` (optionnel): Nombre d'éléments par page

**Réponse réussie (200)**:
```json
{
  "status": "success",
  "data": {
    "items": [
      {
        // Structure du modèle Opération (version courte)
        "id": "string",
        "type": "sale",
        "date": "2023-08-01T12:30:00.000Z",
        "description": "string",
        "amountCdf": 150000.00,
        "amountUsd": 75.00,
        "relatedPartyName": "string",
        "status": "completed"
      }
    ],
    "totalItems": 120,
    "totalPages": 6,
    "currentPage": 1
  }
}
```

### 2. Récupérer le résumé des opérations

**Status**: ✅ **Implémenté**

**Endpoint**: `GET /commerce/api/v1/operations/summary`

**Service**: `OperationsApiService.getOperationsSummary()`

**Description**: Récupère un résumé des opérations regroupées par type et période.

**Paramètres de requête (Query Params)**:
- `period` (obligatoire): Période pour laquelle récupérer les données (valeurs possibles: "day", "week", "month", "year")
- `date` (optionnel): Date de référence (format: YYYY-MM-DD), défaut: aujourd'hui

**Réponse réussie (200)**:
```json
{
  "status": "success",
  "data": {
    "period": "month",
    "dateFrom": "2023-08-01",
    "dateTo": "2023-08-31",
    "summary": {
      "totalOperations": 120,
      "byType": {
        "sale": {
          "count": 65,
          "amountCdf": 9750000.00,
          "amountUsd": 4875.00
        },
        "expense": {
          "count": 45,
          "amountCdf": 3375000.00,
          "amountUsd": 1687.50
        },
        "financing": {
          "count": 2,
          "amountCdf": 20000000.00,
          "amountUsd": 10000.00
        },
        "inventory": {
          "count": 8,
          "productCount": 120
        }
      },
      "byStatus": {
        "completed": 95,
        "pending": 15,
        "cancelled": 8,
        "failed": 2
      }
    }
  }
}
```

### 3. Exporter des opérations

**Status**: ✅ **Implémenté**

**Endpoint**: `POST /commerce/api/v1/operations/export`

**Service**: `OperationsApiService.exportOperations()` + `OperationExportService`

**Description**: Génère un fichier d'exportation (PDF ou Excel) des opérations selon les critères spécifiés.

**Services d'Export** (✅ Complets):
- `OperationExportService.exportToPdf()` - Export PDF avec tables formatées, en-têtes, pieds de page
- `OperationExportService.exportToExcel()` - Export CSV avec toutes les colonnes
- `OperationExportService.calculateStats()` - Calcul de statistiques (totaux, groupement par type)

**Note**: Pour l'export PDF du journal des opérations, voir aussi `JournalService.generateJournalPdf()` dans le module Dashboard.

**Corps de la requête**:
```json
{
  "type": "sale",              // Optionnel: Filtrer par type d'opération
  "dateFrom": "2023-08-01",   // Obligatoire: Date de début
  "dateTo": "2023-08-31",     // Obligatoire: Date de fin
  "relatedPartyId": "string",  // Optionnel: ID du client ou fournisseur lié
  "status": "completed",       // Optionnel: Statut de l'opération
  "format": "pdf",             // Obligatoire: Format d'export (pdf, excel)
  "includeDetails": true,      // Optionnel: Inclure les détails des opérations
  "groupBy": "date"            // Optionnel: Regroupement (date, type, party)
}
```

**Réponse réussie (200)**:
```json
{
  "status": "success",
  "data": {
    "exportId": "string",
    "fileName": "operations_export_2023-08-01_2023-08-31.pdf",
    "fileSize": 1250,
    "fileUrl": "https://api.wanzo.com/exports/operations_export_2023-08-01_2023-08-31.pdf",
    "expiresAt": "2023-09-01T12:30:00.000Z"
  }
}
```

### 4. Récupérer les détails d'une opération spécifique

**Status**: ✅ **Implémenté**

**Endpoint**: `GET /commerce/api/v1/operations/{id}`

**Service**: `OperationsApiService.getOperationById()`

**Description**: Récupère les détails complets d'une opération spécifique.

**Paramètres de chemin (Path Params)**:
- `id`: L'identifiant unique de l'opération

**Réponse réussie (200)**:
```json
{
  "status": "success",
  "data": {
    // Structure complète du modèle Opération
    // Les champs supplémentaires dépendent du type d'opération
    "id": "string",
    "type": "sale",
    "date": "2023-08-01T12:30:00.000Z",
    "description": "string",
    "entityId": "sale-123",
    "amountCdf": 150000.00,
    "amountUsd": 75.00,
    "relatedPartyId": "customer-456",
    "relatedPartyName": "Entreprise ABC",
    "status": "completed",
    "paymentMethod": "cash",
    "products": [
      {
        "productId": "string",
        "name": "string",
        "quantity": 3,
        "unitPrice": 50000.00,
        "totalPrice": 150000.00
      }
    ],
    "notes": "string",
    "createdBy": "user-789",
    "createdAt": "2023-08-01T12:30:00.000Z",
    "updatedAt": "2023-08-01T12:30:00.000Z"
  }
}
```

### 5. Obtenir la chronologie des opérations récentes

**Status**: ✅ **Implémenté**

**Endpoint**: `GET /commerce/api/v1/operations/timeline`

**Service**: `OperationsApiService.getOperationsTimeline()`

**Description**: Récupère une chronologie des opérations récentes pour affichage dans l'interface utilisateur.

**Alternative locale**: `OperationJournalRepository.getRecentEntries(limit: 5)` pour les opérations récentes du journal (mode offline).

**Paramètres de requête (Query Params)**:
- `limit` (optionnel): Nombre d'opérations à récupérer, défaut: 10

**Réponse réussie (200)**:
```json
{
  "status": "success",
  "data": {
    "items": [
      {
        "id": "string",
        "type": "sale",
        "date": "2023-08-01T12:30:00.000Z",
        "description": "Vente à Entreprise ABC",
        "amountCdf": 150000.00,
        "relatedPartyName": "Entreprise ABC",
        "status": "completed",
        "timeAgo": "il y a 2 heures"
      }
    ]
  }
}
```
