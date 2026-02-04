# API Dashboard

Cette documentation détaille les endpoints disponibles pour le tableau de bord (dashboard) dans l'application Wanzo.

## ⚠️ Note d'Architecture

**Architecture Offline-First Implémentée**

Le Dashboard utilise une architecture **offline-first avec synchronisation API optionnelle**:
- **Stockage local**: Hive NoSQL pour accès instantané
- **Calculs en temps réel**: Les KPI sont calculés depuis les données locales (Sales, Customers, Expenses)
- **Mode API**: Les endpoints décrits ci-dessous sont utilisés pour la synchronisation avec le backend (optionnel)
- **Pas de latence réseau**: L'application fonctionne pleinement hors ligne

### Workflow Actuel
```
UI → DashboardApiService → Repositories Locaux (Hive)
                              ├─ SalesRepository
                              ├─ CustomerRepository
                              ├─ ExpenseRepository
                              └─ TransactionRepository
```

### Roadmap API Backend
Les endpoints REST décrits dans cette documentation sont prévus pour:
- Synchronisation multi-appareils
- Backup cloud des données
- Analytics centralisés
- Collaboration en équipe

## Structure du modèle DashboardData

Le modèl6. **Export PDF**: Le journal des opérations peut être exporté en PDF pour les rapports

## Structure de Réponse Standard

Toutes les réponses de l'API Dashboard suivent la structure standard ApiResponse :

```json
{
  "success": boolean,           // Indique si la requête a réussi
  "message": "string",          // Message descriptif du résultat
  "statusCode": number,         // Code de statut HTTP
  "data": any,                  // Données retournées (peut être null)
  "error": "string"             // Message d'erreur détaillé (optionnel)
}
```

## Exemples d'Usage

### Récupérer les données complètes du dashboard
```bash
GET /commerce/api/v1/dashboard/data?date=2023-08-01
```

### Filtrer le journal par type d'opération
```bash
GET /commerce/api/v1/dashboard/operations-journal?type=saleCash&dateFrom=2023-08-01&dateTo=2023-08-31
```

### Récupérer uniquement les ventes du jour
```bash
GET /commerce/api/v1/dashboard/sales-today?date=2023-08-01
``` `DashboardData` représente les indicateurs clés de performance (KPI) affichés sur le tableau de bord principal :

```json
{
  "salesTodayCdf": 1500000.00,     // Montant des ventes du jour en Francs Congolais
  "salesTodayUsd": 750.00,         // Montant des ventes du jour en Dollars US
  "clientsServedToday": 12,        // Nombre de clients uniques servis aujourd'hui
  "receivables": 2500000.00,       // Montant total des créances (à recevoir)
  "expenses": 500000.00            // Total des dépenses du jour
}
```

## Structure du modèle OperationJournalEntry

Le journal des opérations trace toutes les transactions commerciales et financières :

> **✅ Conformité**: Aligné avec `OperationJournalEntry` dans `dashboard.interface.ts`

```json
{
  "id": "string",                          // Identifiant unique de l'opération
  "date": "2023-08-01T12:30:00.000Z",      // Date et heure de l'opération
  "description": "string",                 // Description de l'opération
  "type": "string",                        // Type d'opération (voir énumération ci-dessous)
  "amount": 150000.00,                     // Montant de l'opération (positif pour entrées, négatif pour sorties)
  "currencyCode": "CDF",                   // Code de la devise (CDF, USD, etc.)
  "isDebit": false,                        // Indique si c'est un débit
  "isCredit": true,                        // Indique si c'est un crédit
  "balanceAfter": 2150000.00,              // Solde total après l'opération
  "relatedDocumentId": "string",           // ID du document lié (vente, achat, etc.) - optionnel
  "quantity": 5.0,                         // Quantité pour les mouvements de stock - optionnel
  "productId": "string",                   // ID du produit pour les mouvements de stock - optionnel
  "productName": "string",                 // Nom du produit pour les mouvements de stock - optionnel
  "paymentMethod": "string",               // Méthode de paiement - optionnel
  "balancesByCurrency": {                  // Soldes par devise - optionnel
    "CDF": 2000000.00,
    "USD": 1000.00
  }
}
```

