# Cycle de Vie du Contrat de Crédit

Ce document décrit les différentes étapes du cycle de vie d'un contrat de crédit, de la demande initiale jusqu'à la clôture, ainsi que les transitions d'état possibles et les actions à effectuer à chaque étape.

## 1. Vue d'Ensemble du Cycle de Vie

Le cycle de vie complet d'un contrat de crédit comprend les phases suivantes :

1. **Soumission de la demande de crédit**
2. **Évaluation et approbation de la demande**
3. **Création du contrat**
4. **Activation du contrat**
5. **Déboursement des fonds**
6. **Suivi des remboursements**
7. **Gestion des incidents (optionnel)**
8. **Clôture du contrat**

## 2. Étapes Détaillées

### 2.1. Soumission de la Demande de Crédit

**État initial de la demande :** `pending`

**Actions requises :**
- L'application cliente doit soumettre une demande de crédit complète via l'API
- Toutes les informations obligatoires doivent être fournies
- Les documents justificatifs peuvent être joints à la demande

**Prochaine étape :** La demande passe à l'état `under_review` lorsqu'un agent commence son traitement

### 2.2. Évaluation et Approbation de la Demande

**États possibles :** `under_review` → `approved` ou `rejected`

**Actions requises :**
- L'évaluation est effectuée par les agents de crédit
- Des informations complémentaires peuvent être demandées au client
- Une décision d'approbation ou de rejet est prise

**Prochaine étape :** 
- Si approuvée, la demande passe à l'état `approved` et un contrat peut être créé
- Si rejetée, la demande passe à l'état `rejected` et le cycle s'arrête

### 2.3. Création du Contrat

**État initial du contrat :** `draft`

