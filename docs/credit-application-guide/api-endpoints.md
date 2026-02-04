# Points d'API pour la Gestion des Demandes de Crédit

Ce document présente les différents points d'API disponibles pour interagir avec le microservice portfolio-institution-service concernant les demandes de crédit et la gestion des contrats.

## Base URL

```
https://api.wanzobe.com/portfolio_inst/portfolios/traditional/
```

## Authentification

Toutes les requêtes doivent inclure un token JWT valide dans l'en-tête d'autorisation :

```
Authorization: Bearer <token>
```

## 1. API pour les Demandes de Crédit (Funding Requests)

### 1.1. Créer une nouvelle demande de crédit

**Endpoint :** `POST /funding-requests`

**Corps de la requête :**
```json
{
  "portfolio_id": "uuid",
  "client_id": "uuid",
  "company_name": "string",
  "product_type": "string",
  "amount": 1000000.00,
  "currency": "XOF",
  "purpose": "string",
  "duration": 12,
  "duration_unit": "months",
  "proposed_start_date": "2025-08-01",
  "financial_data": {
    "annual_revenue": 5000000.00,
    "net_profit": 1000000.00,
    "existing_debts": 500000.00,
    "cash_flow": 800000.00,
    "assets": 10000000.00,
    "liabilities": 3000000.00
  },
  "proposed_guarantees": [
    {
      "type": "real_estate",
      "description": "Bâtiment commercial à Dakar",
      "value": 5000000.00,
      "currency": "XOF"
    }
  ]
}
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "request_number": "FR-2025-0001",
    "portfolio_id": "uuid",
    "client_id": "uuid",
    "company_name": "string",
    "product_type": "string",
    "amount": 1000000.00,
    "currency": "XOF",
    "purpose": "string",
    "duration": 12,
    "duration_unit": "months",
    "proposed_start_date": "2025-08-01",
    "status": "pending",
    "created_at": "2025-07-29T12:34:56Z",
    "updated_at": "2025-07-29T12:34:56Z"
  }
}
```

### 1.2. Obtenir toutes les demandes de crédit

**Endpoint :** `GET /funding-requests`

**Paramètres de requête :**
- `portfolioId` (optionnel) - Filtrer par ID de portefeuille
- `status` (optionnel) - Filtrer par statut (`pending`, `under_review`, `approved`, `rejected`, `canceled`, `disbursed`)
- `clientId` (optionnel) - Filtrer par ID client
- `productType` (optionnel) - Filtrer par type de produit
- `dateFrom` (optionnel) - Date de début pour filtrer par période de création
- `dateTo` (optionnel) - Date de fin pour filtrer par période de création
- `search` (optionnel) - Recherche textuelle
- `sortBy` (optionnel) - Champ de tri (`created_at`, `amount`, `client_name`)
- `sortOrder` (optionnel) - Ordre de tri (`asc`, `desc`)

**Réponse :**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "request_number": "FR-2025-0001",
      "portfolio_id": "uuid",
      "client_id": "uuid",
      "company_name": "string",
      "product_type": "string",
      "amount": 1000000.00,
      "currency": "XOF",
      "status": "pending",
      "created_at": "2025-07-29T12:34:56Z"
    }
    // ... autres demandes
  ]
}
```

### 1.3. Obtenir une demande de crédit par ID

**Endpoint :** `GET /funding-requests/{id}`

**Paramètres de chemin :**
- `id` - ID de la demande de crédit

**Réponse :**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "request_number": "FR-2025-0001",
    "portfolio_id": "uuid",
    "client_id": "uuid",
    "company_name": "string",
    "product_type": "string",
    "amount": 1000000.00,
    "currency": "XOF",
    "purpose": "string",
    "duration": 12,
    "duration_unit": "months",
    "proposed_start_date": "2025-08-01",
    "status": "pending",
    "status_date": "2025-07-29T12:34:56Z",
    "assigned_to": "uuid",
    "contract_id": null,
    "financial_data": {
      "annual_revenue": 5000000.00,
      "net_profit": 1000000.00,
      "existing_debts": 500000.00,
      "cash_flow": 800000.00,
      "assets": 10000000.00,
      "liabilities": 3000000.00
    },
    "proposed_guarantees": [
      {
        "type": "real_estate",
        "description": "Bâtiment commercial à Dakar",
        "value": 5000000.00,
        "currency": "XOF"
      }
    ],
    "created_at": "2025-07-29T12:34:56Z",
    "updated_at": "2025-07-29T12:34:56Z"
  }
}
```

### 1.4. Mettre à jour une demande de crédit

**Endpoint :** `PUT /funding-requests/{id}`

**Paramètres de chemin :**
- `id` - ID de la demande de crédit

