# Documentation de l'API d'Authentification

Ce document décrit les points de terminaison de l'API d'authentification pour Wanzo Gestion Commerciale, qui s'appuie sur **Auth0** pour la gestion des identités et une **API Gateway** pour le routage des requêtes.

> **✅ Conformité DTO** : Cette documentation est alignée avec le code source :
> - `auth.controller.ts` - Contrôleur d'authentification
> - `auth.service.ts::getUserProfileWithOrganization()` - Service profil
> - `user.entity.ts`, `company.entity.ts`, `business-unit.entity.ts` - Entités
> 
> **📖 Documentation connexe** :
> - [users/README.md](../users/README.md) - Gestion des utilisateurs et switch business units
> - [ADHA/README.md](../ADHA/README.md) - Chat IA avec contexte business unit

## Flux d'Authentification Général

1. **Connexion Côté Client** : L'utilisateur est redirigé vers la page de connexion hébergée par Auth0.
2. **Émission du Jeton** : Après une authentification réussie, Auth0 émet un jeton JWT à l'application cliente.
3. **Appel à l'API Gateway** : L'application cliente envoie ce jeton JWT à l'API Gateway, qui route la requête vers le service de gestion commerciale.
4. **Vérification du Jeton** : Le backend valide le jeton JWT avec Auth0 et autorise l'accès aux ressources protégées.

## Architecture Multi-Services

Le système Wanzo utilise une architecture événementielle où plusieurs services collaborent :

- **accounting-service** : Service maître pour la gestion des utilisateurs
  - Crée les utilisateurs dans Auth0 via l'API Management
  - Envoie les emails de réinitialisation de mot de passe
  - Publie les événements utilisateur via Kafka (USER_CREATED, USER_UPDATED)
  
- **gestion_commerciale_service** : Service consommateur
  - Reçoit les utilisateurs via événements Kafka
  - Stocke les utilisateurs localement avec leur `auth0Id`
  - Valide les jetons Auth0 via JwtStrategy + JWKS
  - Gère les opérations commerciales pour les utilisateurs synchronisés

### Flux de Création d'Utilisateur

```
1. Création d'utilisateur :
   accounting-service → Crée l'utilisateur dans Auth0 Management API
                     → Envoie l'email de réinitialisation
                     → Publie l'événement USER_CREATED via Kafka
                     → gestion_commerciale consomme l'événement
                     → Stocke l'utilisateur localement avec auth0Id

2. Connexion utilisateur :
   Frontend → Page de connexion hébergée Auth0
           → L'utilisateur s'authentifie
           → Auth0 retourne le JWT access_token
           → Frontend inclut le jeton Bearer dans les requêtes

3. Validation du jeton :
   Requête avec jeton Bearer → JwtStrategy valide via Auth0 JWKS
                            → Recherche l'utilisateur par auth0Id
                            → Utilisateur authentifié
```

## Base URL

Toutes les requêtes doivent passer par l'API Gateway.

```
http://localhost:8000/commerce/api/v1
```

## Authentification

Toutes les requêtes vers les points de terminaison protégés doivent inclure le jeton JWT émis par Auth0 dans l'en-tête `Authorization`.

**En-têtes :**
```
Authorization: Bearer <auth0_jwt_token>
Content-Type: application/json
```

## Points de Terminaison

### Récupérer le Profil Utilisateur avec Company et Business Unit