**Actions requises :**
- Un contrat est créé à partir de la demande approuvée
- Les conditions du prêt sont définies (taux d'intérêt, durée, fréquence de remboursement, etc.)
- Un échéancier de remboursement est généré automatiquement

**Prochaine étape :** Le contrat reste en état `draft` jusqu'à son activation

### 2.4. Activation du Contrat

**Transition d'état :** `draft` → `active`

**Actions requises :**
- Vérification que toutes les conditions préalables sont remplies
- Signature du contrat par toutes les parties
- Validation des garanties fournies

**Prochaine étape :** Une fois activé, le contrat est prêt pour le déboursement

### 2.5. Déboursement des Fonds

**État du contrat :** reste `active`

**Actions requises :**
- Enregistrement du déboursement dans le système
- Mise à jour du solde restant dû du contrat
- La demande de crédit passe à l'état `disbursed`

**Prochaine étape :** Suivi des remboursements selon l'échéancier

### 2.6. Suivi des Remboursements

**État du contrat :** reste `active` tant que les remboursements sont effectués normalement

**Actions requises :**
- Enregistrement des paiements reçus
- Allocation des paiements aux échéances correspondantes
- Mise à jour du statut des échéances
- Mise à jour du solde restant dû du contrat

**Situations particulières :**
- **Paiement anticipé :** Le client peut effectuer un paiement anticipé, qui sera alloué aux prochaines échéances
- **Paiement partiel :** Le paiement ne couvre pas entièrement l'échéance, qui passe à l'état `partially_paid`
- **Retard de paiement :** Si l'échéance n'est pas payée à la date due, elle passe à l'état `late`

### 2.7. Gestion des Incidents (optionnel)

**Transitions d'état possibles :**
- `active` → `suspended` (suspension temporaire)
- `active` → `defaulted` (défaut de paiement)
- `active` → `litigation` (contentieux)
- `active` → `restructured` (restructuration)

#### 2.7.1. Suspension du Contrat

**Actions requises :**
- Enregistrement de la raison de la suspension
- Enregistrement de la date de suspension
- Notification au client

**Transitions possibles :**
- `suspended` → `active` (reprise normale)
- `suspended` → `defaulted` (défaut confirmé)
- `suspended` → `restructured` (restructuration du prêt)
- `suspended` → `litigation` (passage en contentieux)

#### 2.7.2. Défaut de Paiement

**Actions requises :**
- Enregistrement de la date de défaut
- Mise à jour des échéances impayées à l'état `defaulted`
- Notification au client et aux parties concernées

**Transitions possibles :**
- `defaulted` → `active` (régularisation de la situation)
- `defaulted` → `restructured` (restructuration du prêt)
- `defaulted` → `litigation` (passage en contentieux)
- `defaulted` → `completed` (remboursement complet ou arrangement final)

#### 2.7.3. Restructuration du Contrat

**Actions requises :**
- Enregistrement des nouvelles conditions du prêt
- Génération d'un nouvel échéancier
- Notification au client

**Transitions possibles :**
- `restructured` → `active` (suivi normal du nouveau plan)
- `restructured` → `defaulted` (nouveau défaut)
- `restructured` → `litigation` (passage en contentieux)
- `restructured` → `completed` (remboursement complet)

#### 2.7.4. Contentieux

**Actions requises :**
- Enregistrement de la raison du contentieux
- Enregistrement de la date de passage en contentieux
- Notification aux parties concernées

**Transitions possibles :**
- `litigation` → `active` (résolution et reprise normale)
- `litigation` → `defaulted` (défaut confirmé)
- `litigation` → `completed` (résolution finale)

### 2.8. Clôture du Contrat

**Transitions finales :**
- `active` → `completed` (remboursement complet)
- `draft` → `canceled` (annulation avant activation)
- `active` → `canceled` (annulation exceptionnelle)

**Actions requises pour un contrat complété :**
- Vérification que toutes les échéances sont payées
- Calcul des intérêts finaux si nécessaire
- Enregistrement de la date de clôture
- Libération des garanties
- Notification au client

## 3. Diagramme des Transitions d'État

```
┌───────────┐          ┌────────────┐         ┌────────────┐
│           │          │            │         │            │
│  pending  ├─────────►│under_review├────────►│  approved  │
│           │          │            │         │            │
└───────────┘          └────────────┘         └──────┬─────┘
                             │                       │
                             ▼                       ▼
                       ┌──────────┐           ┌───────────┐         ┌─────────┐
                       │          │           │           │         │         │
                       │ rejected │           │ disbursed │◄────────┤  draft  │
                       │          │           │           │         │         │
                       └──────────┘           └───────────┘         └────┬────┘
                                                                         │
                                                                         ▼
┌───────────┐         ┌────────────┐         ┌────────────┐         ┌─────────┐
│           │         │            │         │            │         │         │
│ completed │◄────────┤  defaulted │◄────────┤  suspended │◄────────┤  active │
│           │         │            │         │            │         │         │
└───────────┘         └────────────┘         └────────────┘         └────┬────┘
     ▲                      ▲                      ▲                     │
     │                      │                      │                     │
     │                      │                      │                     ▼
     │                ┌────────────┐         ┌────────────┐         ┌─────────┐
     │                │            │         │            │         │         │
     └────────────────┤ litigation │◄────────┤restructured│◄────────┤ canceled │
                      │            │         │            │         │         │
                      └────────────┘         └────────────┘         └─────────┘
```

## 4. Événements et Notifications

À chaque changement d'état dans le cycle de vie du contrat, le système génère des événements qui peuvent être utilisés pour déclencher des notifications ou d'autres actions automatisées :

### 4.1. Événements de la Demande de Crédit

- `funding_request.created` - Nouvelle demande créée
- `funding_request.under_review` - Demande mise en examen
- `funding_request.approved` - Demande approuvée
- `funding_request.rejected` - Demande rejetée
- `funding_request.canceled` - Demande annulée
- `funding_request.disbursed` - Contrat créé et fonds déboursés

### 4.2. Événements du Contrat

- `contract.created` - Nouveau contrat créé
- `contract.activated` - Contrat activé
- `contract.suspended` - Contrat suspendu
- `contract.restructured` - Contrat restructuré
- `contract.defaulted` - Contrat en défaut
- `contract.litigation` - Contrat en contentieux
- `contract.completed` - Contrat terminé
- `contract.canceled` - Contrat annulé

### 4.3. Événements de Paiement

- `payment_schedule.created` - Échéancier créé
- `payment.received` - Paiement reçu
- `payment_schedule.late` - Échéance en retard
- `payment_schedule.defaulted` - Échéance en défaut

## 5. Intégration avec l'Application Cliente

Pour gérer correctement le cycle de vie du contrat, l'application cliente doit :

1. **Suivre les changements d'état** - Interroger régulièrement l'API pour connaître l'état actuel des demandes et contrats
2. **Réagir aux événements** - S'abonner aux événements via Kafka ou webhooks si disponible
3. **Présenter les informations pertinentes** - Afficher l'état actuel et les actions possibles en fonction de l'état
4. **Faciliter les actions requises** - Permettre au client d'effectuer les actions requises (ex: soumettre des documents, effectuer des paiements)

## 6. Bonnes Pratiques

- **Validation avant soumission** - Vérifier que toutes les données sont valides avant de soumettre une demande
- **Gestion des documents** - Gérer efficacement les documents justificatifs (compression, format approprié)
- **Suivi proactif** - Alerter le client avant les échéances pour éviter les retards
- **Communication claire** - Informer le client à chaque changement d'état important
- **Journalisation** - Conserver un historique détaillé de toutes les actions et changements d'état
