# API Paramètres (Settings)

Cette documentation détaille les endpoints disponibles pour la gestion des paramètres dans l'application Wanzo Gestion Commerciale, incluant les paramètres d'application, les profils utilisateur, les secteurs d'activité et les comptes financiers.

> **✅ Conformité**: Aligné avec `settings-user-profile.controller.ts`, `application-settings.entity.ts`, `business-sector.entity.ts`

## Base URL

```
http://localhost:8000/commerce/api/v1
```

## Authentification

Tous les endpoints requièrent un token JWT Auth0 :
```
Authorization: Bearer <auth0_jwt_token>
```

---

## 1. Paramètres de l'Application (Application Settings)

### Structure du modèle ApplicationSettings

```json
{
  "id": "uuid-string",
  "companyName": "Entreprise ABC SARL",
  "companyLogoUrl": "https://storage.wanzo.cd/logos/abc.png",
  "defaultLanguage": "fr",
  "currency": "CDF",
  "dateFormat": "DD/MM/YYYY",
  "timeFormat": "HH:mm",
  "contactEmail": "contact@abc-sarl.com",
  "contactPhone": "+243999123456",
  "companyAddress": "123 Avenue Kasavubu, Kinshasa",
  "socialMediaLinks": {
    "facebook": "https://facebook.com/abc-sarl",
    "twitter": "https://twitter.com/abc-sarl",
    "linkedin": "https://linkedin.com/company/abc-sarl",
    "instagram": "https://instagram.com/abc-sarl"
  },
  "maintenanceMode": false,
  "createdAt": "2025-01-01T00:00:00.000Z",
  "updatedAt": "2025-01-04T12:00:00.000Z"
}
```

### Récupérer les paramètres de l'application

**Endpoint**: `GET /settings-user-profile/application-settings`

**Rôles requis**: `admin`

**Réponse réussie (200)**:
```json
{
  "id": "uuid-string",
  "companyName": "Entreprise ABC SARL",
  "companyLogoUrl": "https://storage.wanzo.cd/logos/abc.png",
  "defaultLanguage": "fr",
  "currency": "CDF",
  "dateFormat": "DD/MM/YYYY",
  "timeFormat": "HH:mm",
  "contactEmail": "contact@abc-sarl.com",
  "contactPhone": "+243999123456",
  "companyAddress": "123 Avenue Kasavubu, Kinshasa",
  "socialMediaLinks": {
    "facebook": "https://facebook.com/abc-sarl"
  },
  "maintenanceMode": false,
  "createdAt": "2025-01-01T00:00:00.000Z",
  "updatedAt": "2025-01-04T12:00:00.000Z"
}
```

### Mettre à jour les paramètres de l'application

**Endpoint**: `PATCH /settings-user-profile/application-settings`

**Rôles requis**: `admin`

**Corps de la requête**:
```json
{
  "companyName": "Nouvelle Entreprise SARL",
  "currency": "USD",
  "maintenanceMode": true
}
```

**Réponse réussie (200)**:
```json
{
  "id": "uuid-string",
  "companyName": "Nouvelle Entreprise SARL",
  "currency": "USD",
  "maintenanceMode": true,
  "updatedAt": "2025-01-04T14:00:00.000Z"
}
```

---

## 2. Profil Utilisateur (User Profile)

### Récupérer son propre profil

**Endpoint**: `GET /settings-user-profile/profile/me`

**Rôles requis**: Tous les utilisateurs authentifiés

**Réponse réussie (200)**:
```json
{
  "id": "user-uuid-123",
  "email": "john.doe@example.com",
  "firstName": "John",
  "lastName": "Doe",
  "phoneNumber": "+243999123456",
  "role": "manager",
  "isActive": true,
  "profilePictureUrl": "https://storage.wanzo.cd/profiles/user123.jpg",
  "companyId": "company-uuid-456",
  "businessUnitId": "bu-uuid-789",
  "businessUnitType": "branch",
  "createdAt": "2025-01-15T08:00:00.000Z",
  "updatedAt": "2025-01-04T10:30:00.000Z"
}
```

### Mettre à jour son propre profil

**Endpoint**: `PATCH /settings-user-profile/profile/me`

**Rôles requis**: Tous les utilisateurs authentifiés

**Corps de la requête**:
```json
{
  "firstName": "Jean",
  "lastName": "Dupont",
  "phoneNumber": "+243999000111",
  "profilePictureUrl": "https://storage.wanzo.cd/profiles/new-photo.jpg"
}
```

**Réponse réussie (200)**:
```json
{
  "id": "user-uuid-123",
  "firstName": "Jean",
  "lastName": "Dupont",
  "phoneNumber": "+243999000111",
  "profilePictureUrl": "https://storage.wanzo.cd/profiles/new-photo.jpg",
  "updatedAt": "2025-01-04T14:00:00.000Z"
}
```

