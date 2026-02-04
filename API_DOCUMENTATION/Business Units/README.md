# API Unités d'Affaires (Business Units)

Cette documentation détaille les endpoints disponibles pour la gestion des unités d'affaires dans l'application Wanzo. Le module Business Units permet de gérer une hiérarchie organisationnelle à trois niveaux pour isoler les données par entreprise, succursale et point de vente.

## Concepts Clés

### Hiérarchie des Unités d'Affaires

Le système supporte une hiérarchie à 3 niveaux:

```
COMPANY (Entreprise) - Niveau 0
    └── BRANCH (Succursale) - Niveau 1
            └── POS (Point de Vente) - Niveau 2
```

**Règles de hiérarchie:**
- Une **COMPANY** ne peut pas avoir de parent (racine de la hiérarchie)
- Une **BRANCH** doit avoir une COMPANY comme parent
- Un **POS** peut avoir une COMPANY ou une BRANCH comme parent

### Types d'Unités d'Affaires

Les types d'unités sont représentés par des chaînes de caractères:

| Type | Description | Niveau | Parent autorisé |
|------|-------------|--------|-----------------|
| `company` | Entreprise principale | 0 | Aucun |
| `branch` | Succursale/Agence | 1 | COMPANY uniquement |
| `pos` | Point de Vente | 2 | COMPANY ou BRANCH |

### Statuts des Unités

| Statut | Description |
|--------|-------------|
| `active` | Unité opérationnelle |
| `inactive` | Unité temporairement désactivée |
| `suspended` | Unité suspendue (problème) |
| `closed` | Unité définitivement fermée |

## Structure du Modèle Business Unit

```json
{
  "id": "uuid-string",                          // Identifiant unique (UUID)
  "code": "BRN-001",                             // Code unique par entreprise
  "name": "Succursale Gombe",                   // Nom de l'unité
  "type": "branch",                             // Type: company, branch, pos
  "status": "active",                           // Statut: active, inactive, suspended, closed
  "companyId": "uuid-company",                  // ID de l'entreprise principale
  "parentId": "uuid-parent",                    // ID de l'unité parente (null si company)
  "hierarchyLevel": 1,                          // Niveau dans la hiérarchie (0, 1 ou 2)
  "hierarchyPath": "/company-id/unit-id",       // Chemin complet dans la hiérarchie
  "address": "123 Avenue de la Paix",           // Adresse (optionnel)
  "city": "Kinshasa",                           // Ville (optionnel)
  "province": "Kinshasa",                       // Province (optionnel)
  "country": "RDC",                             // Pays (défaut: RDC)
  "phone": "+243999000111",                     // Téléphone (optionnel)
  "email": "gombe@wanzo.cd",                    // Email (optionnel)
  "manager": "Jean Dupont",                     // Nom du responsable (optionnel)
  "managerId": "uuid-manager",                  // ID utilisateur du responsable (optionnel)
  "currency": "CDF",                            // Devise principale (défaut: CDF)
  "timezone": "Africa/Kinshasa",                // Fuseau horaire (défaut: Africa/Kinshasa)
  "settings": {},                               // Paramètres personnalisés (JSON)
  "metadata": {},                               // Métadonnées additionnelles (JSON)
  "accountingServiceId": "uuid-accounting",     // ID correspondant dans accounting-service (sync)
  "createdAt": "2024-01-15T10:30:00.000Z",      // Date de création
  "updatedAt": "2024-01-20T14:00:00.000Z",      // Date de dernière modification
  "createdBy": "uuid-user",                     // Utilisateur créateur
  "updatedBy": "uuid-user"                      // Dernier modificateur
}
```

### Détails des Paramètres (settings)

Le champ `settings` est un objet JSON permettant de configurer des paramètres spécifiques à l'unité:

