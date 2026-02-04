# Système de Création Automatique des Entités

## 🎯 Objectif

Éviter les doublons de **fournisseurs** et **clients** dans le backend en gérant automatiquement leur création basée sur le **numéro de téléphone** comme identifiant unique.

---

## 🔑 Principe de Fonctionnement

### Identifiant Unique: Numéro de Téléphone

- **Client**: `phoneNumber` (unique, requis)
- **Fournisseur**: `phoneNumber` (unique, requis)

Le système **normalise automatiquement** les numéros de téléphone en enlevant tous les caractères non numériques (espaces, tirets, parenthèses) tout en préservant le `+` initial.

**Exemples de normalisation**:
```
"+243 999 123 456"  → "+243999123456"
"0999-123-456"      → "0999123456"
"+1 (555) 123-4567" → "+15551234567"
```

---

## 📦 Méthodes de Service

### 1. Fournisseurs (SuppliersService)

#### `findOrCreateByPhoneNumber(phoneNumber, supplierName?, filterOptions?)`

**Comportement**:
1. Normalise le numéro de téléphone
2. Cherche un fournisseur existant avec ce numéro **dans la même entreprise (companyId)**
3. **Si trouvé**: Retourne le fournisseur existant (met à jour le nom si fourni et différent)
4. **Si non trouvé**: Crée un nouveau fournisseur avec:
   - `phoneNumber`: Numéro normalisé
   - `name`: Nom fourni ou `"Fournisseur {phoneNumber}"`
   - `category`: `REGULAR` (par défaut)
   - `paymentTerms`: `"Net 30"` (par défaut)
   - `deliveryTimeInDays`: `7` (par défaut)
   - `companyId`: ID entreprise du filterOptions
   - `businessUnitId`: ID unité commerciale du filterOptions

**Interface FilterOptions**:
```typescript
interface SupplierFilterOptions {
  companyId?: string;          // ID entreprise (multi-tenant)
  businessUnitId?: string;     // ID unité commerciale
  includeChildUnits?: boolean; // Inclure les unités enfants
  childUnitIds?: string[];     // IDs des unités enfants
}
```

**Exemple d'utilisation**:
```typescript
const supplier = await suppliersService.findOrCreateByPhoneNumber(
  '+243999123456',
  'Fournisseur ABC',
  { companyId: user.companyId, businessUnitId: user.businessUnitId }
);
// Retourne le fournisseur existant OU en crée un nouveau avec contexte Business Unit
```

#### `findByPhoneNumber(phoneNumber)`

Trouve un fournisseur par son numéro (retourne `null` si non trouvé).

---

### 2. Clients (CustomersService)

#### `findOrCreateByPhoneNumber(phoneNumber, customerName?, email?)`

**Comportement**:
1. Normalise le numéro de téléphone
2. Cherche un client existant avec ce numéro
3. **Si trouvé**: Retourne le client existant (met à jour nom et email si fournis et différents)
4. **Si non trouvé**: Crée un nouveau client avec:
   - `phoneNumber`: Numéro normalisé
   - `fullName`: Nom fourni ou `"Client {phoneNumber}"`
   - `email`: Email fourni ou `null`
   - `category`: `NEW_CUSTOMER` (par défaut)
   - `totalPurchases`: `0`

> **Note**: Le contexte Business Unit (companyId, businessUnitId) est géré au niveau du service appelant (ex: SalesService) qui définit ces champs lors de la création de la vente associée.

**Exemple d'utilisation**:
```typescript
const customer = await customersService.findOrCreateByPhoneNumber(
  '+243999123456',
  'Jean Mukendi',
  'jean@example.com'
);
// Retourne le client existant OU en crée un nouveau
```

#### `findByPhoneNumber(phoneNumber)`

Trouve un client par son numéro (retourne `null` si non trouvé).

---

## 💰 Utilisation dans le Module Dépenses (Expenses)

### Nouveau Champ DTO: `supplierPhoneNumber`

Le `CreateExpenseDto` inclut maintenant un champ optionnel:

