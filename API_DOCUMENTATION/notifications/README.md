# API Notifications

Cette documentation détaille les endpoints disponibles pour la gestion des notifications dans l'application Wanzo Gestion Commerciale.

> **✅ Conformité**: Aligné avec `notifications.controller.ts` et `notification.entity.ts`

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

## Structure du modèle Notification

```json
{
  "id": "notification-uuid",
  "title": "Stock bas",
  "message": "Le produit 'Riz Thaï 25kg' est en stock bas (5 unités restantes)",
  "type": "lowStock",
  "timestamp": "2025-01-04T10:30:00.000Z",
  "isRead": false,
  "actionRoute": "/inventory/products/product-uuid",
  "additionalData": {
    "productId": "product-uuid",
    "productName": "Riz Thaï 25kg",
    "currentStock": 5,
    "minStock": 10
  }
}
```

## Types de Notifications

| Type | Valeur API | Description | Icône suggérée |
|------|------------|-------------|----------------|
| Information | `info` | Information générale | ℹ️ |
| Succès | `success` | Confirmation de succès | ✅ |
| Avertissement | `warning` | Avertissement | ⚠️ |
| Erreur | `error` | Erreur ou problème | ❌ |
| Stock bas | `lowStock` | Alerte de stock bas | 📦 |
| Vente | `sale` | Notification de vente | 💰 |
| Paiement | `payment` | Notification de paiement | 💳 |

---

## Endpoints

### 1. Récupérer les notifications

**Endpoint**: `GET /notifications`

**Description**: Récupère la liste des notifications pour l'utilisateur authentifié.

**Paramètres de requête**:
| Paramètre | Type | Description |
|-----------|------|-------------|
| `page` | number | Numéro de page (défaut: 1) |
| `limit` | number | Nombre par page (défaut: 20) |
| `status` | string | Filtrer par statut: `read`, `unread` |
| `type` | string | Filtrer par type de notification |
| `sortBy` | string | Champ de tri (ex: `timestamp`) |
| `sortOrder` | string | Ordre de tri: `ASC`, `DESC` |

**Exemple de requête**:
```
GET /notifications?page=1&limit=10&status=unread&sortOrder=DESC
```

**Réponse réussie (200)**:
```json
{
  "data": [
    {
      "id": "notif-uuid-1",
      "title": "Stock bas",
      "message": "Le produit 'Riz Thaï 25kg' est en stock bas",
      "type": "lowStock",
      "timestamp": "2025-01-04T10:30:00.000Z",
      "isRead": false,
      "actionRoute": "/inventory/products/product-uuid"
    },
    {
      "id": "notif-uuid-2",
      "title": "Nouvelle vente",
      "message": "Vente #INV-2025-001 de 150,000 CDF",
      "type": "sale",
      "timestamp": "2025-01-04T09:15:00.000Z",
      "isRead": false,
      "actionRoute": "/sales/sale-uuid"
    }
  ],
  "total": 25,
  "page": 1,
  "limit": 10
}
```

---

### 2. Récupérer le nombre de notifications non lues

**Endpoint**: `GET /notifications/unread-count`

**Description**: Récupère le nombre de notifications non lues pour l'utilisateur authentifié. Utile pour afficher un badge dans l'interface.

**Réponse réussie (200)**:
```json
{
  "count": 5
}
```

---

### 3. Marquer une notification comme lue

**Endpoint**: `POST /notifications/{notificationId}/mark-read`

**Description**: Marque une notification spécifique comme lue.

**Paramètres de chemin**:
- `notificationId`: ID de la notification

**Réponse réussie (200)**:
```json
{
  "success": true,
  "data": {
    "id": "notif-uuid-1",
    "title": "Stock bas",
    "message": "Le produit 'Riz Thaï 25kg' est en stock bas",
    "type": "lowStock",
    "isRead": true,
    "timestamp": "2025-01-04T10:30:00.000Z"
  },
  "message": "Notification marked as read",
  "statusCode": 200
}
```

**Erreur (404)**:
```json
{
  "success": false,
  "message": "Notification not found",
  "statusCode": 404
}
```

---

### 4. Marquer toutes les notifications comme lues

**Endpoint**: `POST /notifications/mark-all-read`

**Description**: Marque toutes les notifications de l'utilisateur comme lues.

**Réponse réussie (200)**:
```json
{
  "success": true,
  "data": null,
  "message": "All notifications marked as read",
  "statusCode": 200
}
```

---

### 5. Supprimer une notification

**Endpoint**: `DELETE /notifications/{notificationId}`

**Description**: Supprime une notification spécifique.

**Paramètres de chemin**:
- `notificationId`: ID de la notification

**Réponse réussie (200)**:
```json
{
  "success": true,
  "data": null,
  "message": "Notification deleted successfully",
  "statusCode": 200
}
```

**Erreur (404)**:
```json
{
  "success": false,
  "message": "Notification not found",
  "statusCode": 404
}
```

---

## Notifications Automatiques

Le système génère automatiquement des notifications dans les cas suivants :

### Alertes de Stock Bas

Déclenchée quand le stock d'un produit passe sous le seuil minimum :

```json
{
  "type": "lowStock",
  "title": "Stock bas",
  "message": "Le produit 'Riz Thaï 25kg' est en stock bas (5 unités restantes)",
  "additionalData": {
    "productId": "product-uuid",
    "productName": "Riz Thaï 25kg",
    "currentStock": 5,
    "minStock": 10
  }
}
```

### Notifications de Vente

Déclenchée après la création d'une vente :

```json
{
  "type": "sale",
  "title": "Nouvelle vente",
  "message": "Vente #INV-2025-001 de 150,000 CDF enregistrée pour Jean Dupont",
  "additionalData": {
    "saleId": "sale-uuid",
    "invoiceNumber": "INV-2025-001",
    "amount": 150000,
    "customerName": "Jean Dupont"
  }
}
```

### Notifications de Paiement

Déclenchée lors de la réception d'un paiement :

```json
{
  "type": "payment",
  "title": "Paiement reçu",
  "message": "Paiement de 100,000 CDF reçu pour la facture #INV-2025-001",
  "additionalData": {
    "paymentId": "payment-uuid",
    "invoiceNumber": "INV-2025-001",
    "amount": 100000,
    "paymentMethod": "mobileMoney"
  }
}
```

---

## Résumé des Endpoints

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/notifications` | GET | Liste des notifications |
| `/notifications/unread-count` | GET | Nombre de notifications non lues |
| `/notifications/{id}/mark-read` | POST | Marquer comme lue |
| `/notifications/mark-all-read` | POST | Marquer toutes comme lues |
| `/notifications/{id}` | DELETE | Supprimer une notification |

---

## Notes Techniques

### Filtrage par Business Unit

Les notifications sont automatiquement filtrées par le `businessUnitId` de l'utilisateur. Un utilisateur ne voit que les notifications liées à son unité d'affaires.

### Persistance

Les notifications sont stockées dans la base de données PostgreSQL et persistent jusqu'à suppression explicite par l'utilisateur.

### Tri par Défaut

Par défaut, les notifications sont triées par `timestamp` décroissant (les plus récentes en premier).

### Action Routes

Le champ `actionRoute` contient un chemin relatif permettant à l'application frontend de naviguer vers la ressource concernée par la notification.

### Données Additionnelles

Le champ `additionalData` (JSON) permet de stocker des informations contextuelles spécifiques à chaque type de notification, facilitant l'affichage détaillé dans l'interface.
