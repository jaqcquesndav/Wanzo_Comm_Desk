# API Financement

Cette documentation détaille les endpoints disponibles pour la gestion des demandes de financement dans l'application Wanzo.

## Types de Financements

Les types de financements disponibles dans l'API:

- `businessLoan` - Prêt Entreprise
- `equipmentLoan` - Prêt Équipement
- `workingCapital` - Fonds de Roulement
- `expansionLoan` - Prêt pour Expansion
- `lineOfCredit` - Ligne de Crédit

## Statuts des Demandes de Financement

Les statuts des demandes de financement sont représentés par des chaînes de caractères:

- `draft` - Brouillon
- `submitted` - Soumise
- `underReview` - En Cours d'Évaluation
- `approved` - Approuvée
- `rejected` - Rejetée
- `disbursed` - Décaissée
- `completed` - Terminée
- `cancelled` - Annulée

## Structure du modèle Demande de Financement

```json
{
  "id": "string",                       // Identifiant unique de la demande
  "userId": "string",                   // ID de l'utilisateur propriétaire
  "businessId": "string",               // ID de l'entreprise
  "productId": "string",                // ID du produit de financement
  "type": "businessLoan",               // Type de financement
  "amount": 5000.00,                    // Montant demandé
  "currency": "CDF",                    // Devise (CDF, USD, etc.)
  "term": 12,                           // Durée en mois
  "purpose": "string",                  // Objet du financement
  "status": "submitted",                // Statut de la demande (voir liste ci-dessus)
  "institutionId": "string",            // ID de l'institution financière
  "portfolioFundingRequestId": "string", // ID FundingRequest côté portfolio-institution
  "contractId": "string",               // ID du contrat portfolio-institution
  "portfolioRequestNumber": "string",   // Numéro de référence portfolio
  "applicationDate": "2023-08-01T12:30:00.000Z", // Date de soumission
  "lastStatusUpdateDate": "2023-08-02T10:15:00.000Z", // Date de dernière mise à jour
  "approvalDate": "2023-08-15T14:20:00.000Z",    // Date d'approbation (si applicable)
  "disbursementDate": "2023-08-20T09:45:00.000Z", // Date de décaissement (si applicable)
  "businessInformation": {              // Informations sur l'entreprise
    "name": "string",
    "registrationNumber": "string",
    "address": "string",
    "yearsInBusiness": 3,
    "numberOfEmployees": 10,
    "annualRevenue": 50000.00
  },
  "financialInformation": {             // Informations financières
    "monthlyRevenue": 5000.00,
    "monthlyExpenses": 3000.00,
    "existingLoans": [
      {
        "lender": "string",
        "originalAmount": 10000.00,
        "outstandingBalance": 6000.00,
        "monthlyPayment": 500.00
      }
    ]
  },
  "documents": [                       // Documents soumis
    {
      "id": "string",
      "type": "businessPlan",
      "name": "string",
      "url": "string",
      "uploadDate": "2023-08-01T12:30:00.000Z"
    }
  ],
  "notes": "string",                   // Notes supplémentaires
  
  // ============= SCORE CRÉDIT XGBOOST =============
  "creditScore": 75,                   // Score crédit calculé (1-100)
  "creditScoreCalculatedAt": "2023-08-01T12:30:00.000Z", // Date de calcul
  "creditScoreValidUntil": "2023-08-31T12:30:00.000Z",   // Date d'expiration (validité 30 jours)
  "creditScoreModelVersion": "v1.2.3", // Version du modèle XGBoost
  "riskLevel": "MEDIUM",               // Niveau de risque (LOW/MEDIUM/HIGH)
  "confidenceScore": 0.85,             // Score de confiance du modèle (0-1)
  "creditScoreDataSource": "accounting_transactions_6m", // Source des données
  "creditScoreComponents": {           // Composants détaillés du score
    "cashFlowQuality": 78,             // Qualité des flux de trésorerie
    "businessStability": 82,           // Stabilité de l'entreprise
    "financialHealth": 65,             // Santé financière
    "paymentBehavior": 90,             // Comportement de paiement
    "growthTrend": 70                  // Tendance de croissance
  },
  "creditScoreExplanation": [          // Facteurs explicatifs
    "Flux de trésorerie réguliers détectés",
    "Croissance constante du chiffre d'affaires",
    "Ratio d'endettement acceptable"
  ],
  "creditScoreRecommendations": [      // Recommandations
    "Maintenir la régularité des flux",
    "Diversifier les sources de revenus",
    "Optimiser la gestion de trésorerie"
  ],
  // ================================================
  
  "createdAt": "2023-08-01T12:30:00.000Z", // Date de création
  "updatedAt": "2023-08-01T12:30:00.000Z"  // Date de mise à jour
}
```

