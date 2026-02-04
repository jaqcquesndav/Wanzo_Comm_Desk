# API Clients (Customers)

Cette documentation détaille les endpoints disponibles pour la gestion des clients dans le backend Gestion Commerciale.

## Aperçu

Le module Customer du backend NestJS gère toutes les opérations CRUD liées aux clients avec support multi-tenant (Business Units).

## Modèle de Données

### Customer Entity

```typescript
@Entity('customers')
export class Customer {
  id: string;               // UUID - Identifiant unique du client
  fullName: string;         // Nom complet du client
  phoneNumber: string;      // Numéro de téléphone (unique)
  email?: string;           // Adresse email (unique si fourni)
  address?: string;         // Adresse postale
  createdAt: Date;          // Date de création
  updatedAt: Date;          // Date de dernière mise à jour
  notes?: string;           // Notes concernant le client
  totalPurchases: number;   // Montant total des achats (défaut: 0)
  profilePicture?: string;  // URL de la photo de profil
  lastPurchaseDate?: Date;  // Date du dernier achat
  category: CustomerCategory; // Catégorie du client
  
  // === Champs Business Unit (Multi-Tenant) ===
  companyId?: string;       // UUID entreprise principale
  businessUnitId?: string;  // UUID unité commerciale
  businessUnitCode?: string; // Code de l'unité (ex: POS-KIN-001)
  businessUnitType?: BusinessUnitType; // Type: company, branch, pos
}
```

### CustomerCategory (Enum)

Cette énumération définit les différentes catégories de clients:

```typescript
enum CustomerCategory {
  VIP = 'vip',              // Client VIP ou premium
  REGULAR = 'regular',      // Client régulier (défaut)
  NEW_CUSTOMER = 'new_customer', // Nouveau client
  OCCASIONAL = 'occasional', // Client occasionnel
  BUSINESS = 'business'      // Client B2B (Business to Business)
}
```

### BusinessUnitType (Enum)

Types d'unités commerciales pour le système multi-tenant:

```typescript
enum BusinessUnitType {
  COMPANY = 'company',      // Entreprise principale (niveau 0)
  BRANCH = 'branch',        // Succursale/Agence (niveau 1)
  POS = 'pos'               // Point de Vente (niveau 2)
}
```

## Endpoints

### 1. Récupérer tous les clients

**Endpoint:** `GET /commerce/api/v1/customers`

**Paramètres de requête:**
- `page` (optionnel): Numéro de page pour la pagination
- `limit` (optionnel): Nombre d'éléments par page
- `search` (optionnel): Recherche par nom, email ou téléphone
- `sortBy` (optionnel): Champ de tri (createdAt, fullName, totalPurchases)
- `sortOrder` (optionnel): Ordre de tri (`ASC` ou `DESC`)

**Note:** Le filtrage par companyId et businessUnitId est automatiquement appliqué selon l'utilisateur connecté.

**Réponse:**
```json
{
  "customers": [
    {
      "id": "uuid-customer",
      "fullName": "Jean Dupont",
      "phoneNumber": "+243999123456",
      "email": "jean.dupont@example.com",
      "address": "123 Avenue Liberté",
      "notes": "Client fidèle",
      "totalPurchases": 150000.00,
      "profilePicture": "https://example.com/photos/jean.jpg",
      "lastPurchaseDate": "2025-01-03T14:30:00.000Z",
      "category": "regular",
      "companyId": "uuid-company",
      "businessUnitId": "uuid-bu",
      "businessUnitCode": "POS-KIN-001",
      "businessUnitType": "pos",
      "createdAt": "2024-06-01T10:00:00.000Z",
      "updatedAt": "2025-01-03T14:30:00.000Z"
    }
  ],
  "total": 150,
  "page": 1,
  "limit": 20
}
```

### 2. Récupérer un client par ID

**Endpoint:** `GET /commerce/api/v1/customers/{id}`

**Paramètres:**
- `id`: UUID du client à récupérer

**Réponse:**
```json
{
  "id": "uuid-customer",
  "fullName": "Jean Dupont",
  "phoneNumber": "+243999123456",
  "email": "jean.dupont@example.com",
  "address": "123 Avenue Liberté",
  "notes": "Client fidèle",
  "totalPurchases": 150000.00,
  "profilePicture": "https://example.com/photos/jean.jpg",
  "lastPurchaseDate": "2025-01-03T14:30:00.000Z",
  "category": "regular",
  "companyId": "uuid-company",
  "businessUnitId": "uuid-bu",
  "businessUnitCode": "POS-KIN-001",
  "businessUnitType": "pos",
  "createdAt": "2024-06-01T10:00:00.000Z",
  "updatedAt": "2025-01-03T14:30:00.000Z"
}
```

