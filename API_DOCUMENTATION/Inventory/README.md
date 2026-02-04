# API Inventaire (Produits et Stock)

Cette documentation détaille les endpoints disponibles pour la gestion de l'inventaire, des produits et des transactions de stock dans l'application Wanzo.

## Catégories de Produits

Les catégories de produits sont représentées par des chaînes de caractères dans les requêtes et réponses API:

- `food` - Alimentation
- `drink` - Boissons
- `electronics` - Électronique
- `clothing` - Vêtements
- `household` - Articles ménagers
- `hygiene` - Hygiène et beauté
- `office` - Fournitures de bureau
- `cosmetics` - Produits cosmétiques
- `pharmaceuticals` - Produits pharmaceutiques
- `bakery` - Boulangerie
- `dairy` - Produits laitiers
- `meat` - Viande
- `vegetables` - Légumes
- `fruits` - Fruits
- `other` - Autres

## Unités de Mesure

Les unités de mesure sont représentées par des chaînes de caractères:

- `piece` - Pièce
- `kg` - Kilogramme
- `g` - Gramme
- `l` - Litre
- `ml` - Millilitre
- `package` - Paquet
- `box` - Boîte
- `other` - Autre

## Types de Transactions de Stock

Les types de transactions de stock sont représentés par des chaînes de caractères:

- `purchase` - Entrée de stock suite à un achat
- `sale` - Sortie de stock suite à une vente
- `adjustment` - Ajustement manuel (positif ou négatif)
- `transferIn` - Entrée de stock suite à un transfert interne
- `transferOut` - Sortie de stock suite à un transfert interne
- `returned` - Retour de marchandise par un client (entrée)
- `damaged` - Marchandise endommagée (sortie)
- `lost` - Marchandise perdue (sortie)
- `initialStock` - Stock initial lors de la création du produit

## Structure du modèle Produit

```json
{
  "id": "string",                  // Identifiant unique du produit
  "name": "string",                // Nom du produit
  "description": "string",         // Description du produit
  "barcode": "string",             // Code barres ou référence
  "category": "food",              // Catégorie du produit (voir liste ci-dessus)
  "costPriceInCdf": 5000.00,       // Prix d'achat en Francs Congolais
  "sellingPriceInCdf": 7500.00,    // Prix de vente en Francs Congolais
  "stockQuantity": 100.0,          // Quantité en stock
  "unit": "piece",                 // Unité de mesure (voir liste ci-dessus)
  "alertThreshold": 10.0,          // Niveau d'alerte de stock bas
  "createdAt": "2023-08-01T12:30:00.000Z", // Date d'ajout dans l'inventaire
  "updatedAt": "2023-08-01T12:30:00.000Z", // Date de dernière mise à jour
  "imageUrl": "string",            // URL de l'image du produit (optionnel)
  "imagePath": "string",           // Chemin local de l'image (optionnel, local uniquement)
  "supplierIds": ["string"],       // IDs des fournisseurs (optionnel)
  "tags": ["string"],              // Tags pour le produit (optionnel)
  "taxRate": 16.0,                 // Taux de taxe en pourcentage (optionnel)
  "sku": "string",                 // Référence de stock (optionnel)
  "inputCurrencyCode": "CDF",      // Devise de saisie des prix (pour système multi-devises)
  "inputExchangeRate": 1.0,        // Taux de change lors de la saisie (1.0 si CDF)
  "costPriceInInputCurrency": 5000.00,     // Prix d'achat dans la devise de saisie
  "sellingPriceInInputCurrency": 7500.00,  // Prix de vente dans la devise de saisie
  
  // === Champs Business Unit (Multi-Tenant) ===
  "companyId": "uuid-company",     // ID entreprise principale (auto-défini)
  "businessUnitId": "uuid-bu",     // ID unité commerciale (optionnel)
  "businessUnitCode": "POS-KIN-001", // Code de l'unité commerciale
  "businessUnitType": "pos"        // Type: "company", "branch" ou "pos"
}
```

## Système Multi-Devises Avancé pour les Produits

