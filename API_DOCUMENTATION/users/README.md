# API Utilisateurs (Users)

Cette documentation détaille les endpoints disponibles pour la gestion des utilisateurs et des business units dans l'application Wanzo Gestion Commerciale.

> **✅ Conformité**: Aligné avec `user.entity.ts`, `user-business-unit.controller.ts` et `users.controller.ts`

## Architecture

Les utilisateurs sont créés dans **accounting-service** et synchronisés vers **gestion_commerciale_service** via Kafka. Ce module gère :
- Le profil utilisateur local
- Le switch entre business units
- La gestion des unités accessibles

## Rôles Utilisateurs (UserRole)

Les rôles utilisateurs disponibles dans le système :

| Rôle | Valeur API | Description | Accès Business Unit |
|------|------------|-------------|---------------------|
| Administrateur | `admin` | Propriétaire de l'entreprise | Niveau entreprise |
| Super Admin | `super_admin` | Super administrateur | Niveau entreprise |
| Manager | `manager` | Gestionnaire avec droits étendus | Unité assignée |
| Comptable | `accountant` | Accès aux fonctions comptables | Unité assignée |
| Caissier | `cashier` | Accès aux fonctions de caisse | Unité assignée |
| Commercial | `sales` | Accès aux fonctions de vente | Unité assignée |
| Gestionnaire Stock | `inventory_manager` | Accès à la gestion des stocks | Unité assignée |
| Employé | `staff` | Employé standard (rôle par défaut) | Unité assignée |
| Support Client | `customer_support` | Accès au support client | Unité assignée |

## Structure du modèle Utilisateur

```json
{
  "id": "uuid-string",
  "email": "user@example.com",
  "firstName": "John",
  "lastName": "Doe",
  "phoneNumber": "+243123456789",
  "role": "staff",
  "isActive": true,
  "profilePictureUrl": "https://...",
  "lastLoginAt": "2023-08-01T12:30:00Z",
  
  "companyId": "uuid-company",
  "businessUnitId": "uuid-bu",
  "businessUnitCode": "BRN-KIN-001",
  "businessUnitType": "branch",
  
  "auth0Id": "auth0|123456789",
  
  "settings": {
    "theme": "dark",
    "language": "fr",
    "notifications": {
      "email": true,
      "push": false
    }
  },
  
  "createdAt": "2023-07-01T12:30:00Z",
  "updatedAt": "2023-08-01T12:30:00Z"
}
```

### Types d'Unités d'Affaires (businessUnitType)

| Type | Niveau | Description |
|------|--------|-------------|
| `company` | 0 | Entreprise principale - Défaut |
| `branch` | 1 | Succursale/Agence |
| `pos` | 2 | Point de Vente |

---

## Endpoints

### 1. Récupérer le profil utilisateur complet (GET /users/me)

**Endpoint**: `GET /commerce/api/v1/users/me`

**Description**: Récupère les informations complètes de l'utilisateur connecté, incluant les données de l'entreprise (company) et de l'unité d'affaires (business unit). **Aligné avec accounting-service** pour une cohérence inter-services.

**Headers**:
```
Authorization: Bearer <auth0_jwt_token>
```