Ce point de terminaison récupère les informations complètes du profil utilisateur connecté, incluant les détails de son entreprise (company) et de sa business unit (unité d'affaires).

> **⚠️ Conformité DTO** : Aligné avec `auth.service.ts::getUserProfileWithOrganization()`

**URL :** `GET /commerce/api/v1/auth/me`

**Méthode :** `GET`

**Authentification Requise :** Oui (Jeton Bearer Auth0)

**Headers :**
```
Authorization: Bearer <auth0_jwt_token>
```

**Réponse réussie (200 OK) :**

```json
{
  "success": true,
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "firstName": "Jean",
      "lastName": "Kabongo",
      "email": "jean.kabongo@example.com",
      "role": "manager",
      "companyId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "businessUnitId": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
      "businessUnitType": "branch",
      "isActive": true,
      "createdAt": "2024-01-15T10:30:00.000Z",
      "updatedAt": "2024-03-01T14:45:00.000Z"
    },
    "company": {
      "id": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "name": "Entreprise ABC SARL",
      "registrationNumber": "CD/KIN/RCCM/23-B-12345",
      "address": "123 Avenue du Commerce, Gombe, Kinshasa",
      "phone": "+243 999 123 456",
      "email": "contact@abc-sarl.cd",
      "website": "https://www.abc-sarl.cd",
      "createdAt": "2023-06-01T08:00:00.000Z",
      "updatedAt": "2024-03-01T14:45:00.000Z"
    },
    "businessUnit": {
      "id": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
      "name": "Succursale Kinshasa",
      "code": "BRN-KIN-001",
      "type": "branch",
      "hierarchyLevel": 1,
      "hierarchyPath": "/a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p/b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
      "parentId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "address": "45 Avenue du Commerce, Gombe",
      "city": "Kinshasa",
      "phone": "+243 999 654 321",
      "email": "kinshasa@abc-sarl.cd",
      "managerId": "manager-uuid-123",
      "managerName": "Pierre Mukendi",
      "isActive": true,
      "scope": "unit",
      "createdAt": "2023-07-15T10:00:00.000Z",
      "updatedAt": "2024-02-20T16:30:00.000Z"
    }
  }
}
```

**Exemple si l'utilisateur est au niveau Entreprise (admin/super_admin) :**

```json
{
  "success": true,
  "data": {
    "user": {
      "id": "admin-uuid-456",
      "firstName": "Marie",
      "lastName": "Tshimanga",
      "email": "marie.tshimanga@abc-sarl.cd",
      "role": "admin",
      "companyId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "businessUnitId": null,
      "businessUnitType": "company",
      "isActive": true,
      "createdAt": "2023-06-01T08:00:00.000Z",
      "updatedAt": "2024-03-01T14:45:00.000Z"
    },
    "company": {
      "id": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "name": "Entreprise ABC SARL",
      "registrationNumber": "CD/KIN/RCCM/23-B-12345",
      "address": "123 Avenue du Commerce, Gombe, Kinshasa",
      "phone": "+243 999 123 456",
      "email": "contact@abc-sarl.cd",
      "website": "https://www.abc-sarl.cd",
      "createdAt": "2023-06-01T08:00:00.000Z",
      "updatedAt": "2024-03-01T14:45:00.000Z"
    },
    "businessUnit": {
      "id": "company-bu-uuid-789",
      "name": "Entreprise ABC SARL",
      "code": "COMPANY-001",
      "type": "company",
      "hierarchyLevel": 0,
      "hierarchyPath": "/a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "parentId": null,
      "address": "123 Avenue du Commerce, Gombe, Kinshasa",
      "city": "Kinshasa",
      "phone": "+243 999 123 456",
      "email": "contact@abc-sarl.cd",
      "managerId": "admin-uuid-456",
      "managerName": "Marie Tshimanga",
      "isActive": true,
      "scope": "company",
      "createdAt": "2023-06-01T08:00:00.000Z",
      "updatedAt": "2024-03-01T14:45:00.000Z"
    }
  }
}
```

**Types TypeScript (DTOs) :**

```typescript
// UserRole enum (depuis user.entity.ts)
enum UserRole {
  ADMIN = 'admin',
  SUPER_ADMIN = 'super_admin',
  MANAGER = 'manager',
  ACCOUNTANT = 'accountant',
  CASHIER = 'cashier',
  SALES = 'sales',
  INVENTORY_MANAGER = 'inventory_manager',
  STAFF = 'staff',
  CUSTOMER_SUPPORT = 'customer_support',
}

// BusinessUnitType enum (depuis business-unit.entity.ts)
enum BusinessUnitType {
  COMPANY = 'company',    // Niveau entreprise (racine)
  BRANCH = 'branch',      // Succursale/filiale
  POS = 'pos',            // Point de vente
}

// Interface de réponse /auth/me
interface UserProfileResponse {
  success: true;
  data: {
    user: {
      id: string;
      firstName: string;
      lastName: string;
      email: string;
      role: UserRole;
      companyId: string;
      businessUnitId: string | null;
      businessUnitType: BusinessUnitType;
      isActive: boolean;
      createdAt: string; // ISO 8601
      updatedAt: string; // ISO 8601
    };
    company: {
      id: string;
      name: string;
      registrationNumber: string;
      address: string;
      phone: string;
      email: string;
      website: string | null;
      createdAt: string;
      updatedAt: string;
    };
    businessUnit: {
      id: string;
      name: string;
      code: string;
      type: BusinessUnitType;
      hierarchyLevel: number;
      hierarchyPath: string;
      parentId: string | null;
      address: string;
      city: string;
      phone: string;
      email: string;
      managerId: string | null;
      managerName: string | null;
      isActive: boolean;
      scope: 'unit' | 'company'; // 'company' si user au niveau entreprise
      createdAt: string;
      updatedAt: string;
    };
  };
}
```

**Champs Business Unit (complète) :**

| Champ | Type | Description |
|-------|------|-------------|
| `id` | string (UUID) | Identifiant unique de la business unit |
| `name` | string | Nom de l'unité d'affaires |
| `code` | string | Code unique de l'unité (ex: BRN-KIN-001) |
| `type` | enum | Type: `company`, `branch`, ou `pos` |
| `hierarchyLevel` | number | Niveau dans la hiérarchie (0=company, 1=branch, 2=pos) |
| `hierarchyPath` | string | Chemin complet dans l'arbre hiérarchique |
| `parentId` | string \| null | ID de l'unité parente (null si company) |
| `address` | string | Adresse physique de l'unité |
| `city` | string | Ville |
| `phone` | string | Numéro de téléphone |
| `email` | string | Email de contact |
| `managerId` | string \| null | ID du manager assigné |
| `managerName` | string \| null | Nom complet du manager |
| `isActive` | boolean | Statut d'activation de l'unité |
| `scope` | string | `'unit'` (unité spécifique) ou `'company'` (niveau entreprise) |
| `createdAt` | string | Date de création (ISO 8601) |
| `updatedAt` | string | Date de mise à jour (ISO 8601) |

**Champs Company :**

| Champ | Type | Description |
|-------|------|-------------|
| `id` | string (UUID) | Identifiant unique de l'entreprise |
| `name` | string | Nom de l'entreprise |
| `registrationNumber` | string | Numéro RCCM |
| `address` | string | Adresse du siège |
| `phone` | string | Téléphone principal |
| `email` | string | Email principal |
| `website` | string \| null | Site web |
| `createdAt` | string | Date de création (ISO 8601) |
| `updatedAt` | string | Date de mise à jour (ISO 8601) |

**Champs User :**

| Champ | Type | Description |
|-------|------|-------------|
| `id` | string (UUID) | Identifiant unique de l'utilisateur |
| `firstName` | string | Prénom |
| `lastName` | string | Nom de famille |
| `email` | string | Email de l'utilisateur |
| `role` | enum | Rôle de l'utilisateur (voir UserRole) |
| `companyId` | string | ID de l'entreprise |
| `businessUnitId` | string \| null | ID de la business unit assignée |
| `businessUnitType` | enum | Type de BU (company, branch, pos) |
| `isActive` | boolean | Statut actif/inactif |
| `createdAt` | string | Date de création (ISO 8601) |
| `updatedAt` | string | Date de mise à jour (ISO 8601) |

**Hiérarchie des Business Units:**
- **Company** (Entreprise) : Niveau racine, accès complet
- **Branch** (Succursale) : Filiales/agences régionales
- **POS** (Point de Vente) : Boutiques/dépôts locaux

**Rôles Utilisateur:**

| Rôle | Description | Accès Par Défaut |
|------|-------------|------------------|
| `admin` | Administrateur | Niveau entreprise |
| `super_admin` | Super administrateur | Niveau entreprise |
| `manager` | Manager | Unité assignée |
| `accountant` | Comptable | Unité assignée |
| `cashier` | Caissier | Unité assignée |
| `sales` | Vendeur | Unité assignée |
| `inventory_manager` | Gestionnaire de stock | Unité assignée |
| `staff` | Personnel | Unité assignée |
| `customer_support` | Support client | Unité assignée |

**Statut de Synchronisation (cas spécial):**

Si l'utilisateur n'est pas encore synchronisé depuis le service customer-service, une synchronisation on-demand est déclenchée via Kafka:

```json
{
  "success": false,
  "statusCode": 404,
  "message": "Utilisateur en cours de synchronisation. Veuillez réessayer dans quelques instants.",
  "error": "User not found",
  "syncTriggered": true
}
```

> **Note technique :** Le système utilise Kafka pour la synchronisation. Un événement `user.sync.request` est émis et le consumer `SyncConsumerService` traite la demande. Flutter doit réessayer après 2-3 secondes.

**Réponses d'erreur possibles :**

| Status Code | Message | Description |
|-------------|---------|-------------|
| 401 | Unauthorized | Token JWT absent ou invalide |
| 403 | Forbidden | Accès refusé à cette ressource |
| 404 | User not found | Utilisateur pas encore synchronisé |
| 500 | Internal Server Error | Erreur serveur |

```json
// Exemple erreur 401
{
  "success": false,
  "statusCode": 401,
  "message": "Invalid or expired token",
  "error": "Unauthorized"
}

// Exemple erreur 500
{
  "success": false,
  "statusCode": 500,
  "message": "Failed to retrieve user profile",
  "error": "Internal Server Error"
}
```

---

### Obtenir un Jeton de Gestion

Génère un jeton de gestion à courte durée de vie pour les opérations administratives.

**URL :** `/auth/management-token`

**Méthode :** `POST`

**Authentification Requise :** Oui (Admin uniquement)

**Réponse :** `200 OK`

```json
{
  "token": "management-token-here",
  "expiresIn": 3600
}
```

---

## Gestion des Business Units

Les utilisateurs dans gestion commerciale sont assignés à une business unit (entreprise, succursale ou point de vente). Ils peuvent basculer entre les unités s'ils ont les permissions nécessaires.

### Changer de Business Unit

Permet aux utilisateurs de basculer vers une business unit spécifique en utilisant un code unique.

**URL :** `POST /commerce/api/v1/users/switch-unit`

**Méthode :** `POST`

**Authentification Requise :** Oui (Jeton Bearer Auth0)

**Corps de la requête :**
```json
{
  "code": "BRN-KIN-001"
}
```

**Réponse réussie (200 OK) :**

```json
{
  "success": true,
  "message": "Business unit switched successfully",
  "data": {
    "user": {
      "id": "user-uuid-123",
      "firstName": "Jean",
      "lastName": "Kabongo",
      "email": "jean.kabongo@example.com",
      "role": "manager",
      "companyId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "businessUnitId": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
      "businessUnitType": "branch",
      "isActive": true,
      "createdAt": "2024-01-15T10:30:00.000Z",
      "updatedAt": "2024-03-01T14:45:00.000Z"
    },
    "businessUnit": {
      "id": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
      "name": "Succursale Kinshasa",
      "code": "BRN-KIN-001",
      "type": "branch",
      "hierarchyLevel": 1,
      "hierarchyPath": "/company-uuid/branch-uuid",
      "parentId": "company-uuid",
      "address": "45 Avenue du Commerce, Gombe",
      "city": "Kinshasa",
      "phone": "+243 999 654 321",
      "email": "kinshasa@abc-sarl.cd",
      "managerId": "user-uuid-123",
      "managerName": "Jean Kabongo",
      "isActive": true,
      "scope": "unit",
      "createdAt": "2023-07-15T10:00:00.000Z",
      "updatedAt": "2024-02-20T16:30:00.000Z"
    }
  }
}
```

**Notes:**
- Chaque business unit possède un code unique (ex: `BRN-KIN-001` pour les branches, `POS-KIN-ABC-001` pour les points de vente)
- Les utilisateurs reçoivent leur code de business unit par email lors de l'assignation
- Le code est saisi pour activer la business unit
- Seules les unités du même `companyId` que l'utilisateur sont accessibles

**Erreurs:**

```json
// 404 - Business unit non trouvée
{
  "success": false,
  "statusCode": 404,
  "message": "Business unit with code BRN-KIN-999 not found",
  "error": "Not Found"
}

// 403 - Accès non autorisé
{
  "success": false,
  "statusCode": 403,
  "message": "Access denied to this business unit",
  "error": "Forbidden"
}
```

---

### Réinitialiser au Niveau Entreprise

Réinitialise le contexte de l'utilisateur au niveau entreprise (retire l'assignation spécifique à une succursale/point de vente).

