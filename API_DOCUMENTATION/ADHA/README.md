# Documentation du Module ADHA - Gestion Commerciale

> **Synchronisée avec le code source TypeScript** - 22 Janvier 2026  
> **Version**: 2.6.0 (Streaming WebSocket + Client-Generated ConversationId)

---

## ⚠️ Note Importante: companyId

> **Le `companyId` n'est PAS extrait du JWT côté backend.**  
> Il DOIT être envoyé explicitement dans le body de chaque requête `/message` et `/stream`.  
> Sans ce champ, ADHA AI ne pourra pas accéder aux données de l'entreprise.

---

## 🆕 Nouveautés v2.6.0 (22 Janvier 2026) - CHANGEMENT CRITIQUE BACKEND

### conversationId généré côté Client

> **⚠️ CHANGEMENT BACKEND REQUIS**  
> Le frontend génère désormais le `conversationId` (UUID v4) et l'envoie au backend.  
> Le backend DOIT utiliser cet ID au lieu d'en générer un nouveau.

| Aspect | Ancien comportement | Nouveau comportement (v2.6.0) |
|--------|---------------------|-------------------------------|
| **Génération ID** | Backend génère l'UUID | **Frontend** génère l'UUID |
| **Streaming 1er message** | ❌ Impossible (race condition) | ✅ Fonctionne |
| **Souscription WebSocket** | Après réponse HTTP | **Avant** envoi HTTP |
| **Champ conversationId** | Optionnel (null pour nouvelle) | **Requis** (UUID v4 du client) |

### Pourquoi ce changement ?

Le streaming temps réel ne fonctionnait PAS pour le premier message car :
1. Client envoie `POST /stream` avec `conversationId: null`
2. Backend génère un nouvel ID et envoie des chunks via WebSocket
3. Client reçoit la réponse HTTP avec l'ID et s'abonne **APRÈS**
4. → Tous les chunks sont perdus (envoyés à 0 clients)

**Solution**: Le client génère l'ID, s'abonne, PUIS envoie le message.

### Modification Backend Requise

```typescript
// AdhaService.sendMessageStreaming()
async sendMessageStreaming(dto: SendMessageDto, user: UserPayload) {
  let conversationId = dto.conversationId;
  
  if (!conversationId) {
    // ANCIEN: conversationId = uuidv4();
    // NOUVEAU: Erreur si pas d'ID fourni
    throw new BadRequestException('conversationId is required');
  }
  
  // Vérifier si la conversation existe déjà
  let conversation = await this.conversationsRepository.findOne({
    where: { id: conversationId }
  });
  
  if (!conversation) {
    // Créer avec l'ID fourni par le client
    conversation = this.conversationsRepository.create({
      id: conversationId,  // Utiliser l'ID du client!
      userId: user.userId,
      companyId: dto.companyId,
      title: this.generateTitle(dto.text),
    });
    await this.conversationsRepository.save(conversation);
  }
  
  // ... reste du code
}
```

---

## 🆕 Nouveautés v2.5.1

| Fonctionnalité | Description |
|----------------|-------------|
| **companyId explicite** | Le `companyId` doit être envoyé dans le body (non extrait du JWT) |
| **userId optionnel** | Le `userId` peut être envoyé pour une meilleure traçabilité |
| **Mode synchrone recommandé** | ~~Pour les nouvelles conversations, utiliser `/message` au lieu de `/stream`~~ (obsolète avec v2.6.0) |

## 🆕 Nouveautés v2.5.0

| Fonctionnalité | Description |
|----------------|-------------|
| **Persistance DB** | Les réponses AI du streaming sont automatiquement sauvegardées en base (conformité accounting) |
| **Endpoint `/stream`** | Nouvel endpoint `POST /adha/stream` pour streaming WebSocket |
| **Écritures comptables** | Les opérations commerciales sont transformées en écritures SYSCOHADA via ADHA AI |
| **Circuit Breaker** | Protection contre les pannes en cascade avec seuil configurable |
| **Heartbeat** | Signal périodique (30s) pour maintenir les connexions WebSocket actives |
| **Stream Cancellation** | Annulation propre des streams en cours avec événement `cancelled` |
| **7 types d'événements** | `chunk`, `end`, `error`, `tool_call`, `tool_result`, `cancelled`, `heartbeat` |
| **suggestedActions structuré** | Format `{type, label?, payload}` pour actions interactives |

### Configuration Environnement

| Variable | Défaut | Description |
|----------|--------|-------------|
| `AI_TIMEOUT` | 120000 | Timeout appel IA (ms) |
| `STREAMING_TIMEOUT` | 180000 | Timeout streaming total (ms) |
| `DEFAULT_TIMEOUT` | 30000 | Timeout par défaut (ms) |
| `CIRCUIT_BREAKER_THRESHOLD` | 5 | Nombre d'échecs avant ouverture circuit |
| `CIRCUIT_BREAKER_TIMEOUT` | 60000 | Délai avant retry (ms) |
| `STREAM_HEARTBEAT_INTERVAL_S` | 30 | Intervalle heartbeat (secondes) |

---

## Aperçu