## Intégration Machine Learning - Score Crédit XGBoost

Le système intègre un modèle XGBoost qui calcule automatiquement un score de crédit pour chaque demande de financement. Ce score est basé sur l'analyse des transactions comptables des 6 derniers mois.

### Composants du Score

Le score crédit (1-100) est composé de 5 indicateurs :

1. **Cash Flow Quality (cashFlowQuality)** : Analyse la régularité et la qualité des flux de trésorerie
2. **Business Stability (businessStability)** : Évalue la stabilité et la pérennité de l'entreprise
3. **Financial Health (financialHealth)** : Mesure la santé financière globale
4. **Payment Behavior (paymentBehavior)** : Analyse l'historique de paiement des obligations
5. **Growth Trend (growthTrend)** : Évalue la tendance de croissance de l'activité

### Niveaux de Risque

- **LOW** : Score ≥ 75 - Risque faible, recommandé pour approbation
- **MEDIUM** : Score 50-74 - Risque modéré, analyse approfondie requise
- **HIGH** : Score < 50 - Risque élevé, approbation déconseillée

### Cycle de Vie du Score

- **Validité** : 30 jours après calcul
- **Recalcul automatique** : Déclenché si score expiré ou données comptables modifiées
- **Monitoring temps réel** : Alertes générées si changement significatif détecté

## Endpoints

### 1. Récupérer toutes les demandes de financement

**Endpoint**: `GET /api/v1/financing/requests`

**Description**: Récupère la liste de toutes les demandes de financement de l'utilisateur actuel.