**Réponse réussie (200)**:
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "auth0Id": "auth0|abc123def456",
      "email": "john.doe@example.com",
      "firstName": "John",
      "lastName": "Doe",
      "phoneNumber": "+243999123456",
      "role": "manager",
      "companyId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "businessUnitId": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
      "businessUnitCode": "BRN-KIN-001",
      "businessUnitType": "branch",
      "isActive": true,
      "profilePictureUrl": "https://storage.wanzo.cd/profiles/user123.jpg",
      "lastLoginAt": "2025-12-28T10:30:00.000Z",
      "createdAt": "2025-01-15T08:00:00.000Z",
      "updatedAt": "2025-12-28T10:30:00.000Z"
    },
    "company": {
      "id": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "name": "Entreprise ABC SARL",
      "registrationNumber": "RC/KIN/2023/12345",
      "address": "123 Avenue des Martyrs, Kinshasa",
      "phone": "+243999888777",
      "email": "contact@abc-sarl.cd",
      "website": "https://abc-sarl.cd",
      "isActive": true,
      "createdAt": "2025-01-01T00:00:00.000Z",
      "updatedAt": "2025-06-15T12:00:00.000Z"
    },
    "businessUnit": {
      "id": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
      "name": "Succursale Kinshasa",
      "code": "BRN-KIN-001",
      "type": "branch",
      "hierarchyLevel": 1,
      "hierarchyPath": "/a1b2c3d4.../b7a1c3d5...",
      "parentId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "address": "456 Avenue Commerce",
      "city": "Kinshasa",
      "phone": "+243999777666",
      "email": "kinshasa@abc-sarl.cd",
      "status": "active"
    }
  }
}
```

**Erreurs possibles**:

```json
// Utilisateur non associé à une entreprise (403)
{
  "statusCode": 403,
  "message": "Accès refusé : Utilisateur non associé à une entreprise. Veuillez compléter votre inscription via le service client."
}
```

> **Note**: Cet endpoint retourne les informations complètes. Pour plus de détails sur l'authentification, voir aussi `GET /auth/me` dans [auth/README.md](../auth/README.md).

---

### 2. Mettre à jour le profil utilisateur (PUT /users/me)

**Endpoint**: `PUT /commerce/api/v1/users/me`

**Description**: Met à jour les informations de profil de l'utilisateur connecté. Seuls certains champs sont modifiables par l'utilisateur.

**Headers**:
```
Authorization: Bearer <auth0_jwt_token>
```

**Corps de la requête**:
```json
{
  "firstName": "Jean",
  "lastName": "Dupont",
  "phoneNumber": "+243999111222",
  "profilePictureUrl": "https://storage.wanzo.cd/profiles/new-avatar.jpg"
}
```

**Champs modifiables**:
- `firstName` - Prénom
- `lastName` - Nom de famille
- `phoneNumber` - Numéro de téléphone
- `profilePictureUrl` - URL de la photo de profil

**Réponse réussie (200)**:
```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "john.doe@example.com",
    "firstName": "Jean",
    "lastName": "Dupont",
    "phoneNumber": "+243999111222",
    "profilePictureUrl": "https://storage.wanzo.cd/profiles/new-avatar.jpg",
    "updatedAt": "2025-12-28T15:30:00.000Z"
  },
  "message": "Profil mis à jour avec succès"
}
```

---

## Gestion des Business Units

Ces endpoints permettent à l'utilisateur de naviguer entre les différentes unités d'affaires (entreprise, succursales, points de vente) auxquelles il a accès.

### 3. Changer de Business Unit (Switch Unit)

**Endpoint**: `POST /commerce/api/v1/users/switch-unit`

**Description**: Permet à l'utilisateur de basculer vers une succursale ou un point de vente via son code unique. Par défaut, l'utilisateur est connecté à l'Entreprise Générale (niveau company).

**Workflow d'utilisation**:
1. L'administrateur assigne une business unit à l'utilisateur dans accounting-service
2. L'utilisateur reçoit le **code de l'unité** (ex: `BRN-KIN-001`) par email ou de son admin
3. L'utilisateur entre ce code via cet endpoint
4. Toutes ses opérations sont maintenant filtrées par cette unité
5. Les données envoyées à Adha AI incluent le `businessUnitId`

**Corps de la requête**:
```json
{
  "code": "BRN-KIN-001"
}
```

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Vous êtes maintenant connecté à: Succursale Kinshasa",
  "data": {
    "businessUnitId": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
    "businessUnitCode": "BRN-KIN-001",
    "businessUnitName": "Succursale Kinshasa",
    "businessUnitType": "branch",
    "companyId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
    "companyName": "Entreprise ABC SARL",
    "hierarchyPath": "/a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p/b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p"
  }
}
```

**Codes Business Unit**:
| Type | Format Code | Exemple |
|------|-------------|---------|
| Company | `COMPANY-XXX` | `COMPANY-001` |
| Branch | `BRN-XXX-XXX` | `BRN-KIN-001` |
| POS | `POS-XXX-XXX` | `POS-KIN-001` |

**Erreurs possibles**:

```json
// Code non trouvé (404)
{
  "statusCode": 404,
  "message": "Code d'unité \"BRN-INVALID\" non trouvé. Vérifiez le code communiqué par votre administrateur."
}
```

```json
// Unité inactive (400)
{
  "statusCode": 400,
  "message": "L'unité \"Succursale Test\" n'est pas active (statut: suspended)"
}
```

```json
// Accès non autorisé (403)
{
  "statusCode": 403,
  "message": "Vous n'avez pas accès à cette unité d'affaires"
}
```

---

### 3. Revenir à l'Entreprise Générale (Reset to Company)

**Endpoint**: `POST /commerce/api/v1/users/reset-to-company`

**Description**: Réinitialise l'utilisateur vers l'Entreprise Générale (niveau company). Cela retire l'assignation spécifique à une succursale ou point de vente.

