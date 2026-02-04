# API Fournisseurs (Suppliers)

Cette documentation détaille les endpoints disponibles pour la gestion des fournisseurs dans l'application Wanzo.

## Structure du modèle Fournisseur

```json
{
  "id": "string",              // Identifiant unique du fournisseur (UUID)
  "name": "string",            // Nom du fournisseur
  "phoneNumber": "string",     // Numéro de téléphone du fournisseur
  "email": "string",           // Adresse email du fournisseur (optionnel)
  "address": "string",         // Adresse physique du fournisseur (optionnel)
  "contactPerson": "string",   // Personne à contacter chez le fournisseur (optionnel)
  "notes": "string",           // Notes ou informations supplémentaires (optionnel)
  "totalPurchases": 0.0,       // Total des achats effectués auprès de ce fournisseur (en FC)
  "lastPurchaseDate": "string", // Date du dernier achat (format ISO8601, optionnel)
  "category": "string",        // Catégorie du fournisseur (enum)
  "deliveryTimeInDays": 0,     // Délai de livraison moyen en jours
  "paymentTerms": "string",    // Termes de paiement (ex: "Net 30")
  
  // === Relation avec les Produits (ManyToMany) ===
  "products": [                // Liste des produits associés à ce fournisseur (optionnel)
    {
      "id": "uuid-product",
      "name": "Ciment 50kg",
      "sku": "CIM-50KG"
    }
  ],
  
  // === Champs d'Unité d'Affaires (Business Unit) ===
  "companyId": "uuid-company",        // Identifiant de l'entreprise principale (société mère)
  "businessUnitId": "uuid-bu",        // Identifiant de l'unité commerciale
  "businessUnitCode": "POS-KIN-001",  // Code unique de l'unité commerciale
  "businessUnitType": "pos",          // Type d'unité: "company", "branch" ou "pos"
  
  // === Métadonnées ===
  "createdAt": "string",       // Date de création (format ISO8601)
  "updatedAt": "string"        // Date de mise à jour (format ISO8601)
}
```

### Types d'Unités d'Affaires (businessUnitType)

| Type | Description |
|------|-------------|
| `company` | Entreprise principale (niveau 0) |
| `branch` | Succursale/Agence (niveau 1) |
| `pos` | Point de Vente (niveau 2) |

> **Note**: Les champs `companyId` et `businessUnitId` sont automatiquement définis selon le contexte utilisateur et permettent le filtrage multi-tenant des données.

### Catégories de Fournisseurs (SupplierCategory)

Enum représentant les catégories de fournisseurs disponibles:

| Valeur | Description |
|--------|-------------|
| `strategic` | Fournisseur stratégique - Partenaire clé avec une relation commerciale importante |
| `regular` | Fournisseur régulier - Fournisseur habituel avec des commandes fréquentes (valeur par défaut) |
| `newSupplier` | Nouveau fournisseur - Fournisseur récemment ajouté au système |
| `occasional` | Fournisseur occasionnel - Fournisseur utilisé ponctuellement pour des besoins spécifiques |
| `international` | Fournisseur international - Fournisseur basé à l'étranger, impliquant des processus d'import |

**Exemple d'utilisation dans le JSON:**
```json
{
  "category": "strategic"
}
```
```

## Endpoints

### 1. Récupérer tous les fournisseurs

**Endpoint:** `GET /commerce/api/v1/suppliers`

**Paramètres de requête:**
- `page` (optionnel): Numéro de page pour la pagination
- `limit` (optionnel): Nombre d'éléments par page
- `sortBy` (optionnel): Champ sur lequel trier les résultats
- `sortOrder` (optionnel): Ordre de tri (`asc` ou `desc`)
- `q` (optionnel): Terme de recherche pour filtrer les fournisseurs
- `companyId` (optionnel): Filtrer par ID d'entreprise (défaut: entreprise de l'utilisateur)
- `businessUnitId` (optionnel): Filtrer par ID d'unité commerciale
- `businessUnitType` (optionnel): Filtrer par type d'unité (`company`, `branch`, `pos`)

**Note sur le filtrage Business Unit:**
- Si `businessUnitId` est fourni, seuls les fournisseurs de cette unité seront retournés
- Si non fourni, tous les fournisseurs de l'entreprise de l'utilisateur seront retournés

**Réponse:**
```json
{
  "success": true,
  "message": "Suppliers retrieved successfully",
  "statusCode": 200,
  "data": [
    {
      // Objet fournisseur (voir structure ci-dessus)
    },
    // ... autres fournisseurs
  ]
}
```

### 2. Récupérer un fournisseur par ID

**Endpoint:** `GET /commerce/api/v1/suppliers/{id}`

**Paramètres:**
- `id`: ID du fournisseur à récupérer

**Réponse:**
```json
{
  "success": true,
  "message": "Supplier retrieved successfully",
  "statusCode": 200,
  "data": {
    // Objet fournisseur (voir structure ci-dessus)
  }
}
```

### 3. Créer un nouveau fournisseur

**Endpoint:** `POST /commerce/api/v1/suppliers`

**Corps de la requête:**
```json
{
  "name": "string",            // Obligatoire
  "phoneNumber": "string",     // Obligatoire
  "email": "string",           // Optionnel
  "address": "string",         // Optionnel
  "contactPerson": "string",   // Optionnel
  "notes": "string",           // Optionnel
  "category": "string",        // Obligatoire
  "deliveryTimeInDays": 0,     // Obligatoire
  "paymentTerms": "string",    // Obligatoire
  
  // === Champs d'Unité d'Affaires (optionnels, auto-définis si absents) ===
  "companyId": "uuid-company",        // Optionnel - Défaut: entreprise de l'utilisateur
  "businessUnitId": "uuid-bu",        // Optionnel - Défaut: unité de l'utilisateur
  "businessUnitCode": "POS-KIN-001",  // Optionnel - Défaut: code de l'unité de l'utilisateur
  "businessUnitType": "pos"           // Optionnel - "company", "branch" ou "pos"
}
```

**Réponse:**
```json
{
  "success": true,
  "message": "Supplier created successfully",
  "statusCode": 201,
  "data": {
    // Objet fournisseur créé (voir structure ci-dessus)
  }
}
```

### 4. Mettre à jour un fournisseur

**Endpoint:** `PATCH /commerce/api/v1/suppliers/{id}`

**Paramètres:**
- `id`: ID du fournisseur à mettre à jour

**Corps de la requête:**
```json
{
  "name": "string",            // Optionnel
  "phoneNumber": "string",     // Optionnel
  "email": "string",           // Optionnel
  "address": "string",         // Optionnel
  "contactPerson": "string",   // Optionnel
  "notes": "string",           // Optionnel
  "category": "string",        // Optionnel
  "deliveryTimeInDays": 0,     // Optionnel
  "paymentTerms": "string"     // Optionnel
}
```

**Réponse:**
```json
{
  "success": true,
  "message": "Supplier updated successfully",
  "statusCode": 200,
  "data": {
    // Objet fournisseur mis à jour (voir structure ci-dessus)
  }
}
```

### 5. Supprimer un fournisseur

**Endpoint:** `DELETE /commerce/api/v1/suppliers/{id}`

**Paramètres:**
- `id`: ID du fournisseur à supprimer

**Réponse:**
```json
{
  "success": true,
  "message": "Supplier deleted successfully",
  "statusCode": 200,
  "data": null
}
```