```json
{
  "settings": {
    "defaultPriceList": "PRIX-STANDARD",     // Liste de prix par défaut
    "allowDiscounts": true,                   // Autoriser les remises
    "maxDiscountPercent": 15,                 // Remise maximale autorisée (%)
    "maxTransactionAmount": 10000000,         // Montant max par transaction (CDF)
    "dailyTransactionLimit": 50000000,        // Limite journalière (CDF)
    "defaultTaxRate": 16,                     // Taux de taxe par défaut (%)
    "vatNumber": "CD-TVA-123456"              // Numéro de TVA
  }
}

## Changer d'Unité d'Affaires (User Context)

Pour qu'un utilisateur change son contexte d'unité d'affaires (filtrer ses données), utilisez les endpoints dans le module **Users**:

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/users/switch-unit` | POST | Changer d'unité via un code (ex: `{"code": "BRN-KIN-001"}`) |
| `/users/reset-to-company` | POST | Revenir au niveau entreprise |
| `/users/current-unit` | GET | Obtenir l'unité actuelle de l'utilisateur |
| `/users/accessible-units` | GET | Lister les unités accessibles à l'utilisateur |

➡️ Voir la [documentation Users](../users/README.md) pour les détails complets.

## Authentification et Autorisations

Tous les endpoints nécessitent une authentification JWT (Auth0):
```
Authorization: Bearer <jwt_token_auth0>
```

**Rôles requis par endpoint:**

| Endpoint | Méthode | Rôles Requis |
|----------|---------|--------------|
| Lister unités | GET | Tous les utilisateurs authentifiés |
| Voir une unité | GET | Tous les utilisateurs authentifiés |
| Hiérarchie | GET | Tous les utilisateurs authentifiés |
| Créer unité | POST | ADMIN, MANAGER |
| Modifier unité | PUT | ADMIN, MANAGER |
| Supprimer unité | DELETE | ADMIN uniquement |

## Endpoints

### 1. Lister les unités d'affaires

**Endpoint:** `GET /commerce/api/v1/business-units`

**Paramètres de requête:**
| Paramètre | Type | Obligatoire | Description |
|-----------|------|-------------|-------------|
| `companyId` | string | Non | Filtrer par ID d'entreprise (par défaut: entreprise de l'utilisateur) |
| `type` | string | Non | Filtrer par type: `company`, `branch`, `pos` |
| `parentId` | string | Non | Filtrer par ID de l'unité parente |
| `search` | string | Non | Recherche par nom ou code |
| `status` | string | Non | Filtrer par statut |
| `includeInactive` | boolean | Non | Inclure les unités inactives (défaut: false) |

**Exemple de requête:**
```bash
GET /commerce/api/v1/business-units?type=branch&search=gombe
```

**Réponse:**
```json
{
  "success": true,
  "data": [
    {
      "id": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
      "code": "BRN-001",
      "name": "Succursale Gombe",
      "type": "branch",
      "status": "active",
      "companyId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "parentId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "hierarchyLevel": 1,
      "address": "123 Avenue de la Paix",
      "city": "Kinshasa",
      "createdAt": "2024-01-15T10:30:00.000Z"
    },
    {
      "id": "c8b2d4e6-3f5g-7h9i-0j1k-2l3m4n5o6p7q",
      "code": "BRN-002",
      "name": "Succursale Limete",
      "type": "branch",
      "status": "active",
      "companyId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "parentId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "hierarchyLevel": 1,
      "address": "456 Boulevard du 30 Juin",
      "city": "Kinshasa",
      "createdAt": "2024-01-16T08:00:00.000Z"
    }
  ]
}
```

---

### 2. Récupérer la hiérarchie complète

**Endpoint:** `GET /commerce/api/v1/business-units/hierarchy`

Retourne l'arbre hiérarchique complet de l'entreprise de l'utilisateur connecté.

