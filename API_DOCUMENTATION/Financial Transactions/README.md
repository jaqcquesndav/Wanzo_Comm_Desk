# API Transactions Financières

Cette documentation détaille les endpoints disponibles pour la gestion des transactions financières dans l'application Wanzo.

## Types de Transactions (TransactionType)

Les types de transactions sont représentés par des chaînes de caractères dans les requêtes et réponses API:

| Type | Valeur API | Description |
|------|------------|-------------|
| Vente | `sale` | Transaction de vente |
| Achat | `purchase` | Achat auprès d'un fournisseur |
| Paiement client | `customer_payment` | Paiement reçu d'un client |
| Paiement fournisseur | `supplier_payment` | Paiement effectué à un fournisseur |
| Remboursement | `refund` | Remboursement à un client |
| Dépense | `expense` | Dépense générale |
| Paie | `payroll` | Paie des employés |
| Taxes | `tax_payment` | Paiement des taxes |
| Transfert | `transfer` | Transfert entre comptes |
| Autre | `other` | Autre transaction |

## Statuts de Transactions (TransactionStatus)

Les statuts de transactions sont représentés par des chaînes de caractères:

| Statut | Valeur API | Description |
|--------|------------|-------------|
| En attente | `pending` | Transaction en attente de traitement |
| Terminée | `completed` | Transaction finalisée avec succès |
| Échouée | `failed` | Transaction échouée |
| Annulée | `voided` | Transaction annulée/void |
| Remboursée | `refunded` | Transaction entièrement remboursée |
| Partiellement remboursée | `partially_refunded` | Transaction partiellement remboursée |
| En attente d'approbation | `pending_approval` | Transaction nécessitant une approbation |

## Méthodes de Paiement (PaymentMethod)

Les méthodes de paiement disponibles:

| Méthode | Valeur API | Description |
|---------|------------|-------------|
| Espèces | `cash` | Paiement en espèces |
| Virement | `bank_transfer` | Virement bancaire |
| Chèque | `check` | Paiement par chèque |
| Carte crédit | `credit_card` | Carte de crédit |
| Carte débit | `debit_card` | Carte de débit |
| Mobile Money | `mobile_money` | Orange Money, Wave, M-Pesa, etc. |
| PayPal | `paypal` | PayPal |
| Autre | `other` | Autre méthode |

## Structure du modèle Transaction Financière

