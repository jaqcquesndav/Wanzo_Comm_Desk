# Guide de Migration : Distinguer Comptabilité et Trésorerie

> **Date :** Février 2026  
> **Objectif :** Améliorer l'UI/UX pour distinguer clairement la vue comptable (économique) de la vue trésorerie (flux de caisse)

---

## ⚠️ IMPORTANT : Aucune modification des structures de données

**Les modèles de données (Sale, Expense, OperationJournalEntry, etc.) n'ont PAS été modifiés.**

Toutes les modifications sont purement **cosmétiques/UI** et utilisent les champs existants :
- `Sale.paidAmountInCdf` → pour distinguer ce qui est encaissé
- `Sale.totalAmountInCdf` → pour le montant total (revenu comptable)
- `Expense.paymentStatus` → pour distinguer ce qui est décaissé
- `Expense.paidAmount` → pour le montant réellement payé
- `OperationType.impactsCash` → helper existant pour filtrer les opérations de trésorerie

---

## 📚 Terminologie Adoptée

| Concept | Vue Comptable (Économique) | Vue Trésorerie (Cash-flow) |
|---------|---------------------------|---------------------------|
| Argent entrant | **Revenus** | **Encaissements** |
| Argent sortant | **Charges** | **Décaissements** |
| Couleur entrées | 🟢 Vert (`WanzoTheme.success`) | 🔵 Bleu (`Colors.blue`) |
| Couleur sorties | 🔴 Rouge (`WanzoTheme.danger`) | 🟠 Orange (`Colors.orange`) |

### Explication métier
- **Comptabilité** : Enregistre toutes les transactions économiques, qu'elles soient payées ou non
- **Trésorerie** : Ne montre que les mouvements réels de caisse (argent effectivement encaissé/décaissé)

---

## 📁 Fichiers Modifiés

### 1. Traductions (Localisation)

#### `lib/l10n/app_fr.arb`
Ajout des clés suivantes :
```json
"sidebarRevenues": "Revenus",
"sidebarCharges": "Charges",
"chartTitleAccountingView": "Revenus vs Charges",
"chartTitleCashFlowView": "Encaissements vs Décaissements",
"chartLegendRevenues": "Revenus",
"chartLegendCharges": "Charges",
"chartLegendCashIn": "Encaissements",
"chartLegendCashOut": "Décaissements",
"viewModeAccounting": "Comptabilité",
"viewModeCashFlow": "Trésorerie",
"kpiTurnover": "Chiffre d'affaires",
"kpiCashIn": "Encaissé",
"kpiCashOut": "Décaissé",
"paymentStatusPaid": "Payé",
"paymentStatusPartial": "Partiel",
"paymentStatusPending": "En attente",
"paymentStatusNotPaid": "Non payé",
"cashFlowImpact": "Impact trésorerie",
"accountingImpact": "Impact comptable",
"receivablesToCollect": "À encaisser",
"payablesToPay": "À décaisser",
"cashInToday": "Encaissements du jour",
"cashOutToday": "Décaissements du jour"
```

#### `lib/l10n/app_en.arb`
Ajout des mêmes clés en anglais :
```json
"sidebarRevenues": "Revenue",
"sidebarCharges": "Expenses",
"chartTitleAccountingView": "Revenue vs Expenses",
"chartTitleCashFlowView": "Cash In vs Cash Out",
"chartLegendRevenues": "Revenue",
"chartLegendCharges": "Expenses",
"chartLegendCashIn": "Cash In",
"chartLegendCashOut": "Cash Out",
"viewModeAccounting": "Accounting",
"viewModeCashFlow": "Cash Flow",
"kpiTurnover": "Turnover",
"kpiCashIn": "Cashed In",
"kpiCashOut": "Cashed Out",
"paymentStatusPaid": "Paid",
"paymentStatusPartial": "Partial",
"paymentStatusPending": "Pending",
"paymentStatusNotPaid": "Not Paid",
"cashFlowImpact": "Cash flow impact",
"accountingImpact": "Accounting impact",
"receivablesToCollect": "To collect",
"payablesToPay": "To pay",
"cashInToday": "Today's cash in",
"cashOutToday": "Today's cash out"
```

---

### 2. Sidebar Navigation