**URL :** `POST /commerce/api/v1/users/reset-to-company`

**Méthode :** `POST`

**Authentification Requise :** Oui (Jeton Bearer Auth0)

**Corps de la requête :** Aucun (body vide ou `{}`)

**Réponse réussie (200 OK) :**

```json
{
  "success": true,
  "message": "Reset to company level successful",
  "data": {
    "user": {
      "id": "admin-uuid-456",
      "firstName": "Marie",
      "lastName": "Tshimanga",
      "email": "marie.tshimanga@abc-sarl.cd",
      "role": "admin",
      "companyId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "businessUnitId": null,
      "businessUnitType": "company",
      "isActive": true,
      "createdAt": "2023-06-01T08:00:00.000Z",
      "updatedAt": "2024-03-01T14:45:00.000Z"
    },
    "businessUnit": {
      "id": "company-bu-uuid",
      "name": "Entreprise ABC SARL",
      "code": "COMPANY-001",
      "type": "company",
      "hierarchyLevel": 0,
      "hierarchyPath": "/a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "parentId": null,
      "address": "123 Avenue du Commerce, Gombe, Kinshasa",
      "city": "Kinshasa",
      "phone": "+243 999 123 456",
      "email": "contact@abc-sarl.cd",
      "managerId": "admin-uuid-456",
      "managerName": "Marie Tshimanga",
      "isActive": true,
      "scope": "company",
      "createdAt": "2023-06-01T08:00:00.000Z",
      "updatedAt": "2024-03-01T14:45:00.000Z"
    }
  }
}
```