**Corps de la requête :**
```json
{
  "product_type": "string",
  "amount": 1200000.00,
  "currency": "XOF",
  "purpose": "string mis à jour",
  "duration": 18,
  "duration_unit": "months",
  "proposed_start_date": "2025-09-01",
  "financial_data": {
    "annual_revenue": 5500000.00,
    "net_profit": 1100000.00,
    "existing_debts": 450000.00,
    "cash_flow": 850000.00,
    "assets": 10500000.00,
    "liabilities": 2800000.00
  },
  "proposed_guarantees": [
    {
      "type": "real_estate",
      "description": "Bâtiment commercial à Dakar - Mise à jour",
      "value": 5500000.00,
      "currency": "XOF"
    }
  ]
}
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "request_number": "FR-2025-0001",
    // ... autres champs mis à jour
    "updated_at": "2025-07-29T13:45:56Z"
  }
}
```

### 1.5. Mettre à jour le statut d'une demande de crédit

**Endpoint :** `PUT /funding-requests/{id}/status`

**Paramètres de chemin :**
- `id` - ID de la demande de crédit

**Corps de la requête :**
```json
{
  "status": "under_review",
  "notes": "Demande en cours d'examen par l'équipe de crédit"
}
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "request_number": "FR-2025-0001",
    "status": "under_review",
    "status_date": "2025-07-29T14:00:00Z",
    // ... autres champs
    "updated_at": "2025-07-29T14:00:00Z"
  }
}
```

### 1.6. Supprimer une demande de crédit

**Endpoint :** `DELETE /funding-requests/{id}`

**Paramètres de chemin :**
- `id` - ID de la demande de crédit

**Réponse :**
```json
{
  "success": true,
  "message": "Funding request deleted successfully"
}
```

## 2. API pour les Contrats (Contracts)

### 2.1. Créer un contrat à partir d'une demande approuvée

**Endpoint :** `POST /credit-contracts/from-request`

**Corps de la requête :**
```json
{
  "fundingRequestId": "uuid",
  "startDate": "2025-08-01",
  "endDate": "2026-08-01",
  "interestRate": 10.5,
  "interestType": "fixed",
  "frequency": "monthly",
  "specialTerms": "string",
  "amortizationType": "constant",
  "gracePeriod": 3,
  "balloonPayment": 200000.00,
  "guarantees": [
    {
      "type": "real_estate",
      "description": "Bâtiment commercial à Dakar",
      "value": 5000000.00,
      "currency": "XOF",
      "status": "validated"
    }
  ]
}
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "contract_number": "CNT-2025-0001",
    "portfolio_id": "uuid",
    "funding_request_id": "uuid",
    "client_id": "uuid",
    "principal_amount": 1000000.00,
    "interest_rate": 10.5,
    "interest_type": "fixed",
    "term": 12,
    "term_unit": "months",
    "start_date": "2025-08-01",
    "end_date": "2026-08-01",
    "status": "draft",
    "payment_frequency": "monthly",
    "amortization_type": "constant",
    "guarantees": [
      {
        "type": "real_estate",
        "description": "Bâtiment commercial à Dakar",
        "value": 5000000.00,
        "currency": "XOF",
        "status": "validated"
      }
    ],
    "created_at": "2025-07-29T15:30:00Z",
    "updated_at": "2025-07-29T15:30:00Z"
  }
}
```

### 2.2. Obtenir tous les contrats

**Endpoint :** `GET /credit-contracts`

**Paramètres de requête :**
- `portfolioId` (optionnel) - Filtrer par ID de portefeuille
- `status` (optionnel) - Filtrer par statut
- `clientId` (optionnel) - Filtrer par ID client
- `productType` (optionnel) - Filtrer par type de produit
- `dateFrom` (optionnel) - Date de début pour filtrer par période de création
- `dateTo` (optionnel) - Date de fin pour filtrer par période de création
- `search` (optionnel) - Recherche textuelle
- `sortBy` (optionnel) - Champ de tri
- `sortOrder` (optionnel) - Ordre de tri (`asc`, `desc`)