---

## 3. Gestion des Utilisateurs (Admin)

### Lister tous les utilisateurs

**Endpoint**: `GET /settings-user-profile/users`

**Rôles requis**: `admin`

**Réponse réussie (200)**:
```json
[
  {
    "id": "user-uuid-1",
    "email": "admin@example.com",
    "firstName": "Admin",
    "lastName": "User",
    "role": "admin",
    "isActive": true,
    "businessUnitType": "company"
  },
  {
    "id": "user-uuid-2",
    "email": "cashier@example.com",
    "firstName": "Cashier",
    "lastName": "User",
    "role": "cashier",
    "isActive": true,
    "businessUnitCode": "POS-KIN-001",
    "businessUnitType": "pos"
  }
]
```

### Récupérer un utilisateur par ID

**Endpoint**: `GET /settings-user-profile/users/:userId`

**Rôles requis**: `admin`

**Réponse réussie (200)**:
```json
{
  "id": "user-uuid-2",
  "email": "cashier@example.com",
  "firstName": "Cashier",
  "lastName": "User",
  "role": "cashier",
  "isActive": true,
  "businessUnitId": "bu-uuid-pos",
  "businessUnitCode": "POS-KIN-001",
  "businessUnitType": "pos"
}
```

### Mettre à jour un utilisateur

**Endpoint**: `PATCH /settings-user-profile/users/:userId`

**Rôles requis**: `admin`

**Corps de la requête**:
```json
{
  "firstName": "Nouveau Prénom",
  "isActive": false
}
```

### Changer le rôle d'un utilisateur

**Endpoint**: `PATCH /settings-user-profile/users/:userId/role`

**Rôles requis**: `admin`

**Corps de la requête**:
```json
{
  "role": "manager"
}
```

**Réponse réussie (200)**:
```json
{
  "id": "user-uuid-2",
  "email": "user@example.com",
  "role": "manager",
  "updatedAt": "2025-01-04T14:00:00.000Z"
}
```

### Supprimer un utilisateur

**Endpoint**: `DELETE /settings-user-profile/users/:userId`

**Rôles requis**: `admin`

**Réponse réussie (204)**: No Content

---

## 4. Secteurs d'Activité (Business Sectors)

Les secteurs d'activité permettent de catégoriser les entreprises selon leur domaine (Commerce, Services, Production, etc.).

### Structure du modèle BusinessSector

```json
{
  "id": "uuid-string",
  "name": "Commerce de détail",
  "description": "Vente de produits au détail aux consommateurs finaux",
  "createdAt": "2025-01-01T00:00:00.000Z",
  "updatedAt": "2025-01-01T00:00:00.000Z"
}
```

### Créer un secteur d'activité

**Endpoint**: `POST /settings-user-profile/business-sectors`

**Rôles requis**: `admin`

**Corps de la requête**:
```json
{
  "name": "Commerce de gros",
  "description": "Vente de produits en gros aux revendeurs"
}
```

**Réponse réussie (201)**:
```json
{
  "id": "new-sector-uuid",
  "name": "Commerce de gros",
  "description": "Vente de produits en gros aux revendeurs",
  "createdAt": "2025-01-04T14:00:00.000Z",
  "updatedAt": "2025-01-04T14:00:00.000Z"
}
```

### Lister tous les secteurs d'activité

**Endpoint**: `GET /settings-user-profile/business-sectors`

**Rôles requis**: `admin`, `manager`

**Réponse réussie (200)**:
```json
[
  {
    "id": "sector-uuid-1",
    "name": "Commerce de détail",
    "description": "Vente de produits au détail"
  },
  {
    "id": "sector-uuid-2",
    "name": "Services",
    "description": "Prestation de services"
  }
]
```

### Récupérer un secteur par ID

**Endpoint**: `GET /settings-user-profile/business-sectors/:id`

**Rôles requis**: `admin`, `manager`

### Mettre à jour un secteur

**Endpoint**: `PATCH /settings-user-profile/business-sectors/:id`

**Rôles requis**: `admin`

**Corps de la requête**:
```json
{
  "name": "Commerce général",
  "description": "Commerce de détail et de gros"
}
```

### Supprimer un secteur

**Endpoint**: `DELETE /settings-user-profile/business-sectors/:id`

**Rôles requis**: `admin`

**Réponse réussie (204)**: No Content

---

## 5. Configuration des Business Units

La configuration des business units (entreprise, succursales, points de vente) est gérée via le module **Business Units** (voir [Business Units/README.md](../Business%20Units/README.md)).

### Paramètres Personnalisés par Business Unit

Chaque business unit peut avoir des paramètres personnalisés stockés dans le champ `settings` :