> **Note :** Seuls les utilisateurs avec rôle `admin` ou `super_admin` peuvent réinitialiser au niveau entreprise.

---

### Obtenir la Business Unit Courante

Retourne la business unit actuellement active pour l'utilisateur.

**URL :** `GET /commerce/api/v1/users/current-unit`

**Méthode :** `GET`

**Authentification Requise :** Oui (Jeton Bearer Auth0)

**Réponse réussie (200 OK) :**

```json
{
  "success": true,
  "data": {
    "businessUnit": {
      "id": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
      "name": "Succursale Kinshasa",
      "code": "BRN-KIN-001",
      "type": "branch",
      "hierarchyLevel": 1,
      "hierarchyPath": "/company-uuid/branch-uuid",
      "parentId": "company-uuid",
      "address": "45 Avenue du Commerce, Gombe",
      "city": "Kinshasa",
      "phone": "+243 999 654 321",
      "email": "kinshasa@abc-sarl.cd",
      "managerId": "user-uuid-123",
      "managerName": "Jean Kabongo",
      "isActive": true,
      "scope": "unit",
      "createdAt": "2023-07-15T10:00:00.000Z",
      "updatedAt": "2024-02-20T16:30:00.000Z"
    }
  }
}
```

---

### Obtenir les Business Units Accessibles

