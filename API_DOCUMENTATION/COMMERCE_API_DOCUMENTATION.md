# Documentation de l'API du microservice Gestion Commerciale

Cette documentation décrit la structure des URLs et les endpoints disponibles pour communiquer avec le microservice de Gestion Commerciale via l'API Gateway.

## Informations générales

- **Base URL (via API Gateway)**: `http://192.168.1.66:8000/commerce/api/v1`
- **Port API Gateway**: 8000
- **Port Microservice Gestion Commerciale**: 3006 (accès direct interne uniquement)
- **Service Kafka Client ID**: `app-mobile-service-client`
- **Documentation Swagger**: `http://localhost:3006/api/docs` (accès direct)

## Architecture

Le service de gestion commerciale est conçu pour les applications mobiles et communique avec d'autres microservices via Kafka:
- **Kafka Topics produits**: `commerce.operation.created`, `commerce.financing.requested`
- **Kafka Topics consommés**: `accounting.journal.entry.status`, `portfolio.analysis.response`, `accounting.business-unit.created`, `accounting.business-unit.updated`, `accounting.business-unit.deleted`

### Architecture Multi-Tenant (Business Units)

Le service supporte une hiérarchie organisationnelle à 3 niveaux:
```
COMPANY (Entreprise) - Niveau 0
    └── BRANCH (Succursale) - Niveau 1
            └── POS (Point de Vente) - Niveau 2
```

Tous les modules principaux intègrent les champs `companyId`, `businessUnitId`, `businessUnitCode` et `businessUnitType` pour l'isolation des données.

## Authentification

Toutes les requêtes nécessitent une authentification via un token JWT.

**Headers requis**:
```http
Authorization: Bearer <token_jwt>
Content-Type: application/json
Accept: application/json
```

## Versioning et Routing

### Pattern d'accès via API Gateway
```
http://localhost:8000/commerce/api/v1/<endpoint>
          ↓
http://kiota-gestion-commerciale-service:3006/api/<endpoint>
```

Le préfixe `/commerce/api/v1` est transformé en `/api` par l'API Gateway, correspondant au `setGlobalPrefix('api')` du service.

## Format des réponses

Les réponses suivent un format standardisé:

**Succès**:
```json
{
  "success": true,
  "message": "Description du succès",
  "statusCode": 200,
  "data": {
    // Les données spécifiques retournées
  }
}
```

**Erreur**:
```json
{
  "success": false,
  "message": "Description de l'erreur",
  "statusCode": 400,
  "error": "Type d'erreur"
}
```

## Endpoints disponibles

Tous les endpoints sont préfixés par `/commerce/api/v1` via l'API Gateway.

### 1. Authentification & Profil Utilisateur

> **Architecture Auth0**: L'authentification est gérée par **Auth0 OAuth2/OIDC**. Les utilisateurs sont créés dans **accounting-service** et synchronisés via Kafka. gestion_commerciale_service valide uniquement les tokens Auth0.

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/users/me` | Récupérer profil complet (user + company + business unit) - **Aligné avec accounting** |
| PUT | `/users/me` | Mettre à jour le profil utilisateur |
| GET | `/auth/me` | Récupérer profil utilisateur (endpoint legacy, préférer /users/me) |
| POST | `/auth/management-token` | Générer un jeton de gestion (admin) |

#### Gestion des Business Units

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| POST | `/users/switch-unit` | Changer de business unit via code |
| POST | `/users/reset-to-company` | Revenir à l'Entreprise Générale |
| GET | `/users/current-unit` | Obtenir l'unité courante |
| GET | `/users/accessible-units` | Lister les unités accessibles |

**Flux d'authentification**:
1. L'utilisateur s'authentifie via Auth0 Hosted Login
2. Auth0 retourne un JWT `access_token`
3. Le frontend inclut ce token dans les requêtes: `Authorization: Bearer <token>`
4. gestion_commerciale valide le token via JWKS Auth0
5. L'utilisateur peut changer de business unit via `/users/switch-unit`

**Exemple GET /users/me** (recommandé):
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "user-uuid",
      "auth0Id": "auth0|abc123",
      "email": "user@example.com",
      "firstName": "Jean",
      "lastName": "Dupont",
      "role": "manager",
      "companyId": "company-uuid",
      "businessUnitId": "bu-uuid",
      "businessUnitCode": "BRN-KIN-001",
      "businessUnitType": "branch",
      "isActive": true
    },
    "company": {
      "id": "company-uuid",
      "name": "Entreprise ABC SARL",
      "registrationNumber": "RC/KIN/2023/12345",
      "address": "123 Avenue des Martyrs, Kinshasa",
      "phone": "+243999888777",
      "email": "contact@abc-sarl.cd"
    },
    "businessUnit": {
      "id": "bu-uuid",
      "code": "BRN-KIN-001",
      "name": "Succursale Kinshasa",
      "type": "branch",
      "hierarchyLevel": 1
    }
  }
}
```