**Paramètres de requête (Query Params)**:
- `status` (optionnel): Filtre par statut
- `page` (optionnel): Numéro de page pour la pagination
- `limit` (optionnel): Nombre d'éléments par page

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Financing requests retrieved successfully",
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "businessId": "550e8400-e29b-41d4-a716-446655440002",
      "amount": 5000.00,
      "currency": "CDF",
      "type": "businessLoan",
      "status": "submitted",
      "purpose": "Achat d'équipements",
      "applicationDate": "2025-11-01T10:00:00.000Z",
      "creditScore": 75,
      "riskLevel": "MEDIUM"
    }
  ],
  "pagination": {
    "total": 10,
    "page": 1,
    "limit": 10,
    "totalPages": 1
  },
  "statusCode": 200
}
```

### 2. Récupérer une demande de financement spécifique

**Endpoint**: `GET /api/v1/financing/requests/{id}`

**Description**: Récupère les détails d'une demande de financement spécifique.

**Paramètres de chemin (Path Params)**:
- `id`: L'identifiant unique de la demande de financement

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Financing request retrieved successfully",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "userId": "550e8400-e29b-41d4-a716-446655440001",
    "businessId": "550e8400-e29b-41d4-a716-446655440002",
    "productId": "prod-business-loan-001",
    "type": "businessLoan",
    "amount": 5000.00,
    "currency": "CDF",
    "term": 12,
    "purpose": "Achat d'équipements",
    "status": "approved",
    "institutionId": "550e8400-e29b-41d4-a716-446655440003",
    "portfolioFundingRequestId": "550e8400-e29b-41d4-a716-446655440004",
    "contractId": "550e8400-e29b-41d4-a716-446655440005",
    "portfolioRequestNumber": "FR-2025-001234",
    "applicationDate": "2025-11-01T10:00:00.000Z",
    "lastStatusUpdateDate": "2025-11-15T14:30:00.000Z",
    "approvalDate": "2025-11-15T14:30:00.000Z",
    "disbursementDate": null,
    "businessInformation": {
      "name": "Wanzo SARL",
      "registrationNumber": "RC/KIN/2023/12345",
      "address": "123 Avenue des Martyrs, Kinshasa",
      "yearsInBusiness": 3,
      "numberOfEmployees": 10,
      "annualRevenue": 50000.00
    },
    "financialInformation": {
      "monthlyRevenue": 5000.00,
      "monthlyExpenses": 3000.00,
      "existingLoans": []
    },
    "documents": [
      {
        "id": "doc-001",
        "type": "businessPlan",
        "name": "Plan d'affaires 2025.pdf",
        "url": "https://storage.wanzo.cd/documents/doc-001.pdf",
        "uploadDate": "2025-11-01T10:00:00.000Z"
      }
    ],
    "notes": "Client premium avec bon historique",
    "creditScore": 75,
    "creditScoreCalculatedAt": "2025-11-15T12:00:00.000Z",
    "creditScoreValidUntil": "2025-12-15T12:00:00.000Z",
    "creditScoreModelVersion": "v1.2.3",
    "riskLevel": "MEDIUM",
    "confidenceScore": 0.85,
    "creditScoreDataSource": "accounting_transactions_6m",
    "creditScoreComponents": {
      "cashFlowQuality": 78,
      "businessStability": 82,
      "financialHealth": 65,
      "paymentBehavior": 90,
      "growthTrend": 70
    },
    "creditScoreExplanation": [
      "Flux de trésorerie réguliers détectés",
      "Croissance constante du chiffre d'affaires",
      "Ratio d'endettement acceptable"
    ],
    "creditScoreRecommendations": [
      "Maintenir la régularité des flux",
      "Diversifier les sources de revenus",
      "Optimiser la gestion de trésorerie"
    ],
    "createdAt": "2025-11-01T10:00:00.000Z",
    "updatedAt": "2025-11-15T14:30:00.000Z"
  },
  "statusCode": 200
}
```

### 3. Créer une nouvelle demande de financement

**Endpoint**: `POST /api/v1/financing/requests`

**Description**: Crée une nouvelle demande de financement.

**Corps de la requête**:
```json
{
  "productId": "string",
  "amount": 5000.00,
  "currency": "CDF",
  "term": 12,
  "purpose": "string",
  "businessInformation": {
    "name": "string",
    "registrationNumber": "string",
    "address": "string",
    "yearsInBusiness": 3,
    "numberOfEmployees": 10,
    "annualRevenue": 50000.00
  },
  "financialInformation": {
    "monthlyRevenue": 5000.00,
    "monthlyExpenses": 3000.00
  }
}
```

**Réponse réussie (201)**:
```json
{
  "success": true,
  "message": "Financing request created successfully",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "userId": "550e8400-e29b-41d4-a716-446655440001",
    "businessId": "550e8400-e29b-41d4-a716-446655440002",
    "type": "businessLoan",
    "status": "draft",
    "amount": 5000.00,
    "currency": "CDF",
    "term": 12,
    "purpose": "Achat d'équipements",
    "createdAt": "2025-11-01T10:00:00.000Z",
    "updatedAt": "2025-11-01T10:00:00.000Z"
  },
  "statusCode": 201
}
```

### 4. Mettre à jour une demande de financement

**Endpoint**: `PUT /api/v1/financing/requests/{id}`

**Description**: Met à jour une demande de financement existante.

**Paramètres de chemin (Path Params)**:
- `id`: L'identifiant unique de la demande de financement

