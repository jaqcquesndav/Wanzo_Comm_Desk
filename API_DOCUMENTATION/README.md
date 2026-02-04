# Documentation API Wanzo

Ce dossier contient la documentation complète de l'API de l'application Wanzo. Chaque sous-dossier correspond à une fonctionnalité spécifique de l'application et contient les détails des endpoints, des structures de données et des exemples d'utilisation.

## Fonctionnalités documentées

1. [Authentification (Auth)](./auth/README.md)
2. [Gestion Utilisateurs (Users)](./users/README.md) 🆕
3. [Paramètres (Settings)](./Settings/README.md)
4. [Tableau de Bord (Dashboard)](./Dashboard/README.md)
5. [Opérations](./Operations/README.md)
6. [Ventes (Sales)](./Sales/README.md)
7. [Inventaire (Produits et Stock)](./Inventory/README.md)
8. [Fournisseurs (Suppliers)](./Supplier/README.md)
9. [Dépenses (Expenses)](./Expenses/README.md)
10. [Transactions Financières](./Financial%20Transactions/README.md)
11. [Financement](./Financing/README.md)
12. [Profil Utilisateur](./Profile/README.md)
13. [Documents](./documents/README.md)
14. [Notifications](./notifications/README.md)
15. [Unités d'Affaires (Business Units)](./Business%20Units/README.md)
16. [Clients (Customers)](./Customer/README.md)

## Alignement avec la structure du code source

Cette documentation API suit la structure des features de l'application Flutter:

- Les paramètres de l'application (`Settings`) incluent la gestion des comptes financiers
- Les transactions financières (`Financial Transactions`) correspondent à la feature `transactions`
- Le financement (`Financing`) correspond à la feature `financing` pour les demandes de crédit
- Le tableau de bord (`Dashboard`) correspond à la feature `dashboard` pour les statistiques et résumés
- Les opérations (`Operations`) correspondent à la feature `operations` qui centralise les différentes actions commerciales
- Le profil utilisateur (`Profile`) correspond à la feature `profile` pour la gestion des informations personnelles
- Les unités d'affaires (`Business Units`) permettent de gérer une hiérarchie organisationnelle multi-niveaux

## Architecture Multi-Tenant (Business Units)

L'application Wanzo supporte une architecture multi-tenant basée sur les unités d'affaires:

### Hiérarchie à 3 niveaux

```
COMPANY (Entreprise) - Niveau 0
    └── BRANCH (Succursale) - Niveau 1
            └── POS (Point de Vente) - Niveau 2
```

### Isolation des données

Tous les modules principaux (Sales, Expenses, Suppliers, Financial Transactions, etc.) intègrent les champs suivants pour l'isolation des données:

| Champ | Description |
|-------|-------------|
| `companyId` | ID de l'entreprise principale (société mère) |
| `businessUnitId` | ID de l'unité commerciale spécifique |
| `businessUnitCode` | Code unique lisible de l'unité (ex: POS-KIN-001) |
| `businessUnitType` | Type d'unité: `company`, `branch` ou `pos` |

### Filtrage automatique

- Les requêtes sont automatiquement filtrées par l'entreprise de l'utilisateur connecté
- Un utilisateur peut filtrer plus finement par `businessUnitId` pour voir les données d'une unité spécifique
- Les utilisateurs assignés à une succursale voient également les données de leurs points de vente enfants

Pour plus de détails, consultez la [documentation des Unités d'Affaires](./Business%20Units/README.md).

## Structure commune des réponses API

Toutes les réponses de l'API suivent la même structure générale:

```json
{
  "success": boolean,      // Indique si la requête a réussi (true) ou échoué (false)
  "message": "string",     // Message décrivant le résultat de la requête
  "statusCode": number,    // Code HTTP correspondant
  "data": any              // Données retournées (peuvent être null, un objet, ou un tableau)
}
```

## Format des dates

Toutes les dates sont au format ISO8601: `YYYY-MM-DDTHH:mm:ss.sssZ`

Exemple: `2023-08-01T12:30:00.000Z`

## Gestion des erreurs

En cas d'erreur, l'API renvoie une réponse avec `success: false` et un message décrivant l'erreur:

```json
{
  "success": false,
  "message": "Description de l'erreur",
  "statusCode": 400,  // Code d'erreur HTTP approprié
  "data": null
}
```

## Base URL

Tous les endpoints sont accessibles via l'API Gateway:
- **Via API Gateway**: `http://localhost:8000/commerce/api/v1`
- **Accès direct (développement)**: `http://localhost:3006/api`

## Authentification

L'authentification utilise **Auth0** comme fournisseur d'identité OAuth2/OIDC. Les utilisateurs sont créés dans `accounting-service` et synchronisés via Kafka.

### Header d'authentification

```
Authorization: Bearer <jwt_token_auth0>
```

### Flux d'authentification

1. **Login**: Frontend → Auth0 → Token JWT signé par Auth0
2. **Validation**: gestion_commerciale_service valide le JWT via JWKS Auth0
3. **Synchronisation**: Données utilisateur synchronisées depuis accounting-service via Kafka

Pour plus de détails, consultez la [documentation Auth](./auth/README.md).

## Gestion des Utilisateurs et Unités d'Affaires

Les utilisateurs peuvent changer d'unité d'affaires pour filtrer leurs données :

| Endpoint | Description |
|----------|-------------|
| `POST /users/switch-unit` | Changer d'unité via un code (ex: "BRN-KIN-001") |
| `POST /users/reset-to-company` | Revenir au niveau entreprise |
| `GET /users/current-unit` | Obtenir l'unité actuelle |
| `GET /users/accessible-units` | Lister les unités accessibles |

Pour plus de détails, consultez la [documentation Users](./users/README.md).

## Pagination

Pour les endpoints qui retournent plusieurs éléments, la pagination est disponible via les paramètres suivants:

- `page`: Le numéro de page à retourner (commence à 1)
- `limit`: Le nombre d'éléments par page

Exemple: `GET /commerce/api/v1/expenses?page=2&limit=10`

## Filtres et tri

De nombreux endpoints prennent en charge des paramètres de filtrage et de tri:

- `sortBy`: Le champ sur lequel trier
- `sortOrder`: L'ordre de tri (`asc` ou `desc`)
- Autres filtres spécifiques à chaque endpoint (voir la documentation correspondante)

## Notes pour les développeurs frontend

Cette documentation décrit les endpoints REST du backend NestJS. Elle est compatible avec tout client HTTP (web, mobile, desktop).

**Important**: L'authentification est gérée par Auth0. Le backend ne crée pas d'utilisateurs - ils sont synchronisés depuis `accounting-service`.

Si vous rencontrez des incohérences ou si vous avez besoin de clarifications, veuillez contacter l'équipe backend.