> **Note**: Les informations client/fournisseur peuvent être récupérées via `relatedDocumentId` qui pointe vers la vente ou l'achat concerné.

## Types d'Opérations (OperationType)

Les types d'opérations supportés dans le journal (définis dans `operation-type.enum.ts`):

| Type | Valeur | Description |
|------|--------|-------------|
| Vente Espèce | `saleCash` | Vente payée comptant |
| Vente Crédit | `saleCredit` | Vente à crédit |
| Vente Échelonnée | `saleInstallment` | Vente avec paiements échelonnés |
| Entrée Stock | `stockIn` | Entrée de marchandises en stock |
| Sortie Stock | `stockOut` | Sortie de marchandises du stock |
| Entrée Espèce | `cashIn` | Entrée d'argent en caisse |
| Sortie Espèce | `cashOut` | Sortie d'argent de caisse |
| Paiement Client | `customerPayment` | Paiement reçu d'un client |
| Paiement Fournisseur | `supplierPayment` | Paiement effectué à un fournisseur |
| Demande Financement | `financingRequest` | Demande de financement initiée |
| Financement Approuvé | `financingApproved` | Financement approuvé |
| Remboursement | `financingRepayment` | Remboursement de financement |
| Autre | `other` | Autre type d'opération |
| Tous | `all` | **Filtre spécial** - Récupère tous les types |

> **Note**: La valeur `all` est utilisée uniquement pour le filtrage des opérations et n'est jamais stockée en base.

## Méthodes de Service (Implémentation Actuelle)

Les méthodes suivantes sont implémentées dans `DashboardApiService` et utilisent les données locales:

### 1. Récupérer les données du tableau de bord

**Méthode**: `getDashboardData(DateTime date)` → `ApiResponse<DashboardData>`

**Endpoint**: `GET /commerce/api/v1/dashboard/data`

**Paramètres de requête:**
- `date` (optionnel): Date pour laquelle récupérer les données au format ISO8601 (YYYY-MM-DD). Par défaut : date actuelle

**Réponse:**
```json
{
  "success": true,
  "message": "Données du tableau de bord récupérées avec succès",
  "statusCode": 200,
  "data": {
    // Objet DashboardData (voir structure ci-dessus)
  }
}
```

### 2. Récupérer uniquement les ventes du jour

**Méthode**: `getSalesToday(DateTime date)` → `ApiResponse<Map<String, double>>`

**Endpoint**: `GET /commerce/api/v1/dashboard/sales-today`

**Paramètres de requête:**
- `date` (optionnel): Date pour laquelle récupérer les ventes au format ISO8601 (YYYY-MM-DD)

**Réponse:**
```json
{
  "success": true,
  "message": "Ventes du jour récupérées avec succès",
  "statusCode": 200,
  "data": {
    "cdf": 1500000.00,
    "usd": 750.00
  }
}
```

### 3. Récupérer le nombre de clients servis aujourd'hui

**Méthode**: `getClientsServedToday(DateTime date)` → `ApiResponse<int>`

**Endpoint**: `GET /commerce/api/v1/dashboard/clients-served-today`

**Paramètres de requête:**
- `date` (optionnel): Date pour laquelle récupérer les données

**Réponse:**
```json
{
  "success": true,
  "message": "Nombre de clients servis aujourd'hui récupéré avec succès",
  "statusCode": 200,
  "data": 12
}
```

### 4. Récupérer le total des montants à recevoir

**Méthode**: `getTotalReceivables()` → `ApiResponse<double>`

**Endpoint**: `GET /commerce/api/v1/dashboard/receivables`

**Réponse:**
```json
{
  "success": true,
  "message": "Total des montants à recevoir récupéré avec succès",
  "statusCode": 200,
  "data": 2500000.00
}
```

### 5. Récupérer les dépenses du jour