#### `lib/core/shared_widgets/wanzo_scaffold.dart`

**Changement :** Labels du menu latéral

| Avant | Après |
|-------|-------|
| `'Ventes'` | `'Revenus'` |
| `'Dépenses'` | `'Charges'` |

**Code modifié :**
```dart
// Navigation item pour les ventes
NavigationItem(
  icon: Icons.point_of_sale,
  label: 'Revenus', // Était 'Ventes' - Terminologie comptable
  route: '/operations/sales',
),

// Navigation item pour les dépenses  
NavigationItem(
  icon: Icons.money_off,
  label: 'Charges', // Était 'Dépenses' - Terminologie comptable
  route: '/expenses',
),
```

---

### 3. Enum ChartViewMode (Nouveau)

#### `lib/features/dashboard/models/chart_filter.dart`

**Ajout :** Nouvelle énumération pour basculer entre les vues

```dart
/// Mode d'affichage du graphique : comptable ou trésorerie
enum ChartViewMode {
  /// Vue comptable: Revenus vs Charges (toutes les opérations)
  accounting,
  
  /// Vue trésorerie: Encaissements vs Décaissements (mouvements de caisse uniquement)
  cashFlow,
}

extension ChartViewModeExtension on ChartViewMode {
  /// Nom d'affichage
  String get displayName {
    switch (this) {
      case ChartViewMode.accounting:
        return 'Comptabilité';
      case ChartViewMode.cashFlow:
        return 'Trésorerie';
    }
  }

  /// Titre du graphique selon le mode
  String get chartTitle {
    switch (this) {
      case ChartViewMode.accounting:
        return 'Revenus vs Charges';
      case ChartViewMode.cashFlow:
        return 'Encaissements vs Décaissements';
    }
  }

  /// Icône du mode
  IconData get icon {
    switch (this) {
      case ChartViewMode.accounting:
        return Icons.bar_chart;
      case ChartViewMode.cashFlow:
        return Icons.account_balance_wallet;
    }
  }

  /// Label pour la légende des entrées (revenus ou encaissements)
  String get incomeLegend {
    switch (this) {
      case ChartViewMode.accounting:
        return 'Revenus';
      case ChartViewMode.cashFlow:
        return 'Encaissements';
    }
  }

  /// Label pour la légende des sorties (charges ou décaissements)
  String get expenseLegend {
    switch (this) {
      case ChartViewMode.accounting:
        return 'Charges';
      case ChartViewMode.cashFlow:
        return 'Décaissements';
    }
  }
}
```

---

### 4. Graphique Double-Vue

#### `lib/features/dashboard/widgets/expense_chart_widget.dart`

**Modifications majeures :**

#### 4.1 Nouvelle variable d'état
```dart
ChartViewMode _selectedViewMode = ChartViewMode.accounting;
```

#### 4.2 Getters pour les couleurs dynamiques
```dart
/// Couleur pour les revenus/encaissements selon le mode
Color get _incomeColor {
  return _selectedViewMode == ChartViewMode.accounting
      ? WanzoTheme.success  // Vert pour revenus
      : Colors.blue;       // Bleu pour encaissements
}

/// Couleur pour les charges/décaissements selon le mode  
Color get _expenseColor {
  return _selectedViewMode == ChartViewMode.accounting
      ? WanzoTheme.danger  // Rouge pour charges
      : Colors.orange;     // Orange pour décaissements
}
```

#### 4.3 Méthodes d'agrégation pour la trésorerie
```dart
/// Agrège uniquement les ENCAISSEMENTS (montants payés des ventes)
Map<String, double> _aggregateCashInByPeriod(
  List<Sale> sales,
  ChartPeriod period,
) {
  final result = <String, double>{};
  for (final sale in sales) {
    // Ne prendre que le montant RÉELLEMENT ENCAISSÉ
    if (sale.paidAmountInCdf > 0) {
      final key = _getDateKey(sale.date, period);
      result[key] = (result[key] ?? 0) + sale.paidAmountInCdf;
    }
  }
  return result;
}

/// Agrège uniquement les DÉCAISSEMENTS (dépenses effectivement payées)
Map<String, double> _aggregateCashOutByPeriod(
  List<Expense> expenses,
  ChartPeriod period,
) {
  final result = <String, double>{};
  for (final expense in expenses) {
    // Ne prendre que les dépenses PAYÉES ou PARTIELLEMENT payées
    if (expense.paymentStatus == ExpensePaymentStatus.paid ||
        expense.paymentStatus == ExpensePaymentStatus.partial) {
      final key = _getDateKey(expense.date, period);
      final paidAmount = expense.paidAmount ?? expense.amount;
      result[key] = (result[key] ?? 0) + paidAmount;
    }
  }
  return result;
}
```