**Réponse:**
```json
{
  "success": true,
  "data": {
    "id": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
    "code": "WANZO-HQ",
    "name": "Wanzo Corporation",
    "type": "company",
    "status": "active",
    "hierarchyLevel": 0,
    "children": [
      {
        "id": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
        "code": "BRN-001",
        "name": "Succursale Gombe",
        "type": "branch",
        "status": "active",
        "hierarchyLevel": 1,
        "children": [
          {
            "id": "d9c3e5f7-4g6h-8i0j-1k2l-3m4n5o6p7q8r",
            "code": "POS-001",
            "name": "Point de Vente Centre",
            "type": "pos",
            "status": "active",
            "hierarchyLevel": 2
          },
          {
            "id": "e0d4f6g8-5h7i-9j1k-2l3m-4n5o6p7q8r9s",
            "code": "POS-002",
            "name": "Point de Vente Nord",
            "type": "pos",
            "status": "active",
            "hierarchyLevel": 2
          }
        ]
      },
      {
        "id": "c8b2d4e6-3f5g-7h9i-0j1k-2l3m4n5o6p7q",
        "code": "BRN-002",
        "name": "Succursale Limete",
        "type": "branch",
        "status": "active",
        "hierarchyLevel": 1,
        "children": [
          {
            "id": "f1e5g7h9-6i8j-0k2l-3m4n-5o6p7q8r9s0t",
            "code": "POS-003",
            "name": "Point de Vente Limete",
            "type": "pos",
            "status": "active",
            "hierarchyLevel": 2
          }
        ]
      }
    ]
  }
}
```

---

### 3. Récupérer l'unité courante de l'utilisateur

**Endpoint:** `GET /commerce/api/v1/business-units/current`

Retourne l'unité d'affaires associée à l'utilisateur connecté. Si aucune unité n'est assignée, retourne l'entreprise principale par défaut.

**Réponse (Unité assignée):**
```json
{
  "success": true,
  "data": {
    "id": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
    "code": "BRN-001",
    "name": "Succursale Gombe",
    "type": "branch",
    "status": "active",
    "companyId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
    "parentId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
    "hierarchyLevel": 1,
    "parent": {
      "id": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "code": "WANZO-HQ",
      "name": "Wanzo Corporation",
      "type": "company"
    }
  }
}
```

**Réponse (Unité par défaut):**
```json
{
  "success": true,
  "data": {
    "id": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
    "code": "WANZO-HQ",
    "name": "Wanzo Corporation",
    "type": "company",
    "status": "active",
    "hierarchyLevel": 0
  },
  "message": "Unité par défaut (Entreprise Générale)"
}
```

---

### 4. Récupérer une unité par ID

**Endpoint:** `GET /commerce/api/v1/business-units/{id}`

**Paramètres:**
| Paramètre | Type | Description |
|-----------|------|-------------|
| `id` | string | ID UUID de l'unité à récupérer |

**Exemple de requête:**
```bash
GET /commerce/api/v1/business-units/b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p
```

**Réponse:**
```json
{
  "success": true,
  "data": {
    "id": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
    "code": "BRN-001",
    "name": "Succursale Gombe",
    "type": "branch",
    "status": "active",
    "companyId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
    "parentId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
    "hierarchyLevel": 1,
    "hierarchyPath": "/a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p/b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
    "address": "123 Avenue de la Paix",
    "city": "Kinshasa",
    "province": "Kinshasa",
    "country": "RDC",
    "phone": "+243999000111",
    "email": "gombe@wanzo.cd",
    "manager": "Jean Dupont",
    "parent": {
      "id": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "code": "WANZO-HQ",
      "name": "Wanzo Corporation",
      "type": "company"
    },
    "children": [
      {
        "id": "d9c3e5f7-4g6h-8i0j-1k2l-3m4n5o6p7q8r",
        "code": "POS-001",
        "name": "Point de Vente Centre"
      }
    ],
    "createdAt": "2024-01-15T10:30:00.000Z",
    "updatedAt": "2024-01-20T14:00:00.000Z"
  }
}
```