### 3. Créer un nouveau client

**Endpoint:** `POST /commerce/api/v1/customers`

**Corps de la requête (CreateCustomerDto):**
```json
{
  "fullName": "Jean Dupont",           // Requis
  "phoneNumber": "+243999123456",      // Requis
  "email": "jean.dupont@example.com",  // Optionnel
  "address": "123 Avenue Liberté",     // Optionnel
  "notes": "Client référé par Marie", // Optionnel
  "totalPurchases": 0,                 // Optionnel, défaut: 0
  "profilePicture": "https://...",     // Optionnel
  "lastPurchaseDate": "2025-01-03T14:30:00.000Z", // Optionnel
  "category": "new_customer",          // Optionnel, défaut: regular
  "companyId": "uuid-company",         // Optionnel (auto-défini)
  "businessUnitId": "uuid-bu",         // Optionnel (auto-défini)
  "businessUnitCode": "POS-KIN-001",   // Optionnel
  "businessUnitType": "pos"            // Optionnel
}
```

**Réponse:**
```json
{
  "id": "uuid-new-customer",
  "fullName": "Jean Dupont",
  "phoneNumber": "+243999123456",
  "email": "jean.dupont@example.com",
  "address": "123 Avenue Liberté",
  "notes": "Client référé par Marie",
  "totalPurchases": 0,
  "category": "new_customer",
  "companyId": "uuid-company",
  "businessUnitId": "uuid-bu",
  "businessUnitCode": "POS-KIN-001",
  "businessUnitType": "pos",
  "createdAt": "2025-01-04T10:00:00.000Z",
  "updatedAt": "2025-01-04T10:00:00.000Z"
}
```

### 4. Mettre à jour un client

**Endpoint:** `PATCH /commerce/api/v1/customers/{id}`

**Paramètres:**
- `id`: UUID du client à mettre à jour

**Corps de la requête (UpdateCustomerDto):**
```json
{
  "fullName": "Jean Dupont Jr",        // Optionnel
  "phoneNumber": "+243999654321",      // Optionnel
  "email": "jean.jr@example.com",      // Optionnel
  "address": "456 Avenue Paix",        // Optionnel
  "notes": "VIP depuis 2025",          // Optionnel
  "totalPurchases": 500000,            // Optionnel
  "profilePicture": "https://...",     // Optionnel
  "lastPurchaseDate": "2025-01-04",    // Optionnel
  "category": "vip"                    // Optionnel
}
```

**Réponse:**
```json
{
  "id": "uuid-customer",
  "fullName": "Jean Dupont Jr",
  "phoneNumber": "+243999654321",
  "email": "jean.jr@example.com",
  "category": "vip",
  "updatedAt": "2025-01-04T12:00:00.000Z"
}
```

### 5. Supprimer un client

**Endpoint:** `DELETE /commerce/api/v1/customers/{id}`

**Paramètres:**
- `id`: UUID du client à supprimer

**Réponse:** `204 No Content`

## Validation des Données

### CreateCustomerDto - Règles de validation

| Champ | Type | Validation |
|-------|------|------------|
| `fullName` | string | Requis, non vide |
| `phoneNumber` | string | Requis, format téléphone valide |
| `email` | string | Optionnel, format email valide |
| `address` | string | Optionnel |
| `notes` | string | Optionnel |
| `totalPurchases` | number | Optionnel, >= 0 |
| `profilePicture` | string | Optionnel, format URL valide |
| `lastPurchaseDate` | string | Optionnel, format ISO8601 |
| `category` | enum | Optionnel, valeur de CustomerCategory |
| `companyId` | string | Optionnel, format UUID |
| `businessUnitId` | string | Optionnel, format UUID |
| `businessUnitCode` | string | Optionnel |
| `businessUnitType` | enum | Optionnel, valeur de BusinessUnitType |

## Codes d'erreur

| Code | Description |
|------|-------------|
| 201 | Client créé avec succès |
| 200 | Opération réussie |
| 204 | Client supprimé avec succès |
| 400 | Données invalides |
| 401 | Non autorisé - Token manquant ou invalide |
| 404 | Client non trouvé |
| 409 | Conflit - Email ou téléphone déjà utilisé |

## Architecture Multi-Tenant

Le filtrage des clients est automatiquement appliqué selon le contexte de l'utilisateur connecté:

1. **companyId**: Filtre par l'entreprise de l'utilisateur
2. **businessUnitId**: Filtre par l'unité commerciale de l'utilisateur (si défini)

Les champs business unit sont automatiquement renseignés lors de la création si non fournis.