**Corps de la requête**:
```json
{
  "amount": 6000.00,
  "term": 18,
  "purpose": "string",
  // Autres champs à mettre à jour
}
```

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Financing request updated successfully",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "amount": 6000.00,
    "term": 18,
    "updatedAt": "2025-11-15T14:30:00.000Z"
  },
  "statusCode": 200
}
```

### 5. Soumettre une demande de financement

**Endpoint**: `POST /api/v1/financing/requests/{id}/submit`

**Description**: Change le statut d'une demande de financement de "brouillon" à "soumise".

**Paramètres de chemin (Path Params)**:
- `id`: L'identifiant unique de la demande de financement

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Demande de financement soumise avec succès",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "status": "submitted",
    "applicationDate": "2025-11-01T10:00:00.000Z"
  },
  "statusCode": 200
}
```

### 6. Annuler une demande de financement

**Endpoint**: `POST /api/v1/financing/requests/{id}/cancel`

**Description**: Annule une demande de financement en attente.

**Paramètres de chemin (Path Params)**:
- `id`: L'identifiant unique de la demande de financement

**Corps de la requête**:
```json
{
  "reason": "string" // Raison de l'annulation
}
```

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Demande de financement annulée avec succès",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "status": "cancelled"
  },
  "statusCode": 200
}
```

### 7. Supprimer une demande de financement

**Endpoint**: `DELETE /api/v1/financing/requests/{id}`

**Description**: Supprime une demande de financement (uniquement si statut = draft).

**Paramètres de chemin (Path Params)**:
- `id`: L'identifiant unique de la demande de financement

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Financing request deleted successfully",
  "statusCode": 200
}
```

**Réponse erreur (400)**:
```json
{
  "success": false,
  "message": "Cannot delete financing request with status 'approved'",
  "statusCode": 400
}
```

### 8. Récupérer les produits de financement disponibles

**Endpoint**: `GET /api/v1/financing/products`

**Description**: Récupère la liste des produits de financement disponibles.

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Financing products retrieved successfully",
  "data": {
    "items": [
      {
        "id": "prod-business-loan-001",
        "name": "Prêt Entreprise Standard",
        "description": "Prêt destiné aux PME pour financer leurs activités courantes",
        "provider": "Wanzo Finance",
        "type": "businessLoan",
        "minAmount": 1000.00,
        "maxAmount": 50000.00,
        "term": {
          "min": 3,
          "max": 36
        },
        "interestRate": 15.5,
        "currency": "CDF",
        "requirementsSummary": "Entreprise enregistrée avec minimum 6 mois d'activité",
        "requiredDocuments": ["businessPlan", "financialStatements", "registrationCertificate"]
      },
      {
        "id": "prod-equipment-loan-001",
        "name": "Prêt Équipement",
        "description": "Financement pour l'achat d'équipements professionnels",
        "provider": "Wanzo Finance",
        "type": "equipmentLoan",
        "minAmount": 2000.00,
        "maxAmount": 100000.00,
        "term": {
          "min": 6,
          "max": 48
        },
        "interestRate": 14.0,
        "currency": "CDF",
        "requirementsSummary": "Facture proforma de l'équipement requise",
        "requiredDocuments": ["proformaInvoice", "businessPlan", "financialStatements"]
      },
      {
        "id": "prod-working-capital-001",
        "name": "Fonds de Roulement",
        "description": "Crédit de trésorerie pour financer le cycle d'exploitation",
        "provider": "Wanzo Finance",
        "type": "workingCapital",
        "minAmount": 500.00,
        "maxAmount": 30000.00,
        "term": {
          "min": 1,
          "max": 12
        },
        "interestRate": 16.5,
        "currency": "CDF",
        "requirementsSummary": "Flux de trésorerie des 6 derniers mois requis",
        "requiredDocuments": ["cashFlowStatement", "financialStatements"]
      }
    ]
  },
  "statusCode": 200
}
```