**Exemple POST /users/switch-unit**:
```json
{
  "code": "BRN-KIN-001"
}
```

**Réponse**:
```json
{
  "success": true,
  "message": "Vous êtes maintenant connecté à: Succursale Kinshasa",
  "data": {
    "businessUnitId": "uuid",
    "businessUnitCode": "BRN-KIN-001",
    "businessUnitName": "Succursale Kinshasa",
    "businessUnitType": "branch",
    "companyId": "uuid",
    "companyName": "Entreprise ABC SARL"
  }
}
```

### 2. Produits (Products)

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/products` | Récupérer tous les produits avec pagination et filtres |
| GET | `/products/:id` | Récupérer un produit par son ID |
| POST | `/products` | Créer un nouveau produit |
| PATCH | `/products/:id` | Mettre à jour un produit |
| DELETE | `/products/:id` | Supprimer un produit |

**Query Parameters GET /products**:
- `page` (number): Numéro de page (défaut: 1)
- `limit` (number): Éléments par page (défaut: 20)
- `search` (string): Recherche par nom ou SKU
- `category` (string): Filtrer par catégorie
- `inStock` (boolean): Filtrer produits en stock
- `companyId` (uuid): Filtrer par entreprise (défaut: entreprise utilisateur)
- `businessUnitId` (uuid): Filtrer par unité commerciale
- `businessUnitType` (string): 'company' | 'branch' | 'pos'
- `sortBy` (string): Champ de tri (name, price, stock)
- `sortOrder` (string): 'ASC' ou 'DESC'

**DTO CreateProductDto**:
```typescript
{
  name: string;              // Requis - Nom du produit
  description?: string;      // Optionnel - Description détaillée
  sku: string;               // Requis, unique - Référence stock (Stock Keeping Unit)
  barcode?: string;          // Optionnel - Code-barres du produit
  category: ProductCategory; // Requis - Catégorie (food, drink, electronics, clothing, etc.)
  unit: MeasurementUnit;     // Requis - Unité de mesure (piece, kg, g, l, ml, etc.)
  costPriceInCdf: number;    // Requis, >= 0 - Prix d'achat en Francs Congolais
  sellingPriceInCdf: number; // Requis, >= 0 - Prix de vente en Francs Congolais
  stockQuantity: number;     // Requis, >= 0 - Quantité en stock
  alertThreshold?: number;   // Optionnel - Niveau d'alerte stock bas
  supplierIds?: string[];    // Optionnel - IDs des fournisseurs
  imageUrl?: string;         // Optionnel - URL de l'image du produit
  attributes?: Array<{name: string; value: string}>; // Optionnel - Attributs spécifiques
  tags?: string[];           // Optionnel - Tags pour le produit
  taxRate?: number;          // Optionnel - Taux de taxe en pourcentage
  inputCurrencyCode?: string; // Optionnel, défaut 'CDF' - Devise de saisie des prix
  inputExchangeRate?: number; // Optionnel, défaut 1.0 - Taux de change vers CDF
  companyId?: string;        // UUID entreprise (optionnel, auto-défini)
  businessUnitId?: string;   // UUID unité commerciale (optionnel, auto-défini)
  businessUnitCode?: string; // Code unité (ex: POS-KIN-001)
  businessUnitType?: string; // 'company' | 'branch' | 'pos'
}
```

### 3. Ventes (Sales)

**Status**: ✅ **Implémentation Complète** - Service API + Repository hybride offline-first

**Service**: `SalesApiService` (✅ 9 méthodes) | **Repository**: `SalesRepository` (✅ Intégration hybride)

| Méthode | Endpoint | Description | Status |
|---------|----------|-------------|--------|
| GET | `/sales` | Récupérer toutes les ventes avec filtrage | ✅ |
| GET | `/sales/:id` | Récupérer une vente par son ID | ✅ |
| POST | `/sales` | Créer une nouvelle vente | ✅ |
| PATCH | `/sales/:id` | Mettre à jour une vente | ✅ |
| PUT | `/sales/:id/complete` | Marquer une vente comme complétée | ✅ |
| PUT | `/sales/:id/cancel` | Annuler une vente | ✅ |
| POST | `/sales/sync` | Synchroniser les ventes locales vers le backend | ✅ |
| GET | `/sales/stats` | Récupérer les statistiques de ventes | ✅ |
| DELETE | `/sales/:id` | Supprimer une vente | ✅ |

**Query Parameters GET /sales**:
- `page` (number): Numéro de page
- `limit` (number): Éléments par page
- `dateFrom` (string): Date début ISO8601 (YYYY-MM-DD)
- `dateTo` (string): Date fin ISO8601
- `status` (string): 'pending' | 'completed' | 'cancelled'
- `customerId` (uuid): ID du client
- `minAmount` (number): Montant minimum
- `maxAmount` (number): Montant maximum
- `companyId` (uuid): Filtrer par entreprise (défaut: entreprise utilisateur)
- `businessUnitId` (uuid): Filtrer par unité commerciale
- `businessUnitType` (string): 'company' | 'branch' | 'pos'
- `sortBy` (string): Champ de tri
- `sortOrder` (string): 'ASC' | 'DESC'

**DTO CreateSaleDto**:
```typescript
{
  localId?: string;            // Optionnel - Identifiant local pour synchronisation offline
  date: string;                // Requis - Date de la vente (ISO8601)
  dueDate?: string;            // Optionnel - Date d'échéance (ISO8601)
  customerId?: string;         // Optionnel - UUID du client
  customerName: string;        // Requis - Nom du client
  items: CreateSaleItemDto[];  // Requis, min 1 item
  paymentMethod: string;       // Requis - "cash", "mobile_money", "bank_transfer", "credit"
  paymentReference?: string;   // Optionnel - Référence de paiement
  notes?: string;              // Optionnel
  exchangeRate: number;        // Requis, > 0 - Taux de change
  companyId?: string;          // UUID entreprise (optionnel, auto-défini)
  businessUnitId?: string;     // UUID unité commerciale (optionnel, auto-défini)
  businessUnitCode?: string;   // Code unité (ex: POS-KIN-001)
  businessUnitType?: string;   // 'company' | 'branch' | 'pos'
}