#### 4.4 Sélecteur de mode de vue
```dart
Widget _buildViewModeSelector(BuildContext context) {
  final theme = Theme.of(context);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: ChartViewMode.values.map((mode) {
      final isSelected = _selectedViewMode == mode;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                mode.icon,
                size: 16,
                color: isSelected 
                    ? theme.colorScheme.onPrimary 
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(mode.displayName),
            ],
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() => _selectedViewMode = mode);
            }
          },
        ),
      );
    }).toList(),
  );
}
```

#### 4.5 Logique de données dans build()
```dart
// Dans la méthode build(), sélectionner les données selon le mode
Map<String, double> incomeData;
Map<String, double> expenseData;

if (_selectedViewMode == ChartViewMode.accounting) {
  // Vue comptable: toutes les ventes et dépenses
  incomeData = _aggregateSalesByPeriod(sales, _selectedPeriod);
  expenseData = _aggregateExpensesByPeriod(expenses, _selectedPeriod);
} else {
  // Vue trésorerie: seulement les mouvements de caisse
  incomeData = _aggregateCashInByPeriod(sales, _selectedPeriod);
  expenseData = _aggregateCashOutByPeriod(expenses, _selectedPeriod);
}
```

#### 4.6 Couleurs dynamiques dans les graphiques

**LineChart :**
```dart
LineChartBarData(
  // ...
  color: _incomeColor,  // Au lieu de WanzoTheme.success fixe
),
LineChartBarData(
  // ...
  color: _expenseColor, // Au lieu de WanzoTheme.danger fixe
),
```

**BarChart :**
```dart
BarChartRodData(
  toY: salesValue,
  color: _incomeColor,  // Dynamique
),
BarChartRodData(
  toY: expenseValue,
  color: _expenseColor, // Dynamique
),
```

**PieChart :**
```dart
PieChartSectionData(
  value: totalIncome,
  color: _incomeColor,
  title: _selectedViewMode.incomeLegend,
),
PieChartSectionData(
  value: totalExpense,
  color: _expenseColor,
  title: _selectedViewMode.expenseLegend,
),
```

---

### 5. Filtres du Journal

#### `lib/features/dashboard/models/journal_filter.dart`

**Ajout :** Deux nouvelles factory methods

```dart
/// Filtre pour la TRÉSORERIE uniquement (opérations impactant la caisse)
/// Vue "Encaissements vs Décaissements"
factory JournalFilter.cashFlowOnly({DateTime? startDate, DateTime? endDate}) {
  return JournalFilter(
    startDate: startDate,
    endDate: endDate,
    selectedTypes: {
      // Encaissements (entrées de caisse)
      OperationType.cashIn,
      OperationType.customerPayment,
      // Décaissements (sorties de caisse)
      OperationType.cashOut,
      OperationType.supplierPayment,
      OperationType.financingRepayment,
    },
  );
}

/// Filtre pour la vue COMPTABLE (toutes opérations économiques)
/// Vue "Revenus vs Charges" (indépendamment du paiement effectif)
factory JournalFilter.accountingOnly({DateTime? startDate, DateTime? endDate}) {
  return JournalFilter(
    startDate: startDate,
    endDate: endDate,
    selectedTypes: {
      // Revenus (ventes = chiffre d'affaires)
      OperationType.saleCash,
      OperationType.saleCredit,
      OperationType.saleInstallment,
      // Charges (dépenses)
      OperationType.cashOut,
      OperationType.supplierPayment,
    },
  );
}
```

---

### 6. Panel de Filtres du Journal

#### `lib/features/dashboard/widgets/journal_filter_panel.dart`

**Ajout :** Nouveaux chips de filtres rapides