```json
{
  "id": "bu-uuid-789",
  "code": "BRN-KIN-001",
  "name": "Succursale Kinshasa",
  "type": "branch",
  "settings": {
    "defaultPriceList": "PRIX-STANDARD",
    "allowDiscounts": true,
    "maxDiscountPercent": 15,
    "maxTransactionAmount": 10000000,
    "dailyTransactionLimit": 50000000,
    "defaultTaxRate": 16,
    "vatNumber": "CD-TVA-123456",
    "receiptFooter": "Merci de votre visite!",
    "autoGenerateInvoiceNumber": true,
    "invoicePrefix": "BRN-KIN"
  }
}
```

### Paramètres Business Unit Disponibles

| Paramètre | Type | Description |
|-----------|------|-------------|
| `defaultPriceList` | string | Liste de prix par défaut |
| `allowDiscounts` | boolean | Autoriser les remises |
| `maxDiscountPercent` | number | Remise maximale autorisée (%) |
| `maxTransactionAmount` | number | Montant max par transaction (CDF) |
| `dailyTransactionLimit` | number | Limite journalière (CDF) |
| `defaultTaxRate` | number | Taux de taxe par défaut (%) |
| `vatNumber` | string | Numéro de TVA |
| `receiptFooter` | string | Pied de page des reçus |
| `autoGenerateInvoiceNumber` | boolean | Génération auto des numéros de facture |
| `invoicePrefix` | string | Préfixe des factures |

### Code Business Unit

Chaque business unit possède un **code unique** qui sert à :
1. **Identifier l'unité** de manière lisible
2. **Permettre le switch** d'unité par l'utilisateur
3. **Tracer les opérations** dans les rapports

**Formats de codes** :
| Type | Format | Exemple |
|------|--------|---------|
| Company | `COMPANY-XXX` | `COMPANY-001` |
| Branch | `BRN-{VILLE}-XXX` | `BRN-KIN-001`, `BRN-LUB-001` |
| POS | `POS-{VILLE}-XXX` | `POS-KIN-001`, `POS-GOM-001` |

**Workflow de communication du code** :
1. Admin crée une business unit dans accounting-service
2. Le code est généré automatiquement selon le format
3. L'événement Kafka synchronise vers gestion_commerciale
4. Admin communique le code à l'utilisateur (email, SMS, ou verbalement)
5. L'utilisateur entre le code via `POST /users/switch-unit`

---

## 6. Comptes Financiers

> **⚠️ Note**: La gestion des comptes financiers (comptes bancaires, Mobile Money) est centralisée dans le module **accounting-service**. Les endpoints de ce module ne sont pas disponibles dans gestion_commerciale_service.
>
> Pour gérer les comptes financiers, consultez la documentation de l'API accounting-service.

---

## Résumé des Endpoints

| Endpoint | Méthode | Description | Rôles |
|----------|---------|-------------|-------|
| `/settings-user-profile/application-settings` | GET | Paramètres application | admin |
| `/settings-user-profile/application-settings` | PATCH | MAJ paramètres | admin |
| `/settings-user-profile/profile/me` | GET | Mon profil | Tous |
| `/settings-user-profile/profile/me` | PATCH | MAJ mon profil | Tous |
| `/settings-user-profile/users` | GET | Liste utilisateurs | admin |
| `/settings-user-profile/users/:id` | GET | Utilisateur par ID | admin |
| `/settings-user-profile/users/:id` | PATCH | MAJ utilisateur | admin |
| `/settings-user-profile/users/:id/role` | PATCH | Changer rôle | admin |
| `/settings-user-profile/users/:id` | DELETE | Supprimer user | admin |
| `/settings-user-profile/business-sectors` | POST | Créer secteur | admin |
| `/settings-user-profile/business-sectors` | GET | Liste secteurs | admin, manager |
| `/settings-user-profile/business-sectors/:id` | GET | Secteur par ID | admin, manager |
| `/settings-user-profile/business-sectors/:id` | PATCH | MAJ secteur | admin |
| `/settings-user-profile/business-sectors/:id` | DELETE | Supprimer secteur | admin |

---

## Notes Techniques

### Relation entre Settings et Business Units

- Les **paramètres d'application** (`application-settings`) sont globaux pour toute l'entreprise
- Les **paramètres par business unit** (`settings` JSON) permettent une personnalisation par succursale/POS
- Les données sont filtrées selon le `businessUnitId` de l'utilisateur connecté

### Synchronisation

- Les business units et leurs paramètres sont synchronisés depuis accounting-service via Kafka
- Les modifications locales des paramètres applicatifs sont stockées uniquement dans gestion_commerciale
- Les secteurs d'activité sont gérés localement

### Sécurité

- Seuls les admins peuvent modifier les paramètres globaux
- Les utilisateurs ne peuvent modifier que leur propre profil
- Les comptes financiers sensibles nécessitent des droits admin