// CreateSaleItemDto
{
  productId: string;           // UUID requis
  productName: string;         // Requis - Nom du produit
  quantity: number;            // Requis, > 0
  unitPrice: number;           // Requis, > 0
  discount?: number;           // Optionnel - Remise
  currencyCode?: string;       // Optionnel - Code devise
  taxRate?: number;            // Optionnel - Taux de taxe
  notes?: string;              // Optionnel
}
```

**Intégration Kafka**: Après création, publie événement `commerce.operation.created` vers accounting-service pour génération écritures comptables.

### 4. Clients (Customers)

**Status**: ✅ **Implémentation Complète** - CRUD + pagination et recherche

| Méthode | Endpoint | Description | Status |
|---------|----------|-------------|--------|
| GET | `/customers` | Récupérer tous les clients avec pagination et recherche | ✅ |
| GET | `/customers/:id` | Récupérer un client par son ID | ✅ |
| POST | `/customers` | Créer un nouveau client | ✅ |
| PATCH | `/customers/:id` | Mettre à jour un client | ✅ |
| DELETE | `/customers/:id` | Supprimer un client | ✅ |

**Query Parameters GET /customers**:
- `page` (number): Numéro de page
- `limit` (number): Éléments par page
- `search` (string): Recherche nom, email, téléphone
- `sortBy` (string): Champ de tri (createdAt, fullName, totalPurchases)
- `sortOrder` (string): 'ASC' | 'DESC'

**DTO CreateCustomerDto**:
```typescript
{
  fullName: string;            // Requis - Nom complet du client
  phoneNumber: string;         // Requis - Numéro de téléphone (format international)
  email?: string;              // Optionnel, unique si fourni
  address?: string;            // Optionnel - Adresse postale
  notes?: string;              // Optionnel - Notes concernant le client
  totalPurchases?: number;     // Optionnel, défaut 0 - Montant total des achats
  profilePicture?: string;     // Optionnel - URL de la photo de profil
  lastPurchaseDate?: string;   // Optionnel - Date du dernier achat (ISO8601)
  category?: CustomerCategory; // Optionnel, défaut 'regular' - Catégorie du client
  companyId?: string;          // UUID entreprise (optionnel, auto-défini)
  businessUnitId?: string;     // UUID unité commerciale (optionnel, auto-défini)
  businessUnitCode?: string;   // Code unité (ex: POS-KIN-001)
  businessUnitType?: string;   // 'company' | 'branch' | 'pos'
}

// CustomerCategory enum
enum CustomerCategory {
  VIP = 'vip',
  REGULAR = 'regular',
  NEW_CUSTOMER = 'new_customer',
  OCCASIONAL = 'occasional',
  BUSINESS = 'business'
}
```

### 5. Fournisseurs (Suppliers)

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/suppliers` | Récupérer tous les fournisseurs avec pagination |
| GET | `/suppliers/:id` | Récupérer un fournisseur par son ID |
| POST | `/suppliers` | Créer un nouveau fournisseur |
| PATCH | `/suppliers/:id` | Mettre à jour un fournisseur |
| DELETE | `/suppliers/:id` | Supprimer un fournisseur |

**Query Parameters GET /suppliers**:
- `page` (number): Numéro de page
- `limit` (number): Éléments par page
- `search` (string): Recherche par nom ou contact