```typescript
{
  "motif": "Achat de stock",
  "amount": 5000.0,
  "category": "inventory",
  "supplierPhoneNumber": "+243999123456",  // ⬅️ NOUVEAU CHAMP
  "supplierName": "Fournisseur ABC",        // Optionnel
  "paidAmount": 2000.0,
  "paymentStatus": "partial",
  
  // === Champs Business Unit (optionnels, auto-définis si absents) ===
  "companyId": "uuid-company",              // Optionnel - Défaut: entreprise utilisateur
  "businessUnitId": "uuid-bu",              // Optionnel - Défaut: unité utilisateur
  "businessUnitCode": "POS-KIN-001",        // Optionnel - Code de l'unité
  "businessUnitType": "pos"                 // Optionnel - company, branch, pos
}
```

### Méthode de Service: `createExpenseWithSupplierAutoCreate`

**Workflow automatique**:

1. **Validation** du montant (> 0)
2. **Si `supplierPhoneNumber` est fourni**:
   - Appelle `suppliersService.findOrCreateByPhoneNumber()`
   - Récupère l'ID et le nom du fournisseur (existant ou créé)
   - Assigne `supplierId` et `supplierName` à la dépense
3. **Crée la dépense** avec toutes les informations

**Exemple d'appel dans le controller**:
```typescript
@Post()
async createExpense(
  @Body() createExpenseDto: CreateExpenseDto,
  @CurrentUser() user: User
) {
  if (createExpenseDto.supplierPhoneNumber) {
    return this.expensesService.createExpenseWithSupplierAutoCreate(
      createExpenseDto,
      user.id,
      createExpenseDto.supplierPhoneNumber
    );
  }
  
  return this.expensesService.createExpense(createExpenseDto, user.id);
}
```

---

## 🔄 Scénarios d'Utilisation

### Scénario 1: Première Dépense avec Nouveau Fournisseur

**Requête**:
```json
POST /expenses
{
  "date": "2025-11-20T10:00:00Z",
  "motif": "Achat de ciment",
  "amount": 500000.0,
  "category": "inventory",
  "supplierPhoneNumber": "+243999555888",
  "supplierName": "Cimenterie du Congo"
}
```

**Résultat**:
1. ✅ Nouveau fournisseur créé automatiquement avec le numéro `+243999555888`
2. ✅ Dépense créée avec `supplierId` = ID du nouveau fournisseur
3. ✅ `supplierName` = "Cimenterie du Congo"

---

### Scénario 2: Deuxième Dépense avec Même Fournisseur

**Requête**:
```json
POST /expenses
{
  "date": "2025-11-21T14:00:00Z",
  "motif": "Achat de sable",
  "amount": 200000.0,
  "category": "inventory",
  "supplierPhoneNumber": "+243 999 555 888",  // ⬅️ Même numéro (format différent)
  "supplierName": "Cimenterie du Congo"
}
```

**Résultat**:
1. ✅ Numéro normalisé → `+243999555888`
2. ✅ Fournisseur existant trouvé (pas de doublon créé)
3. ✅ Dépense créée avec `supplierId` = ID du fournisseur existant
4. ✅ **Aucun doublon** dans la base de données

---

### Scénario 3: Mise à Jour du Nom du Fournisseur

**Requête**:
```json
POST /expenses
{
  "motif": "Achat de briques",
  "amount": 150000.0,
  "category": "inventory",
  "supplierPhoneNumber": "+243999555888",
  "supplierName": "Cimenterie du Congo SARL"  // ⬅️ Nom mis à jour
}
```

**Résultat**:
1. ✅ Fournisseur existant trouvé
2. ✅ Nom du fournisseur mis à jour: "Cimenterie du Congo SARL"
3. ✅ Dépense créée avec les infos à jour

---

## 🛡️ Gestion des Conflits

### Email Unique (Clients seulement)

Si lors de la mise à jour d'un client avec `findOrCreateByPhoneNumber`, un **email** est fourni:

1. **Vérification**: L'email n'est pas déjà utilisé par un autre client
2. **Si disponible**: Email mis à jour
3. **Si conflit**: Email **non modifié**, pas d'erreur levée

**Exemple**:
```typescript
// Client A: phone="+243999111222", email="client@example.com"
// Client B: phone="+243999333444", email=null

// Tentative de mise à jour de Client B avec l'email de Client A
const clientB = await customersService.findOrCreateByPhoneNumber(
  '+243999333444',
  'Client B',
  'client@example.com'  // ⬅️ Déjà utilisé par Client A
);
// Résultat: clientB.email reste null (pas d'erreur)
```

