# API Gestion des Informations de Paiement Entreprise

Cette documentation détaille les endpoints disponibles pour la gestion des comptes bancaires et Mobile Money des entreprises.

## Base URL

Tous les endpoints sont accessibles via: `/companies/:companyId/payment-info`

## Authentification

Tous les endpoints requièrent une authentification JWT valide.

**Header requis**:
```
Authorization: Bearer <jwt_token>
```

---

## Structures de Données

### BankAccountInfo

```json
{
  "id": "string",
  "accountNumber": "string",
  "accountName": "string",
  "bankName": "string",
  "bankCode": "string",
  "branchCode": "string",
  "swiftCode": "string",
  "rib": "string",
  "iban": "string",
  "isDefault": boolean,
  "status": "active" | "inactive" | "suspended",
  "currency": "CDF" | "USD" | "EUR",
  "balance": number,
  "createdAt": "ISO8601",
  "updatedAt": "ISO8601"
}
```

### MobileMoneyAccount

```json
{
  "id": "string",
  "phoneNumber": "string",
  "accountName": "string",
  "operator": "AM" | "OM" | "WAVE" | "MP" | "AF",
  "operatorName": "Airtel Money" | "Orange Money" | "Wave" | "M-Pesa" | "Africell Money",
  "isDefault": boolean,
  "status": "active" | "inactive" | "suspended",
  "verificationStatus": "pending" | "verified" | "failed",
  "currency": "CDF" | "USD",
  "dailyLimit": number,
  "monthlyLimit": number,
  "balance": number,
  "purpose": "disbursement" | "collection" | "general",
  "createdAt": "ISO8601",
  "updatedAt": "ISO8601"
}
```

### Codes Opérateurs Mobile Money

| Code | Opérateur | Nom Complet |
|------|-----------|-------------|
| `AM` | Airtel | Airtel Money |
| `OM` | Orange | Orange Money |
| `WAVE` | Wave | Wave |
| `MP` | Vodacom | M-Pesa |
| `AF` | Africell | Africell Money |

---

## Endpoints

### 1. Récupérer les informations de paiement

**Endpoint**: `GET /companies/:companyId/payment-info`

**Description**: Récupère toutes les informations de paiement d'une entreprise (comptes bancaires, Mobile Money, préférences).

**Paramètres**:
- `companyId` (path, UUID) - ID de l'entreprise

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Payment information retrieved successfully",
  "data": {
    "companyId": "550e8400-e29b-41d4-a716-446655440000",
    "bankAccounts": [
      {
        "id": "ba-001",
        "accountNumber": "CD12345678901234567890",
        "accountName": "Wanzo SARL",
        "bankName": "Rawbank",
        "bankCode": "RAWB",
        "branchCode": "001",
        "swiftCode": "RAWBCDKIN",
        "rib": "CD12 3456 7890 1234 5678 90",
        "iban": null,
        "isDefault": true,
        "status": "active",
        "currency": "CDF",
        "balance": 1500000.00,
        "createdAt": "2025-01-01T10:00:00.000Z",
        "updatedAt": "2025-11-19T10:00:00.000Z"
      }
    ],
    "mobileMoneyAccounts": [
      {
        "id": "mm-001",
        "phoneNumber": "+243812345678",
        "accountName": "Wanzo SARL",
        "operator": "AM",
        "operatorName": "Airtel Money",
        "isDefault": true,
        "status": "active",
        "verificationStatus": "verified",
        "currency": "CDF",
        "dailyLimit": 5000000.00,
        "monthlyLimit": 50000000.00,
        "balance": 250000.00,
        "purpose": "disbursement",
        "createdAt": "2025-01-01T10:00:00.000Z",
        "updatedAt": "2025-11-19T10:00:00.000Z"
      }
    ],
    "paymentPreferences": {
      "preferredMethod": "bank",
      "defaultBankAccountId": "ba-001",
      "defaultMobileMoneyAccountId": "mm-001",
      "allowPartialPayments": true,
      "allowAdvancePayments": false
    }
  },
  "statusCode": 200
}
```

---

### 2. Mettre à jour les informations de paiement

**Endpoint**: `PUT /companies/:companyId/payment-info`

**Description**: Met à jour les informations de paiement complètes d'une entreprise.

**Paramètres**:
- `companyId` (path, UUID) - ID de l'entreprise

**Corps de la requête**:
```json
{
  "bankAccounts": [...],
  "mobileMoneyAccounts": [...],
  "paymentPreferences": {
    "preferredMethod": "bank",
    "defaultBankAccountId": "ba-001",
    "allowPartialPayments": true
  }
}
```

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Payment information updated successfully",
  "data": { /* Structure complète mise à jour */ },
  "statusCode": 200
}
```

---

### 3. Ajouter un compte bancaire

**Endpoint**: `POST /companies/:companyId/payment-info/bank-accounts`

**Description**: Ajoute un nouveau compte bancaire à l'entreprise.

**Paramètres**:
- `companyId` (path, UUID) - ID de l'entreprise

**Corps de la requête**:
```json
{
  "accountNumber": "CD12345678901234567890",
  "accountName": "Wanzo SARL - Compte Principal",
  "bankName": "Rawbank",
  "bankCode": "RAWB",
  "branchCode": "001",
  "swiftCode": "RAWBCDKIN",
  "rib": "CD12 3456 7890 1234 5678 90",
  "iban": null,
  "currency": "CDF",
  "isDefault": false
}
```