**DTO CreateSupplierDto**:
```typescript
{
  name: string;                // Nom du fournisseur, requis
  contactPerson?: string;      // Personne de contact
  email?: string;
  phone: string;               // Requis
  address?: string;
  city?: string;
  country?: string;
  notes?: string;
  companyId: string;           // UUID entreprise principale
  businessUnitId?: string;     // UUID unité commerciale (optionnel, auto-défini)
  businessUnitCode?: string;   // Code unité (ex: POS-KIN-001)
  businessUnitType?: string;   // 'company' | 'branch' | 'pos'
  paymentTerms?: string;       // Ex: "Net 30", "Net 60"
  taxId?: string;              // Numéro fiscal
}
```

### 6. Dépenses (Expenses)

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/expenses` | Récupérer toutes les dépenses avec filtres |
| GET | `/expenses/:id` | Récupérer une dépense par son ID |
| POST | `/expenses` | Créer une nouvelle dépense |
| PATCH | `/expenses/:id` | Mettre à jour une dépense |
| DELETE | `/expenses/:id` | Supprimer une dépense |
| POST | `/expenses/:id/upload-receipt` | Upload justificatif (image/PDF) |
| GET | `/expenses/categories` | Liste catégories de dépenses |
| POST | `/expenses/categories` | Créer catégorie personnalisée |
| PATCH | `/expenses/categories/:id` | Modifier catégorie |
| DELETE | `/expenses/categories/:id` | Supprimer catégorie |

**Query Parameters GET /expenses**:
- `page` (number): Numéro de page
- `limit` (number): Éléments par page
- `dateFrom` (string): Date début ISO8601 (YYYY-MM-DD)
- `dateTo` (string): Date fin ISO8601
- `categoryId` (uuid): Filtrer par catégorie
- `minAmount` (number): Montant minimum
- `maxAmount` (number): Montant maximum
- `companyId` (uuid): Filtrer par entreprise (défaut: entreprise utilisateur)
- `businessUnitId` (uuid): Filtrer par unité commerciale
- `businessUnitType` (string): 'company' | 'branch' | 'pos'
- `type` (string): 'fixed' | 'variable' | 'one-time'

**DTO CreateExpenseDto**:
```typescript
{
  title: string;               // Requis
  description?: string;
  amount: number;              // > 0, requis
  expenseDate: Date;           // Requis
  categoryId: string;          // UUID catégorie, requis
  paymentMethod: string;       // "cash", "mobile_money", "bank_transfer", "check"
  supplierId?: string;         // UUID si dépense liée à fournisseur
  receiptUrl?: string;         // URL du justificatif
  notes?: string;
  companyId: string;           // UUID entreprise principale
  businessUnitId?: string;     // UUID unité commerciale (optionnel, auto-défini)
  businessUnitCode?: string;   // Code unité (ex: POS-KIN-001)
  businessUnitType?: string;   // 'company' | 'branch' | 'pos'
  type: ExpenseCategoryType;   // "fixed", "variable", "one-time"
}
```

**Catégories prédéfinies**: Loyer, Salaires, Électricité, Eau, Internet, Transport, Marketing, Fournitures, Assurance, Taxes, Maintenance, Autres.

### 7. Opérations Commerciales (Business Operations)

**Status**: ✅ **Implémentation Complète** - Service API + Services d'Export

**Service**: `OperationsApiService` (✅ 5 méthodes) | **Export**: `OperationExportService` (✅ PDF/Excel)

| Méthode | Endpoint | Description | Status |
|---------|----------|-------------|--------|
| GET | `/operations` | Récupérer journal des opérations avec filtres avancés (11 paramètres) | ✅ |
| GET | `/operations/:id` | Récupérer détails d'une opération | ✅ |
| GET | `/operations/summary` | Résumé des opérations par période (day/week/month/year) | ✅ |
| POST | `/operations/export` | Exporter opérations (PDF/Excel avec options avancées) | ✅ |
| GET | `/operations/timeline` | Timeline des opérations récentes | ✅ |

**Services Locaux Complémentaires**:
- `OperationFilter` - Modèle de filtrage avec 8 critères + factory methods (today, thisWeek, thisMonth)
- `OperationExportService` - Export PDF multi-pages, CSV, calcul statistiques

**Query Parameters GET /operations**:
- `page` (number): Numéro de page (défaut: 1)
- `limit` (number): Éléments par page (défaut: 10)
- `dateFrom` (string): Date de début ISO8601 (YYYY-MM-DD)
- `dateTo` (string): Date de fin ISO8601 (YYYY-MM-DD)
- `type` (string): Type d'opération (voir OperationType)
- `status` (string): 'completed' | 'pending' | 'cancelled' | 'failed'
- `relatedPartyId` (string): ID du client ou fournisseur lié
- `minAmount` (number): Montant minimum
- `maxAmount` (number): Montant maximum
- `sortBy` (string): Champ de tri (date, amount, relatedPartyName, status)
- `sortOrder` (string): Ordre de tri ('asc' | 'desc')

**DTO CreateBusinessOperationDto**:
```typescript
{
  type: string;                // 'sale' | 'purchase' | 'expense' | 'income' | 'adjustment'
  description: string;         // Requis
  amount: number;              // Requis, > 0
  operationDate: Date;         // Requis
  relatedEntityId?: string;    // ID vente/achat/dépense liée
  relatedEntityType?: string;  // 'sale' | 'purchase' | 'expense'
  notes?: string;
  companyId: string;
  userId: string;              // Utilisateur créateur
}
```

### 8. Gestion des Documents

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/documents` | Récupérer documents avec filtres et pagination |
| GET | `/documents/:id` | Récupérer métadonnées d'un document |
| GET | `/documents/:id/download` | Télécharger fichier document |
| POST | `/documents/upload` | Upload nouveau document (multipart/form-data) |
| PATCH | `/documents/:id` | Modifier métadonnées document |
| DELETE | `/documents/:id` | Supprimer document (fichier + DB) |