**Erreur 404:**
```json
{
  "success": false,
  "message": "Unité d'affaires b7a1c3d5-... non trouvée",
  "statusCode": 404
}
```

---

### 5. Récupérer une unité par code

**Endpoint:** `GET /commerce/api/v1/business-units/code/{code}`

**Paramètres:**
| Paramètre | Type | Description |
|-----------|------|-------------|
| `code` | string | Code de l'unité (ex: BRN-001, POS-002) |

**Exemple de requête:**
```bash
GET /commerce/api/v1/business-units/code/BRN-001
```

**Réponse:**
```json
{
  "success": true,
  "data": {
    "id": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
    "code": "BRN-001",
    "name": "Succursale Gombe",
    "type": "branch",
    "status": "active",
    "companyId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
    "parent": {
      "id": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "code": "WANZO-HQ",
      "name": "Wanzo Corporation"
    }
  }
}
```

---

### 6. Créer une nouvelle unité d'affaires

**Endpoint:** `POST /commerce/api/v1/business-units`

**Rôles requis:** `ADMIN`, `MANAGER`

**Corps de la requête:**
```json
{
  "code": "BRN-003",                            // Obligatoire - Code unique
  "name": "Succursale Ngaliema",                // Obligatoire - Nom de l'unité
  "type": "branch",                             // Obligatoire - company, branch, pos
  "companyId": "uuid-company",                  // Optionnel - Défaut: entreprise de l'utilisateur
  "parentId": "uuid-parent",                    // Optionnel - Requis sauf pour type company
  "address": "789 Avenue de la Victoire",       // Optionnel
  "city": "Kinshasa",                           // Optionnel
  "province": "Kinshasa",                       // Optionnel
  "country": "RDC",                             // Optionnel
  "phone": "+243999000333",                     // Optionnel
  "email": "ngaliema@wanzo.cd",                 // Optionnel
  "manager": "Pierre Martin",                   // Optionnel
  "managerId": "uuid-manager",                  // Optionnel
  "currency": "CDF",                            // Optionnel
  "settings": {                                 // Optionnel
    "autoSync": true
  },
  "metadata": {}                                // Optionnel
}
```

**Réponse succès (201):**
```json
{
  "success": true,
  "data": {
    "id": "g2f6h8i0-7j9k-1l3m-4n5o-6p7q8r9s0t1u",
    "code": "BRN-003",
    "name": "Succursale Ngaliema",
    "type": "branch",
    "status": "active",
    "companyId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
    "parentId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
    "hierarchyLevel": 1,
    "hierarchyPath": "/a1b2c3d4-.../g2f6h8i0-...",
    "address": "789 Avenue de la Victoire",
    "city": "Kinshasa",
    "createdAt": "2024-01-25T09:00:00.000Z"
  },
  "message": "Unité BRN-003 créée avec succès"
}
```

**Erreurs possibles:**

| Code | Message | Cause |
|------|---------|-------|
| 400 | "Seule une entreprise peut être sans parent" | Type branch/pos sans parentId |
| 400 | "Une entreprise ne peut pas avoir de parent" | Type company avec parentId |
| 400 | "Une succursale doit avoir une entreprise comme parent" | Branch avec parent non-company |
| 400 | "Un point de vente ne peut pas avoir d'unités enfants" | Parent de type POS |
| 404 | "Unité parente {id} non trouvée" | parentId invalide |
| 409 | "Une unité avec le code {code} existe déjà" | Code en doublon |

---

### 7. Mettre à jour une unité d'affaires

**Endpoint:** `PUT /commerce/api/v1/business-units/{id}`

**Rôles requis:** `ADMIN`, `MANAGER`

**Paramètres:**
| Paramètre | Type | Description |
|-----------|------|-------------|
| `id` | string | ID UUID de l'unité à modifier |