L'application implémente un **système de double prix avancé** qui permet:

### Fonctionnalités
- Saisir les prix dans n'importe quelle devise (USD, EUR, CDF, etc.)
- Conversion automatique vers CDF avec le taux de change du moment
- Conservation des prix originaux et du taux utilisé
- Possibilité de recalcul si le taux de change évolue

### Champs Multi-Devises

| Champ | Description |
|-------|-------------|
| `inputCurrencyCode` | Code de la devise utilisée lors de la saisie (USD, EUR, CDF, etc.) |
| `inputExchangeRate` | Taux de change vers CDF au moment de la saisie |
| `costPriceInInputCurrency` | Prix d'achat original dans la devise de saisie |
| `sellingPriceInInputCurrency` | Prix de vente original dans la devise de saisie |
| `costPriceInCdf` | Prix d'achat converti en CDF (calculé automatiquement) |
| `sellingPriceInCdf` | Prix de vente converti en CDF (calculé automatiquement) |

### Exemple d'Utilisation

**Scénario**: Enregistrement d'un produit avec prix en USD

```json
{
  "name": "iPhone 15 Pro",
  "inputCurrencyCode": "USD",
  "inputExchangeRate": 2500.0,
  "costPriceInInputCurrency": 800.0,       // 800 USD
  "sellingPriceInInputCurrency": 1000.0,   // 1000 USD
  "costPriceInCdf": 2000000.0,             // Calculé: 800 × 2500
  "sellingPriceInCdf": 2500000.0           // Calculé: 1000 × 2500
}
```

**Avantages**:
1. **Traçabilité**: On conserve toujours le prix original
2. **Flexibilité**: Possibilité d'afficher les prix dans la devise d'origine
3. **Recalcul**: Si le taux change, on peut recalculer les prix CDF
4. **Multi-marché**: Support des fournisseurs internationaux

### Différence entre `imageUrl` et `imagePath`

- **`imageUrl`**: URL publique Cloudinary après synchronisation avec le backend
- **`imagePath`**: Chemin local du fichier image avant synchronisation (mode offline)

**Workflow**:
1. L'utilisateur ajoute un produit avec une image locale → `imagePath` défini
2. L'app synchronise avec le backend → Image uploadée sur Cloudinary
3. Backend retourne `imageUrl` → L'app met à jour le produit
4. Les deux champs sont conservés pour compatibilité offline

## Structure du modèle Transaction de Stock

```json
{
  "id": "string",                  // Identifiant unique de la transaction
  "productId": "string",           // ID du produit concerné
  "type": "purchase",              // Type de transaction (voir liste ci-dessus)
  "quantity": 10.0,                // Quantité (positive ou négative selon le type)
  "date": "2023-08-01T12:30:00.000Z", // Date de la transaction
  "referenceId": "string",         // ID de référence (vente, achat, etc.) (optionnel)
  "notes": "string",               // Notes additionnelles (optionnel)
  "createdBy": "string",           // ID de l'utilisateur qui a créé la transaction (optionnel)
  "createdAt": "2023-08-01T12:30:00.000Z", // Date de création de l'enregistrement
  "unitCostPrice": 5000.00,        // Prix unitaire d'achat (optionnel)
  "locationId": "string"           // ID de l'emplacement de stock (optionnel)
}
```

## Endpoints pour les Produits

### 1. Récupérer tous les produits

**Endpoint:** `GET /commerce/api/v1/products`

