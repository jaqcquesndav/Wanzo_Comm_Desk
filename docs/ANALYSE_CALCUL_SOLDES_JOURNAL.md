# Analyse des Incohérences Comptables - Journal des Opérations

> **Date d'analyse :** Février 2026  
> **Statut :** ✅ CORRIGÉ

---

## 📊 Résumé des Problèmes

Le journal des opérations mélange actuellement des catégories comptables incompatibles, ce qui produit des soldes sans signification économique.

---

## 🔍 Analyse Détaillée

### 1. Structure de Données (✅ Correcte)

Le modèle `OperationJournalEntry` a une bonne structure avec des soldes séparés :

```dart
// lib/features/dashboard/models/operation_journal_entry.dart

@HiveField(19)
final double? cashBalance;       // Solde de TRÉSORERIE

@HiveField(20)  
final double? salesBalance;      // Cumul des VENTES

@HiveField(21)
final double? stockValue;        // Valeur du STOCK

// Et les versions multi-devises:
@HiveField(22)
final Map<String, double>? cashBalancesByCurrency;

@HiveField(23)
final Map<String, double>? salesBalancesByCurrency;

@HiveField(24)
final Map<String, double>? stockValuesByCurrency;
```

De plus, une méthode helper existe déjà :
```dart
double? getRelevantBalance() {
  if (type.impactsCash) return cashBalance;
  if (type.isSalesOperation) return salesBalance;
  if (type.impactsStock) return stockValue;
  return balanceAfter; // Fallback
}
```

---

### 2. Calcul des Soldes dans Repository (✅ Correct mais incomplet)

**Fichier :** `lib/features/dashboard/repositories/operation_journal_repository.dart`

Le repository calcule correctement les soldes par type (ligne 491-575) :

```dart
// 1. Opérations de TRÉSORERIE
if (entryToSave.type.impactsCash) {
  newCashBalances[currency] = currentCash + cashImpact;
  cashBalance = newCashBalances[currency];
}
// 2. Opérations de VENTES
else if (entryToSave.type.isSalesOperation) {
  newSalesBalances[currency] = currentSales + entryToSave.amount;
  salesBalance = newSalesBalances[currency];
}
// 3. Opérations de STOCK
else if (entryToSave.type.impactsStock) {
  newStockBalances[currency] = currentStock + stockImpact;
  stockValue = newStockBalances[currency];
}
```

**⚠️ PROBLÈME :** Le `balanceAfter` (obsolète) est calculé incorrectement :
```dart
// Ligne 566-567 - PROBLÈME!
double totalBalance = 0.0;
newCashBalances.forEach((_, value) => totalBalance += value);
```

Cela prend UNIQUEMENT les soldes de caisse, mais `balanceAfter` est ensuite utilisé pour TOUTES les opérations dans le PDF !

---

### 3. Export PDF (❌ INCORRECT)

**Fichier :** `lib/features/dashboard/services/journal_service.dart`

#### Problème 1 : Utilisation de `balanceAfter` obsolète

```dart
// Ligne 130 - PROBLÈME!
entryCurrencyFormat.format(entry.balanceAfter),
```

Le PDF utilise `balanceAfter` qui :
- Est calculé uniquement à partir des soldes de caisse
- Est affiché pour TOUTES les opérations (ventes, stocks, etc.)
- Donne des soldes incohérents

#### Problème 2 : Une seule colonne "Solde"

Le PDF affiche :
| Date | Heure | Description | Débit | Crédit | **Solde** |

Alors qu'il devrait y avoir des colonnes séparées ou des sections distinctes.

#### Problème 3 : Mélange de toutes les opérations