Retourne la liste de toutes les business units auxquelles l'utilisateur peut accéder.

**URL :** `GET /commerce/api/v1/users/accessible-units`

**Méthode :** `GET`

**Authentification Requise :** Oui (Jeton Bearer Auth0)

**Réponse réussie (200 OK) :**

```json
{
  "success": true,
  "data": {
    "units": [
      {
        "id": "company-uuid",
        "name": "Entreprise ABC SARL",
        "code": "COMPANY-001",
        "type": "company",
        "hierarchyLevel": 0,
        "isActive": true
      },
      {
        "id": "branch-uuid-1",
        "name": "Succursale Kinshasa",
        "code": "BRN-KIN-001",
        "type": "branch",
        "hierarchyLevel": 1,
        "parentId": "company-uuid",
        "isActive": true
      },
      {
        "id": "pos-uuid-1",
        "name": "Point de Vente Gombe",
        "code": "POS-KIN-GBE-001",
        "type": "pos",
        "hierarchyLevel": 2,
        "parentId": "branch-uuid-1",
        "isActive": true
      }
    ],
    "total": 3
  }
}
```

> **Note :** Les utilisateurs au niveau `company` voient toutes les unités. Les utilisateurs assignés à une `branch` voient uniquement leur branche et ses `POS` enfants.