```dart
Wrap(
  spacing: WanzoTheme.spacingSm,
  children: [
    _buildQuickFilterChip('Toutes', JournalFilter.defaultFilter()),
    _buildQuickFilterChip('Ventes', JournalFilter.salesOnly()),
    _buildQuickFilterChip('Stock', JournalFilter.stockOnly()),
    _buildQuickFilterChip('Dépenses', JournalFilter.expensesOnly()),
    _buildQuickFilterChip('Dettes', JournalFilter.customerDebts()),
    // NOUVEAUX FILTRES
    _buildQuickFilterChip('💰 Trésorerie', JournalFilter.cashFlowOnly()),
    _buildQuickFilterChip('📊 Comptabilité', JournalFilter.accountingOnly()),
  ],
),
```

---

### 7. Liste des Ventes (Revenus)

#### `lib/features/sales/screens/sales_list_screen.dart`

**Changements :**

#### 7.1 Titre de l'écran
```dart
WanzoScaffold(
  currentIndex: 1,
  title: 'Revenus', // Était 'Ventes'
  // ...
)
```

#### 7.2 Colonne du tableau
```dart
DataColumn(
  label: Text('Encaissement'), // Était 'Payé'
  numeric: false, // Changé car on utilise maintenant des badges
),
```

#### 7.3 Badge de statut de paiement (Vue trésorerie)
```dart
/// Badge de statut de paiement pour la vue trésorerie
Widget _buildPaymentStatusBadge(
  BuildContext context,
  double paidAmount,
  double totalAmount,
  NumberFormat currencyFormat,
) {
  final theme = Theme.of(context);
  final percentage = totalAmount > 0 ? (paidAmount / totalAmount * 100) : 0;
  final isFullyPaid = paidAmount >= totalAmount;
  final isPartiallyPaid = paidAmount > 0 && paidAmount < totalAmount;
  final isNotPaid = paidAmount <= 0;

  Color statusColor;
  String statusText;
  IconData statusIcon;

  if (isFullyPaid) {
    statusColor = Colors.green;
    statusText = 'Encaissé';
    statusIcon = Icons.check_circle;
  } else if (isPartiallyPaid) {
    statusColor = Colors.blue;
    statusText = '${percentage.toStringAsFixed(0)}%';
    statusIcon = Icons.pie_chart;
  } else {
    statusColor = Colors.orange;
    statusText = 'Non encaissé';
    statusIcon = Icons.schedule;
  }

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, size: 12, color: statusColor),
            const SizedBox(width: 4),
            Text(
              statusText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      if (isPartiallyPaid || isNotPaid) ...[
        const SizedBox(width: 8),
        Text(
          currencyFormat.format(paidAmount),
          style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
        ),
      ],
    ],
  );
}
```

---

### 8. Liste des Dépenses (Charges)

#### `lib/features/expenses/screens/expenses_list_screen.dart`

**Changements :**

#### 8.1 Titre de l'écran
```dart
WanzoScaffold(
  currentIndex: 2,
  title: 'Charges', // Était 'Dépenses'
  // ...
)
```

#### 8.2 Colonne du tableau
```dart
DataColumn(
  label: Text('Décaissement'), // Était 'Paiement'
  // ...
),
```

#### 8.3 Fonction helper renommée
```dart
/// Helper pour obtenir la couleur du statut de paiement
/// Vue trésorerie: distinguer ce qui a impacté la caisse (décaissement effectif)
Color getDecaissementStatusColor(ExpensePaymentStatus? status) {
  switch (status) {
    case ExpensePaymentStatus.paid:
      return Colors.green; // ✅ Décaissé (sortie de caisse effective)
    case ExpensePaymentStatus.partial:
      return Colors.blue; // 🔵 Partiellement décaissé
    case ExpensePaymentStatus.unpaid:
      return Colors.orange; // ⚠️ Charge comptable, pas encore décaissé
    case ExpensePaymentStatus.credit:
      return Colors.purple; // 💳 À crédit (dette fournisseur)
    default:
      return Colors.grey;
  }
}
```

---

### 9. Cards KPI du Dashboard

#### `lib/features/dashboard/screens/dashboard_screen.dart`

**Changements :**

#### 9.1 Terminologie des cards