**Query Parameters GET /documents**:
- `page` (number): Numéro de page (défaut: 1)
- `limit` (number): Éléments par page (défaut: 10)
- `documentType` (string): Type de document (ex: 'Invoice')
- `relatedToEntityType` (string): 'customer' | 'sale' | 'supplier' | 'expense'
- `relatedToEntityId` (uuid): ID de l'entité liée
- `tag` (string): Filtrer par tag
- `searchTerm` (string): Recherche nom fichier ou description
- `sortBy` (string): Champ de tri (défaut: 'uploadedAt')
- `sortOrder` (string): 'ASC' | 'DESC' (défaut: 'DESC')

**Upload POST /documents/upload** (multipart/form-data):
```typescript
{
  file: File;                  // Requis, max 10MB
  documentType: string;        // Requis
  relatedToEntityType?: string;
  relatedToEntityId?: string;
  name?: string;               // Auto-généré si absent
  description?: string;
  companyId: string;
}
```

**Stockage**: Cloudinary pour fichiers, métadonnées en PostgreSQL.

### 9. Tableau de Bord (Dashboard)

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/dashboard/data` | Données complètes tableau de bord (KPIs globaux) |
| GET | `/dashboard/sales-today` | Ventes du jour en temps réel |
| GET | `/dashboard/sales-summary` | Résumé ventes par période |
| GET | `/dashboard/customer-stats` | Statistiques clients (nouveaux, actifs, top) |
| GET | `/dashboard/operations-journal` | Journal opérations récentes |
| GET | `/dashboard/inventory-alerts` | Alertes stock bas/rupture |
| GET | `/dashboard/receivables` | Total créances à recevoir |
| GET | `/dashboard/clients-served-today` | Nombre clients servis aujourd'hui |
| GET | `/dashboard/export-journal` | Export journal (CSV/Excel) |

**Query Parameters GET /dashboard/data**:
- `date` (string): Date de référence au format YYYY-MM-DD (optionnel, défaut: aujourd'hui)
- `timezone` (string): Fuseau horaire pour les calculs de date (optionnel)

**Réponse GET /dashboard/data**:
```typescript
{
  success: true,
  data: {
    salesToday: {
      totalAmount: number,
      count: number,
      sales: Sale[]
    },
    salesSummary: {
      totalRevenue: number,
      totalSales: number,
      averageSaleValue: number,
      growthRate: number
    },
    customerStats: {
      totalCustomers: number,
      newCustomers: number,
      activeCustomers: number,
      topCustomers: Customer[]
    },
    inventoryAlerts: {
      lowStock: Product[],
      outOfStock: Product[]
    },
    operationsJournal: Operation[]
  }
}
```

### 10. Transactions Financières

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/financial-transactions` | Liste transactions avec filtres avancés |
| GET | `/financial-transactions/:id` | Détails transaction |
| POST | `/financial-transactions` | Créer transaction manuelle |
| PATCH | `/financial-transactions/:id` | Modifier transaction |
| DELETE | `/financial-transactions/:id` | Supprimer transaction |
| GET | `/transaction-categories` | Liste catégories transactions |
| POST | `/transaction-categories` | Créer catégorie personnalisée |
| PATCH | `/transaction-categories/:id` | Modifier catégorie |
| DELETE | `/transaction-categories/:id` | Supprimer catégorie |

**Query Parameters GET /financial-transactions**:
- `page` (number): Numéro de page
- `limit` (number): Éléments par page
- `dateFrom` (string): Date de début ISO8601 (YYYY-MM-DD)
- `dateTo` (string): Date de fin ISO8601 (YYYY-MM-DD)
- `transactionType` (string): Type de transaction (voir TransactionType enum)
- `status` (string): Statut (voir TransactionStatus enum)
- `minAmount` (number): Montant minimum
- `maxAmount` (number): Montant maximum
- `paymentMethod` (string): Méthode de paiement (voir PaymentMethod enum)
- `customerId` (uuid): Filtrer par client
- `supplierId` (uuid): Filtrer par fournisseur
- `companyId` (uuid): Filtrer par entreprise (défaut: entreprise utilisateur)
- `businessUnitId` (uuid): Filtrer par unité commerciale
- `businessUnitType` (string): 'company' | 'branch' | 'pos'