**Réponse :**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "contract_number": "CNT-2025-0001",
      "portfolio_id": "uuid",
      "client_id": "uuid",
      "principal_amount": 1000000.00,
      "interest_rate": 10.5,
      "term": 12,
      "term_unit": "months",
      "start_date": "2025-08-01",
      "end_date": "2026-08-01",
      "status": "draft",
      "created_at": "2025-07-29T15:30:00Z"
    }
    // ... autres contrats
  ]
}
```

### 2.3. Obtenir un contrat par ID

**Endpoint :** `GET /credit-contracts/{id}`

**Paramètres de chemin :**
- `id` - ID du contrat

**Réponse :**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "contract_number": "CNT-2025-0001",
    "portfolio_id": "uuid",
    "funding_request_id": "uuid",
    "client_id": "uuid",
    "principal_amount": 1000000.00,
    "interest_rate": 10.5,
    "interest_type": "fixed",
    "term": 12,
    "term_unit": "months",
    "start_date": "2025-08-01",
    "end_date": "2026-08-01",
    "status": "draft",
    "payment_frequency": "monthly",
    "disbursed_amount": null,
    "outstanding_balance": 1000000.00,
    "total_interest_due": 105000.00,
    "total_paid_to_date": 0.00,
    "amortization_type": "constant",
    "guarantees": [
      {
        "type": "real_estate",
        "description": "Bâtiment commercial à Dakar",
        "value": 5000000.00,
        "currency": "XOF",
        "status": "validated"
      }
    ],
    "created_at": "2025-07-29T15:30:00Z",
    "updated_at": "2025-07-29T15:30:00Z"
  }
}
```

### 2.4. Mettre à jour un contrat

**Endpoint :** `PUT /credit-contracts/{id}`

**Paramètres de chemin :**
- `id` - ID du contrat

**Corps de la requête :**
```json
{
  "interest_rate": 11.0,
  "interest_type": "fixed",
  "payment_frequency": "monthly",
  "amortization_type": "constant",
  "guarantees": [
    {
      "type": "real_estate",
      "description": "Bâtiment commercial à Dakar - Mise à jour",
      "value": 5500000.00,
      "currency": "XOF",
      "status": "validated"
    }
  ]
}
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "contract_number": "CNT-2025-0001",
    // ... autres champs mis à jour
    "updated_at": "2025-07-29T16:15:00Z"
  }
}
```

### 2.5. Activer un contrat

**Endpoint :** `POST /credit-contracts/{id}/activate`

**Paramètres de chemin :**
- `id` - ID du contrat

**Réponse :**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "contract_number": "CNT-2025-0001",
    "status": "active",
    // ... autres champs
    "updated_at": "2025-07-29T16:30:00Z"
  }
}
```

### 2.6. Suspendre un contrat

**Endpoint :** `POST /credit-contracts/{id}/suspend`

**Paramètres de chemin :**
- `id` - ID du contrat

**Corps de la requête :**
```json
{
  "reason": "Retards de paiement récurrents"
}
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "contract_number": "CNT-2025-0001",
    "status": "suspended",
    "suspension_reason": "Retards de paiement récurrents",
    "suspension_date": "2025-07-29T16:45:00Z",
    // ... autres champs
    "updated_at": "2025-07-29T16:45:00Z"
  }
}
```

### 2.7. Marquer un contrat comme en défaut

**Endpoint :** `POST /credit-contracts/{id}/default`

**Paramètres de chemin :**
- `id` - ID du contrat

**Corps de la requête :**
```json
{
  "reason": "Non-paiement de 3 échéances consécutives"
}
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "contract_number": "CNT-2025-0001",
    "status": "defaulted",
    // ... autres champs
    "updated_at": "2025-07-29T17:00:00Z"
  }
}
```

### 2.8. Restructurer un contrat

**Endpoint :** `POST /credit-contracts/{id}/restructure`

**Paramètres de chemin :**
- `id` - ID du contrat

**Corps de la requête :**
```json
{
  "new_term": 18,
  "new_interest_rate": 12.0,
  "restructuring_reason": "Difficultés financières temporaires du client"
}
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "contract_number": "CNT-2025-0001",
    "status": "restructured",
    "restructured_date": "2025-07-29T17:15:00Z",
    // ... autres champs mis à jour
    "updated_at": "2025-07-29T17:15:00Z"
  }
}
```

### 2.9. Marquer un contrat comme en contentieux

**Endpoint :** `POST /credit-contracts/{id}/litigation`

**Paramètres de chemin :**
- `id` - ID du contrat

**Corps de la requête :**
```json
{
  "reason": "Refus de coopération du client"
}
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "contract_number": "CNT-2025-0001",
    "status": "litigation",
    "litigation_reason": "Refus de coopération du client",
    "litigation_date": "2025-07-29T17:30:00Z",
    // ... autres champs
    "updated_at": "2025-07-29T17:30:00Z"
  }
}
```

### 2.10. Marquer un contrat comme terminé

**Endpoint :** `POST /credit-contracts/{id}/complete`

**Paramètres de chemin :**
- `id` - ID du contrat

**Réponse :**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "contract_number": "CNT-2025-0001",
    "status": "completed",
    // ... autres champs
    "updated_at": "2025-07-29T17:45:00Z"
  }
}
```

## 3. API pour les Échéanciers de Paiement

### 3.1. Obtenir l'échéancier d'un contrat

**Endpoint :** `GET /credit-contracts/{id}/schedule`

**Paramètres de chemin :**
- `id` - ID du contrat