```json
{
  "id": "string",                           // Identifiant unique de la transaction (UUID)
  "referenceNumber": "TRX-2025-0001",       // Numéro de référence unique
  "transactionDate": "2023-08-01T12:30:00.000Z", // Date de la transaction (format ISO8601)
  "amount": 150.00,                         // Montant de la transaction (decimal 15,2)
  "transactionType": "sale",                // Type de transaction (voir TransactionType)
  "description": "string",                  // Description de la transaction (optionnel)
  "paymentMethod": "cash",                  // Méthode de paiement (voir PaymentMethod, optionnel)
  "status": "completed",                    // Statut de la transaction (voir TransactionStatus)
  "notes": "string",                        // Notes additionnelles (optionnel)
  
  // === Relations (optionnelles) ===
  "customerId": "uuid-customer",            // ID du client associé (optionnel)
  "supplierId": "uuid-supplier",            // ID du fournisseur associé (optionnel)
  "relatedDocumentId": "string",            // ID du document lié (facture, commande, etc.)
  "relatedDocumentType": "string",          // Type: "invoice", "expense", "sale", etc.
  "relatedDocumentNumber": "FACT-2025-0124", // Numéro du document associé (optionnel)
  
  // === Champs d'Unité d'Affaires (Business Unit) ===
  "companyId": "uuid-company",              // Identifiant de l'entreprise principale (société mère)
  "businessUnitId": "uuid-bu",              // Identifiant de l'unité commerciale
  "businessUnitCode": "POS-KIN-001",        // Code unique de l'unité commerciale
  "businessUnitType": "pos",                // Type d'unité: "company", "branch" ou "pos"
  
  // === Métadonnées ===
  "createdById": "uuid-user",               // ID de l'utilisateur créateur
  "approvedById": "uuid-user",              // ID de l'utilisateur approbateur (optionnel)
  "approvalDate": "2023-08-02T10:00:00.000Z", // Date d'approbation (optionnel)
  "createdAt": "2023-08-01T12:30:00.000Z",  // Date de création
  "updatedAt": "2023-08-01T12:30:00.000Z"   // Date de mise à jour
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

### 1. Récupérer toutes les transactions financières

**Endpoint:** `GET /commerce/api/v1/financial-transactions`

**Paramètres de requête:**
- `page` (optionnel): Numéro de page pour la pagination (défaut: 1)
- `limit` (optionnel): Nombre d'éléments par page (défaut: 10)
- `sortBy` (optionnel): Champ à utiliser pour le tri (défaut: `transactionDate`)
- `sortOrder` (optionnel): Ordre de tri - `ASC` ou `DESC` (défaut: `DESC`)
- `dateFrom` (optionnel): Date de début de la période au format ISO8601
- `dateTo` (optionnel): Date de fin de la période au format ISO8601
- `transactionTypes[]` (optionnel): Types de transactions à inclure (tableau, voir TransactionType)
- `statuses[]` (optionnel): Statuts de transactions à inclure (tableau, voir TransactionStatus)
- `paymentMethods[]` (optionnel): Méthodes de paiement à inclure (tableau, voir PaymentMethod)
- `customerId` (optionnel): Filtrer par ID du client
- `supplierId` (optionnel): Filtrer par ID du fournisseur
- `minAmount` (optionnel): Montant minimum
- `maxAmount` (optionnel): Montant maximum
- `currency` (optionnel): Devise (ex: `XOF`)
- `searchTerm` (optionnel): Rechercher dans la description
- `categoryIds[]` (optionnel): IDs des catégories de transaction
- `companyId` (optionnel): Filtrer par ID d'entreprise (défaut: entreprise de l'utilisateur)
- `businessUnitId` (optionnel): Filtrer par ID d'unité commerciale
- `businessUnitType` (optionnel): Filtrer par type d'unité (`company`, `branch`, `pos`)

**Note sur le filtrage Business Unit:**
- Si `businessUnitId` est fourni, seules les transactions de cette unité seront retournées
- Si non fourni, toutes les transactions de l'entreprise de l'utilisateur seront retournées
- Un utilisateur associé à une succursale (branch) verra également les transactions de ses points de vente enfants

**Réponse:**
```json
{
  "success": true,
  "message": "Financial transactions fetched successfully.",
  "statusCode": 200,
  "data": [
    {
      // Objet transaction financière (voir structure ci-dessus)
    },
    // ... autres transactions
  ]
}
```

### 2. Récupérer une transaction financière par ID

**Endpoint:** `GET /commerce/api/v1/financial-transactions/{id}`

**Paramètres:**
- `id`: ID de la transaction à récupérer

**Réponse:**
```json
{
  "success": true,
  "message": "Financial transaction fetched successfully.",
  "statusCode": 200,
  "data": {
    // Objet transaction financière (voir structure ci-dessus)
  }
}
```

### 3. Créer une nouvelle transaction financière

**Endpoint:** `POST /commerce/api/v1/financial-transactions`

**Corps de la requête:**
```json
{
  // === Champs obligatoires ===
  "transactionDate": "2023-08-01T12:30:00.000Z", // Date de la transaction
  "amount": 150.00,                              // Montant
  "transactionType": "sale",                     // Type (voir TransactionType)
  "status": "completed",                         // Statut (voir TransactionStatus)
  
  // === Champs optionnels ===
  "description": "string",                       // Description de la transaction
  "paymentMethod": "cash",                       // Méthode de paiement (voir PaymentMethod)
  "paymentReference": "CH-123456",               // Référence du paiement (n° chèque, virement, etc.)
  "notes": "string",                             // Notes additionnelles
  
  // === Relations (optionnelles) ===
  "customerId": "uuid-customer",                 // ID client
  "supplierId": "uuid-supplier",                 // ID fournisseur
  "relatedDocumentId": "uuid-document",          // ID du document lié
  "relatedDocumentType": "invoice",              // Type: "invoice", "expense", "sale", etc.
  "relatedDocumentNumber": "FACT-2025-0124",     // Numéro du document associé
  
  // === Comptes et devises (optionnels) ===
  "sourceAccount": "Compte principal",           // Compte source
  "destinationAccount": "Compte fournisseur",    // Compte destination
  "currency": "XOF",                             // Devise (défaut: XOF)
  "exchangeRate": 655.957,                       // Taux de change (si applicable)
  
  // === Pièces jointes et métadonnées (optionnelles) ===
  "attachments": ["https://example.com/doc.pdf"], // URLs des pièces jointes
  "categoryIds": ["uuid-category-1"],            // IDs des catégories associées
  "metadata": { "key": "value" },                // Métadonnées additionnelles
  
  // === Champs d'Unité d'Affaires (optionnels, auto-définis si absents) ===
  "companyId": "uuid-company",                   // Défaut: entreprise de l'utilisateur
  "businessUnitId": "uuid-bu",                   // Défaut: unité de l'utilisateur
  "businessUnitCode": "POS-KIN-001",             // Défaut: code de l'unité de l'utilisateur
  "businessUnitType": "pos"                      // "company", "branch" ou "pos"
}
```

**Réponse:**
```json
{
  "success": true,
  "message": "Financial transaction created successfully.",
  "statusCode": 201,
  "data": {
    // Objet transaction financière créée (voir structure ci-dessus)
  }
}
```

### 4. Mettre à jour une transaction financière

**Endpoint:** `PATCH /commerce/api/v1/financial-transactions/{id}`

**Paramètres:**
- `id`: ID de la transaction à mettre à jour

**Corps de la requête:**
```json
{
  "transactionDate": "2023-08-01T12:30:00.000Z", // Optionnel - Date de la transaction
  "amount": 150.00,                              // Optionnel - Montant
  "description": "string",                       // Optionnel - Description
  "paymentMethod": "cash",                       // Optionnel - Méthode de paiement
  "paymentReference": "CH-123456",               // Optionnel - Référence du paiement
  "status": "completed",                         // Optionnel - Statut
  "notes": "string",                             // Optionnel - Notes
  "attachments": ["https://example.com/doc.pdf"], // Optionnel - Pièces jointes
  "categoryIds": ["uuid-category-1"],            // Optionnel - IDs des catégories
  "metadata": { "key": "value" }                 // Optionnel - Métadonnées
}
```

**Réponse:**
```json
{
  "success": true,
  "message": "Financial transaction updated successfully.",
  "statusCode": 200,
  "data": {
    // Objet transaction financière mise à jour (voir structure ci-dessus)
  }
}
```

### 5. Supprimer une transaction financière

**Endpoint:** `DELETE /commerce/api/v1/financial-transactions/{id}`

**Paramètres:**
- `id`: ID de la transaction à supprimer

**Réponse:**
```json
{
  "success": true,
  "message": "Financial transaction deleted successfully.",
  "statusCode": 200,
  "data": null
}
```

### 6. Récupérer le résumé des transactions financières

**Endpoint:** `GET /commerce/api/v1/financial-transactions/summary`

**Paramètres de requête:**
(Mêmes paramètres de filtrage que pour l'endpoint de liste - voir section 1)

**Réponse:**
```json
{
  "success": true,
  "message": "Financial transactions summary fetched successfully.",
  "statusCode": 200,
  "data": {
    "totalIncome": 5000.00,
    "totalExpense": 2000.00,
    "netAmount": 3000.00,
    "totalCount": 25,
    "typeBreakdown": [
      {
        "type": "income",
        "amount": 5000.00,
        "count": 10
      },
      {
        "type": "expense",
        "amount": 2000.00,
        "count": 15
      }
    ]
  }
}
```

### 7. Mettre à jour le statut d'une transaction

**Endpoint:** `PATCH /commerce/api/v1/financial-transactions/{id}/status`

**Paramètres:**
- `id`: ID de la transaction

**Corps de la requête:**
```json
{
  "status": "completed"  // Nouveau statut (voir TransactionStatus)
}
```

**Réponse:**
```json
{
  "success": true,
  "message": "Transaction status updated successfully.",
  "statusCode": 200,
  "data": {
    // Transaction avec le nouveau statut
  }
}
```

---

## Catégories de Transactions (Transaction Categories)

Les catégories de transactions permettent d'organiser les transactions par type (revenus/dépenses) avec une structure hiérarchique.

### Structure du modèle TransactionCategory

```json
{
  "id": "string",                    // Identifiant unique (UUID)
  "name": "string",                  // Nom de la catégorie
  "description": "string",           // Description (optionnel)
  "code": "string",                  // Code unique de la catégorie
  "transactionType": "income",       // Type: "income", "expense", "both"
  "parentId": "string",              // ID de la catégorie parente (optionnel)
  "isActive": true,                  // Statut actif/inactif
  "companyId": "string",             // ID de l'entreprise
  "createdAt": "string",             // Date de création
  "updatedAt": "string"              // Date de mise à jour
}
```

### 8. Créer une catégorie de transaction

**Endpoint:** `POST /commerce/api/v1/transaction-categories`

**Corps de la requête:**
```json
{
  "name": "string",                  // Obligatoire - Nom
  "description": "string",           // Optionnel - Description
  "code": "string",                  // Obligatoire - Code unique
  "transactionType": "income",       // Obligatoire - "income", "expense", "both"
  "parentId": "string"               // Optionnel - ID catégorie parente
}
```

**Réponse (201 Created):**
```json
{
  "id": "uuid-category",
  "name": "Ventes de produits",
  "code": "SALES-PROD",
  "transactionType": "income",
  "isActive": true
}
```

### 9. Récupérer toutes les catégories

**Endpoint:** `GET /commerce/api/v1/transaction-categories`

**Paramètres de requête:**
- `page` (optionnel): Numéro de page
- `limit` (optionnel): Éléments par page
- `parentId` (optionnel): Filtrer par catégorie parente (null = racine)
- `searchTerm` (optionnel): Recherche par nom
- `includeInactive` (optionnel): Inclure les catégories inactives
- `transactionType` (optionnel): Filtrer par type ("income", "expense", "both")
- `sortBy` (optionnel): Champ de tri
- `sortOrder` (optionnel): "ASC" ou "DESC"

**Réponse:**
```json
{
  "data": [
    {
      "id": "uuid-1",
      "name": "Ventes",
      "code": "SALES",
      "transactionType": "income",
      "isActive": true
    }
  ],
  "total": 10,
  "page": 1,
  "limit": 20
}
```

### 10. Récupérer l'arborescence des catégories

**Endpoint:** `GET /commerce/api/v1/transaction-categories/tree`

**Paramètres de requête:**
- `includeInactive` (optionnel): Inclure les catégories inactives

**Description:** Retourne les catégories sous forme d'arbre hiérarchique.

**Réponse:**
```json
[
  {
    "id": "uuid-1",
    "name": "Ventes",
    "code": "SALES",
    "transactionType": "income",
    "children": [
      {
        "id": "uuid-2",
        "name": "Ventes de produits",
        "code": "SALES-PROD",
        "parentId": "uuid-1",
        "children": []
      },
      {
        "id": "uuid-3",
        "name": "Ventes de services",
        "code": "SALES-SERV",
        "parentId": "uuid-1",
        "children": []
      }
    ]
  }
]
```

### 11. Récupérer une catégorie par ID

**Endpoint:** `GET /commerce/api/v1/transaction-categories/{id}`

**Paramètres:**
- `id`: UUID de la catégorie

**Réponse:**
```json
{
  "id": "uuid-category",
  "name": "Ventes de produits",
  "description": "Catégorie pour les ventes de produits physiques",
  "code": "SALES-PROD",
  "transactionType": "income",
  "parentId": "uuid-parent",
  "isActive": true,
  "createdAt": "2025-01-01T10:00:00.000Z",
  "updatedAt": "2025-01-01T10:00:00.000Z"
}
```

### 12. Mettre à jour une catégorie

**Endpoint:** `PATCH /commerce/api/v1/transaction-categories/{id}`

**Paramètres:**
- `id`: UUID de la catégorie

**Corps de la requête:**
```json
{
  "name": "string",                  // Optionnel
  "description": "string",           // Optionnel
  "code": "string",                  // Optionnel
  "transactionType": "income",       // Optionnel
  "parentId": "string",              // Optionnel
  "isActive": false                  // Optionnel
}
```

**Réponse:**
```json
{
  "id": "uuid-category",
  "name": "Nouveau nom",
  "isActive": false,
  "updatedAt": "2025-01-01T15:30:00.000Z"
}
```

### 13. Supprimer une catégorie

**Endpoint:** `DELETE /commerce/api/v1/transaction-categories/{id}`

**Paramètres:**
- `id`: UUID de la catégorie à supprimer

**⚠️ Attention:** Une catégorie ne peut pas être supprimée si:
- Elle contient des sous-catégories
- Elle est utilisée par des transactions

**Réponse:**
```json
{
  "message": "Catégorie supprimée avec succès"
}
```

**Erreurs:**
- `404 Not Found`: Catégorie non trouvée
- `409 Conflict`: Catégorie contient des sous-catégories ou est utilisée