**Réponse réussie (201)**:
```json
{
  "success": true,
  "message": "Bank account added successfully",
  "data": {
    "id": "ba-002",
    "accountNumber": "CD12345678901234567890",
    "status": "active",
    "createdAt": "2025-11-19T10:00:00.000Z"
  },
  "statusCode": 201
}
```

**Réponse erreur (409)**:
```json
{
  "success": false,
  "message": "Bank account with this account number already exists",
  "statusCode": 409
}
```

---

### 4. Ajouter un compte Mobile Money

**Endpoint**: `POST /companies/:companyId/payment-info/mobile-money-accounts`

**Description**: Ajoute un nouveau compte Mobile Money à l'entreprise.

**Paramètres**:
- `companyId` (path, UUID) - ID de l'entreprise

**Corps de la requête**:
```json
{
  "phoneNumber": "+243812345678",
  "accountName": "Wanzo SARL",
  "operator": "AM",
  "currency": "CDF",
  "purpose": "disbursement",
  "isDefault": false
}
```

**Réponse réussie (201)**:
```json
{
  "success": true,
  "message": "Mobile money account added successfully",
  "data": {
    "id": "mm-002",
    "phoneNumber": "+243812345678",
    "operator": "AM",
    "operatorName": "Airtel Money",
    "verificationStatus": "pending",
    "status": "active",
    "createdAt": "2025-11-19T10:00:00.000Z"
  },
  "statusCode": 201
}
```

---

### 5. Vérifier un compte Mobile Money

**Endpoint**: `POST /companies/:companyId/payment-info/mobile-money-accounts/verify`

**Description**: Vérifie un compte Mobile Money via code SMS.

**Paramètres**:
- `companyId` (path, UUID) - ID de l'entreprise

**Corps de la requête**:
```json
{
  "phoneNumber": "+243812345678",
  "verificationCode": "123456"
}
```

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Mobile money account verified successfully",
  "statusCode": 200
}
```

**Réponse erreur (400)**:
```json
{
  "success": false,
  "message": "Invalid verification code",
  "statusCode": 400
}
```

---

### 6. Supprimer un compte bancaire

**Endpoint**: `DELETE /companies/:companyId/payment-info/bank-accounts/:accountNumber`

**Description**: Supprime un compte bancaire de l'entreprise.

**Paramètres**:
- `companyId` (path, UUID) - ID de l'entreprise
- `accountNumber` (path, string) - Numéro du compte bancaire

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Bank account removed successfully",
  "data": { /* Informations de paiement mises à jour */ },
  "statusCode": 200
}
```

**Réponse erreur (404)**:
```json
{
  "success": false,
  "message": "Bank account not found",
  "statusCode": 404
}
```

---

### 7. Supprimer un compte Mobile Money

**Endpoint**: `DELETE /companies/:companyId/payment-info/mobile-money-accounts/:phoneNumber`

**Description**: Supprime un compte Mobile Money de l'entreprise.

**Paramètres**:
- `companyId` (path, UUID) - ID de l'entreprise
- `phoneNumber` (path, string) - Numéro de téléphone du compte (format: +243XXXXXXXXX)

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Mobile money account removed successfully",
  "data": { /* Informations de paiement mises à jour */ },
  "statusCode": 200
}
```

---

### 8. Définir un compte bancaire par défaut

**Endpoint**: `PUT /companies/:companyId/payment-info/bank-accounts/:accountNumber/default`

**Description**: Définit un compte bancaire comme compte par défaut pour les décaissements.

**Paramètres**:
- `companyId` (path, UUID) - ID de l'entreprise
- `accountNumber` (path, string) - Numéro du compte bancaire

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Default bank account set successfully",
  "data": { /* Informations de paiement mises à jour */ },
  "statusCode": 200
}
```

---

### 9. Définir un compte Mobile Money par défaut

**Endpoint**: `PUT /companies/:companyId/payment-info/mobile-money-accounts/:phoneNumber/default`

**Description**: Définit un compte Mobile Money comme compte par défaut pour les décaissements.

**Paramètres**:
- `companyId` (path, UUID) - ID de l'entreprise
- `phoneNumber` (path, string) - Numéro de téléphone du compte

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Default mobile money account set successfully",
  "data": { /* Informations de paiement mises à jour */ },
  "statusCode": 200
}
```

---

## Codes d'Erreur

| Code | Description |
|------|-------------|
| 200 | Succès |
| 201 | Ressource créée |
| 400 | Requête invalide |
| 401 | Non authentifié |
| 404 | Ressource non trouvée |
| 409 | Conflit (ressource existe déjà) |
| 500 | Erreur serveur |

---

## Notes Importantes

### Limites Transactionnelles Mobile Money

- **Airtel Money**: 5 000 000 CDF/jour, 50 000 000 CDF/mois
- **Orange Money**: 3 000 000 CDF/jour, 30 000 000 CDF/mois
- **Wave**: 10 000 000 CDF/jour, 100 000 000 CDF/mois
- **M-Pesa**: 5 000 000 CDF/jour, 50 000 000 CDF/mois
- **Africell Money**: 2 000 000 CDF/jour, 20 000 000 CDF/mois

### Validation Comptes

- Les comptes bancaires sont actifs immédiatement
- Les comptes Mobile Money nécessitent une vérification SMS (statut `pending` → `verified`)
- Un compte peut avoir 3 statuts: `active`, `inactive`, `suspended`

### Workflow Décaissement

1. Récupérer informations paiement via `GET /payment-info`
2. Vérifier que compte par défaut existe et est `active`
3. Vérifier limites transactionnelles (Mobile Money)
4. Exécuter décaissement via service payment
5. Mettre à jour balance après confirmation