**Enums**:
```typescript
// Types de transaction
enum TransactionType {
  SALE = 'sale',                      // Vente
  PURCHASE = 'purchase',              // Achat fournisseur
  CUSTOMER_PAYMENT = 'customer_payment', // Paiement client
  SUPPLIER_PAYMENT = 'supplier_payment', // Paiement fournisseur
  REFUND = 'refund',                  // Remboursement
  EXPENSE = 'expense',                // Dépense générale
  PAYROLL = 'payroll',                // Paie
  TAX_PAYMENT = 'tax_payment',        // Taxes
  TRANSFER = 'transfer',              // Transfert
  OTHER = 'other'                     // Autre
}

// Statuts de transaction
enum TransactionStatus {
  PENDING = 'pending',                // En attente
  COMPLETED = 'completed',            // Terminée
  FAILED = 'failed',                  // Échouée
  VOIDED = 'voided',                  // Annulée
  REFUNDED = 'refunded',              // Remboursée
  PARTIALLY_REFUNDED = 'partially_refunded', // Partiellement remboursée
  PENDING_APPROVAL = 'pending_approval' // En attente d'approbation
}

// Méthodes de paiement
enum PaymentMethod {
  CASH = 'cash',
  BANK_TRANSFER = 'bank_transfer',
  CHECK = 'check',
  CREDIT_CARD = 'credit_card',
  DEBIT_CARD = 'debit_card',
  MOBILE_MONEY = 'mobile_money',
  PAYPAL = 'paypal',
  OTHER = 'other'
}
```

**DTO CreateFinancialTransactionDto**:
```typescript
{
  transactionType: TransactionType;  // Requis - Type de transaction
  amount: number;                    // Requis - Montant > 0
  transactionDate: Date;             // Requis - Date de transaction
  status: TransactionStatus;         // Requis - Statut initial
  description?: string;              // Description optionnelle
  paymentMethod?: PaymentMethod;     // Méthode de paiement
  notes?: string;                    // Notes
  customerId?: string;               // UUID client (optionnel)
  supplierId?: string;               // UUID fournisseur (optionnel)
  linkedDocumentId?: string;         // ID document lié
  linkedDocumentType?: string;       // Type: "sale", "expense", "invoice"
  companyId?: string;                // UUID entreprise (auto-défini)
  businessUnitId?: string;           // UUID unité commerciale (auto-défini)
  businessUnitCode?: string;         // Code unité (ex: POS-KIN-001)
  businessUnitType?: string;         // 'company' | 'branch' | 'pos'
}
```

### 11. Financement (Financing)

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/financing/requests` | Liste demandes financement avec filtres |
| GET | `/financing/requests/:id` | Détails demande financement |
| POST | `/financing/requests` | Créer demande financement |
| PUT | `/financing/requests/:id` | Modifier demande |
| DELETE | `/financing/requests/:id` | Supprimer demande |
| POST | `/financing/requests/:id/submit` | Soumettre demande pour analyse |
| POST | `/financing/requests/:id/cancel` | Annuler une demande |
| GET | `/financing/requests/products` | Récupérer les produits de financement disponibles |

**DTO CreateFinancingRecordDto**:
```typescript
{
  type: FinancingType;         // 'loan' | 'credit_line' | 'invoice_financing'
  amount: number;              // Montant demandé, > 0
  purpose: string;             // Raison du financement
  description?: string;
  duration?: number;           // Durée en mois
  companyId: string;
  status: FinancingRequestStatus; // 'draft' | 'pending' | 'approved' | 'rejected'
}
```

**Intégration Kafka**: Publie `commerce.financing.requested` vers portfolio-institution-service pour analyse crédit via Adha AI.

### 12. Entreprise (Company)

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/companies` | Liste entreprises (admin uniquement) |
| GET | `/companies/:id` | Détails entreprise |
| PATCH | `/companies/:id` | Modifier info entreprise |
| GET | `/companies/:id/payment-info` | Info paiement/abonnement |
| POST | `/companies/:id/payment-info` | Créer info paiement |
| PATCH | `/companies/:id/payment-info/:paymentId` | Modifier info paiement |