**Corps de la requête:**
```json
{
  "name": "Succursale Gombe - Centre",          // Optionnel
  "status": "active",                           // Optionnel
  "address": "123 Avenue de la Paix, 2ème étage", // Optionnel
  "city": "Kinshasa",                           // Optionnel
  "province": "Kinshasa",                       // Optionnel
  "country": "RDC",                             // Optionnel
  "phone": "+243999000111",                     // Optionnel
  "email": "gombe-centre@wanzo.cd",             // Optionnel
  "manager": "Marie Ntumba",                    // Optionnel
  "managerId": "uuid-new-manager",              // Optionnel
  "currency": "USD",                            // Optionnel
  "settings": {                                 // Optionnel
    "autoSync": true,
    "defaultPriceList": "retail"
  },
  "metadata": {}                                // Optionnel
}
```

> **Note:** Le `code`, `type`, `companyId` et `parentId` ne peuvent pas être modifiés après création.

**Réponse:**
```json
{
  "success": true,
  "data": {
    "id": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
    "code": "BRN-001",
    "name": "Succursale Gombe - Centre",
    "type": "branch",
    "status": "active",
    "email": "gombe-centre@wanzo.cd",
    "manager": "Marie Ntumba",
    "updatedAt": "2024-01-26T11:30:00.000Z"
  },
  "message": "Unité mise à jour avec succès"
}
```

---

### 8. Supprimer une unité d'affaires

**Endpoint:** `DELETE /commerce/api/v1/business-units/{id}`

**Rôles requis:** `ADMIN` uniquement

Cette opération effectue une suppression logique (soft delete) en changeant le statut à `closed`.

**Paramètres:**
| Paramètre | Type | Description |
|-----------|------|-------------|
| `id` | string | ID UUID de l'unité à supprimer |

**Contraintes:**
- Impossible de supprimer une unité ayant des enfants actifs
- L'entreprise principale (COMPANY) ne peut généralement pas être supprimée

**Réponse:**
```json
{
  "success": true,
  "message": "Unité supprimée avec succès"
}
```

**Erreur (enfants actifs):**
```json
{
  "success": false,
  "message": "Impossible de supprimer: l'unité a des enfants actifs",
  "statusCode": 400
}
```

---

### 9. Récupérer les unités enfants

**Endpoint:** `GET /commerce/api/v1/business-units/{id}/children`

Retourne toutes les unités dont le parent est l'unité spécifiée.

**Paramètres:**
| Paramètre | Type | Description |
|-----------|------|-------------|
| `id` | string | ID UUID de l'unité parente |

**Exemple:**
```bash
GET /commerce/api/v1/business-units/b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p/children
```

**Réponse:**
```json
{
  "success": true,
  "data": [
    {
      "id": "d9c3e5f7-4g6h-8i0j-1k2l-3m4n5o6p7q8r",
      "code": "POS-001",
      "name": "Point de Vente Centre",
      "type": "pos",
      "status": "active",
      "parentId": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
      "hierarchyLevel": 2
    },
    {
      "id": "e0d4f6g8-5h7i-9j1k-2l3m-4n5o6p7q8r9s",
      "code": "POS-002",
      "name": "Point de Vente Nord",
      "type": "pos",
      "status": "active",
      "parentId": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
      "hierarchyLevel": 2
    }
  ]
}
```

---

### 10. Récupérer le chemin vers l'entreprise

**Endpoint:** `GET /commerce/api/v1/business-units/{id}/path-to-company`

Retourne le chemin hiérarchique complet depuis l'unité spécifiée jusqu'à l'entreprise principale, utile pour la navigation et l'agrégation des données.

**Paramètres:**
| Paramètre | Type | Description |
|-----------|------|-------------|
| `id` | string | ID UUID de l'unité de départ |

**Exemple:**
```bash
GET /commerce/api/v1/business-units/d9c3e5f7-4g6h-8i0j-1k2l-3m4n5o6p7q8r/path-to-company
```