---

## 📊 Avantages du Système

### 1. **Évite les Doublons**
- Un seul fournisseur par numéro de téléphone
- Un seul client par numéro de téléphone
- Normalisation automatique des formats de numéros

### 2. **Expérience Utilisateur Fluide**
- Pas besoin de créer manuellement fournisseurs/clients
- Création automatique lors de la première transaction
- Mise à jour automatique des informations

### 3. **Intégrité des Données**
- Identifiant unique garanti (phoneNumber)
- Historique d'achats consolidé par entité
- Relations cohérentes entre dépenses/ventes et fournisseurs/clients

### 4. **Maintenance Simplifiée**
- Moins d'entités dupliquées à nettoyer
- Statistiques fiables (totalPurchases, lastPurchaseDate)
- Rapports précis par fournisseur/client

---

## 🔍 Cas d'Usage Réels

### Commerce de Détail (Kinshasa)

**Problème**: Un commerçant achète du stock chez le même fournisseur mais écrit le nom différemment:
- "Fournisseur ABC"
- "ABC SARL"
- "Fourni ABC"

**Solution**: En utilisant le numéro de téléphone comme identifiant unique, tous ces achats sont liés au **même fournisseur**, évitant 3 entrées dupliquées.

### Ventes à Crédit

**Problème**: Un client fait plusieurs achats à crédit. Si créé plusieurs fois, impossible de suivre le total des créances.

**Solution**: Le numéro de téléphone garantit qu'un seul profil client existe, permettant de:
- Calculer le total des achats
- Suivre le total des créances
- Déterminer la catégorie client (VIP, REGULAR, etc.)

---

## 🚀 Prochaines Étapes

### À Implémenter

1. **Module Ventes (Sales)**:
   - Ajouter `customerPhoneNumber` au `CreateSaleDto`
   - Utiliser `customersService.findOrCreateByPhoneNumber()` lors de la création de ventes
   - Mettre à jour automatiquement `totalPurchases` et `lastPurchaseDate`

2. **Module Achats (si existe)**:
   - Même logique que Dépenses pour les fournisseurs

3. **API Endpoints dédiés**:
   ```
   GET /suppliers/by-phone/:phoneNumber
   GET /customers/by-phone/:phoneNumber
   ```

4. **Dashboard Analytics**:
   - Top 10 fournisseurs par volume d'achats
   - Top 10 clients par chiffre d'affaires
   - Alertes de doublons potentiels (noms similaires, numéros différents)

---

## 📝 Notes Techniques

### Contraintes Base de Données

Les colonnes `phoneNumber` sont définies comme **UNIQUE** dans les entités:

```typescript
// Customer Entity
@Column({ name: 'phone_number', unique: true })
phoneNumber: string;

// Supplier Entity
@Column()
phoneNumber: string; // Devrait aussi être unique
```

⚠️ **TODO**: Ajouter la contrainte `unique: true` sur `Supplier.phoneNumber` si pas déjà fait.

### Performances

- **Index automatique**: La contrainte `UNIQUE` crée un index sur `phoneNumber`
- **Recherche rapide**: `O(log n)` grâce à l'index B-tree de PostgreSQL
- **Pas de scan complet**: Pas besoin de parcourir toutes les lignes

### Migration Base de Données

Si des doublons existent déjà:

1. **Identifier les doublons**:
   ```sql
   SELECT phone_number, COUNT(*) as count
   FROM suppliers
   GROUP BY phone_number
   HAVING COUNT(*) > 1;
   ```

2. **Fusionner manuellement** ou écrire un script de migration

3. **Ajouter la contrainte unique** après nettoyage

---

## 📞 Support

Pour toute question sur ce système, contacter l'équipe backend ou consulter:
- `/suppliers/suppliers.service.ts` - Ligne ~85
- `/customers/customers.service.ts` - Ligne ~150
- `/expenses/expenses.service.ts` - Ligne ~70

---

**Dernière mise à jour**: 28 Décembre 2025  
**Version**: 1.1.0