---

## Validation des Jetons

Les jetons sont validés en utilisant le point de terminaison JWKS (JSON Web Key Set) d'Auth0. La stratégie JWT :
1. Récupère les clés publiques depuis `/.well-known/jwks.json` d'Auth0
2. Valide la signature du jeton
3. Extrait le `auth0Id` depuis le claim `sub` du jeton
4. Recherche l'utilisateur dans la base de données locale par `auth0Id`
5. Attache l'utilisateur à la requête pour les vérifications d'autorisation

## Erreurs

**Jeton invalide (401):**
```json
{
  "statusCode": 401,
  "message": "Jeton invalide ou expiré"
}
```

**Permissions insuffisantes (403):**
```json
{
  "statusCode": 403,
  "message": "Permissions insuffisantes"
}
```

**Utilisateur non trouvé (404):**
```json
{
  "statusCode": 404,
  "message": "Utilisateur non trouvé"
}
```

**Erreur serveur (500):**
```json
{
  "statusCode": 500,
  "message": "Erreur interne du serveur"
}
```

---

## Flux Complet d'Utilisation

### 1. Création de l'Utilisateur (accounting-service)

L'administrateur crée un utilisateur dans accounting-service :

```
POST /accounting/api/v1/users
{
  "email": "jean.kabongo@example.com",
  "firstName": "Jean",
  "lastName": "Kabongo",
  "role": "manager",
  "organizationId": "company-uuid-456",
  "businessUnitId": "bu-uuid-789"
}
```

**Actions automatiques:**
1. Création du compte Auth0
2. Envoi de l'email de réinitialisation de mot de passe
3. Publication de l'événement Kafka USER_CREATED
4. Synchronisation vers gestion_commerciale_service

### 2. Première Connexion (Frontend)

L'utilisateur :
1. Clique sur le lien dans l'email Auth0
2. Définit son mot de passe
3. Est redirigé vers Auth0 Hosted Login
4. Reçoit un JWT access_token après authentification

```javascript
// Exemple de réponse Auth0
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 86400
}
```

### 3. Utilisation dans gestion_commerciale

Le frontend inclut le token dans toutes les requêtes :