**Réponse:**
```json
{
  "success": true,
  "data": [
    {
      "id": "d9c3e5f7-4g6h-8i0j-1k2l-3m4n5o6p7q8r",
      "code": "POS-001",
      "name": "Point de Vente Centre",
      "type": "pos",
      "hierarchyLevel": 2
    },
    {
      "id": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
      "code": "BRN-001",
      "name": "Succursale Gombe",
      "type": "branch",
      "hierarchyLevel": 1
    },
    {
      "id": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "code": "WANZO-HQ",
      "name": "Wanzo Corporation",
      "type": "company",
      "hierarchyLevel": 0
    }
  ]
}
```

---

## Cas d'utilisation

### 1. Configuration initiale d'une entreprise

```bash
# 1. Créer l'entreprise principale
POST /commerce/api/v1/business-units
{
  "code": "WANZO-HQ",
  "name": "Wanzo Corporation",
  "type": "company",
  "address": "Tour Wanzo, Gombe",
  "city": "Kinshasa",
  "country": "RDC"
}

# 2. Créer les succursales
POST /commerce/api/v1/business-units
{
  "code": "BRN-001",
  "name": "Succursale Gombe",
  "type": "branch",
  "parentId": "<company-id>",
  "city": "Kinshasa"
}

# 3. Créer les points de vente
POST /commerce/api/v1/business-units
{
  "code": "POS-001",
  "name": "Point de Vente Centre",
  "type": "pos",
  "parentId": "<branch-id>"
}
```

### 2. Filtrage des données par unité d'affaires

Les autres modules (Sales, Expenses, etc.) utilisent les champs suivants pour filtrer les données:

- `companyId`: Filtre au niveau entreprise (toutes les données)
- `businessUnitId`: Filtre au niveau de l'unité spécifique
- `businessUnitCode`: Code lisible de l'unité
- `businessUnitType`: Type d'unité pour filtres conditionnels

**Exemple: Récupérer les ventes d'une succursale**
```bash
GET /commerce/api/v1/sales?businessUnitId=b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p
```

---

## Synchronisation via Kafka

Le module Business Units publie des événements Kafka pour synchroniser les unités entre les microservices:

### Topics Kafka

| Topic | Description |
|-------|-------------|
| `accounting.business-unit.created` | Nouvelle unité créée |
| `accounting.business-unit.updated` | Unité modifiée |
| `accounting.business-unit.deleted` | Unité supprimée |

### Structure d'un événement

```json
{
  "eventType": "business-unit.created",
  "businessUnit": {
    "id": "uuid",
    "code": "BRN-001",
    "name": "Succursale Gombe",
    "type": "branch",
    "status": "active",
    "companyId": "uuid-company",
    "parentId": "uuid-parent",
    "hierarchyLevel": 1,
    "metadata": {}
  },
  "timestamp": "2024-01-25T10:00:00.000Z",
  "source": "gestion_commerciale_service"
}
```

---

## Codes d'erreur

| Code HTTP | Message | Cause |
|-----------|---------|-------|
| 400 | Bad Request | Données invalides ou règles de hiérarchie violées |
| 401 | Unauthorized | Token JWT manquant ou invalide |
| 403 | Forbidden | Rôle insuffisant pour l'opération |
| 404 | Not Found | Unité ou parent non trouvé |
| 409 | Conflict | Code d'unité déjà existant |
| 500 | Internal Server Error | Erreur serveur |

---

## Notes pour les développeurs

1. **Isolation des données**: Chaque opération est automatiquement filtrée par `companyId` de l'utilisateur
2. **Héritage des permissions**: Un utilisateur avec accès à une BRANCH voit également les données de ses POS enfants
3. **Migration**: Lors de la première utilisation, une entreprise principale est automatiquement créée pour chaque companyId existant
4. **Cache**: Les hiérarchies sont mises en cache pour améliorer les performances
5. **Soft Delete**: La suppression est toujours logique - les données historiques restent accessibles