**ADHA** (Assistant Digital pour Heure d'Affaires) est un assistant virtuel intégré à l'application Wanzo. Il utilise l'intelligence artificielle pour fournir des analyses, des insights et une assistance contextuelle concernant les activités commerciales des utilisateurs.

### Capacités principales

- **Analyse de données commerciales** - Analyse des ventes, inventaire et flux financiers
- **Interaction conversationnelle** - Questions en langage naturel
- **Support multi-modal** - Interactions texte et voix
- **Streaming temps réel** - Réponses progressives via WebSocket/Kafka
- **Transformation en écritures comptables** - Les opérations commerciales sont automatiquement transformées en écritures SYSCOHADA

---

## Flux des Écritures Comptables

### Comment gestion_commerciale contribue aux écritures comptables

Les opérations commerciales créées dans `gestion_commerciale_service` sont automatiquement transformées en écritures comptables via ADHA AI :

```
┌─────────────────────────────────────┐
│    GESTION COMMERCIALE SERVICE      │
│                                     │
│  BusinessOperationsService.create() │
│           │                         │
│           ▼                         │
│  EventsService.publishBusinessOp    │
│           │ Topic: commerce.        │
│           │ operation.created       │
└───────────┼─────────────────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│           KAFKA                      │
│  Topic: commerce.operation.created   │
└───────────┼─────────────────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│       ADHA AI SERVICE (Python)       │
│                                     │
│  consumer_commerce.py               │
│           │                         │
│           ▼                         │
│  accounting_processor.py            │
│  - Valide l'opération               │
│  - Utilise AccountingKnowledgeRDC   │
│  - Génère écriture SYSCOHADA        │
│           │                         │
│           ▼                         │
│  producer_accounting.py             │
│  - Publie sur accounting.journal.   │
│    entry                            │
└───────────┼─────────────────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│     ACCOUNTING SERVICE              │
│                                     │
│  Reçoit et crée l'écriture compta   │
│  dans la base de données            │
└─────────────────────────────────────┘
```

### Types d'opérations supportées

| Type d'opération | Compte débit | Compte crédit | Journal |
|-----------------|--------------|---------------|---------|
| `SALE` | 411 (Clients) | 701 (Ventes) | Ventes |
| `PURCHASE` | 601 (Achats) | 401 (Fournisseurs) | Achats |
| `EXPENSE` | 6xx (Charges) | 521/571 (Banque/Caisse) | Général |
| `INCOME` | 521/571 | 7xx (Produits) | Général |
| `PAYMENT` | 401/421 | 521/571 | Trésorerie |
| `RECEIPT` | 521/571 | 411 | Trésorerie |

### Données transmises à l'écriture comptable

```json
{
  "id": "uuid-generated",
  "sourceId": "operation-uuid",
  "sourceType": "commerce_operation",
  "clientId": "company-id",
  "companyId": "company-id",
  "businessUnitId": "unit-id",
  "businessUnitType": "BOUTIQUE",
  "businessUnitCode": "BOU001",
  "date": "2026-01-20",
  "description": "Vente de marchandises",
  "amount": 50000,
  "currency": "CDF",
  "journalType": "sales",
  "totalDebit": 50000,
  "totalCredit": 50000,
  "lines": [
    { "accountCode": "411", "debit": 50000, "credit": 0 },
    { "accountCode": "701", "debit": 0, "credit": 50000 }
  ]
}
```

---

## Persistance des Messages

### Conformité avec accounting-service

Le `StreamingConsumer` sauvegarde automatiquement les réponses AI en base de données à la fin du streaming, conformément au comportement d'`accounting-service` :

1. **Message utilisateur** : Sauvegardé immédiatement dans `AdhaService.sendMessageStreaming()`
2. **Chunks de streaming** : Envoyés en temps réel via WebSocket (non persistés)
3. **Réponse AI complète** : Sauvegardée dans `StreamingConsumer.handleStreamEnd()`

```typescript
// StreamingConsumer.handleStreamEnd()
const aiMessage = messagesRepository.create({
  conversationId: conversationId,
  text: chunk.content,          // Réponse complète de l'IA
  sender: AdhaMessageSender.AI,
  timestamp: new Date(),
  contextInfo: {
    streaming: true,
    totalChunks,
    processingTime,
    journalEntry: chunk.journalEntry,       // Écriture comptable si proposée
    suggestedActions: chunk.suggestedActions,
    processingDetails: chunk.processingDetails,
  },
});
await messagesRepository.save(aiMessage);
```

### CRUD des Conversations et Messages

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/adha/message` | POST | Envoyer un message (mode synchrone) |
| `/adha/stream` | POST | Envoyer un message (mode streaming) |
| `/adha/conversations` | GET | Lister les conversations de l'utilisateur |
| `/adha/conversations/:id/messages` | GET | Historique des messages d'une conversation |

---

## Architecture

```
┌────────────────────────────────────────────────────────────────────────────┐
│                           FLUTTER MOBILE APP                                │
│  ┌─────────────────┐    ┌──────────────────────────────────────────────┐   │
│  │   REST Client   │    │  Socket.IO Client (socket_io_client)          │   │
│  │  (API calls)    │    │  Events: subscribe_conversation,             │   │
│  │                 │    │          adha.stream.chunk/end/error/tool    │   │
│  └───────┬─────────┘    └────────────────────┬─────────────────────────┘   │
└──────────┼───────────────────────────────────┼─────────────────────────────┘
           │ HTTP                               │ WebSocket
           ▼                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          API GATEWAY (:8000)                                │
│  ┌─────────────────────┐    ┌───────────────────────────────────────────┐   │
│  │ REST Proxy          │    │ WebSocket Proxy                           │   │
│  │ /api/v1/commerce/*  │    │ /commerce/chat → :3006/socket.io          │   │
│  └───────┬─────────────┘    └────────────────┬──────────────────────────┘   │
└──────────┼───────────────────────────────────┼──────────────────────────────┘
           │                                    │
           ▼                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                   GESTION COMMERCIALE SERVICE (:3006)                       │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────────┐  │
│  │ AdhaController  │    │   ChatGateway   │    │  StreamingConsumer      │  │
│  │ /adha/message   │───▶│  (Socket.IO)    │◀───│  (Kafka Consumer)       │  │
│  │ /adha/convo/*   │    │                 │    │  topic: adha.chat.stream│  │
│  └────────┬────────┘    └─────────────────┘    └───────────▲─────────────┘  │
│           │                                                 │                │
│           ▼                                                 │                │
│  ┌─────────────────┐                                       │                │
│  │  KafkaProducer  │                                       │                │
│  │  ─────────────  │                                       │                │
│  │  topic: adha.*  │──────────────┐                        │                │
│  └─────────────────┘              │                        │                │
└───────────────────────────────────┼────────────────────────┼────────────────┘
                                    │                        │
                          ┌─────────▼────────────────────────┴─────────┐
                          │                 KAFKA                       │
                          │  Topics:                                    │
                          │  • adha.chat.message.sent (→ ADHA AI)      │
                          │  • adha.chat.stream (← ADHA AI)            │
                          │  • adha.chat.response.ready                │
                          └────────────────────┬───────────────────────┘
                                               │
                                               ▼
                          ┌────────────────────────────────────────────┐
                          │           ADHA AI SERVICE (Python)         │
                          │  • LLM Processing                          │
                          │  • Streaming Chunks Generation             │
                          │  • Tool Calling (analytics, etc.)          │
                          └────────────────────────────────────────────┘
```

---

## Modèles de Données (Backend DTOs)

### SendMessageDto

DTO pour l'envoi d'un message à ADHA.

> **⚠️ Important**: Le `companyId` n'est PAS extrait du JWT côté backend. Il DOIT être envoyé explicitement dans le body de la requête pour que ADHA AI puisse accéder aux données de l'entreprise.

```typescript
class SendMessageDto {
  text: string;                    // Texte du message (requis)
  conversationId?: string;         // UUID (optionnel pour nouvelle conversation)
  timestamp: string;               // ISO8601 datetime (requis)
  contextInfo: AdhaContextInfoDto; // Contexte (requis)
  companyId: string;               // UUID de l'entreprise (requis pour accès données)
  userId?: string;                 // UUID de l'utilisateur (optionnel, pour traçabilité)
}
```

### AdhaContextInfoDto

```typescript
class AdhaContextInfoDto {
  baseContext: BaseContextDto;               // Contexte de base (requis)
  interactionContext: InteractionContextDto; // Contexte d'interaction (requis)
}
```

### BaseContextDto

```typescript
class BaseContextDto {
  operationJournalSummary: OperationJournalSummaryDto;  // Journal des opérations
  businessProfile: BusinessProfileDto;                  // Profil entreprise
}
```

### InteractionContextDto

```typescript
class InteractionContextDto {
  interactionType: InteractionType;         // Type d'interaction (requis)
  sourceIdentifier?: string;                // Identifiant source (optionnel)
  interactionData?: Record<string, any>;    // Données additionnelles (optionnel)
}
```

### InteractionType (Enum)

> **⚠️ Important**: Seuls ces deux types sont supportés par le backend.

```typescript
enum InteractionType {
  GENERIC_CARD_ANALYSIS = 'generic_card_analysis',  // Analyse générique
  FOLLOW_UP = 'follow_up',                          // Suivi de conversation
}
```

### AdhaMessage (Entity)

```typescript
class AdhaMessage {
  id: string;              // UUID
  conversationId: string;  // UUID
  text: string;            // Contenu du message
  sender: 'user' | 'ai';   // Expéditeur
  timestamp: Date;         // Horodatage
  contextInfo?: any;       // Contexte (nullable)
}
```

### AdhaConversation (Entity)

```typescript
class AdhaConversation {
  id: string;                    // UUID
  userId: string;                // UUID de l'utilisateur
  title?: string;                // Titre (nullable)
  messages: AdhaMessage[];       // Liste des messages
  lastMessageTimestamp?: Date;   // Dernier message
  createdAt: Date;
  updatedAt: Date;
}
```

---

## API Endpoints

### 1. Envoyer un message

**Endpoint**: `POST /api/v1/commerce/adha/message`

**Headers**:
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Corps de la requête**:

> **⚠️ Important**: `companyId` est REQUIS car il n'est pas extrait du JWT.

```json
{
  "text": "Comment mes ventes ont-elles évolué ce mois-ci ?",
  "conversationId": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
  "timestamp": "2025-08-01T12:00:00.000Z",
  "companyId": "d0a01bbb-6b28-402c-8ba0-b324bfd85526",
  "userId": "user-uuid-456",
  "contextInfo": {
    "baseContext": {
      "operationJournalSummary": {
        "recentEntries": [
          {
            "timestamp": "2025-08-01T10:00:00.000Z",
            "description": "Vente #123 créée",
            "operationType": "CREATE_SALE",
            "details": { "amount": 2500, "customer": "John Doe" }
          }
        ]
      },
      "businessProfile": {
        "name": "Ma Boutique",
        "sector": "Alimentation",
        "address": "123 Avenue du Commerce, Kinshasa",
        "additionalInfo": { "employees": 5, "foundingYear": 2020 }
      }
    },
    "interactionContext": {
      "interactionType": "generic_card_analysis",
      "sourceIdentifier": "sales_summary_card",
      "interactionData": { "selectedPeriod": "last_month" }
    }
  }
}
```

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Reply successfully generated.",
  "statusCode": 200,
  "data": {
    "conversationId": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
    "messages": [
      {
        "id": "msg-uuid-123",
        "text": "Vos ventes ont augmenté de 15% par rapport au mois dernier.",
        "sender": "ai",
        "timestamp": "2025-08-01T12:00:05.000Z",
        "contextInfo": null
      }
    ]
  }
}
```

### 1b. Envoyer un message (Mode Streaming)

**Endpoint**: `POST /api/v1/commerce/adha/stream`

**Description**: Initie une conversation avec réponse en streaming via WebSocket. La réponse HTTP est immédiate et contient le `conversationId` et `requestMessageId`. Les chunks de la réponse arrivent via Socket.IO (événements `adha.stream.chunk`, `adha.stream.end`).

**Headers**:
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Corps de la requête**:

> **⚠️ Important**: `companyId` est REQUIS car il n'est pas extrait du JWT.

```json
{
  "text": "Quels sont mes 5 produits les plus vendus ?",
  "conversationId": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
  "timestamp": "2025-08-01T12:00:00.000Z",
  "companyId": "d0a01bbb-6b28-402c-8ba0-b324bfd85526",
  "userId": "user-uuid-456",
  "contextInfo": {
    "baseContext": {
      "operationJournalSummary": { "recentEntries": [] },
      "businessProfile": {
        "name": "Ma Boutique",
        "sector": "Alimentation",
        "address": "123 Avenue du Commerce, Kinshasa"
      }
    },
    "interactionContext": {
      "interactionType": "generic_card_analysis",
      "sourceIdentifier": "top_products_card"
    }
  }
}
```

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Streaming request initiated.",
  "statusCode": 200,
  "data": {
    "conversationId": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
    "requestMessageId": "msg-request-uuid-789"
  }
}
```

> **Note**: Après cette réponse, le client doit écouter les événements WebSocket `adha.stream.chunk` et `adha.stream.end` pour recevoir la réponse progressive de l'IA.

> **✅ Race Condition RÉSOLUE (v2.6.0)**: Le client génère désormais le `conversationId` (UUID v4) et s'abonne à la room WebSocket **AVANT** d'envoyer la requête HTTP. Le backend DOIT utiliser l'ID fourni par le client.

> **~~⚠️ OBSOLÈTE~~**: ~~Pour les NOUVELLES conversations (sans `conversationId`), le client ne peut pas s'abonner à la room WebSocket avant de recevoir le `conversationId` dans la réponse. Les chunks envoyés entre temps sont perdus.~~ → Résolu avec v2.6.0

### 2. Récupérer les conversations

**Endpoint**: `GET /api/v1/commerce/adha/conversations`

**Query params**:
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `page` | number | 1 | Numéro de page |
| `limit` | number | 10 | Éléments par page |
| `sortBy` | string | lastMessageTimestamp | Champ de tri |
| `sortOrder` | string | desc | Ordre (asc/desc) |

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Conversations fetched successfully.",
  "statusCode": 200,
  "data": [
    {
      "id": "conv-uuid-123",
      "userId": "user-uuid-456",
      "title": "Analyse des ventes mensuelles",
      "lastMessageTimestamp": "2025-08-01T12:00:05.000Z",
      "createdAt": "2025-08-01T10:30:00.000Z",
      "updatedAt": "2025-08-01T12:00:05.000Z"
    }
  ],
  "pagination": {
    "total": 25,
    "page": 1,
    "limit": 10,
    "totalPages": 3
  }
}
```

### 3. Récupérer l'historique d'une conversation

**Endpoint**: `GET /api/v1/commerce/adha/conversations/{conversationId}/messages`

**Query params**:
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `page` | number | 1 | Numéro de page |
| `limit` | number | 20 | Messages par page |

**Réponse réussie (200)**:
```json
{
  "success": true,
  "message": "Conversation history fetched.",
  "statusCode": 200,
  "data": [
    {
      "id": "msg-uuid-1",
      "conversationId": "conv-uuid-123",
      "text": "Comment mes ventes ont-elles évolué ce mois-ci ?",
      "sender": "user",
      "timestamp": "2025-08-01T12:00:00.000Z",
      "contextInfo": { "..." }
    },
    {
      "id": "msg-uuid-2",
      "conversationId": "conv-uuid-123",
      "text": "Vos ventes ont augmenté de 15% par rapport au mois dernier.",
      "sender": "ai",
      "timestamp": "2025-08-01T12:00:05.000Z",
      "contextInfo": null
    }
  ],
  "pagination": {
    "total": 10,
    "page": 1,
    "limit": 20,
    "totalPages": 1
  }
}
```

---

## Streaming WebSocket (Socket.IO)

### Connexion

**URLs**:
- **Production**: `wss://api.wanzo.io/commerce/chat`
- **Développement**: `ws://localhost:8000/commerce/chat`
- **Direct (dev)**: `ws://localhost:3006/socket.io`

**Protocole**: Socket.IO (avec fallback polling)

### Authentification

Le token JWT peut être fourni de 3 manières :

```dart
// Option 1: Socket.IO auth object (recommandé)
IO.io(url, {
  'auth': {'token': authToken},
});

// Option 2: Query parameter
IO.io('$url?token=$authToken');

// Option 3: Header (extraHeaders)
IO.io(url, {
  'extraHeaders': {'Authorization': 'Bearer $authToken'},
});
```

### Événements

#### Client → Serveur

| Événement | Payload | Description |
|-----------|---------|-------------|
| `subscribe_conversation` | `{ conversationId: string }` | S'abonner aux updates |
| `unsubscribe_conversation` | `{ conversationId: string }` | Se désabonner |

#### Serveur → Client

| Événement | Description | Type de chunk |
|-----------|-------------|---------------|
| `adha.stream.chunk` | Fragment de texte | `chunk` |
| `adha.stream.end` | Fin du streaming | `end` |
| `adha.stream.error` | Erreur pendant traitement | `error` |
| `adha.stream.tool` | Appel/résultat de fonction IA | `tool_call` / `tool_result` |
| `adha.stream.cancelled` | Stream annulé | `cancelled` |
| `adha.stream.heartbeat` | Signal de connexion active | `heartbeat` |

### Structure des Chunks

#### Chunk de contenu

```json
{
  "id": "chunk-uuid-123",
  "requestMessageId": "msg-456",
  "conversationId": "conv-789",
  "type": "chunk",
  "content": "Vos ventes ont augmenté de",
  "chunkId": 1,
  "timestamp": "2026-01-09T12:00:01.123Z",
  "userId": "user-abc",
  "companyId": "company-xyz",
  "metadata": {
    "source": "adha_ai_service",
    "streamVersion": "2.0.0"
  }
}
```

#### Message de fin

```json
{
  "id": "end-uuid-456",
  "requestMessageId": "msg-456",
  "conversationId": "conv-789",
  "type": "end",
  "content": "Vos ventes ont augmenté de 15% ce mois-ci...",
  "chunkId": 8,
  "totalChunks": 7,
  "timestamp": "2026-01-09T12:00:05.456Z",
  "userId": "user-abc",
  "companyId": "company-xyz",
  "processingDetails": {
    "totalChunks": 7,
    "contentLength": 285,
    "aiModel": "adha-1",
    "source": "gestion_commerciale"
  },
  "metadata": {
    "source": "adha_ai_service",
    "streamVersion": "2.0.0",
    "streamComplete": true
  }
}
```

#### Message d'erreur

```json
{
  "id": "error-uuid-789",
  "requestMessageId": "msg-456",
  "conversationId": "conv-789",
  "type": "error",
  "content": "Impossible d'analyser les données de ventes",
  "chunkId": -1,
  "timestamp": "2026-01-09T12:00:02.000Z",
  "userId": "user-abc",
  "companyId": "company-xyz",
  "metadata": {
    "source": "adha_ai_service",
    "streamVersion": "2.0.0",
    "error": true
  }
}
```

### Types de Chunks

| Type | Description | Usage | Fréquence |
|------|-------------|-------|-----------|
| `chunk` | Fragment de texte | Affichage progressif | Multiple par réponse |
| `end` | Fin du stream | Finalisation message | 1 par réponse |
| `error` | Erreur de traitement | Notification utilisateur | 0-1 par réponse |
| `tool_call` | L'IA appelle une fonction | Indicateur traitement | 0-N par réponse |
| `tool_result` | Résultat de fonction | Données d'analyse | 0-N par réponse |
| `cancelled` | Stream annulé par l'utilisateur | Nettoyage UI | 0-1 par réponse |
| `heartbeat` | Signal de connexion active | Maintien connexion | Toutes les 30s |

#### Détails du Circuit Breaker

Le Circuit Breaker protège contre les pannes en cascade :

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   CLOSED    │─────▶│    OPEN     │─────▶│  HALF-OPEN  │
│  (Normal)   │ 5 échecs│ (Bloqué)    │ timeout│  (Test)     │
└─────────────┘      └─────────────┘      └──────┬──────┘
       ▲                                        │
       └────────────── succès ───────────────┘
```

- **CLOSED** : Fonctionnement normal, requêtes passent
- **OPEN** : Après 5 échecs consécutifs, toutes les requêtes sont rejetées pendant 60s
- **HALF-OPEN** : Après le timeout, une requête test est envoyée

---

## Intégration Flutter

### Modèles Dart

```dart
// ===== CONTEXT INFO =====
class AdhaContextInfo {
  final AdhaBaseContext baseContext;
  final AdhaInteractionContext interactionContext;

  AdhaContextInfo({required this.baseContext, required this.interactionContext});

  Map<String, dynamic> toJson() => {
    'baseContext': baseContext.toJson(),
    'interactionContext': interactionContext.toJson(),
  };
}

class AdhaBaseContext {
  final AdhaOperationJournalSummary operationJournalSummary;
  final AdhaBusinessProfile businessProfile;

  AdhaBaseContext({required this.operationJournalSummary, required this.businessProfile});

  Map<String, dynamic> toJson() => {
    'operationJournalSummary': operationJournalSummary.toJson(),
    'businessProfile': businessProfile.toJson(),
  };
}

class AdhaInteractionContext {
  final AdhaInteractionType interactionType;
  final String? sourceIdentifier;
  final Map<String, dynamic>? interactionData;

  AdhaInteractionContext({
    required this.interactionType,
    this.sourceIdentifier,
    this.interactionData,
  });

  Map<String, dynamic> toJson() => {
    'interactionType': interactionType.value,
    if (sourceIdentifier != null) 'sourceIdentifier': sourceIdentifier,
    if (interactionData != null) 'interactionData': interactionData,
  };
}

enum AdhaInteractionType {
  genericCardAnalysis('generic_card_analysis'),
  followUp('follow_up');

  final String value;
  const AdhaInteractionType(this.value);
}

// ===== MESSAGE =====
class AdhaMessage {
  final String id;
  final String text;
  final AdhaMessageSender sender;
  final DateTime timestamp;
  final Map<String, dynamic>? contextInfo;

  AdhaMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.contextInfo,
  });

  factory AdhaMessage.fromJson(Map<String, dynamic> json) {
    return AdhaMessage(
      id: json['id'],
      text: json['text'],
      sender: AdhaMessageSender.fromString(json['sender']),
      timestamp: DateTime.parse(json['timestamp']),
      contextInfo: json['contextInfo'],
    );
  }
}

enum AdhaMessageSender {
  user('user'),
  ai('ai');

  final String value;
  const AdhaMessageSender(this.value);

  static AdhaMessageSender fromString(String value) {
    return AdhaMessageSender.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AdhaMessageSender.ai,
    );
  }
}

// ===== STREAMING =====

/// Action suggérée par l'IA (v2.4.0)
class AdhaSuggestedAction {
  final String type;    // 'navigate', 'action', 'query', 'info'
  final String? label;  // Libellé affichable (optionnel)
  final dynamic payload; // Données de l'action

  AdhaSuggestedAction({
    required this.type,
    this.label,
    required this.payload,
  });

  factory AdhaSuggestedAction.fromJson(Map<String, dynamic> json) {
    return AdhaSuggestedAction(
      type: json['type'],
      label: json['label'],
      payload: json['payload'],
    );
  }
}

class AdhaStreamChunkEvent {
  final String id;
  final String requestMessageId;
  final String conversationId;
  final AdhaStreamType type;
  final String content;
  final int chunkId;
  final DateTime timestamp;
  final String userId;
  final String companyId;
  final int? totalChunks;
  final List<AdhaSuggestedAction>? suggestedActions; // v2.4.0
  final Map<String, dynamic>? processingDetails;
  final AdhaStreamMetadata? metadata;

  AdhaStreamChunkEvent({
    required this.id,
    required this.requestMessageId,
    required this.conversationId,
    required this.type,
    required this.content,
    required this.chunkId,
    required this.timestamp,
    required this.userId,
    required this.companyId,
    this.totalChunks,
    this.suggestedActions,
    this.processingDetails,
    this.metadata,
  });

  factory AdhaStreamChunkEvent.fromJson(Map<String, dynamic> json) {
    return AdhaStreamChunkEvent(
      id: json['id'],
      requestMessageId: json['requestMessageId'],
      conversationId: json['conversationId'],
      type: AdhaStreamType.fromString(json['type']),
      content: json['content'],
      chunkId: json['chunkId'],
      timestamp: DateTime.parse(json['timestamp']),
      userId: json['userId'],
      companyId: json['companyId'],
      totalChunks: json['totalChunks'],
      suggestedActions: json['suggestedActions'] != null
          ? (json['suggestedActions'] as List)
              .map((a) => AdhaSuggestedAction.fromJson(a))
              .toList()
          : null,
      processingDetails: json['processingDetails'],
      metadata: json['metadata'] != null
          ? AdhaStreamMetadata.fromJson(json['metadata'])
          : null,
    );
  }
}

enum AdhaStreamType {
  chunk,
  end,
  error,
  toolCall,
  toolResult,
  cancelled,
  heartbeat;

  static AdhaStreamType fromString(String value) {
    switch (value) {
      case 'chunk': return AdhaStreamType.chunk;
      case 'end': return AdhaStreamType.end;
      case 'error': return AdhaStreamType.error;
      case 'tool_call': return AdhaStreamType.toolCall;
      case 'tool_result': return AdhaStreamType.toolResult;
      case 'cancelled': return AdhaStreamType.cancelled;
      case 'heartbeat': return AdhaStreamType.heartbeat;
      default: return AdhaStreamType.chunk;
    }
  }
}

class AdhaStreamMetadata {
  final String source;
  final String streamVersion;
  final bool? streamComplete;
  final bool? error;

  AdhaStreamMetadata({
    required this.source,
    required this.streamVersion,
    this.streamComplete,
    this.error,
  });

  factory AdhaStreamMetadata.fromJson(Map<String, dynamic> json) {
    return AdhaStreamMetadata(
      source: json['source'] ?? 'unknown',
      streamVersion: json['streamVersion'] ?? '1.0.0',
      streamComplete: json['streamComplete'],
      error: json['error'],
    );
  }
}
```

### Service de Streaming

```dart
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class AdhaStreamService {
  IO.Socket? _socket;
  final StreamController<AdhaStreamChunkEvent> _chunkController =
      StreamController<AdhaStreamChunkEvent>.broadcast();
  String? _currentConversationId;

  Stream<AdhaStreamChunkEvent> get chunkStream => _chunkController.stream;

  /// Connexion au WebSocket via API Gateway
  Future<void> connect(String authToken) async {
    // Utiliser l'URL appropriée selon l'environnement
    const baseUrl = 'http://localhost:8000'; // ou https://api.wanzo.io

    _socket = IO.io('$baseUrl/commerce/chat', <String, dynamic>{
      'transports': ['websocket', 'polling'],
      'autoConnect': true,
      'auth': {'token': authToken},
      'path': '/socket.io',
    });

    _socket!.onConnect((_) {
      print('✅ Connected to ADHA streaming');
    });

    _socket!.onConnectError((error) {
      print('❌ Connection error: $error');
    });

    _socket!.onDisconnect((_) {
      print('⚠️ Disconnected from ADHA streaming');
    });

    // Écouter les événements de streaming
    _socket!.on('adha.stream.chunk', (data) {
      final chunk = AdhaStreamChunkEvent.fromJson(data);
      _chunkController.add(chunk);
    });

    _socket!.on('adha.stream.end', (data) {
      final chunk = AdhaStreamChunkEvent.fromJson(data);
      _chunkController.add(chunk);
    });

    _socket!.on('adha.stream.error', (data) {
      final chunk = AdhaStreamChunkEvent.fromJson(data);
      _chunkController.add(chunk);
    });

    _socket!.on('adha.stream.tool', (data) {
      final chunk = AdhaStreamChunkEvent.fromJson(data);
      _chunkController.add(chunk);
    });

    // Écouter les événements d'annulation
    _socket!.on('adha.stream.cancelled', (data) {
      final chunk = AdhaStreamChunkEvent.fromJson(data);
      _chunkController.add(chunk);
    });

    // Écouter les heartbeats (optionnel: pour reset timeout)
    _socket!.on('adha.stream.heartbeat', (data) {
      // Heartbeat reçu - connexion active
      // Optionnel: parser et ajouter au stream si besoin
      print('💓 Heartbeat received');
    });
  }

  /// S'abonner à une conversation
  void subscribeToConversation(String conversationId) {
    _currentConversationId = conversationId;
    _socket?.emit('subscribe_conversation', {'conversationId': conversationId});
  }

  /// Se désabonner d'une conversation
  void unsubscribeFromConversation(String conversationId) {
    _socket?.emit('unsubscribe_conversation', {'conversationId': conversationId});
  }

  void dispose() {
    if (_currentConversationId != null) {
      unsubscribeFromConversation(_currentConversationId!);
    }
    _socket?.disconnect();
    _socket?.dispose();
    _chunkController.close();
  }
}
```

### Intégration BLoC

```dart
class AdhaBloc extends Bloc<AdhaEvent, AdhaState> {
  final AdhaRepository adhaRepository;
  final AdhaStreamService _streamService;
  StreamSubscription? _streamSubscription;
  final StringBuffer _accumulatedContent = StringBuffer();

  AdhaBloc({
    required this.adhaRepository,
    required AdhaStreamService streamService,
  }) : _streamService = streamService, super(AdhaInitial()) {
    on<SendAdhaMessage>(_onSendMessage);
    on<LoadConversations>(_onLoadConversations);

    // Écouter les chunks de streaming
    _streamSubscription = _streamService.chunkStream.listen(_handleStreamChunk);
  }

  void _handleStreamChunk(AdhaStreamChunkEvent chunk) {
    switch (chunk.type) {
      case AdhaStreamType.chunk:
        _accumulatedContent.write(chunk.content);
        emit(AdhaStreaming(
          conversationId: chunk.conversationId,
          partialContent: _accumulatedContent.toString(),
          chunkId: chunk.chunkId,
        ));
        break;

      case AdhaStreamType.end:
        emit(ResponseReceived(
          conversationId: chunk.conversationId,
          message: AdhaMessage(
            id: chunk.id,
            text: chunk.content,
            sender: AdhaMessageSender.ai,
            timestamp: chunk.timestamp,
          ),
          processingDetails: chunk.processingDetails,
        ));
        _accumulatedContent.clear();
        break;

      case AdhaStreamType.error:
        emit(AdhaError(message: chunk.content));
        _accumulatedContent.clear();
        break;

      case AdhaStreamType.toolCall:
      case AdhaStreamType.toolResult:
        // Optionnel: afficher un indicateur de traitement
        emit(AdhaProcessingTool(toolType: chunk.type.name));
        break;

      case AdhaStreamType.cancelled:
        // Stream annulé par l'utilisateur ou le serveur
        emit(AdhaStreamCancelled(
          conversationId: chunk.conversationId,
          reason: chunk.metadata?['reason'] ?? 'Stream cancelled',
        ));
        _accumulatedContent.clear();
        break;

      case AdhaStreamType.heartbeat:
        // Signal de connexion active - pas d'action UI nécessaire
        // Optionnel: reset du timeout de déconnexion côté client
        break;
    }
  }

  @override
  Future<void> close() {
    _streamSubscription?.cancel();
    return super.close();
  }
}
```

### Widget de Streaming

```dart
class StreamingMessageWidget extends StatelessWidget {
  final String partialContent;
  final bool isComplete;

  const StreamingMessageWidget({
    Key? key,
    required this.partialContent,
    this.isComplete = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(partialContent, style: const TextStyle(fontSize: 14)),
          if (!isComplete) ...[
            const SizedBox(height: 8),
            const TypingIndicator(),
          ],
        ],
      ),
    );
  }
}

// Dans votre écran
BlocBuilder<AdhaBloc, AdhaState>(
  builder: (context, state) {
    if (state is AdhaStreaming) {
      return StreamingMessageWidget(
        partialContent: state.partialContent,
        isComplete: false,
      );
    } else if (state is ResponseReceived) {
      return ChatMessageWidget(
        message: state.message,
        isComplete: true,
      );
    }
    return const SizedBox.shrink();
  },
)
```

---

## Exemple d'Utilisation Complet

```dart
// 1. Récupérer companyId et userId (REQUIS pour ADHA AI)
final businessContextService = BusinessContextService();
final companyId = businessContextService.companyId;
final userId = businessContextService.userId; // UUID de la DB, PAS Auth0 ID

// ⚠️ Le companyId n'est PAS dans le JWT - il DOIT être envoyé explicitement
// ⚠️ Le userId doit être l'UUID de la base de données (ex: 807b15e7-...)
//    PAS l'Auth0 ID (ex: google-oauth2|...)
if (companyId == null) {
  throw Exception('companyId est requis pour ADHA AI');
}

// 2. Initialiser le service de streaming
final streamService = AdhaStreamService();
await streamService.connect(authToken);

// 3. S'abonner à la conversation (après création ou chargement)
// ⚠️ Pour les NOUVELLES conversations, utiliser le mode synchrone car
// le streaming ne fonctionne pas avant d'avoir le conversationId
streamService.subscribeToConversation(conversationId);

// 4. Préparer le contexte
final contextInfo = AdhaContextInfo(
  baseContext: AdhaBaseContext(
    operationJournalSummary: AdhaOperationJournalSummary(
      recentEntries: [
        AdhaOperationJournalEntry(
          timestamp: '2025-08-01T10:00:00.000Z',
          description: 'Vente #123 créée',
          operationType: 'CREATE_SALE',
          details: {'amount': 2500, 'customer': 'John Doe'},
        ),
      ],
    ),
    businessProfile: AdhaBusinessProfile(
      name: 'Ma Boutique',
      sector: 'Alimentation',
      address: '123 Avenue du Commerce, Kinshasa',
    ),
  ),
  interactionContext: AdhaInteractionContext(
    interactionType: AdhaInteractionType.genericCardAnalysis,
    sourceIdentifier: 'sales_summary_card',
    interactionData: {'selectedPeriod': 'last_month'},
  ),
);

// 5. Envoyer le message via REST API
// ⚠️ IMPORTANT: Inclure companyId et userId dans la requête
final response = await adhaApiService.sendMessage(
  text: 'Quelle est ma meilleure journée de ventes ce mois-ci ?',
  conversationId: conversationId, // null pour nouvelle conversation
  timestamp: DateTime.now().toIso8601String(),
  contextInfo: contextInfo,
  companyId: companyId,  // REQUIS - non extrait du JWT
  userId: userId,        // Optionnel - pour traçabilité
);

// 6. La réponse streamée arrivera via WebSocket (chunkStream)
```

---

## Bonnes Pratiques

### Backend
- Toujours valider `interactionType` contre l'enum `InteractionType`
- Le `conversationId` est optionnel pour créer une nouvelle conversation
- Les champs `text`, `timestamp`, `contextInfo` et **`companyId`** sont requis
- Le `companyId` n'est PAS extrait du JWT - il doit être lu depuis le body

### Frontend
1. **companyId obligatoire**: Toujours envoyer le `companyId` depuis `BusinessContextService`
2. **Mode synchrone pour nouvelles conversations**: Utiliser `/message` au lieu de `/stream`
3. **Connexion WebSocket**: Établir la connexion avant d'envoyer des messages
4. **Abonnement**: S'abonner à la conversation après envoi du premier message
5. **Affichage progressif**: Utiliser `BlocBuilder` pour afficher le texte en temps réel
6. **Gestion des erreurs**: Toujours gérer le type `error` pour informer l'utilisateur
7. **Timeout**: Implémenter un timeout de 120s pour les requêtes ADHA (l'IA peut être lente)
8. **Fallback**: Proposer un mode non-streaming si WebSocket indisponible
9. **Désabonnement**: Se désabonner et déconnecter lors du `dispose()`

---

## Topics Kafka

| Topic | Direction | Description |
|-------|-----------|-------------|
| `adha.chat.message.sent` | Commerce → ADHA AI | Message envoyé par l'utilisateur |
| `adha.chat.stream` | ADHA AI → Commerce | Chunks de réponse streaming |
| `adha.chat.response.ready` | ADHA AI → Commerce | Réponse complète prête |

---

## Format Standardisé des Messages Kafka

> ⚠️ **IMPORTANT**: Tous les messages Kafka vers ADHA AI doivent utiliser le format standardisé via `MessageVersionManager`.

### Structure du Message Standardisé

Le service gestion_commerciale utilise `MessageVersionManager.createStandardMessage()` pour garantir que ADHA AI peut correctement extraire le `conversationId` et autres données:

```typescript
import { MessageVersionManager } from '@wanzobe/shared/events/message-versioning';

// Format d'envoi standardisé
const standardMessage = MessageVersionManager.createStandardMessage(
  topic,
  {
    conversationId: 'conv-uuid-123',
    messageId: 'msg-uuid-456',
    text: 'Ma question...',
    userId: 'user-uuid',
    companyId: 'company-uuid',
    contextInfo: { ... },
  },
  'gestion_commerciale_service'
);

// Résultat du message standardisé
{
  id: 'unique-uuid',
  eventType: 'adha.chat.message.sent',
  timestamp: '2025-01-09T12:00:00.000Z',
  data: {
    conversationId: 'conv-uuid-123',
    messageId: 'msg-uuid-456',
    text: 'Ma question...',
    userId: 'user-uuid',
    companyId: 'company-uuid',
    contextInfo: { ... },
  },
  metadata: {
    version: '1.0.0',
    source: 'gestion_commerciale_service',
    correlationId: 'correlation-uuid'
  }
}
```

### Pourquoi ce format est nécessaire

ADHA AI Service extrait les données via `message.data`:
```python
# Dans ADHA AI Service
conversation_id = message.get('data', {}).get('conversationId')
```

Si le message n'est pas encapsulé correctement dans la structure `{ data: {...} }`, ADHA AI recevra un `conversationId` vide, ce qui causera des erreurs de routage WebSocket.

---

## 🎙️ Mode Audio Duplex (v2.4.0)

> **Nouveauté**: Conversation vocale avec ADHA pour gérer votre commerce sans les mains.

### Architecture Audio

```
┌───────────────────┐     ┌─────────────────────┐     ┌───────────────────────┐
│   App Flutter     │     │  API Gateway        │     │  ADHA AI Service      │
│   (Microphone)    │────▶│  /commerce/adha     │────▶│  AudioService         │
│                   │◀────│                     │◀────│  (Whisper + TTS)      │
│   (Haut-parleur)  │     │                     │     │                       │
└───────────────────┘     └─────────────────────┘     └───────────────────────┘
```

### Endpoints Audio (via ADHA AI Service)

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/adha-ai/audio/transcribe/` | POST | Transcription audio → texte |
| `/adha-ai/audio/synthesize/` | POST | Synthèse texte → audio |
| `/adha-ai/audio/duplex/` | POST | Mode duplex (STT + Chat + TTS) |
| `/adha-ai/audio/voices/` | GET | Voix disponibles |

### Cas d'Usage Commerce

| Scénario | Mode | Exemple |
|----------|------|---------|
| Dictée inventaire | `transcribe_only` | "Article X, quantité 50" |
| Rapport vocal | `speak_only` | Lecture du CA journalier |
| Question rapide | `full_duplex` | "Combien de ventes aujourd'hui?" |

### Exemple Flutter: Mode Duplex

```dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class AdhaAudioService {
  final String baseUrl;
  final String authToken;
  
  AdhaAudioService({required this.baseUrl, required this.authToken});
  
  /// Mode duplex: envoie audio, reçoit réponse audio
  Future<DuplexResponse> sendAudioDuplex({
    required File audioFile,
    required String companyId,
    String? conversationId,
    Map<String, dynamic>? context,
    String voice = 'nova',
    String language = 'fr',
  }) async {
    final uri = Uri.parse('$baseUrl/adha-ai/audio/duplex/');
    final request = http.MultipartRequest('POST', uri);
    
    // Headers
    request.headers['Authorization'] = 'Bearer $authToken';
    
    // Audio file
    request.files.add(await http.MultipartFile.fromPath(
      'audio',
      audioFile.path,
      contentType: MediaType('audio', 'webm'),
    ));
    
    // Form fields
    request.fields['company_id'] = companyId;
    request.fields['voice'] = voice;
    request.fields['language'] = language;
    if (conversationId != null) {
      request.fields['conversation_id'] = conversationId;
    }
    if (context != null) {
      request.fields['context'] = jsonEncode(context);
    }
    
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    return DuplexResponse.fromJson(jsonDecode(responseBody));
  }
}

class DuplexResponse {
  final String transcribedText;
  final String chatResponse;
  final String audioBase64;
  final String conversationId;
  final AudioMetrics metrics;
  
  DuplexResponse.fromJson(Map<String, dynamic> json)
      : transcribedText = json['transcription']['text'],
        chatResponse = json['chat_response']['text'],
        audioBase64 = json['audio_response']['audio_base64'],
        conversationId = json['chat_response']['conversation_id'],
        metrics = AudioMetrics.fromJson(json['metrics']);
}
```

---

## 📄 Génération de Documents (v2.4.0)

> **Nouveauté**: ADHA génère des documents commerciaux (factures, rapports) et les stocke sur Cloudinary.

### Types de Documents pour Commerce

| Type | Format | Description |
|------|--------|-------------|
| `sales_report` | PDF | Rapport de ventes |
| `inventory_report` | Excel | État des stocks |
| `invoice` | PDF | Facture client |
| `expense_report` | PDF/Excel | Rapport de dépenses |
| `analysis_report` | PDF | Analyse ADHA |

### Endpoint Génération

```
POST /commerce/adha-ai/documents/generate/
```

**Request**:
```json
{
  "company_id": "company-123",
  "type": "sales_report",
  "format": "pdf",
  "data": {
    "dateRange": {
      "from": "2026-01-01",
      "to": "2026-01-14"
    },
    "groupBy": "day",
    "includeProducts": true,
    "includeCustomers": false
  }
}
```

**Response**:
```json
{
  "success": true,
  "document": {
    "id": "doc_sales_123456",
    "format": "pdf",
    "type": "sales_report",
    "cloudinary_url": "https://res.cloudinary.com/wanzo/adha-documents/sales_report_202601.pdf",
    "filename": "rapport_ventes_jan2026.pdf",
    "pages": 5,
    "size_bytes": 125678
  }
}
```

### Export Excel Inventaire

```json
POST /commerce/adha-ai/documents/export/excel/
{
  "company_id": "company-123",
  "type": "inventory",
  "filters": {
    "category": "alimentaire",
    "lowStock": true
  },
  "columns": ["productName", "sku", "quantity", "alertThreshold", "supplier"]
}
```

---

## 📎 Pièces Jointes dans le Chat

### Analyse de Documents Commerciaux

ADHA peut analyser vos documents commerciaux:

**Request avec pièce jointe**:
```json
{
  "text": "Peux-tu extraire les informations de cette facture fournisseur?",
  "conversationId": "conv-123",
  "timestamp": "2026-01-14T10:00:00.000Z",
  "contextInfo": {
    "baseContext": {...},
    "interactionContext": {
      "interactionType": "generic_card_analysis"
    }
  },
  "attachment": {
    "name": "facture_fournisseur.pdf",
    "type": "application/pdf",
    "content": "JVBERi0xLjQK..."
  }
}
```

### Capacités d'Analyse

ADHA peut:
1. **Extraire** les informations (montant, TVA, articles)
2. **Créer** une dépense ou un achat automatiquement
3. **Vérifier** la cohérence avec l'inventaire
4. **Suggérer** des actions (mise à jour stock, paiement)

---

## Codes d'Erreur

| Code | Message | Description |
|------|---------|-------------|
| 400 | Bad Request | Paramètres invalides (validation DTO) |
| 401 | Unauthorized | Token JWT manquant ou invalide |
| 403 | Forbidden | Accès non autorisé à la ressource |
| 404 | Not Found | Conversation non trouvée |
| 500 | Internal Server Error | Erreur serveur (Kafka, DB, etc.) |

---

## Changelog

### 15 Janvier 2026 (v2.4.1) - Audit Conformité
- 🔄 **streamVersion** harmonisé à `"2.0.0"` dans tous les exemples JSON
- 📱 **Flutter BLoC** - Ajout gestion des cas `heartbeat` et `cancelled`
- 📡 **AdhaStreamService** - Ajout listeners `adha.stream.cancelled` et `adha.stream.heartbeat`
- 📝 Audit de conformité documentation vs code source effectué

### 14 Janvier 2026 (v2.4.0)
- 🎙️ **Mode Audio Duplex** - Conversation vocale bidirectionnelle
- 📄 **Génération de Documents** - PDF/Excel avec URLs Cloudinary
- 📎 **Pièces Jointes** - Analyse de documents dans le chat
- ✅ 7 types d'événements streaming standardisés (+ `cancelled`, `heartbeat`)
- ⚡ Circuit Breaker pour la résilience Kafka
- 💓 Heartbeat toutes les 30s pour maintien connexion WebSocket

### Janvier 2026 (Mise à jour)
- 🔧 Correction du format des messages Kafka avec `MessageVersionManager`
- 📝 Ajout de la documentation sur le format standardisé Kafka
- ✅ Synchronisation avec accounting-service pour cohérence

### Janvier 2026
- ✅ Ajout du streaming WebSocket via Socket.IO
- ✅ Intégration Kafka pour les chunks temps réel
- ✅ ChatGateway dans gestion_commerciale_service
- ✅ Proxy WebSocket dans API Gateway
- ✅ Documentation unifiée (fusion README + API_REFERENCE + INTEGRATION_GUIDE)

### Août 2025
- ✅ API REST initiale (send message, conversations, history)
- ✅ Intégration avec ADHA AI Service via Kafka