**Paramètres de requête:**
- `page` (optionnel): Numéro de page pour la pagination
- `limit` (optionnel): Nombre d'éléments par page
- `category` (optionnel): Filtrer par catégorie
- `sortBy` (optionnel): Champ sur lequel trier les résultats
- `sortOrder` (optionnel): Ordre de tri (`asc` ou `desc`)
- `searchQuery` (optionnel): Terme de recherche pour filtrer les produits
- `companyId` (optionnel): Filtrer par entreprise (défaut: entreprise de l'utilisateur)
- `businessUnitId` (optionnel): Filtrer par unité commerciale
- `businessUnitType` (optionnel): Filtrer par type: `company`, `branch`, `pos`

**Réponse:**
```json
{
  "success": true,
  "message": "Products retrieved successfully",
  "statusCode": 200,
  "data": [
    {
      // Objet produit (voir structure ci-dessus)
    },
    // ... autres produits
  ]
}
```

### 2. Récupérer un produit par ID

**Endpoint:** `GET /commerce/api/v1/products/{id}`

**Paramètres:**
- `id`: ID du produit à récupérer

**Réponse:**
```json
{
  "success": true,
  "message": "Product retrieved successfully",
  "statusCode": 200,
  "data": {
    // Objet produit (voir structure ci-dessus)
  }
}
```

### 3. Créer un nouveau produit

**Endpoint:** `POST /commerce/api/v1/products`

**Type de requête:** `multipart/form-data` (si vous incluez une image) ou `application/json`

**Corps de la requête:**
```json
{
  "name": "string",                // Obligatoire
  "description": "string",         // Obligatoire
  "barcode": "string",             // Optionnel
  "category": "food",              // Obligatoire
  "costPriceInCdf": 5000.00,       // Obligatoire
  "sellingPriceInCdf": 7500.00,    // Obligatoire
  "stockQuantity": 100.0,          // Obligatoire
  "unit": "piece",                 // Obligatoire
  "alertThreshold": 10.0,          // Optionnel
  "supplierIds": ["string"],       // Optionnel
  "tags": ["string"],              // Optionnel
  "taxRate": 16.0,                 // Optionnel
  "sku": "string",                 // Optionnel
  
  // === Champs Business Unit (optionnels, auto-définis si absents) ===
  "companyId": "uuid-company",     // Défaut: entreprise de l'utilisateur
  "businessUnitId": "uuid-bu",     // Défaut: unité de l'utilisateur
  "businessUnitCode": "POS-KIN-001", // Défaut: code de l'unité de l'utilisateur
  "businessUnitType": "pos"        // "company", "branch" ou "pos"
}
```

**Champs supplémentaires pour multipart/form-data:**
- `image`: Fichier image du produit (jpg, png, etc.)

**Réponse:**
```json
{
  "success": true,
  "message": "Product created successfully",
  "statusCode": 201,
  "data": {
    // Objet produit créé (voir structure ci-dessus)
  }
}
```

### 4. Mettre à jour un produit

**Endpoint:** `PATCH /commerce/api/v1/products/{id}`

**Paramètres:**
- `id`: ID du produit à mettre à jour

**Type de requête:** `multipart/form-data` (si vous incluez une image) ou `application/json`

**Corps de la requête:**
```json
{
  "name": "string",                // Optionnel
  "description": "string",         // Optionnel
  "barcode": "string",             // Optionnel
  "category": "food",              // Optionnel
  "costPriceInCdf": 5000.00,       // Optionnel
  "sellingPriceInCdf": 7500.00,    // Optionnel
  "stockQuantity": 100.0,          // Optionnel (préférer les transactions de stock pour modifier)
  "unit": "piece",                 // Optionnel
  "alertThreshold": 10.0,          // Optionnel
  "supplierIds": ["string"],       // Optionnel
  "tags": ["string"],              // Optionnel
  "taxRate": 16.0,                 // Optionnel
  "sku": "string",                 // Optionnel
  "removeImage": false             // Optionnel, pour supprimer l'image existante
}
```

**Champs supplémentaires pour multipart/form-data:**
- `image`: Fichier image du produit (jpg, png, etc.)

**Réponse:**
```json
{
  "success": true,
  "message": "Product updated successfully",
  "statusCode": 200,
  "data": {
    // Objet produit mis à jour (voir structure ci-dessus)
  }
}
```

### 5. Supprimer un produit

**Endpoint:** `DELETE /commerce/api/v1/products/{id}`

**Paramètres:**
- `id`: ID du produit à supprimer

**Réponse:**
```json
{
  "success": true,
  "message": "Product deleted successfully",
  "statusCode": 200,
  "data": null
}
```

## Endpoints pour les Transactions de Stock

### 1. Récupérer toutes les transactions de stock

**Endpoint:** `GET /commerce/api/v1/stock-transactions`

**Paramètres de requête:**
- `page` (optionnel): Numéro de page pour la pagination (défaut: 1)
- `limit` (optionnel): Nombre d'éléments par page (défaut: 20)
- `productId` (optionnel): Filtrer par ID de produit
- `type` (optionnel): Filtrer par type de transaction
- `dateFrom` (optionnel): Date de début au format ISO8601 (YYYY-MM-DD)
- `dateTo` (optionnel): Date de fin au format ISO8601 (YYYY-MM-DD)
- `sortBy` (optionnel): Champ de tri (date, quantity, type, createdAt)
- `sortOrder` (optionnel): Ordre de tri (`asc` ou `desc`)

**Réponse:**
```json
{
  "data": [
    {
      // Objet transaction de stock (voir structure ci-dessus)
    }
  ],
  "total": 150,
  "page": 1,
  "limit": 20
}
```

### 2. Récupérer une transaction de stock par ID

**Endpoint:** `GET /commerce/api/v1/stock-transactions/{id}`

**Paramètres:**
- `id`: ID de la transaction à récupérer (UUID)

**Réponse:**
```json
{
  "id": "uuid-transaction",
  "productId": "uuid-product",
  "type": "purchase",
  "quantity": 10.0,
  "date": "2025-01-04T12:30:00.000Z",
  "referenceId": "PO-2025-001",
  "notes": "Réapprovisionnement",
  "createdBy": "uuid-user",
  "createdAt": "2025-01-04T12:30:00.000Z",
  "unitCostPrice": 5000.00
}
```

### 3. Créer une nouvelle transaction de stock

**Endpoint:** `POST /commerce/api/v1/stock-transactions`

**Rôles autorisés:** ADMIN, MANAGER, INVENTORY_MANAGER, CASHIER

**Corps de la requête:**
```json
{
  "productId": "string",           // Obligatoire
  "type": "purchase",              // Obligatoire
  "quantity": 10.0,                // Obligatoire
  "date": "2025-01-04T12:30:00.000Z", // Obligatoire
  "referenceId": "string",         // Optionnel
  "notes": "string",               // Optionnel
  "unitCostPrice": 5000.00,        // Optionnel
  "locationId": "string"           // Optionnel
}
```

**Réponse:**
```json
{
  "id": "uuid-new-transaction",
  "productId": "uuid-product",
  "type": "purchase",
  "quantity": 10.0,
  "date": "2025-01-04T12:30:00.000Z",
  "createdBy": "uuid-user",
  "createdAt": "2025-01-04T12:30:00.000Z"
}
```

### 4. Récupérer l'historique de stock d'un produit

**Endpoint:** `GET /commerce/api/v1/stock-transactions/product/{productId}/history`

**Description:** Récupère l'historique complet des transactions de stock pour un produit spécifique.

**Paramètres:**
- `productId`: UUID du produit

**Paramètres de requête:**
- `dateFrom` (optionnel): Date de début au format ISO8601
- `dateTo` (optionnel): Date de fin au format ISO8601
- `limit` (optionnel): Nombre maximum de résultats (défaut: 50)

**Réponse:**
```json
[
  {
    "id": "uuid-transaction-1",
    "productId": "uuid-product",
    "type": "purchase",
    "quantity": 100.0,
    "date": "2025-01-01T10:00:00.000Z",
    "referenceId": "PO-2025-001",
    "notes": "Stock initial",
    "createdBy": "uuid-user",
    "createdAt": "2025-01-01T10:00:00.000Z"
  },
  {
    "id": "uuid-transaction-2",
    "productId": "uuid-product",
    "type": "sale",
    "quantity": -5.0,
    "date": "2025-01-02T14:30:00.000Z",
    "referenceId": "SALE-2025-001",
    "notes": "Vente client",
    "createdBy": "uuid-user",
    "createdAt": "2025-01-02T14:30:00.000Z"
  }
]
```