Le PDF liste dans le même tableau :
- ✅ Entrées de caisse
- ✅ Sorties de caisse
- ❌ Ventes (chiffre d'affaires) - NE DEVRAIT PAS IMPACTER le solde "Caisse"
- ❌ Entrées de stock - NE DEVRAIT PAS IMPACTER le solde "Caisse"
- ❌ Sorties de stock - NE DEVRAIT PAS IMPACTER le solde "Caisse"

---

### 4. Écran du Journal (❌ PARTIELLEMENT INCORRECT)

**Fichier :** `lib/features/dashboard/screens/enhanced_operation_journal_screen.dart`

#### Problème 1 : Calcul du "Solde net" (ligne 208-212)

```dart
final totalAmount = state.filteredOperations.fold<double>(
  0.0,
  (sum, op) => sum + op.amount,
);
// ...
Text('Solde net: ${totalAmount.toStringAsFixed(2)} CDF'),
```

Ce calcul additionne :
- Ventes (positif)
- Dépenses (négatif)
- Entrées de stock (positif)
- Sorties de stock (négatif)
- Mouvements de caisse

**Résultat :** Un chiffre sans signification comptable !

#### Problème 2 : Affichage du solde par opération (ligne 904)

```dart
operation.getRelevantBalance() ?? 0,
```

Ici, c'est ✅ CORRECT - la méthode `getRelevantBalance()` est utilisée.

---

## 📐 Règles Comptables (OHADA/SYSCOHADA)

### Classification des Opérations

| Type d'Opération | Classe OHADA | Impact Comptable |
|-----------------|--------------|------------------|
| `saleCash` | Classe 7 (Produits) + Classe 5 (Caisse) | CA + Encaissement |
| `saleCredit` | Classe 7 (Produits) + Classe 4 (Clients) | CA + Créance |
| `saleInstallment` | Classe 7 + Classe 4 | CA + Créance échelonnée |
| `stockIn` | Classe 3 (Stocks) | ↑ Actif Stock |
| `stockOut` | Classe 3 (Stocks) | ↓ Actif Stock |
| `cashIn` | Classe 5 (Trésorerie) | ↑ Caisse |
| `cashOut` | Classe 5 (Trésorerie) | ↓ Caisse |
| `customerPayment` | Classe 5 + Classe 4 | Encaissement créance |
| `supplierPayment` | Classe 5 + Classe 4 | Règlement dette |

### Règle Fondamentale

> **On ne peut pas additionner des montants de classes comptables différentes !**

Par exemple, additionner une vente (classe 7) et une entrée de stock (classe 3) n'a aucun sens.

---

## 🛠️ Corrections Nécessaires

### Correction 1 : Service PDF - Séparer par Catégorie

Le PDF devrait avoir des sections distinctes :

```
=== JOURNAL DE TRÉSORERIE ===
| Date | Description | Encaissement | Décaissement | Solde Caisse |

=== JOURNAL DES VENTES ===
| Date | Description | Montant | Cumul Ventes |

=== JOURNAL DES STOCKS ===
| Date | Description | Entrées | Sorties | Valeur Stock |
```

**OU** afficher le type de solde :

```
| Date | Description | Débit | Crédit | Type | Solde |
| ...  | Vente X     | 1000  |        | CA   | 50000 |
| ...  | Achat stock |       | 2000   | Stock| 30000 |
```

### Correction 2 : Utiliser `getRelevantBalance()` dans le PDF

```dart
// AVANT (incorrect):
entryCurrencyFormat.format(entry.balanceAfter),

// APRÈS (correct):
entryCurrencyFormat.format(entry.getRelevantBalance() ?? 0),
```

**ET** ajouter une colonne pour le libellé :
```dart
entry.getBalanceLabel(), // "Solde Caisse", "Total Ventes", "Valeur Stock"
```

### Correction 3 : Écran - Résumé par Catégorie

```dart
// AVANT (incorrect):
final totalAmount = state.filteredOperations.fold<double>(
  0.0, (sum, op) => sum + op.amount,
);

// APRÈS (correct):
final cashTotal = state.filteredOperations
    .where((op) => op.type.impactsCash)
    .fold<double>(0.0, (sum, op) => sum + op.amount);

final salesTotal = state.filteredOperations
    .where((op) => op.type.isSalesOperation)
    .fold<double>(0.0, (sum, op) => sum + op.amount);

final stockTotal = state.filteredOperations
    .where((op) => op.type.impactsStock)
    .fold<double>(0.0, (sum, op) => sum + op.amount);
```

Affichage :
```dart
Column(
  children: [
    Text('Caisse: ${cashTotal.toStringAsFixed(2)} CDF'),
    Text('Ventes: ${salesTotal.toStringAsFixed(2)} CDF'),
    Text('Stock: ${stockTotal.toStringAsFixed(2)} CDF'),
  ],
)
```

### Correction 4 : Solde d'ouverture par type

La méthode `getOpeningBalance()` ne devrait pas être utilisée globalement. Utiliser `getOpeningBalancesByType()` à la place.

---

## 📋 Plan d'Action

### Phase 1 : Corrections Urgentes (PDF)

1. [ ] Modifier `journal_service.dart` pour utiliser `getRelevantBalance()`
2. [ ] Ajouter une colonne "Type de solde" ou séparer en sections
3. [ ] Calculer le solde d'ouverture PAR TYPE

### Phase 2 : Corrections Écran

4. [ ] Modifier `enhanced_operation_journal_screen.dart` pour le résumé par catégorie
5. [ ] Afficher 3 totaux distincts au lieu d'un "Solde net" global

### Phase 3 : Options Utilisateur

6. [ ] Permettre le filtrage par catégorie dans l'export PDF
7. [ ] Option pour exporter uniquement la trésorerie / les ventes / le stock
8. [ ] Ajouter un toggle "Vue consolidée" vs "Vue par catégorie"

---

## 📈 Impact Business

| Problème Actuel | Impact |
|-----------------|--------|
| Solde mélangé | Impossible de connaître le vrai solde de caisse |
| Résumé global | Chiffre sans signification pour la prise de décision |
| PDF incohérent | Document non utilisable pour un comptable externe |

---

## ⚠️ Note Importante

**Les structures de données sont correctes** (`cashBalance`, `salesBalance`, `stockValue`).

Le problème est uniquement dans :
1. Le calcul de `balanceAfter` (devrait être supprimé ou ignoré)
2. L'affichage dans le PDF et l'écran qui n'utilisent pas les bons champs

**Aucune migration de données n'est nécessaire** - il suffit de corriger l'affichage.

---

## ✅ CORRECTIONS APPLIQUÉES

### 1. Service PDF (`journal_service.dart`)

**Réécriture complète** avec séparation en 4 sections distinctes :

| Section | Couleur | Contenu |
|---------|---------|---------|
| 📘 Trésorerie | Bleu | Encaissements/Décaissements avec solde courant |
| 📗 Chiffre d'Affaires | Vert | Ventes avec CA cumulé |
| 📙 Stock | Orange | Entrées/Sorties avec variation |
| ⬜ Autres Opérations | Gris | Financements, etc. |

**Structure du PDF :**
```
┌────────────────────────────────────────┐
│ RÉSUMÉ PAR CATÉGORIE                   │
│ • Trésorerie: +X / -Y = Net Z          │
│ • CA Réalisé: Total ventes             │
│ • Stock: +entrées / -sorties           │
│ • Autres: total                        │
├────────────────────────────────────────┤
│ 📘 TRÉSORERIE (N opérations)           │
│ [Tableau avec colonnes: Date, Réf,     │
│  Description, Encaissement, Décaiss.,  │
│  Solde courant]                        │
├────────────────────────────────────────┤
│ 📗 CHIFFRE D'AFFAIRES (N opérations)   │
│ [Tableau avec: Date, Réf, Description, │
│  Montant, CA Cumulé]                   │
├────────────────────────────────────────┤
│ 📙 STOCK (N opérations)                │
│ [Tableau avec: Date, Réf, Description, │
│  Entrée, Sortie, Valeur stock]         │
├────────────────────────────────────────┤
│ ⬜ AUTRES OPÉRATIONS (N opérations)    │
│ [Tableau avec: Date, Réf, Description, │
│  Montant]                              │
└────────────────────────────────────────┘
```

### 2. Écran Journal (`enhanced_operation_journal_screen.dart`)

**Méthode `_buildResultsSummary()` réécrite :**

Avant (INCORRECT) :
```dart
// Calculait un "Solde net" global mélangeant tout
final netBalance = totalIncoming - totalOutgoing;
```

Après (CORRECT) :
```dart
// Séparation par catégorie
final cashIn = entries.where((e) => e.impactsCash && e.amount > 0).sum();
final cashOut = entries.where((e) => e.impactsCash && e.amount < 0).sum();
final salesTotal = entries.where((e) => e.isSalesOperation).sum();
final stockIn = entries.where((e) => e.impactsStock && e.amount > 0).sum();
final stockOut = entries.where((e) => e.impactsStock && e.amount < 0).sum();
```

**Affichage :** 3 lignes distinctes avec icônes
- 💵 Trésorerie: +encaissements / -décaissements = net
- 📈 CA: total des ventes
- 📦 Stock: ↑entrées / ↓sorties

### 3. Fichiers Modifiés

| Fichier | Lignes | Type de modification |
|---------|--------|---------------------|
| `lib/features/dashboard/services/journal_service.dart` | ~450 | Réécriture complète |
| `lib/features/dashboard/screens/enhanced_operation_journal_screen.dart` | ~40 | Modification méthode |

### 4. Validation

- ✅ Compilation sans erreurs
- ✅ Respect des règles OHADA SYSCOHADA
- ✅ Chaque catégorie a son propre solde courant
- ✅ Aucun mélange de classes comptables
- ✅ `balanceAfter` n'est plus utilisé

---

## 📋 Checklist de Vérification

- [ ] Tester l'export PDF et vérifier les 4 sections
- [ ] Vérifier les calculs dans chaque section
- [ ] Confirmer que les soldes courants sont indépendants
- [ ] Valider avec un comptable externe si possible

