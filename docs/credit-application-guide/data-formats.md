# Formats de Données pour les Demandes de Crédit

Ce document détaille les structures de données requises pour la soumission des demandes de crédit et la gestion des contrats.

## 1. Structure de la Demande de Crédit (Funding Request)

Lors de la soumission d'une nouvelle demande de crédit, votre application doit envoyer les données suivantes :

```json
{
  "portfolio_id": "uuid",              // ID du portefeuille (obligatoire)
  "client_id": "uuid",                 // ID du client (obligatoire)
  "company_name": "string",            // Nom de l'entreprise (obligatoire)
  "product_type": "string",            // Type de produit financier (obligatoire)
  "amount": 1000000.00,                // Montant demandé (obligatoire)
  "currency": "XOF",                   // Devise (optionnel, par défaut "XOF")
  "purpose": "string",                 // Objet du financement (optionnel)
  "duration": 12,                      // Durée du prêt (obligatoire)
  "duration_unit": "months",           // Unité de durée (optionnel, valeurs: "days", "weeks", "months", "years", par défaut "months")
  "proposed_start_date": "2025-08-01", // Date de début proposée (optionnel)
  "financial_data": {                  // Données financières (optionnel)
    "annual_revenue": 5000000.00,
    "net_profit": 1000000.00,
    "existing_debts": 500000.00,
    "cash_flow": 800000.00,
    "assets": 10000000.00,
    "liabilities": 3000000.00
  },
  "proposed_guarantees": [             // Garanties proposées (optionnel)
    {
      "type": "real_estate",           // Type de garantie
      "description": "Bâtiment commercial à Dakar",
      "value": 5000000.00,             // Valeur de la garantie
      "currency": "XOF"                // Devise de la garantie
    }
  ]
}
```

### Types de Garanties Acceptés

- `real_estate` - Biens immobiliers
- `movable_property` - Biens mobiliers
- `financial_security` - Titres financiers
- `personal_guarantee` - Caution personnelle
- `third_party_guarantee` - Garantie tierce partie
- `cash_collateral` - Garantie en espèces
- `insurance` - Assurance
- `other` - Autre (à préciser dans la description)

### Statuts d'une Demande de Crédit

Une demande de crédit peut avoir les statuts suivants :

- `pending` - En attente d'examen
- `under_review` - En cours d'examen
- `approved` - Approuvée
- `rejected` - Rejetée
- `canceled` - Annulée
- `disbursed` - Déboursée (contrat créé)

## 2. Structure du Contrat (Contract)

Lorsqu'une demande de crédit est approuvée, un contrat peut être créé avec les données suivantes :

```json
{
  "fundingRequestId": "uuid",         // ID de la demande de financement (obligatoire)
  "startDate": "2025-08-01",          // Date de début du contrat (obligatoire)
  "endDate": "2026-08-01",            // Date de fin du contrat (optionnel, calculée automatiquement si non fournie)
  "interestRate": 10.5,               // Taux d'intérêt (obligatoire)
  "interestType": "fixed",            // Type d'intérêt (optionnel, valeurs: "fixed", "variable")
  "frequency": "monthly",             // Fréquence de paiement (obligatoire, valeurs: "monthly", "quarterly", "biannual", "annual")
  "specialTerms": "string",           // Conditions spéciales (optionnel)
  "amortizationType": "constant",     // Type d'amortissement (obligatoire, valeurs: "constant", "degressive", "balloon", "bullet", "custom")
  "gracePeriod": 3,                   // Période de grâce en nombre de périodes (optionnel)
  "balloonPayment": 200000.00,        // Paiement ballon à la fin (optionnel, utilisé avec amortizationType "balloon")
  "guarantees": [                     // Garanties (optionnel, peut reprendre les garantees proposées ou les modifier)
    {
      "type": "real_estate",
      "description": "Bâtiment commercial à Dakar",
      "value": 5000000.00,
      "currency": "XOF",
      "status": "validated"           // Statut de la garantie
    }
  ]
}
```

### Statuts d'un Contrat

Un contrat peut avoir les statuts suivants :

- `draft` - Brouillon
- `active` - Actif
- `suspended` - Suspendu
- `restructured` - Restructuré
- `litigation` - En contentieux
- `defaulted` - En défaut
- `completed` - Terminé
- `canceled` - Annulé

### Types d'Amortissement

- `constant` - Amortissement constant (échéances égales)
- `degressive` - Amortissement dégressif (principal constant, intérêts variables)
- `balloon` - Amortissement avec paiement ballon à la fin
- `bullet` - Amortissement in fine (principal payé intégralement à la fin)
- `custom` - Amortissement personnalisé (nécessite un échéancier détaillé)

## 3. Structure de l'Échéancier de Paiement

L'échéancier de paiement est généré automatiquement lors de la création du contrat, mais il peut être consulté via l'API :

```json
[
  {
    "installment_number": 1,           // Numéro d'échéance
    "due_date": "2025-09-01",          // Date d'échéance
    "principal_amount": 80000.00,      // Montant en principal
    "interest_amount": 8750.00,        // Montant des intérêts
    "total_amount": 88750.00,          // Montant total
    "remaining_amount": 88750.00,      // Montant restant à payer
    "status": "pending"                // Statut de l'échéance
  },
  // ... autres échéances
]
```

### Statuts d'une Échéance

- `pending` - En attente de paiement
- `partially_paid` - Partiellement payée
- `paid` - Intégralement payée
- `late` - En retard
- `defaulted` - En défaut

## 4. Structure d'un Déboursement

```json
{
  "contract_id": "uuid",              // ID du contrat (obligatoire)
  "amount": 1000000.00,               // Montant déboursé (obligatoire)
  "disbursement_date": "2025-08-10",  // Date du déboursement (obligatoire)
  "disbursement_method": "bank_transfer", // Méthode de déboursement (obligatoire)
  "transaction_reference": "string",  // Référence de la transaction (optionnel)
  "notes": "string",                  // Notes (optionnel)
  "bank_details": {                   // Détails bancaires (optionnel)
    "bank_name": "string",
    "account_number": "string",
    "account_name": "string"
  }
}
```

## 5. Structure d'un Remboursement

```json
{
  "contract_id": "uuid",              // ID du contrat (obligatoire)
  "payment_date": "2025-09-01",       // Date du paiement (obligatoire)
  "amount": 88750.00,                 // Montant payé (obligatoire)
  "payment_method": "bank_transfer",  // Méthode de paiement (obligatoire)
  "transaction_reference": "string",  // Référence de la transaction (optionnel)
  "notes": "string",                  // Notes (optionnel)
  "allocation": [                     // Allocation du paiement (optionnel, si non fourni, allocation automatique)
    {
      "schedule_id": "uuid",          // ID de l'échéance
      "amount": 88750.00              // Montant alloué à cette échéance
    }
  ]
}
```

## Validation des Données

Toutes les données envoyées à l'API sont validées selon les règles suivantes :

1. Les champs marqués comme obligatoires doivent être présents et non nuls.
2. Les types de données doivent correspondre à ceux indiqués (string, number, array, etc.).
3. Les montants doivent être positifs.
4. Les dates doivent être au format ISO 8601 (YYYY-MM-DD ou YYYY-MM-DDTHH:MM:SSZ).
5. Les identifiants (UUID) doivent être au format UUID v4.