```
GET /commerce/api/v1/auth/me
Headers: {
  Authorization: "Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### 4. Sélection du Business Unit

Si l'utilisateur a reçu un code business unit, il peut l'activer :

```
POST /commerce/api/v1/users/switch-unit
{
  "code": "BRN-KIN-001"
}
```

Toutes les opérations suivantes seront filtrées par ce business unit.

---

## Différences avec accounting-service

| Aspect | accounting-service | gestion_commerciale_service |
|--------|-------------------|----------------------------|
| Création utilisateurs | ✅ Oui (Auth0 Management API) | ❌ Non (consomme via Kafka) |
| Validation tokens | ✅ Oui (Auth0 JWKS) | ✅ Oui (Auth0 JWKS) |
| Endpoint /auth/verify | ✅ Oui | ❌ Non |
| Endpoint /auth/me | ✅ Oui | ✅ Oui |
| Endpoint /auth/logout | ✅ Oui | ❌ Non (géré côté client) |
| Business unit switch | ❌ Non | ✅ Oui |
| En-tête personnalisé | X-Accounting-Client | Aucun |

---

## Synchronisation Kafka

> **Architecture de synchronisation :** Le gestion_commerciale_service est en mode "Kafka-only" (pas d'appels HTTP inter-services). Toutes les données utilisateurs et entreprises sont synchronisées via Kafka.

### Événements Consommés

**USER_CREATED (topic: user-events):**
```json
{
  "pattern": "user.created",
  "data": {
    "id": "user-uuid-123",
    "email": "jean.kabongo@example.com",
    "firstName": "Jean",
    "lastName": "Kabongo",
    "auth0Id": "auth0|abc123def456",
    "role": "manager",
    "companyId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
    "businessUnitId": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
    "businessUnitType": "branch",
    "isActive": true,
    "createdAt": "2024-01-15T10:30:00.000Z"
  }
}
```

**COMPANY_PROFILE_SHARED (topic: company-events):**
```json
{
  "pattern": "company.profile.shared",
  "data": {
    "id": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
    "name": "Entreprise ABC SARL",
    "registrationNumber": "CD/KIN/RCCM/23-B-12345",
    "address": "123 Avenue du Commerce, Gombe, Kinshasa",
    "phone": "+243 999 123 456",
    "email": "contact@abc-sarl.cd",
    "website": "https://www.abc-sarl.cd",
    "bankAccounts": [],
    "mobileMoneyAccounts": [],
    "createdAt": "2023-06-01T08:00:00.000Z",
    "updatedAt": "2024-03-01T14:45:00.000Z"
  }
}
```

**CUSTOMER_CREATED (topic: customer-events):**
```json
{
  "pattern": "customer.created",
  "data": {
    "id": "customer-uuid-789",
    "companyId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
    "name": "Client XYZ",
    "email": "client@xyz.com",
    "phone": "+243 999 888 777",
    "createdAt": "2024-02-01T10:00:00.000Z"
  }
}
```

### Consumer Implementation

```typescript
// src/modules/events/consumers/sync-consumer.service.ts
@Injectable()
export class SyncConsumerService {
  
  @MessagePattern('user.created')
  async handleUserCreated(data: UserCreatedEvent) {
    await this.userRepository.upsert({
      id: data.id,
      email: data.email,
      firstName: data.firstName,
      lastName: data.lastName,
      auth0Id: data.auth0Id,
      role: data.role,
      companyId: data.companyId,
      businessUnitId: data.businessUnitId,
      businessUnitType: data.businessUnitType,
      isActive: data.isActive,
    });
  }
  
  @MessagePattern('company.profile.shared')
  async handleCompanyProfileShared(data: CompanyProfileEvent) {
    await this.companyRepository.upsert({
      id: data.id,
      name: data.name,
      registrationNumber: data.registrationNumber,
      // ... autres champs
    });
  }
}
```

### Demande de Synchronisation On-Demand

Si un utilisateur accède à `/auth/me` mais n'est pas encore synchronisé, le système :
1. Déclenche un événement Kafka `user.sync.request`
2. Le customer-service répond avec `user.sync.response`
3. Le frontend doit réessayer après 2-3 secondes

```json
// user.sync.request
{
  "pattern": "user.sync.request",
  "data": {
    "auth0Id": "auth0|abc123def456",
    "requestedBy": "gestion_commerciale_service",
    "timestamp": "2024-03-01T14:45:00.000Z"
  }
}
```
