# API Dépenses (Expenses)

Cette documentation détaille les endpoints disponibles pour la gestion des dépenses dans l'application Wanzo.

## Catégories de Dépenses

Les catégories de dépenses sont représentées par des chaînes de caractères dans les requêtes et réponses API. Voici les catégories disponibles :

- `rent` - Loyer
- `utilities` - Services Publics
- `supplies` - Fournitures
- `salaries` - Salaires
- `marketing` - Marketing
- `transport` - Transport
- `maintenance` - Maintenance
- `other` - Autre
- `inventory` - Stock et Inventaire
- `equipment` - Équipement
- `taxes` - Taxes et Impôts
- `insurance` - Assurances
- `loan` - Remboursement de Prêt
- `office` - Fournitures de Bureau
- `training` - Formation et Développement
- `travel` - Voyages d'Affaires
- `software` - Logiciels et Technologie
- `advertising` - Publicité
- `legal` - Services Juridiques
- `manufacturing` - Production et Fabrication
- `consulting` - Conseil et Services
- `research` - Recherche et Développement
- `fuel` - Carburant
- `entertainment` - Représentation et Cadeaux
- `communication` - Télécommunications

## Structure du modèle Dépense

```json
{
  "id": "string",                     // Identifiant unique de la dépense (UUID)
  "localId": "string",                // Identifiant local pour offline (optionnel, local uniquement)
  "date": "2023-08-01T12:30:00.000Z", // Date de la dépense (format ISO8601)
  "motif": "string",                  // Motif de la dépense
  "amount": 150.00,                   // Montant de la dépense
  "category": "rent",                 // Catégorie de la dépense (voir liste ci-dessus)
  "paymentMethod": "string",          // Méthode de paiement (optionnel)
  "attachmentUrls": [                 // URLs Cloudinary des pièces jointes après sync (optionnel)
    "string",
    "string"
  ],
  "localAttachmentPaths": [           // Chemins locaux des pièces jointes avant sync (optionnel, local uniquement)
    "string",
    "string"
  ],
  "supplierId": "string",             // ID du fournisseur (optionnel)
  "beneficiary": "string",            // Bénéficiaire de la dépense (optionnel)
  "notes": "string",                  // Notes additionnelles (optionnel)
  "currencyCode": "CDF",              // Code de la devise (CDF, USD, EUR, etc.) (optionnel, défaut: CDF)
  "supplierName": "string",           // Nom du fournisseur (optionnel)
  "paidAmount": 0.0,                  // Montant déjà payé (optionnel, défaut: 0.0)
  "exchangeRate": 2500.0,             // Taux de change appliqué (optionnel)
  "paymentStatus": "unpaid",          // Statut de paiement: "paid", "partial", "unpaid", "credit" (optionnel, défaut: "unpaid")
  "userId": "string",                 // ID de l'utilisateur (optionnel)
  
  // === Champs d'Unité d'Affaires (Business Unit) ===
  "companyId": "uuid-company",        // Identifiant de l'entreprise principale (société mère)
  "businessUnitId": "uuid-bu",        // Identifiant de l'unité commerciale
  "businessUnitCode": "POS-KIN-001",  // Code unique de l'unité commerciale
  "businessUnitType": "pos",          // Type d'unité: "company", "branch" ou "pos"
  
  // === Métadonnées ===
  "createdAt": "2023-08-01T12:30:00.000Z", // Date de création (optionnel)
  "updatedAt": "2023-08-01T12:30:00.000Z", // Date de mise à jour (optionnel)
  "syncStatus": "synced",             // Statut de synchronisation: "synced", "pending", "failed" (local uniquement)
  "lastSyncAttempt": "2023-08-01T12:30:00.000Z", // Dernière tentative de sync (local uniquement, optionnel)
  "errorMessage": "string"            // Message d'erreur de synchronisation (local uniquement, optionnel)
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

## Gestion du Suivi des Paiements

L'application permet de suivre l'état des paiements pour chaque dépense:

### Statuts de Paiement
- `paid` - Payé entièrement
- `partial` - Partiellement payé
- `unpaid` - Non payé
- `credit` - À crédit

### Champs de Suivi
- `paidAmount`: Montant déjà payé (défaut: 0.0)
- `paymentStatus`: Statut du paiement (défaut: "unpaid")
- `supplierName`: Nom du fournisseur pour affichage

### Exemple d'Utilisation

**Scénario**: Paiement partiel d'une dépense

```json
{
  "motif": "Achat de stock",
  "amount": 5000.0,
  "paidAmount": 2000.0,
  "paymentStatus": "partial",
  "supplierId": "supplier_123",
  "supplierName": "Fournisseur ABC",
  "category": "inventory"
}
```

Le système calcule automatiquement le reste à payer: 5000.0 - 2000.0 = 3000.0

## Gestion Multi-Devises des Dépenses

L'application supporte l'enregistrement des dépenses dans différentes devises:

### Fonctionnalités
- Saisir une dépense en CDF, USD, EUR, ou toute autre devise
- Conversion automatique vers CDF pour les rapports consolidés
- Conservation de la devise d'origine pour traçabilité

### Exemple d'Utilisation

**Scénario**: Dépense en USD

```json
{
  "motif": "Achat de matériel informatique",
  "amount": 500.0,
  "currencyCode": "USD",
  "category": "equipment",
  "paymentMethod": "Virement bancaire"
}
```

Le système:
1. Enregistre le montant original (500 USD)
2. Applique le taux de change du jour
3. Calcule l'équivalent en CDF pour les statistiques

## Gestion des Pièces Jointes

### Workflow Offline-First

1. **Mode Offline**: Les pièces jointes sont stockées localement
   - Chemin stocké dans `localAttachmentPaths[]`
   - Fichiers sauvegardés dans le stockage local de l'appareil

2. **Synchronisation**: Lors de la connexion internet
   - Upload automatique des fichiers vers Cloudinary
   - URLs retournées stockées dans `attachmentUrls[]`
   - `localAttachmentPaths[]` conservés comme backup

3. **Différence entre les champs**:
   - `attachmentUrls`: URLs publiques Cloudinary (après sync)
   - `localAttachmentPaths`: Chemins locaux (avant sync)

### Champs de Synchronisation Offline

- `localId`: Identifiant temporaire généré localement
- `syncStatus`: État de synchronisation (`synced`, `pending`, `failed`)
- `lastSyncAttempt`: Date de la dernière tentative
- `errorMessage`: Message d'erreur détaillé en cas d'échec

**Note**: Ces champs de synchronisation ne sont pas envoyés au serveur.

## Endpoints

### 1. Récupérer toutes les dépenses

**Endpoint:** `GET /commerce/api/v1/expenses`

**Paramètres de requête:**
- `page` (optionnel): Numéro de page pour la pagination
- `limit` (optionnel): Nombre d'éléments par page
- `dateFrom` (optionnel): Date de début au format ISO8601 (YYYY-MM-DD)
- `dateTo` (optionnel): Date de fin au format ISO8601 (YYYY-MM-DD)
- `categoryId` (optionnel): Filtrer par catégorie de dépense
- `companyId` (optionnel): Filtrer par ID d'entreprise (défaut: entreprise de l'utilisateur)
- `businessUnitId` (optionnel): Filtrer par ID d'unité commerciale
- `businessUnitType` (optionnel): Filtrer par type d'unité (`company`, `branch`, `pos`)
- `sortBy` (optionnel): Champ sur lequel trier les résultats
- `sortOrder` (optionnel): Ordre de tri (`asc` ou `desc`)

**Note sur le filtrage Business Unit:**
- Si `businessUnitId` est fourni, seules les dépenses de cette unité seront retournées
- Si non fourni, toutes les dépenses de l'entreprise de l'utilisateur seront retournées
- Un utilisateur associé à une succursale (branch) verra également les dépenses de ses points de vente enfants

**Réponse:**
```json
{
  "success": true,
  "message": "Expenses retrieved successfully",
  "statusCode": 200,
  "data": [
    {
      // Objet dépense (voir structure ci-dessus)
    },
    // ... autres dépenses
  ]
}
```

### 2. Récupérer une dépense par ID

**Endpoint:** `GET /commerce/api/v1/expenses/{id}`

**Paramètres:**
- `id`: ID de la dépense à récupérer

**Réponse:**
```json
{
  "success": true,
  "message": "Expense retrieved successfully",
  "statusCode": 200,
  "data": {
    // Objet dépense (voir structure ci-dessus)
  }
}
```

### 3. Créer une nouvelle dépense

**Endpoint:** `POST /commerce/api/v1/expenses`

**Création Automatique du Fournisseur** 🆕

Le système crée **automatiquement** un fournisseur s'il n'existe pas encore, en utilisant le `supplierPhoneNumber` comme identifiant unique. Cela évite les doublons et simplifie le workflow.

**Corps de la requête:**
```json
{
  "date": "2023-08-01T12:30:00.000Z", // Obligatoire
  "motif": "string",                  // Obligatoire
  "amount": 150.00,                   // Obligatoire
  "category": "rent",                 // Obligatoire
  "paymentMethod": "string",          // Optionnel
  "supplierId": "string",             // Optionnel
  "supplierPhoneNumber": "+243999123456", // Optionnel - CRÉATION AUTO du fournisseur
  "supplierName": "string",           // Optionnel
  "beneficiary": "string",            // Optionnel
  "notes": "string",                  // Optionnel
  "currencyCode": "USD",              // Optionnel
  "paidAmount": 0.0,                  // Optionnel (défaut: 0.0)
  "paymentStatus": "unpaid",          // Optionnel (défaut: "unpaid")
  "exchangeRate": 2500.0,             // Optionnel
  
  // === Champs d'Unité d'Affaires (optionnels, auto-définis si absents) ===
  "companyId": "uuid-company",        // Optionnel - Défaut: entreprise de l'utilisateur
  "businessUnitId": "uuid-bu",        // Optionnel - Défaut: unité de l'utilisateur
  "businessUnitCode": "POS-KIN-001",  // Optionnel - Défaut: code de l'unité de l'utilisateur
  "businessUnitType": "pos"           // Optionnel - "company", "branch" ou "pos"
}
}
```

**Exemple avec création automatique du fournisseur:**
```json
{
  "date": "2023-08-01T12:30:00.000Z",
  "motif": "Achat de stock",
  "amount": 500000.0,
  "category": "inventory",
  "supplierPhoneNumber": "+243999123456",
  "supplierName": "Fournisseur ABC",
  "paidAmount": 200000.0,
  "paymentStatus": "partial"
}
```

Le système:
1. Normalise le numéro: `+243999123456`
2. Cherche un fournisseur existant avec ce numéro
3. **Si trouvé**: Utilise le fournisseur existant
4. **Si non trouvé**: Crée automatiquement un nouveau fournisseur
5. Crée la dépense avec le `supplierId` correspondant

➡️ **Aucun doublon** de fournisseur n'est créé!

**Réponse:**
```json
{
  "success": true,
  "message": "Expense created successfully",
  "statusCode": 201,
  "data": {
    // Objet dépense créé (voir structure ci-dessus)
  }
}
```

### 4. Mettre à jour une dépense

**Endpoint:** `PATCH /commerce/api/v1/expenses/{id}`

**Paramètres:**
- `id`: ID de la dépense à mettre à jour

**Corps de la requête:**
```json
{
  "date": "2023-08-01T12:30:00.000Z", // Optionnel
  "motif": "string",                  // Optionnel
  "amount": 150.00,                   // Optionnel
  "category": "rent",                 // Optionnel
  "paymentMethod": "string",          // Optionnel
  "supplierId": "string",             // Optionnel
  "supplierName": "string",           // Optionnel
  "beneficiary": "string",            // Optionnel
  "notes": "string",                  // Optionnel
  "currencyCode": "USD",              // Optionnel
  "paidAmount": 150.0,                // Optionnel
  "paymentStatus": "paid",            // Optionnel
  "exchangeRate": 2500.0              // Optionnel
}
```

**Réponse:**
```json
{
  "success": true,
  "message": "Expense updated successfully",
  "statusCode": 200,
  "data": {
    // Objet dépense mis à jour (voir structure ci-dessus)
  }
}
```

### 5. Supprimer une dépense

**Endpoint:** `DELETE /commerce/api/v1/expenses/{id}`

**Paramètres:**
- `id`: ID de la dépense à supprimer

**Réponse:**
```json
{
  "success": true,
  "message": "Expense deleted successfully",
  "statusCode": 200,
  "data": null
}
```

### 6. Téléchargement de pièces jointes

**Endpoint:** `POST /commerce/api/v1/expenses/:id/upload-receipt`

**Type de requête:** `multipart/form-data`

**Paramètres:**
- `file`: Fichier à télécharger (image ou PDF)
- `expenseId` (optionnel): ID de la dépense associée

**Réponse:**
```json
{
  "success": true,
  "message": "Attachment uploaded successfully",
  "statusCode": 200,
  "data": {
    "url": "string", // URL de la pièce jointe téléchargée
    "fileType": "string",
    "fileName": "string"
  }
}
```

---

## Gestion des Catégories de Dépenses

Les catégories de dépenses peuvent être gérées dynamiquement via les endpoints suivants.

### Structure du modèle ExpenseCategory

```json
{
  "id": "string",              // Identifiant unique de la catégorie (UUID)
  "name": "string",            // Nom de la catégorie
  "description": "string",     // Description de la catégorie (optionnel)
  "color": "string",           // Couleur pour l'affichage (optionnel, ex: "#FF5733")
  "icon": "string",            // Icône pour l'affichage (optionnel)
  "isActive": true,            // Statut actif/inactif
  "createdAt": "string",       // Date de création (format ISO8601)
  "updatedAt": "string"        // Date de mise à jour (format ISO8601)
}
```

### 7. Créer une catégorie de dépense

**Endpoint:** `POST /commerce/api/v1/expenses/categories`

**Corps de la requête:**
```json
{
  "name": "string",            // Obligatoire - Nom de la catégorie
  "description": "string",     // Optionnel - Description
  "color": "#FF5733",          // Optionnel - Code couleur hex
  "icon": "fa-briefcase"       // Optionnel - Classe d'icône
}
```

**Réponse:**
```json
{
  "success": true,
  "message": "Expense category created successfully",
  "statusCode": 201,
  "data": {
    // Objet catégorie créé (voir structure ci-dessus)
  }
}
```

### 8. Récupérer toutes les catégories de dépense

**Endpoint:** `GET /commerce/api/v1/expenses/categories`

**Paramètres de requête:**
- `page` (optionnel): Numéro de page pour la pagination (défaut: 1)
- `limit` (optionnel): Nombre d'éléments par page (défaut: 20)

**Réponse:**
```json
{
  "success": true,
  "message": "Expense categories retrieved successfully",
  "statusCode": 200,
  "data": [
    {
      // Objet catégorie (voir structure ci-dessus)
    }
  ],
  "total": 25,
  "page": 1,
  "limit": 20
}
```

### 9. Récupérer une catégorie de dépense par ID

**Endpoint:** `GET /commerce/api/v1/expenses/categories/{id}`

**Paramètres:**
- `id`: UUID de la catégorie

**Réponse:**
```json
{
  "success": true,
  "message": "Expense category retrieved successfully",
  "statusCode": 200,
  "data": {
    // Objet catégorie (voir structure ci-dessus)
  }
}
```

### 10. Mettre à jour une catégorie de dépense

**Endpoint:** `PATCH /commerce/api/v1/expenses/categories/{id}`

**Paramètres:**
- `id`: UUID de la catégorie à mettre à jour

**Corps de la requête:**
```json
{
  "name": "string",            // Optionnel
  "description": "string",     // Optionnel
  "color": "#00FF00",          // Optionnel
  "icon": "fa-money"           // Optionnel
}
```

**Réponse:**
```json
{
  "success": true,
  "message": "Expense category updated successfully",
  "statusCode": 200,
  "data": {
    // Objet catégorie mis à jour (voir structure ci-dessus)
  }
}
```

### 11. Supprimer une catégorie de dépense

**Endpoint:** `DELETE /commerce/api/v1/expenses/categories/{id}`

**Paramètres:**
- `id`: UUID de la catégorie à supprimer

**⚠️ Attention:** Une catégorie utilisée par des dépenses existantes ne peut pas être supprimée.

**Réponse:**
```json
{
  "success": true,
  "message": "Expense category deleted successfully",
  "statusCode": 200,
  "data": null
}
```

**Erreur si catégorie utilisée:**
```json
{
  "success": false,
  "message": "Cannot delete category: it is used by existing expenses",
  "statusCode": 409,
  "error": "Conflict"
}
```