| Avant | Après | Sous-titre ajouté |
|-------|-------|-------------------|
| `Ventes (USD)` | `Revenus (USD)` | "Chiffre d'affaires" |
| `Ventes (CDF)` | `Revenus (CDF)` | "Chiffre d'affaires" |
| `Dépenses (USD)` | `Charges (USD)` | "Dépenses engagées" |
| `Dépenses (CDF)` | `Charges (CDF)` | "Dépenses engagées" |

#### 9.2 Nouvelle card "À encaisser" (Vue trésorerie)
```dart
_buildResponsiveStatCard(
  context,
  title: 'À encaisser', // Vue trésorerie
  value: formatCurrency(kpiData.receivables, 'CDF'),
  icon: Icons.schedule_send,
  color: Colors.purple,
  l10n: l10n,
  subtitle: 'Créances clients',
  isCompact: availableWidth < mobileBreakpoint,
),
```

#### 9.3 Icônes modifiées

| Contexte | Avant | Après |
|----------|-------|-------|
| Revenus | `Icons.monetization_on` | `Icons.trending_up` |
| Charges | `Icons.money_off` | `Icons.trending_down` |
| À encaisser | (nouveau) | `Icons.schedule_send` |

#### 9.4 Layout desktop
```dart
// Avant: 5 colonnes
crossAxisCount = 5;

// Après: 6 colonnes (pour la nouvelle card "À encaisser")
crossAxisCount = 6;
```

---

## 🎨 Palette de Couleurs

### Vue Comptable (Économique)
| Élément | Couleur | Code |
|---------|---------|------|
| Revenus | 🟢 Vert | `WanzoTheme.success` ou `Colors.green` |
| Charges | 🔴 Rouge | `WanzoTheme.danger` ou `Colors.red` |

### Vue Trésorerie (Cash-flow)
| Élément | Couleur | Code |
|---------|---------|------|
| Encaissements | 🔵 Bleu | `Colors.blue` |
| Décaissements | 🟠 Orange | `Colors.orange` |

### Statuts de Paiement
| Statut | Couleur | Code |
|--------|---------|------|
| Payé/Encaissé | 🟢 Vert | `Colors.green` |
| Partiel | 🔵 Bleu | `Colors.blue` |
| Non payé/En attente | 🟠 Orange | `Colors.orange` |
| À crédit | 🟣 Violet | `Colors.purple` |

---

## 📋 Checklist pour la Version Mobile

- [ ] Ajouter les traductions dans `app_fr.arb` et `app_en.arb`
- [ ] Modifier les labels du menu/navigation (Revenus, Charges)
- [ ] Créer l'enum `ChartViewMode` avec son extension
- [ ] Ajouter le sélecteur de vue dans le widget graphique
- [ ] Implémenter les méthodes `_aggregateCashInByPeriod` et `_aggregateCashOutByPeriod`
- [ ] Utiliser des couleurs dynamiques dans les graphiques
- [ ] Ajouter les factory methods `cashFlowOnly()` et `accountingOnly()` au filtre journal
- [ ] Ajouter les chips de filtres "Trésorerie" et "Comptabilité"
- [ ] Modifier le titre de l'écran ventes → "Revenus"
- [ ] Modifier le titre de l'écran dépenses → "Charges"
- [ ] Ajouter les badges de statut de paiement avec icônes
- [ ] Renommer les colonnes "Payé" → "Encaissement" et "Paiement" → "Décaissement"
- [ ] Mettre à jour les cards KPI avec la nouvelle terminologie
- [ ] Ajouter la card "À encaisser" (créances)
- [ ] Changer les icônes des KPI (trending_up, trending_down)

---

## 🔑 Points Clés à Retenir

1. **Aucun changement de modèle de données** : Tout est UI/cosmétique
2. **Double vocabulaire** : Comptabilité (Revenus/Charges) vs Trésorerie (Encaissements/Décaissements)
3. **Double palette** : Vert/Rouge pour comptabilité, Bleu/Orange pour trésorerie
4. **Logique de filtrage** : 
   - Comptabilité = toutes les opérations
   - Trésorerie = seulement où `paidAmount > 0` ou `paymentStatus == paid/partial`
5. **Cohérence OHADA** : La terminologie respecte le plan comptable SYSCOHADA