### 13. Utilisateurs (Users)

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/users` | Liste utilisateurs de l'entreprise |
| GET | `/users/:id` | Détails utilisateur |
| POST | `/users` | Créer utilisateur (owner/admin) |
| PATCH | `/users/:id` | Modifier utilisateur |
| DELETE | `/users/:id` | Désactiver utilisateur |
| GET | `/user-activities` | Historique activités utilisateurs |

### 14. Paramètres (Settings)

| Méthode | Endpoint | Description | Rôles |
|---------|----------|-------------|-------|
| GET | `/settings` | Récupérer tous les paramètres | ADMIN, MANAGER |
| GET | `/settings/public` | Récupérer les paramètres publics | Tous |
| GET | `/settings/category/:category` | Récupérer les paramètres par catégorie | ADMIN, MANAGER |
| GET | `/settings/:key` | Récupérer un paramètre par sa clé | Tous |
| POST | `/settings` | Créer un nouveau paramètre | ADMIN |
| PUT | `/settings/:key` | Mettre à jour un paramètre | ADMIN |
| DELETE | `/settings/:key` | Supprimer un paramètre | ADMIN |
| POST | `/settings/initialize` | Initialiser les paramètres par défaut | ADMIN |

### 15. Notifications

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/notifications` | Liste notifications avec pagination |
| GET | `/notifications/unread-count` | Nombre de notifications non lues |
| POST | `/notifications/:id/mark-read` | Marquer une notification comme lue |
| POST | `/notifications/mark-all-read` | Marquer toutes les notifications comme lues |
| DELETE | `/notifications/:id` | Supprimer notification |

**Query Parameters GET /notifications**:
- `page` (number): Numéro de page
- `limit` (number): Éléments par page
- `type` (NotificationType): Filtrer par type de notification
- `status` (string): 'read' | 'unread' - Filtrer par statut lu/non lu
- `sortBy` (string): Champ de tri (ex: timestamp)
- `sortOrder` (string): 'ASC' | 'DESC'

### 16. Unités d'Affaires (Business Units) 🆕

**Status**: ✅ **Implémentation Complète** - Gestion hiérarchique multi-niveaux

Le module Business Units permet de gérer une hiérarchie organisationnelle à 3 niveaux pour l'isolation des données par entreprise, succursale et point de vente.

| Méthode | Endpoint | Description | Rôles |
|---------|----------|-------------|-------|
| GET | `/business-units` | Lister les unités avec filtres | Tous |
| GET | `/business-units/hierarchy` | Récupérer la hiérarchie complète | Tous |
| GET | `/business-units/current` | Récupérer l'unité courante de l'utilisateur | Tous |
| GET | `/business-units/:id` | Récupérer une unité par ID | Tous |
| GET | `/business-units/code/:code` | Récupérer une unité par code | Tous |
| POST | `/business-units` | Créer une nouvelle unité | ADMIN, MANAGER |
| PUT | `/business-units/:id` | Mettre à jour une unité | ADMIN, MANAGER |
| DELETE | `/business-units/:id` | Supprimer une unité (soft delete) | ADMIN |
| GET | `/business-units/:id/children` | Récupérer les unités enfants | Tous |
| GET | `/business-units/:id/path-to-company` | Chemin hiérarchique vers l'entreprise | Tous |

**Types d'Unités (BusinessUnitType)**:
- `company` - Entreprise principale (niveau 0, racine)
- `branch` - Succursale/Agence (niveau 1, parent: company)
- `pos` - Point de Vente (niveau 2, parent: company ou branch)

**Statuts d'Unités (BusinessUnitStatus)**:
- `active` - Unité opérationnelle
- `inactive` - Temporairement désactivée
- `suspended` - Suspendue
- `closed` - Définitivement fermée

**Query Parameters GET /business-units**:
- `companyId` (uuid): Filtrer par entreprise
- `type` (string): 'company' | 'branch' | 'pos'
- `parentId` (uuid): Filtrer par unité parente
- `search` (string): Recherche par nom ou code
- `status` (string): Filtrer par statut
- `includeInactive` (boolean): Inclure les unités inactives

**DTO CreateBusinessUnitDto**:
```typescript
{
  code: string;                // Requis, unique par entreprise (ex: BRN-001)
  name: string;                // Requis
  type: BusinessUnitType;      // 'company' | 'branch' | 'pos'
  companyId?: string;          // Défaut: entreprise de l'utilisateur
  parentId?: string;           // Requis sauf pour type 'company'
  address?: string;
  city?: string;
  province?: string;
  country?: string;
  phone?: string;
  email?: string;
  manager?: string;            // Nom du responsable
  managerId?: string;          // UUID du responsable
  currency?: string;           // Devise principale (ex: CDF, USD)
  settings?: object;           // Paramètres personnalisés
  metadata?: object;           // Métadonnées additionnelles
}
```

**Règles de hiérarchie**:
- Une `company` ne peut pas avoir de parent
- Une `branch` doit avoir une `company` comme parent
- Un `pos` peut avoir une `company` ou une `branch` comme parent

**Réponse GET /business-units/hierarchy**:
```json
{
  "success": true,
  "data": {
    "id": "uuid-company",
    "code": "WANZO-HQ",
    "name": "Wanzo Corporation",
    "type": "company",
    "status": "active",
    "hierarchyLevel": 0,
    "children": [
      {
        "id": "uuid-branch",
        "code": "BRN-001",
        "name": "Succursale Gombe",
        "type": "branch",
        "hierarchyLevel": 1,
        "children": [
          {
            "id": "uuid-pos",
            "code": "POS-001",
            "name": "Point de Vente Centre",
            "type": "pos",
            "hierarchyLevel": 2
          }
        ]
      }
    ]
  }
}
```