**Méthode**: `getExpensesToday(DateTime date)` → `ApiResponse<double>`

**Endpoint**: `GET /commerce/api/v1/dashboard/expenses-today`

**Paramètres de requête:**
- `date` (optionnel): Date pour laquelle récupérer les dépenses

**Réponse:**
```json
{
  "success": true,
  "message": "Dépenses du jour récupérées avec succès",
  "statusCode": 200,
  "data": 500000.00
}
```

## Journal des Opérations

Le dashboard inclut également un journal des opérations détaillé qui trace toutes les activités commerciales et financières.

### ✅ Implémentation Complète

Le journal des opérations est **pleinement fonctionnel** avec une architecture hybride offline-first + API:

**Repository**: `OperationJournalRepository`
- Stockage local Hive avec cache persistant
- Synchronisation automatique avec backend (si disponible)
- Support multi-devises (CDF, USD, autres)
- Calcul automatique des soldes par devise
- Gestion intelligente des conflits

**Bloc**: `OperationJournalBloc`
- States: Initial, Loading, Loaded, Error
- Events: LoadOperations, RefreshJournal, AddOperation, AddMultiple
- Écoute connectivité pour auto-sync
- Filtrage et tri avancés

**Service d'Export**: `JournalService`
- Export PDF multi-pages avec pagination
- Formatage localisé (dates, montants)
- Support multi-devises dans le PDF
- En-têtes et pieds de page personnalisés

### 6. Récupérer les entrées du journal des opérations

**Méthode**: `getOperations(DateTime dateFrom, DateTime dateTo)` → `List<OperationJournalEntry>`

**Stratégie hybride**:
1. Lecture immédiate depuis Hive (réponse instantanée)
2. Tentative API avec timeout 5s (si connexion disponible)
3. Fusion données API + locales non synchronisées
4. Persistance automatique des données API
5. Fallback local en cas d'échec réseau

**Endpoint API**: `GET /commerce/api/v1/journal/operations`

**Paramètres de requête:**
- `dateFrom` (optionnel): Date de début au format ISO8601
- `dateTo` (optionnel): Date de fin au format ISO8601
- `type` (optionnel): Filtrer par type d'opération
- `page` (optionnel): Numéro de page pour la pagination
- `limit` (optionnel): Nombre d'éléments par page

**Réponse:**
```json
{
  "success": true,
  "message": "Entrées du journal récupérées avec succès",
  "statusCode": 200,
  "data": [
    {
      // Objets OperationJournalEntry (voir structure ci-dessus)
    }
  ]
}
```

## Notes d'Implémentation

1. **Mise à jour périodique**: Le dashboard se met à jour automatiquement toutes les 5 minutes
2. **Gestion des devises**: Support natif pour CDF et USD avec conversion automatique
3. **Calculs en temps réel**: Les KPI sont calculés dynamiquement à partir des données locales
4. **Gestion hors ligne**: Fonctionnement complet en mode hors ligne avec synchronisation ultérieure
5. **Export PDF**: Le journal des opérations peut être exporté en PDF pour les rapports

**Description**: Récupère les données complètes du tableau de bord pour la date actuelle par défaut.

**Paramètres de requête (Query Params)**:
- `date` (optionnel): Date pour laquelle récupérer les données (format: YYYY-MM-DD)
- `timezone` (optionnel): Fuseau horaire pour les calculs de date

**Réponse réussie (200)**:
```json
{
  "status": "success",
  "data": {
    // Structure complète de DashboardData
  }
}
```

### 2. Récupérer le résumé des ventes

**Endpoint**: `GET /commerce/api/v1/dashboard/sales-summary`

**Description**: Récupère uniquement le résumé des ventes pour une période spécifique.

**Paramètres de requête (Query Params)**:
- `period` (obligatoire): Période pour laquelle récupérer les données (valeurs possibles: "day", "week", "month", "year")
- `date` (optionnel): Date de référence (format: YYYY-MM-DD), défaut: aujourd'hui
- `currency` (optionnel): Devise pour les montants (valeurs possibles: "CDF", "USD", "all"), défaut: "all"