**Corps de la requête**: Vide ou `{}`

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Vous êtes maintenant connecté à: Entreprise ABC SARL",
  "data": {
    "businessUnitId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
    "businessUnitCode": "COMPANY-001",
    "businessUnitName": "Entreprise ABC SARL",
    "businessUnitType": "company",
    "companyId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
    "companyName": "Entreprise ABC SARL",
    "hierarchyPath": "/a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p"
  }
}
```

---

### 4. Obtenir l'Unité Courante

**Endpoint**: `GET /commerce/api/v1/users/current-unit`

**Description**: Retourne l'unité d'affaires actuellement active pour l'utilisateur.

**Réponse réussie (200)**:
```json
{
  "success": true,
  "data": {
    "businessUnitId": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
    "businessUnitCode": "BRN-KIN-001",
    "businessUnitType": "branch",
    "companyId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p"
  },
  "message": "Connecté à branch: BRN-KIN-001"
}
```

**Réponse si au niveau entreprise**:
```json
{
  "success": true,
  "data": {
    "businessUnitId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
    "businessUnitCode": "COMPANY-001",
    "businessUnitType": "company",
    "companyId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p"
  },
  "message": "Connecté à l'Entreprise Générale"
}
```

---

### 5. Lister les Unités Accessibles

**Endpoint**: `GET /commerce/api/v1/users/accessible-units`

**Description**: Retourne la liste des unités d'affaires auxquelles l'utilisateur peut accéder selon son rôle et ses permissions.

**Réponse réussie (200)**:
```json
{
  "success": true,
  "data": [
    {
      "id": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
      "code": "COMPANY-001",
      "name": "Entreprise ABC SARL",
      "type": "company",
      "status": "active",
      "hierarchyLevel": 0
    },
    {
      "id": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p",
      "code": "BRN-KIN-001",
      "name": "Succursale Kinshasa",
      "type": "branch",
      "status": "active",
      "hierarchyLevel": 1,
      "parentId": "a1b2c3d4-5e6f-7g8h-9i0j-1k2l3m4n5o6p"
    },
    {
      "id": "c8d9e0f1-2g3h-4i5j-6k7l-8m9n0o1p2q3r",
      "code": "POS-KIN-001",
      "name": "Point de Vente Centre",
      "type": "pos",
      "status": "active",
      "hierarchyLevel": 2,
      "parentId": "b7a1c3d5-2e4f-6g8h-9i0j-1k2l3m4n5o6p"
    }
  ],
  "message": "3 unité(s) accessible(s)"
}
```

**Règles d'accès par rôle**:
| Rôle | Unités Accessibles |
|------|-------------------|
| `admin`, `super_admin` | Toutes les unités de l'entreprise |
| `manager` | L'unité assignée + ses unités enfants |
| Autres rôles | Uniquement l'unité assignée |

---

## Flux Complet d'Utilisation

### Première Connexion

```
1. Utilisateur se connecte via Auth0
   → Reçoit JWT access_token

2. Appel GET /auth/me
   → Vérifie son profil et businessUnitType

3. Si businessUnitType === "company" (défaut)
   → L'utilisateur doit entrer son code business unit

4. Appel POST /users/switch-unit { "code": "BRN-KIN-001" }
   → Activation de la succursale

5. Toutes les opérations suivantes (ventes, stocks, etc.)
   → Filtrées automatiquement par businessUnitId
```

### Changement d'Unité en Cours de Session

```
1. Utilisateur veut changer de succursale
   → Appel GET /users/accessible-units
   → Affiche la liste des unités disponibles

2. Sélectionne une unité
   → Appel POST /users/switch-unit { "code": "POS-KIN-002" }

3. Confirmation du switch
   → Toutes les données sont maintenant filtrées par la nouvelle unité
```

---

## Authentification

Tous les endpoints requièrent une authentification JWT Auth0 valide:

```
Authorization: Bearer <auth0_jwt_token>
```

### Résumé des Endpoints

| Endpoint | Méthode | Description | Accès |
|----------|---------|-------------|-------|
| `/users/profile` | GET | Profil utilisateur | Tous |
| `/users/switch-unit` | POST | Changer de business unit | Tous |
| `/users/reset-to-company` | POST | Revenir à l'entreprise | Tous |
| `/users/current-unit` | GET | Unité actuelle | Tous |
| `/users/accessible-units` | GET | Unités accessibles | Tous |

---

## Notes Techniques

### Filtrage des Données par Business Unit

Lorsqu'un utilisateur est connecté à une business unit spécifique :
- Toutes les ventes sont filtrées par `businessUnitId`
- Tous les produits affichent le stock de cette unité
- Les rapports sont agrégés au niveau de l'unité
- Les données Adha AI sont contextualisées par l'unité

### Synchronisation avec Accounting-Service

Le `businessUnitId` est transmis lors de chaque opération vers accounting-service via Kafka, permettant :
- L'enregistrement comptable au bon niveau hiérarchique
- L'agrégation automatique vers les unités parentes
- La consolidation au niveau entreprise

### Codes Business Unit

Les codes sont générés automatiquement lors de la création d'une business unit dans accounting-service :
- Format standardisé selon le type d'unité
- Uniques au sein de l'entreprise
- Communicables par email ou physiquement aux utilisateurs

### Intégration Auth0

- `auth0Id` est renseigné lors de la synchronisation Kafka
- L'authentification passe par Auth0 (OAuth2/OIDC)
- Le profil local est mis à jour via les événements Kafka