**Réponse :**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "contract_id": "uuid",
      "installment_number": 1,
      "due_date": "2025-09-01",
      "principal_amount": 80000.00,
      "interest_amount": 8750.00,
      "total_amount": 88750.00,
      "remaining_amount": 88750.00,
      "status": "pending",
      "created_at": "2025-07-29T15:30:00Z",
      "updated_at": "2025-07-29T15:30:00Z"
    },
    // ... autres échéances
  ]
}
```

## 4. API pour les Déboursements

### 4.1. Créer un déboursement

**Endpoint :** `POST /credit-contracts/{id}/disbursements`

**Paramètres de chemin :**
- `id` - ID du contrat

**Corps de la requête :**
```json
{
  "amount": 1000000.00,
  "disbursement_date": "2025-08-10",
  "disbursement_method": "bank_transfer",
  "transaction_reference": "TRF123456",
  "notes": "Déboursement initial du prêt",
  "bank_details": {
    "bank_name": "Banque XYZ",
    "account_number": "123456789",
    "account_name": "Entreprise ABC"
  }
}
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "contract_id": "uuid",
    "amount": 1000000.00,
    "disbursement_date": "2025-08-10",
    "disbursement_method": "bank_transfer",
    "transaction_reference": "TRF123456",
    "notes": "Déboursement initial du prêt",
    "bank_details": {
      "bank_name": "Banque XYZ",
      "account_number": "123456789",
      "account_name": "Entreprise ABC"
    },
    "created_at": "2025-07-29T18:00:00Z",
    "updated_at": "2025-07-29T18:00:00Z"
  }
}
```

### 4.2. Obtenir tous les déboursements d'un contrat

**Endpoint :** `GET /credit-contracts/{id}/disbursements`

**Paramètres de chemin :**
- `id` - ID du contrat

**Réponse :**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "contract_id": "uuid",
      "amount": 1000000.00,
      "disbursement_date": "2025-08-10",
      "disbursement_method": "bank_transfer",
      "transaction_reference": "TRF123456",
      "created_at": "2025-07-29T18:00:00Z"
    }
    // ... autres déboursements
  ]
}
```

## 5. API pour les Remboursements

### 5.1. Enregistrer un remboursement

**Endpoint :** `POST /credit-contracts/{id}/repayments`

**Paramètres de chemin :**
- `id` - ID du contrat

**Corps de la requête :**
```json
{
  "payment_date": "2025-09-01",
  "amount": 88750.00,
  "payment_method": "bank_transfer",
  "transaction_reference": "TRF789012",
  "notes": "Paiement de la première échéance",
  "allocation": [
    {
      "schedule_id": "uuid",
      "amount": 88750.00
    }
  ]
}
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "contract_id": "uuid",
    "payment_date": "2025-09-01",
    "amount": 88750.00,
    "payment_method": "bank_transfer",
    "transaction_reference": "TRF789012",
    "notes": "Paiement de la première échéance",
    "allocation": [
      {
        "schedule_id": "uuid",
        "amount": 88750.00
      }
    ],
    "created_at": "2025-07-29T18:15:00Z",
    "updated_at": "2025-07-29T18:15:00Z"
  }
}
```

### 5.2. Obtenir tous les remboursements d'un contrat

**Endpoint :** `GET /credit-contracts/{id}/repayments`

**Paramètres de chemin :**
- `id` - ID du contrat

**Réponse :**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "contract_id": "uuid",
      "payment_date": "2025-09-01",
      "amount": 88750.00,
      "payment_method": "bank_transfer",
      "transaction_reference": "TRF789012",
      "created_at": "2025-07-29T18:15:00Z"
    }
    // ... autres remboursements
  ]
}
```

## 6. Codes d'Erreur

| Code HTTP | Description | Cas d'utilisation |
|-----------|-------------|-------------------|
| 400       | Bad Request | Requête mal formée, validation échouée |
| 401       | Unauthorized | Token d'authentification manquant ou invalide |
| 403       | Forbidden | Permissions insuffisantes pour l'opération |
| 404       | Not Found | Ressource non trouvée |
| 409       | Conflict | Conflit avec l'état actuel de la ressource |
| 422       | Unprocessable Entity | Requête bien formée mais données invalides |
| 500       | Internal Server Error | Erreur serveur interne |

## 7. Limites et Considérations

- **Rate Limiting :** Les API sont soumises à des limites de taux. Le rate limit par défaut est de 100 requêtes par minute par clé API.
- **Pagination :** Les endpoints qui retournent des listes prennent en charge la pagination avec les paramètres `page` et `limit`.
- **Cohérence Éventuelle :** Les opérations asynchrones peuvent prendre un certain temps à se propager dans le système.
- **Versionnement :** La version actuelle de l'API est v1. Spécifiez la version dans l'en-tête `Accept` : `application/json;version=1`.