**Réponse réussie (200)**:
```json
{
  "status": "success",
  "data": {
    "period": "week",
    "dateFrom": "2023-07-25",
    "dateTo": "2023-08-01",
    "salesCdf": 7500000.00,
    "salesUsd": 3750.00,
    "transactionCount": 50,
    "averageTransactionCdf": 150000.00,
    "averageTransactionUsd": 75.00,
    "salesByDay": [
      {
        "date": "2023-07-25",
        "amountCdf": 1200000.00,
        "amountUsd": 600.00,
        "count": 8
      }
      // Suite des jours...
    ]
  }
}
```

### 3. Récupérer les statistiques clients

**Endpoint**: `GET /commerce/api/v1/dashboard/customer-stats`

**Description**: Récupère les statistiques des clients pour une période spécifique.

**Paramètres de requête (Query Params)**:
- `period` (obligatoire): Période pour laquelle récupérer les données (valeurs possibles: "day", "week", "month", "year")
- `date` (optionnel): Date de référence (format: YYYY-MM-DD), défaut: aujourd'hui

**Réponse réussie (200)**:
```json
{
  "status": "success",
  "data": {
    "totalCustomers": 45,
    "newCustomers": 3,
    "activeCustomers": 15,
    "inactiveCustomers": 30,
    "averagePurchaseCdf": 150000.00,
    "averagePurchaseUsd": 75.00,
    "topCustomers": [
      {
        "id": "string",
        "name": "string",
        "totalPurchasesCdf": 450000.00,
        "totalPurchasesUsd": 225.00,
        "purchaseCount": 3
      }
      // Suite des clients...
    ]
  }
}
```

### 4. Récupérer les entrées du journal d'opérations

**Endpoint**: `GET /commerce/api/v1/dashboard/operations-journal`

**Description**: Récupère les entrées du journal d'opérations pour une période spécifique.

**Paramètres de requête (Query Params)**:
- `dateFrom` (obligatoire): Date de début (format: YYYY-MM-DD)
- `dateTo` (obligatoire): Date de fin (format: YYYY-MM-DD)
- `type` (optionnel): Type d'opération (valeurs possibles: "sale", "expense", "inventory", "customer", "all"), défaut: "all"
- `page` (optionnel): Numéro de page pour la pagination
- `limit` (optionnel): Nombre d'éléments par page

**Réponse réussie (200)**:
```json
{
  "status": "success",
  "data": {
    "items": [
      {
        "id": "string",
        "date": "2023-08-01T12:30:00.000Z",
        "operationType": "sale",
        "entityId": "string",
        "description": "string",
        "amount": 150000.00,
        "currency": "CDF",
        "userName": "string"
      }
      // Suite des entrées...
    ],
    "totalItems": 120,
    "totalPages": 6,
    "currentPage": 1
  }
}
```

### 5. Exporter le journal des opérations (PDF/CSV)

**Endpoint**: `GET /commerce/api/v1/dashboard/operations-journal/export`

**Description**: Exporte le journal des opérations en format PDF ou CSV pour les rapports.

**Paramètres de requête (Query Params)**:
- `dateFrom` (obligatoire): Date de début (format: YYYY-MM-DD)
- `dateTo` (obligatoire): Date de fin (format: YYYY-MM-DD)
- `type` (optionnel): Type d'opération à filtrer
- `format` (optionnel): Format d'export (`pdf` ou `csv`), défaut: `pdf`

**Réponse réussie (200)**:
- **Content-Type**: `application/pdf` ou `text/csv`
- **Content-Disposition**: `attachment; filename="journal-operations.pdf"` ou `.csv`

**Exemple d'usage**:
```bash
# Export PDF
GET /commerce/api/v1/dashboard/operations-journal/export?dateFrom=2023-08-01&dateTo=2023-08-31&format=pdf

# Export CSV
GET /commerce/api/v1/dashboard/operations-journal/export?dateFrom=2023-08-01&dateTo=2023-08-31&format=csv
```