## Format des Réponses

### Réponse Success
```json
{
  "success": true,
  "message": "Description du succès",
  "statusCode": 200,
  "data": {
    // Données spécifiques
  }
}
```

### Réponse Error
```json
{
  "success": false,
  "message": "Description de l'erreur",
  "statusCode": 400,
  "error": "Type d'erreur"
}
```

## Exemples d'utilisation

### 1. Inscription et Login (React Native / Expo)

```typescript
// Inscription
const register = async (userData: RegisterDto) => {
  try {
    const response = await fetch('http://localhost:8000/commerce/api/v1/auth/register', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify(userData)
    });
    
    const result = await response.json();
    
    if (result.accessToken) {
      // Stocker tokens
      await AsyncStorage.setItem('accessToken', result.accessToken);
      await AsyncStorage.setItem('refreshToken', result.refreshToken);
      return result;
    } else {
      throw new Error(result.message || 'Inscription échouée');
    }
  } catch (error) {
    console.error('Erreur inscription:', error);
    throw error;
  }
};

// Login
const login = async (email: string, password: string) => {
  const response = await fetch('http://localhost:8000/commerce/api/v1/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  });
  
  const result = await response.json();
  if (result.accessToken) {
    await AsyncStorage.setItem('accessToken', result.accessToken);
    await AsyncStorage.setItem('refreshToken', result.refreshToken);
  }
  return result;
};
```

### 2. Récupérer produits avec pagination

```typescript
const fetchProducts = async (page = 1, limit = 20, search = '') => {
  const token = await AsyncStorage.getItem('accessToken');
  
  const params = new URLSearchParams({
    page: page.toString(),
    limit: limit.toString(),
    ...(search && { search })
  });
  
  const response = await fetch(
    `http://localhost:8000/commerce/api/v1/products?${params}`,
    {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    }
  );
  
  const result = await response.json();
  return result.success ? result.data : [];
};
```

### 3. Créer une vente

```typescript
const createSale = async (saleData: CreateSaleDto) => {
  const token = await AsyncStorage.getItem('accessToken');
  
  const response = await fetch('http://localhost:8000/commerce/api/v1/sales', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(saleData)
  });
  
  const result = await response.json();
  
  if (result.success) {
    console.log('Vente créée:', result.data);
    return result.data;
  } else {
    throw new Error(result.message);
  }
};

// Exemple de données
const saleData = {
  customerId: 'customer-uuid',
  saleDate: new Date().toISOString(),
  paymentMethod: 'cash',
  paymentStatus: 'paid',
  items: [
    {
      productId: 'product-uuid-1',
      quantity: 2,
      unitPrice: 5000
    },
    {
      productId: 'product-uuid-2',
      quantity: 1,
      unitPrice: 15000
    }
  ],
  companyId: 'company-uuid'
};

await createSale(saleData);
```

### 4. Dashboard pour mobile

```typescript
const getDashboardData = async (period: 'day' | 'week' | 'month' = 'month') => {
  const token = await AsyncStorage.getItem('accessToken');
  
  const response = await fetch(
    `http://localhost:8000/commerce/api/v1/dashboard/data?period=${period}`,
    {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    }
  );
  
  const result = await response.json();
  
  if (result.success) {
    const { salesToday, salesSummary, customerStats, inventoryAlerts } = result.data;
    return {
      todaySales: salesToday.totalAmount,
      todayCount: salesToday.count,
      totalRevenue: salesSummary.totalRevenue,
      lowStockProducts: inventoryAlerts.lowStock.length,
      outOfStockProducts: inventoryAlerts.outOfStock.length
    };
  }
  
  return null;
};
```

### 5. Upload document/photo

```typescript
const uploadExpenseReceipt = async (expenseId: string, imageUri: string) => {
  const token = await AsyncStorage.getItem('accessToken');
  
  const formData = new FormData();
  formData.append('file', {
    uri: imageUri,
    type: 'image/jpeg',
    name: `receipt-${Date.now()}.jpg`
  } as any);
  formData.append('documentType', 'receipt');
  formData.append('relatedToEntityType', 'expense');
  formData.append('relatedToEntityId', expenseId);
  
  const response = await fetch(
    'http://localhost:8000/commerce/api/v1/documents/upload',
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'multipart/form-data'
      },
      body: formData
    }
  );
  
  return await response.json();
};
```

## Codes d'erreur courants

| Code | Description |
|------|-------------|
| 400 | Requête invalide (validation DTO échouée) |
| 401 | Non authentifié (token manquant/invalide) |
| 403 | Non autorisé (permissions insuffisantes) |
| 404 | Ressource non trouvée |
| 409 | Conflit (ex: email déjà utilisé) |
| 422 | Entité non traitable (validation métier échouée) |
| 500 | Erreur serveur interne |
| 503 | Service temporairement indisponible |
