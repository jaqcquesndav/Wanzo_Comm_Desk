# Chat ADHA API Documentation

Ce document décrit l'API Chat ADHA pour l'application Wanzo Compta. Le système de chat ADHA (Assistant Digital en Haut niveau d'Analyse) permet l'interaction avec l'assistant IA comptable.

**✅ STATUT**: API Backend **IMPLÉMENTÉE ET OPÉRATIONNELLE** (v2.4.0 - 14 Janvier 2026)

> **Dernière mise à jour**: 14 Janvier 2026 - Ajout Circuit Breaker, Heartbeat, types standardisés

---

## 🆕 Nouveautés v2.4.0 (14 Janvier 2026)

### Fonctionnalités Implémentées

| Fonctionnalité | Description | Configuration |
|----------------|-------------|---------------|
| **Circuit Breaker** | Protection contre les cascades d'erreurs Kafka | `CIRCUIT_BREAKER_THRESHOLD=5`, `CIRCUIT_BREAKER_TIMEOUT=60` |
| **Heartbeat** | Signal de connexion active (maintien WebSocket) | `STREAM_HEARTBEAT_INTERVAL_S=30` |
| **Annulation Stream** | Possibilité d'arrêter un stream en cours | Event `cancel_stream` via WebSocket |
| **7 Types d'événements** | `chunk`, `end`, `error`, `tool_call`, `tool_result`, `cancelled`, `heartbeat` | - |
| **suggestedActions** | Format standardisé avec label optionnel | `Array<{type: string; label?: string; payload: any}>` |

### Timeouts Configurés

```env
# Variables d'environnement (accounting-service)
AI_TIMEOUT=120000              # 120s - Timeout appel IA synchrone
STREAMING_TIMEOUT=180000       # 180s - Timeout streaming max
DEFAULT_TIMEOUT=30000          # 30s - Timeout par défaut HTTP
STREAM_HEARTBEAT_INTERVAL_S=30 # Heartbeat toutes les 30s
CIRCUIT_BREAKER_THRESHOLD=5    # Erreurs avant ouverture circuit
CIRCUIT_BREAKER_TIMEOUT=60     # Secondes avant retry circuit
```

---

## ⚠️ IMPORTANT : 2 modes d'appel disponibles

| Endpoint | Type | Comportement | Cas d'usage |
|----------|------|--------------|-------------|
| `POST /chat` | Bloquant | Attend la réponse complète puis la renvoie en une fois | Simple, mais attente de 5-15 secondes |
| `POST /chat/stream` | Non-bloquant | Retourne immédiatement, réponse via WebSocket | Streaming temps réel, UX optimale |

### Résumé

- **`POST /chat`** = Réponse HTTP classique (en vrac, pas de streaming)
- **`POST /chat/stream`** = Réponse via WebSocket (streaming temps réel)

---

## ✅ Bugs Corrigés (v2.3.1 - 9 Janvier 2026)

> **Les bugs suivants ont été identifiés et corrigés.**

### Bug #1: Messages non persistés - **CORRIGÉ** ✅

**Problème**: Le `companyId` n'était pas passé lors de la création de conversation, causant des problèmes de filtrage.

**Correction appliquée**:
- Ajout de `companyId` au DTO `CreateChatDto`
- Passage du `companyId` dans les endpoints `POST /chat`, `POST /chat/stream`, `POST /chat/message`
- Le service `ChatService.create()` sauvegarde maintenant correctement le `companyId`

### Bug #2: Conversation créée par /chat/stream introuvable - **CORRIGÉ** ✅

**Problème**: La conversation créée n'était pas retrouvable car le `companyId` manquait.

**Correction appliquée**: Même fix que Bug #1 - le `companyId` est maintenant correctement associé.

### Bug #3: Timeout sur POST /chat - **CORRIGÉ** ✅

**Problème**: Le timeout de 30 secondes était trop court pour les réponses IA complexes.

**Correction appliquée**: Timeout augmenté à 120 secondes dans `AdhaAiService.sendMessage()`.

**Recommandation**: Utiliser `POST /chat/stream` pour une meilleure expérience utilisateur (pas de timeout, réponse progressive).

---

## � GUIDE COMPLET : Comment recevoir le streaming (Frontend)

> **Cette section est CRITIQUE**. Si le frontend ne suit pas ces étapes, il ne recevra PAS les chunks de streaming.

### Architecture du Streaming

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                      │
│   FRONTEND                            API GATEWAY (8000)         ACCOUNTING (3001)   │
│                                                                                      │
│   ┌─────────────┐                     ┌─────────────────┐        ┌──────────────┐   │
│   │             │   WebSocket         │                 │        │              │   │
│   │  Socket.IO  │ =================>  │  Proxy WS       │ =====> │ ChatGateway  │   │
│   │  Client     │  /accounting/chat   │  /accounting/   │        │ namespace    │   │
│   │             │                     │  chat → /chat   │        │   /chat      │   │
│   └─────────────┘                     └─────────────────┘        └──────────────┘   │
│         ↑                                                                │          │
│         │ Events:                                                        │          │
│         │ - adha.stream.chunk                                            │          │
│         │ - adha.stream.end                                              ↓          │
│         │ - adha.stream.error            ┌─────────────────────────────────────┐   │
│         │                                │           Kafka                      │   │
│   ┌─────────────┐                        │   accounting.chat.stream topic      │   │
│   │             │                        └─────────────────────────────────────┘   │
│   │    POST     │  HTTP /chat/stream              ↑                               │
│   │   Request   │ ==================>             │                               │
│   │             │  (retour immédiat)              │                               │
│   └─────────────┘                        ┌────────┴────────┐                      │
│                                          │  ADHA AI Service │                      │
│                                          │  (génère chunks) │                      │
│                                          └─────────────────┘                      │
│                                                                                      │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

### Étapes OBLIGATOIRES (dans cet ordre exact)

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│  ÉTAPE 1: CONNEXION WebSocket (au démarrage de l'application)                      │
│  ──────────────────────────────────────────────────────────────────────────────    │
│                                                                                    │
│  // ⚠️ IMPORTANT: Comprendre la différence entre URL et path Socket.IO            │
│  //                                                                                │
│  // - URL de base: ws://localhost:8000 (le serveur API Gateway)                    │
│  // - path: '/accounting/chat' (le chemin où Socket.IO envoie ses requêtes)        │
│  // - Le namespace '/chat' est géré automatiquement par le proxy                   │
│                                                                                    │
│  const socket = io('ws://localhost:8000', {                                        │
│    path: '/accounting/chat',   // ⚠️ CRITIQUE: path du proxy API Gateway           │
│    auth: { token: 'VOTRE_JWT_TOKEN' },                                             │
│    transports: ['websocket'],  // Forcer WebSocket (pas de polling)                │
│  });                                                                               │
│                                                                                    │
│  socket.on('connect', () => console.log('✅ Connecté, ID:', socket.id));           │
│  socket.on('connect_error', (err) => console.error('❌ Erreur:', err.message));    │
│                                                                                    │
│  // Le proxy API Gateway route automatiquement:                                    │
│  //   /accounting/chat/* → accounting-service/socket.io/* (namespace /chat)        │
│  //   /portfolio/chat/*  → portfolio-service/socket.io/* (futur)                   │
│  //   /commerce/chat/*   → commerce-service/socket.io/* (futur)                    │
│                                                                                    │
└────────────────────────────────────────────────────────────────────────────────────┘
                                         ↓
┌────────────────────────────────────────────────────────────────────────────────────┐
│  ÉTAPE 2: CONFIGURER les listeners d'événements                                    │
│  ──────────────────────────────────────────────────────────────────────────────    │
│                                                                                    │
│  socket.on('adha.stream.chunk', (payload) => {                                     │
│    console.log('Chunk reçu:', payload.content);                                    │
│    // Ajouter le texte à l'UI progressivement                                      │
│    appendToMessage(payload.content);                                               │
│  });                                                                               │
│                                                                                    │
│  socket.on('adha.stream.end', (payload) => {                                       │
│    console.log('Message complet:', payload.content);                               │
│    // Fin du streaming, message complet disponible                                 │
│  });                                                                               │
│                                                                                    │
│  socket.on('adha.stream.error', (payload) => {                                     │
│    console.error('Erreur streaming:', payload.content);                            │
│  });                                                                               │
│                                                                                    │
└────────────────────────────────────────────────────────────────────────────────────┘
                                         ↓
┌────────────────────────────────────────────────────────────────────────────────────┐
│  ÉTAPE 3: S'ABONNER à la conversation (AVANT d'envoyer le message)                 │
│  ──────────────────────────────────────────────────────────────────────────────    │
│                                                                                    │
│  // Si conversation existante                                                      │
│  socket.emit('subscribe_conversation', { conversationId: 'conv-xxx' });            │
│                                                                                    │
│  // Attendre la confirmation (optionnel mais recommandé)                           │
│  socket.on('subscribe_conversation', (response) => {                               │
│    if (response.success) console.log('✅ Abonné à:', response.conversationId);     │
│  });                                                                               │
│                                                                                    │
└────────────────────────────────────────────────────────────────────────────────────┘
                                         ↓
┌────────────────────────────────────────────────────────────────────────────────────┐
│  ÉTAPE 4: ENVOYER le message via POST /chat/stream                                 │
│  ──────────────────────────────────────────────────────────────────────────────    │
│                                                                                    │
│  const response = await fetch('http://localhost:8000/accounting/api/v1/chat/stream', {
│    method: 'POST',                                                                 │
│    headers: {                                                                      │
│      'Authorization': 'Bearer VOTRE_JWT_TOKEN',                                    │
│      'Content-Type': 'application/json'                                            │
│    },                                                                              │
│    body: JSON.stringify({                                                          │
│      conversationId: 'conv-xxx',  // optionnel, sera créé si absent                │
│      message: { content: 'Bonjour ADHA' },                                         │
│      modelId: 'adha-1',                                                            │
│      writeMode: false                                                              │
│    })                                                                              │
│  });                                                                               │
│                                                                                    │
│  const data = await response.json();                                               │
│  // { messageId, conversationId, userMessageId }                                   │
│                                                                                    │
└────────────────────────────────────────────────────────────────────────────────────┘
                                         ↓
┌────────────────────────────────────────────────────────────────────────────────────┐
│  ÉTAPE 5: SI nouvelle conversation, S'ABONNER avec le nouveau ID                   │
│  ──────────────────────────────────────────────────────────────────────────────    │
│                                                                                    │
│  // Si pas de conversationId fourni, en créer une nouvelle                         │
│  if (!conversationId) {                                                            │
│    socket.emit('subscribe_conversation', {                                         │
│      conversationId: data.conversationId                                           │
│    });                                                                             │
│  }                                                                                 │
│                                                                                    │
│  // Les chunks arrivent maintenant via les événements configurés à l'étape 2       │
│                                                                                    │
└────────────────────────────────────────────────────────────────────────────────────┘
```

### Code Frontend Complet (React + TypeScript)

```typescript
import { io, Socket } from 'socket.io-client';
import { useEffect, useState, useRef, useCallback } from 'react';

// Types standardisés v2.4
interface StreamingChunkPayload {
  requestMessageId: string;      // ID du message pour suivre le stream
  conversationId: string;        // ID de la conversation
  type: 'chunk' | 'end' | 'error' | 'tool_call' | 'tool_result' | 'cancelled' | 'heartbeat';
  content: string;               // Contenu du chunk
  chunkId: number;               // Numéro de séquence (commence à 1)
  totalChunks?: number;          // Nombre total (uniquement dans 'end')
  journalEntry?: JournalEntry;   // Écriture comptable (si writeMode=true)
  suggestedActions?: Array<{     // Actions suggérées (format standardisé)
    type: string;                // Type d'action (ex: 'view_entry', 'validate')
    label?: string;              // Libellé optionnel pour l'UI
    payload: any;                // Données de l'action
  }>;
  processingDetails?: {
    totalChunks?: number;
    contentLength?: number;
    aiModel?: string;
    tokensUsed?: number;         // Tokens utilisés
    inputTokens?: number;        // Tokens en entrée
    outputTokens?: number;       // Tokens en sortie
    processingTime?: number;     // Temps de traitement en ms
    duration_ms?: number;        // Durée totale
    finishReason?: string;       // Raison de fin (stop, length, etc.)
  };
  metadata?: Record<string, any>; // Métadonnées additionnelles
}

// Hook personnalisé pour le chat streaming
export function useChatStreaming(token: string) {
  const socketRef = useRef<Socket | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const [currentMessage, setCurrentMessage] = useState('');
  const [isStreaming, setIsStreaming] = useState(false);

  // ÉTAPE 1: Connexion WebSocket au montage
  useEffect(() => {
    // ═══════════════════════════════════════════════════════════════════
    // CONFIGURATION SOCKET.IO - ARCHITECTURE MULTI-SERVICES
    // ═══════════════════════════════════════════════════════════════════
    //
    // Le path détermine OÙ Socket.IO envoie ses requêtes HTTP/WS:
    //   - '/accounting/chat' → pour le service comptabilité
    //   - '/portfolio/chat'  → pour le service portfolio (futur)
    //   - '/commerce/chat'   → pour le service commerce (futur)
    //
    // L'API Gateway proxy automatiquement vers le bon service backend.
    //
    // ═══════════════════════════════════════════════════════════════════
    
    const socket = io('ws://localhost:8000', {
      path: '/accounting/chat',  // ⚠️ CRITIQUE: chemin du proxy API Gateway
      auth: { token },
      transports: ['websocket'], // Forcer WebSocket (pas de HTTP polling)
      reconnection: true,
      reconnectionAttempts: 5,
      reconnectionDelay: 1000,
    });

    socket.on('connect', () => {
      console.log('✅ WebSocket connecté:', socket.id);
      setIsConnected(true);
    });

    socket.on('connect_error', (error) => {
      console.error('❌ Erreur WebSocket:', error.message);
      setIsConnected(false);
    });

    socket.on('disconnect', (reason) => {
      console.warn('⚠️ WebSocket déconnecté:', reason);
      setIsConnected(false);
    });

    // ÉTAPE 2: Configurer les listeners
    socket.on('adha.stream.chunk', (payload: StreamingChunkPayload) => {
      console.log(`📨 Chunk ${payload.chunkId}:`, payload.content);
      setCurrentMessage(prev => prev + payload.content);
    });

    socket.on('adha.stream.end', (payload: StreamingChunkPayload) => {
      console.log('✅ Stream terminé:', payload.processingDetails);
      setIsStreaming(false);
      // Le message complet est dans payload.content
      // Si writeMode, payload.journalEntry contient l'écriture comptable
    });

    socket.on('adha.stream.error', (payload: StreamingChunkPayload) => {
      console.error('❌ Erreur stream:', payload.content);
      setIsStreaming(false);
    });

    socket.on('adha.stream.cancelled', (payload: StreamingChunkPayload) => {
      console.log('🛑 Stream annulé:', payload.content);
      setIsStreaming(false);
    });

    socket.on('adha.stream.heartbeat', () => {
      // Heartbeat reçu - la connexion est active
      // Pas d'action requise côté UI
    });

    socketRef.current = socket;

    return () => {
      socket.disconnect();
    };
  }, [token]);

  // ÉTAPE 3 & 4: Fonction pour envoyer un message
  const sendMessage = useCallback(async (
    content: string,
    conversationId?: string,
    writeMode = false
  ) => {
    if (!socketRef.current?.connected) {
      throw new Error('WebSocket non connecté');
    }

    // Reset du message courant
    setCurrentMessage('');
    setIsStreaming(true);

    // ÉTAPE 3: S'abonner si conversation existante
    if (conversationId) {
      socketRef.current.emit('subscribe_conversation', { conversationId });
      // Petit délai pour s'assurer que la subscription est active
      await new Promise(resolve => setTimeout(resolve, 100));
    }

    // ÉTAPE 4: Appeler POST /chat/stream
    const response = await fetch('http://localhost:8000/accounting/api/v1/chat/stream', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        conversationId,
        message: { content },
        modelId: 'adha-1',
        writeMode,
      }),
    });

    const data = await response.json();

    // ÉTAPE 5: S'abonner avec le nouveau conversationId si créé
    if (!conversationId && data.data?.conversationId) {
      socketRef.current.emit('subscribe_conversation', {
        conversationId: data.data.conversationId,
      });
    }

    return data.data;
  }, [token]);

  return {
    isConnected,
    isStreaming,
    currentMessage,
    sendMessage,
    socket: socketRef.current,
  };
}

// Exemple d'utilisation dans un composant
function ChatComponent() {
  const token = 'VOTRE_JWT_TOKEN';
  const { isConnected, isStreaming, currentMessage, sendMessage } = useChatStreaming(token);
  const [messages, setMessages] = useState<Array<{role: string, content: string}>>([]);

  const handleSend = async (text: string) => {
    // Ajouter le message utilisateur
    setMessages(prev => [...prev, { role: 'user', content: text }]);

    try {
      const result = await sendMessage(text, undefined, false);
      console.log('Message envoyé, conversationId:', result.conversationId);
    } catch (error) {
      console.error('Erreur envoi:', error);
    }
  };

  // Quand le streaming est terminé, ajouter le message final
  useEffect(() => {
    if (!isStreaming && currentMessage) {
      setMessages(prev => [...prev, { role: 'assistant', content: currentMessage }]);
    }
  }, [isStreaming, currentMessage]);

  return (
    <div>
      <div>Status: {isConnected ? '🟢 Connecté' : '🔴 Déconnecté'}</div>
      
      {messages.map((msg, i) => (
        <div key={i} className={msg.role}>
          {msg.content}
        </div>
      ))}
      
      {/* Affichage du message en cours de streaming */}
      {isStreaming && (
        <div className="assistant streaming">
          {currentMessage}
          <span className="cursor">▊</span>
        </div>
      )}
      
      <input
        type="text"
        onKeyPress={(e) => e.key === 'Enter' && handleSend(e.target.value)}
        disabled={!isConnected || isStreaming}
      />
    </div>
  );
}
```

### Points Clés à Retenir

| Point | Détail |
|-------|--------|
| **URL Socket.IO** | `ws://localhost:8000` (base) + `path: '/accounting/chat'` |
| **URL HTTP** | `http://localhost:8000/accounting/api/v1/chat/stream` |
| **Path Socket.IO** | `/accounting/chat` (PAS `/socket.io` !) |
| **Namespace** | `/chat` (géré automatiquement par le proxy) |
| **Transport** | `websocket` (pas de polling) |
| **Token** | Via `auth: { token }` dans les options Socket.IO |
| **Subscription** | **OBLIGATOIRE** avant d'envoyer le message |
| **Événements** | `adha.stream.chunk`, `adha.stream.end`, `adha.stream.error` |

### ⚠️ Erreur Courante à Éviter

```typescript
// ❌ FAUX - Ne PAS faire ceci !
const socket = io('ws://localhost:8000/accounting/chat', {
  path: '/socket.io',  // ❌ Le proxy n'écoute pas sur /socket.io
  auth: { token },
});

// ✅ CORRECT - Faire ceci !
const socket = io('ws://localhost:8000', {
  path: '/accounting/chat',  // ✅ Le proxy écoute ici
  auth: { token },
  transports: ['websocket'],
});
```

### ❌ Pourquoi "0 clients" dans les logs ?

Si vous voyez `📤 Sending chunk chunk N to 0 clients`, cela signifie :

1. **WebSocket non connecté** → Vérifier `socket.connected`
2. **Pas abonné à la conversation** → Appeler `subscribe_conversation` AVANT `/chat/stream`
3. **Mauvaise URL** → Utiliser `ws://localhost:8000/accounting/chat`
4. **Token invalide** → L'utilisateur sera "anonymous" et pas dans la bonne room

---

## �🔍 Diagnostic Streaming (v2.3.2 - 9 Janvier 2026)

### ✅ Backend Validé - Streaming Opérationnel

Les logs du backend confirment que le streaming fonctionne parfaitement :

```
📤 Sending chunk chunk 51 to 0 clients in room conversation:e615d85e-3e44-47f8-ab7d-09cd12403cb4
⚠️ No clients subscribed to conversation e615d85e-3e44-47f8-ab7d-09cd12403cb4 - chunk not delivered!
✅ Sent adha.stream.chunk for conversation e615d85e-3e44-47f8-ab7d-09cd12403cb4: )....
Stream ended for request 2d936d52-8a79-4c2e-9c91-ad66d2db6edf: 58 chunks, 269 chars, 1666ms
Stream message archived for conversation e615d85e-3e44-47f8-ab7d-09cd12403cb4
```

**Résultat**: 
- ✅ 58 chunks générés et envoyés en 1.6 secondes
- ✅ Messages archivés en base de données
- ✅ WebSocket Gateway initialisé
- ⚠️ **0 clients connectés** → Problème côté frontend

### ⚠️ Problème Identifié : Frontend non connecté

**Symptôme**: `⚠️ No clients subscribed to conversation XXX - chunk not delivered!`

**Cause**: Le frontend n'établit pas de connexion WebSocket ou ne s'abonne pas à la room de conversation **AVANT** d'appeler `/chat/stream`.

### 🔧 Checklist Frontend (OBLIGATOIRE)

| # | Action | Timing | Status |
|---|--------|--------|--------|
| 1 | Connexion WebSocket à `ws://localhost:8000/accounting/chat` | Au chargement de l'app | ✅ Implémenté |
| 2 | Passer le token JWT (auth/query/header) | À la connexion | ✅ Implémenté |
| 3 | `subscribe_conversation` avec `conversationId` | **AVANT** `/chat/stream` | ✅ Implémenté |
| 4 | Écouter `adha.stream.chunk`, `adha.stream.end` | Après subscription | ✅ Implémenté |

### ✅ Proxy WebSocket API Gateway - IMPLÉMENTÉ (v2.3.3)

> **Le proxy WebSocket est maintenant configuré dans l'API Gateway NestJS.**

**Implémentation actuelle** (`apps/api-gateway/src/main.ts`):

```typescript
import { createProxyMiddleware } from 'http-proxy-middleware';

// WebSocket Proxy for Chat Streaming
const accountingServiceUrl = process.env.ACCOUNTING_SERVICE_URL || 'http://kiota-accounting-service-dev:3001';

const wsProxy = createProxyMiddleware({
  target: accountingServiceUrl,
  changeOrigin: true,
  ws: true, // Enable WebSocket proxy
  pathRewrite: { '^/chat': '/chat' },
});

expressApp.use('/chat', wsProxy);

// Enable WebSocket upgrade handling
server.on('upgrade', (request, socket, head) => {
  if (request.url?.startsWith('/chat')) {
    wsProxy.upgrade(request, socket, head);
  }
});
```

**URLs de connexion:**

| Environnement | URL REST | URL WebSocket |
|---------------|----------|---------------|
| Via API Gateway (recommandé) | `http://localhost:8000/accounting/api/v1` | `ws://localhost:8000/accounting/chat` |
| Direct (dev uniquement) | `http://localhost:3003/api/v1` | `ws://localhost:3003/chat` |

> **Note**: Le port **3003** est le port Docker mappé (3003 → 3001 interne). La nouvelle architecture utilise `/accounting/chat` pour permettre l'ajout futur d'autres services WebSocket (`/portfolio/chat`, `/commerce/chat`).

---

## ✅ Checklist Backend - VALIDÉ (v2.3.3)

- [✅] **Persistance messages**: Sauvegarder `user` + `bot` messages dans `chat_messages`
- [✅] **Relation Chat-Message**: Relation `OneToMany` fonctionne correctement
- [✅] **CompanyId**: Passé lors de la création de conversation
- [✅] **WebSocket Gateway**: Initialisé et opérationnel sur namespace `/chat`
- [✅] **IoAdapter**: Configuré dans `main.ts` pour Socket.IO
- [✅] **Streaming Consumer**: Reçoit chunks Kafka et émet via WebSocket
- [✅] **Archivage**: Messages complets sauvegardés après streaming
- [✅] **Timeout /chat**: Augmenté à 120 secondes
- [✅] **Logs détaillés**: `📤`, `✅`, `⚠️` pour diagnostic
- [✅] **Proxy WebSocket API Gateway**: `http-proxy-middleware` configuré pour `/chat`

## ✅ Checklist Frontend - IMPLÉMENTÉ

- [✅] **Connexion WebSocket**: Se connecte à `ws://localhost:8000/accounting/chat` (via API Gateway)
- [✅] **Authentification**: Passe JWT via `auth.token` ET header `Authorization`
- [✅] **Subscription**: Appelle `subscribe_conversation` AVANT `/chat/stream`
- [✅] **Event listeners**: Écoute `adha.stream.chunk`, `adha.stream.end`, `adha.stream.error`, `adha.stream.tool`
- [✅] **Affichage progressif**: Met à jour l'UI à chaque chunk reçu

---

## ✅ Proxy WebSocket API Gateway - IMPLÉMENTÉ (v2.3.3)

> **Le proxy WebSocket DOIT être configuré dans l'API Gateway NestJS avec le préfixe `/accounting`.**

### Architecture de Connexion

```
Frontend → ws://localhost:8000/accounting/chat → API Gateway → ws://localhost:3001/chat (accounting-service interne)
                                          │
                   ✅ Proxy WebSocket configuré via http-proxy-middleware
                   ⚠️ DOIT écouter sur /accounting/chat (pas /chat)
```

### ⚠️ IMPORTANT : Configuration avec Préfixe Service

Le proxy WebSocket **DOIT** être configuré sur `/accounting/chat` (avec le préfixe du service) pour respecter l'architecture multi-services.

### Implémentation REQUISE dans `apps/api-gateway/src/main.ts`

```typescript
import { createProxyMiddleware } from 'http-proxy-middleware';

// WebSocket Proxy for Chat Streaming - ACCOUNTING SERVICE
// ⚠️ IMPORTANT: Le chemin DOIT inclure le préfixe /accounting
const accountingServiceUrl = process.env.ACCOUNTING_SERVICE_URL || 'http://kiota-accounting-service-dev:3001';

const accountingChatWsProxy = createProxyMiddleware({
  target: accountingServiceUrl,
  changeOrigin: true,
  ws: true, // Enable WebSocket proxy
  pathRewrite: { 
    '^/accounting/chat': '/chat'  // Réécrire /accounting/chat → /chat (backend)
  },
  logLevel: 'debug',  // Pour déboguer les connexions WebSocket
});

// ⚠️ IMPORTANT: Appliquer sur /accounting/chat (PAS /chat)
expressApp.use('/accounting/chat', accountingChatWsProxy);

// Enable WebSocket upgrade handling
server.on('upgrade', (request, socket, head) => {
  const url = request.url || '';
  
  // Gérer les upgrades WebSocket pour le service accounting
  if (url.startsWith('/accounting/chat') || url.includes('/accounting/chat')) {
    accountingChatWsProxy.upgrade(request, socket, head);
  }
  
  // Futurs services (exemple):
  // if (url.startsWith('/portfolio/chat')) { portfolioChatWsProxy.upgrade(...) }
  // if (url.startsWith('/commerce/chat')) { commerceChatWsProxy.upgrade(...) }
});
```

### URLs de Connexion Frontend

| Environnement | URL REST | URL WebSocket |
|---------------|----------|---------------|
| **Via API Gateway** (recommandé) | `http://localhost:8000/accounting/api/v1` | `ws://localhost:8000/accounting/chat` |
| **Production** | `https://api.wanzo-land.com/accounting/api/v1` | `wss://api.wanzo-land.com/accounting/chat` |

> **Architecture Multi-Service**: Chaque service a son propre préfixe WebSocket :
> - `ws://localhost:8000/accounting/chat` → accounting-service ✅
> - `ws://localhost:8000/portfolio/chat` → portfolio-institution-service (futur)
> - `ws://localhost:8000/commerce/chat` → gestion-commerciale-service (futur)

### Test de Validation

```bash
# Tester via API Gateway
wscat -c "ws://localhost:8000/accounting/chat/?transport=websocket"

# Tester en direct (dev)
wscat -c "ws://localhost:3003/chat/?transport=websocket"
```

### Configuration Nginx (Production - Optionnel)

Si vous utilisez Nginx en reverse proxy devant l'API Gateway en production :

```nginx
# Dans la configuration de l'API Gateway (port 8000)

# Proxy Socket.IO WebSocket
location /socket.io/ {
    proxy_pass http://chat-service:3001;
    proxy_http_version 1.1;
    
    # OBLIGATOIRE pour WebSocket
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    
    # Headers standards
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # Timeout pour les connexions longues
    proxy_read_timeout 86400;
    proxy_send_timeout 86400;
}

# Proxy namespace /chat (optionnel si Socket.IO gère via /socket.io)
location /chat {
    proxy_pass http://chat-service:3001;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

> **Note**: La configuration Nginx est optionnelle. L'API Gateway NestJS gère déjà le proxy WebSocket via `http-proxy-middleware`.

---

## Base URL

```
http://localhost:8000/accounting/api/v1
```

## Authentication

All endpoints require authentication with a Bearer token.

**Required Headers:**
```
Authorization: Bearer <jwt_token>
X-Accounting-Client: Wanzo-Accounting-UI/1.0.0
Content-Type: application/json
```

## Architecture Actuelle

### Implémentation Backend
- **Base de données**: PostgreSQL avec tables `chats` et `chat_messages`
- **Entités**: `Chat` (conversations) et `ChatMessage` (messages) liées via relation OneToMany
- **Persistance**: Toutes les conversations et messages sont sauvegardés côté serveur
- **API REST**: Endpoints `/chat/*` implémentés dans `ChatController`

### Implémentation Frontend
- **Stockage**: localStorage + Zustand store (`useChatStore`) avec synchronisation API
- **API Backend**: Toutes les requêtes passent par `/chat/*` endpoints
- **Fallback**: Réponses mock avec patterns de mots-clés si API indisponible
- **Modes**: 2 modes disponibles
  - **Mode Chat**: Conversation normale avec ADHA Assistant
  - **Mode Écriture ADHA**: Génération d'écritures comptables via `useAdhaWriteMode`
- **Conversations**: Créées automatiquement si `conversationId` non fourni
- **Modèle**: Un seul modèle ADHA géré côté backend

### Workflow
```
Frontend → API Gateway → Accounting Service → PostgreSQL
                                    ↓
                            (optionnel) Adha AI Service
```

### ⚠️ Changements Récents (Janvier 2026)
- **Ajouté**: Backend API complet avec persistance PostgreSQL
- **Ajouté**: Relations `Chat` ↔ `ChatMessage` (OneToMany/ManyToOne)
- **Ajouté**: Création automatique de conversation si `conversationId` absent
- **Supprimé**: Appels directs OpenAI côté frontend
- **Supprimé**: Sélecteur de modèle IA (ModelSelector)
- **Conservé**: Toggle Chat/Écriture ADHA uniquement
- **Workflow**: Frontend → API Backend → IA Backend → Réponse

---

## 📋 Contrats d'API (Attendus par le Frontend)

> **Pour les développeurs backend**: Voici exactement ce que le frontend attend de chaque endpoint.

### POST /chat/stream - Contrat

**Entrée**:
```json
{
  "conversationId": "uuid-existant",  // Optionnel
  "message": {
    "content": "Texte du message utilisateur"
  },
  "writeMode": false,
  "modelId": "adha-1"
}
```

**Sortie attendue** (DOIT être synchrone, avant les chunks WebSocket):
```json
{
  "success": true,
  "data": {
    "messageId": "uuid-nouveau-message-bot",
    "conversationId": "uuid-conversation",  // Nouveau si non fourni
    "userMessageId": "uuid-message-user"
  }
}
```

**Actions backend OBLIGATOIRES**:
1. ✅ Si `conversationId` absent → Créer nouvelle conversation en DB
2. ✅ Créer le message utilisateur en DB (`role: 'user'`)
3. ✅ Créer un placeholder pour le message bot en DB (`role: 'assistant'`)
4. ✅ Retourner les IDs **immédiatement**
5. ✅ Lancer le traitement IA en **async**
6. ✅ Émettre les chunks via WebSocket sur namespace `/chat`

### GET /chat/conversations - Contrat

**Sortie attendue**:
```json
{
  "success": true,
  "data": {
    "conversations": [
      {
        "id": "uuid",
        "title": "Titre de la conversation",
        "timestamp": "2026-01-09T10:00:00Z",
        "isActive": true,
        "model": { "id": "adha-1", "name": "Adha 1", ... },
        "context": [],
        "messages": []  // Vide ici, OK - utiliser GET /conversations/{id}
      }
    ]
  }
}
```

### GET /chat/conversations/{id} - Contrat

**Sortie attendue** (DOIT inclure les messages):
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "title": "Titre",
    "timestamp": "2026-01-09T10:00:00Z",
    "isActive": true,
    "model": { "id": "adha-1", ... },
    "context": [],
    "messages": [
      {
        "id": "msg-1",
        "sender": "user",  // Mapper depuis role: 'user'
        "content": "Question de l'utilisateur",
        "timestamp": "2026-01-09T10:00:00Z"
      },
      {
        "id": "msg-2", 
        "sender": "bot",   // Mapper depuis role: 'assistant'
        "content": "Réponse de ADHA",
        "timestamp": "2026-01-09T10:00:05Z",
        "likes": 0,
        "dislikes": 0
      }
    ]
  }
}
```

**⚠️ IMPORTANT**: Le champ `sender` du frontend correspond au champ `role` du backend:
- `role: 'user'` → `sender: 'user'`
- `role: 'assistant'` → `sender: 'bot'`
- `role: 'system'` → Ne pas retourner au frontend

### WebSocket /chat - Événements Attendus

**Après POST /chat/stream**, le frontend s'abonne et attend:

```javascript
// 1. Chunks de texte (pendant la génération)
socket.on('adha.stream.chunk', {
  requestMessageId: "uuid-message-bot",
  conversationId: "uuid-conversation",
  type: "chunk",
  content: "Bout de texte...",
  chunkId: 1
});

// 2. Fin du stream (message complet)
socket.on('adha.stream.end', {
  requestMessageId: "uuid-message-bot",
  conversationId: "uuid-conversation", 
  type: "end",
  content: "Texte complet de la réponse...",
  chunkId: 45,
  totalChunks: 44,
  journalEntry: { ... }  // Si writeMode=true
});

// 3. En cas d'erreur
socket.on('adha.stream.error', {
  requestMessageId: "uuid-message-bot",
  conversationId: "uuid-conversation",
  type: "error",
  content: "Message d'erreur"
});
```

---

## Data Structures (Actuelles dans le Code)

### Message

```typescript
interface Message {
  id: string;
  sender: 'user' | 'bot';
  content: string;
  timestamp: string; // ISO 8601 format
  likes?: number;
  dislikes?: number;
  isEditing?: boolean;
  attachment?: {
    name: string;
    type: string;
    content: string; // base64
  };
}
```

### Conversation

```typescript
interface Conversation {
  id: string;
  title: string;
  timestamp: string; // ISO 8601 format
  messages: Message[];
  isActive: boolean;
  model: AIModel;
  context: string[];
}
```

### AIModel

```typescript
interface AIModel {
  id: string;
  name: string;
  description: string;
  capabilities: string[];
  contextLength: number;
}

// Modèles actuellement définis
const AI_MODELS = [
  {
    id: 'adha-1',
    name: 'Adha 1',
    description: 'Modèle de base pour la comptabilité générale',
    capabilities: ['Comptabilité générale', 'Écritures simples', 'Rapprochements'],
    contextLength: 4096
  },
  {
    id: 'adha-fisk',
    name: 'Adha Fisk',
    description: 'Spécialisé en fiscalité et déclarations',
    capabilities: ['Fiscalité', 'TVA', 'Déclarations fiscales', 'Optimisation fiscale'],
    contextLength: 8192
  },
  {
    id: 'adha-o1',
    name: 'Adha O1',
    description: 'Version avancée pour l\'analyse financière',
    capabilities: ['Analyse financière', 'Ratios', 'Prévisions', 'Tableaux de bord'],
    contextLength: 16384
  }
];
```

## Implémentation Frontend

### Hooks Utilisés
- `useChatStore`: Store Zustand pour l'état global du chat avec appels API
- `useChatMode`: Gestion du mode floating/fullscreen
- `useAdhaWriteMode`: Toggle entre mode chat et mode écriture comptable

### Stockage
- **localStorage**: Persistance des conversations via Zustand persist
- **Synchronisation**: Envoi automatique en arrière-plan vers l'API
- **Mode hors ligne**: Fallback vers données mock si API indisponible

### Workflow de Réponse IA
1. **Utilisateur envoie message** → `useChatStore.addMessage()`
2. **Envoi vers API** → `chatApi.sendMessage()` via `/chat/message`
3. **Backend traite** → IA génère la réponse
4. **Réponse affichée** → Message bot ajouté à la conversation
5. **Fallback si erreur** → Utilise `mockChatResponses.ts` (patterns de mots-clés)

### Mode Écriture ADHA
- **État**: Géré par `useAdhaWriteMode` hook (Zustand avec persist)
- **Toggle**: Switch Chat ↔ Écriture ADHA dans l'UI
- **Intégration**: Paramètre `writeMode` envoyé à l'API
- **Résultat**: Backend retourne `journalEntry` en plus du message
- **Validation**: Écriture proposée ajoutée aux agent entries

## API Endpoints

### Send Message

Envoie un message et reçoit une réponse de l'assistant. Si `conversationId` n'est pas fourni, une nouvelle conversation est automatiquement créée.

**URL:** `POST /chat` ou `POST /chat/message`

**Method:** `POST`

**Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "conversationId": "conv-123",  // Optionnel - si absent, nouvelle conversation créée
  "message": {
    "content": "Comment calculer l'amortissement linéaire ?",
    "attachment": {
      "name": "facture.pdf",
      "type": "application/pdf",
      "content": "base64-encoded-content"
    }
  },
  "modelId": "adha-1",
  "writeMode": false,
  "context": ["fiscal-year-2024"]
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "message": {
      "id": "msg-6",
      "sender": "bot",
      "content": "Pour calculer l'amortissement linéaire...",
      "timestamp": "2026-01-09T10:15:30Z",
      "likes": 0,
      "dislikes": 0
    },
    "conversationId": "conv-123",
    "journalEntry": null
  }
}
```

> **Note**: Si `conversationId` était absent dans la requête, le champ `conversationId` de la réponse contiendra l'ID de la nouvelle conversation créée.

### Get Conversations

Récupère la liste des conversations de l'utilisateur connecté.

**URL:** `GET /chat/conversations`

**Method:** `GET`

**Response:** `200 OK`
```json
{
  "success": true,
  "data": [
    {
      "id": "conv-123",
      "title": "Assistance comptabilité SYSCOHADA",
      "timestamp": "2026-01-09T10:30:45Z",
      "isActive": true,
      "model": {
        "id": "adha-1",
        "name": "Adha 1",
        "description": "Modèle de base pour la comptabilité générale",
        "capabilities": ["Comptabilité générale", "Écritures simples", "Rapprochements"],
        "contextLength": 4096
      },
      "context": ["fiscal-year-2024", "SYSCOHADA"],
      "messages": []
    }
  ]
}
```

> **Note**: La liste des messages est vide dans cette réponse. Utilisez `GET /chat/conversations/{id}` pour récupérer les messages d'une conversation.

### Get Conversation History

Récupère le détail d'une conversation avec tous ses messages.

**URL:** `GET /chat/conversations/{id}`

**Method:** `GET`

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "id": "conv-123",
    "title": "Assistance comptabilité SYSCOHADA",
    "timestamp": "2026-01-09T10:30:45Z",
    "isActive": true,
    "model": {
      "id": "adha-1",
      "name": "Adha 1",
      "description": "Modèle de base pour la comptabilité générale",
      "capabilities": ["Comptabilité générale", "Écritures simples", "Rapprochements"],
      "contextLength": 4096
    },
    "context": ["fiscal-year-2024", "SYSCOHADA"],
    "messages": [
      {
        "id": "msg-1",
        "sender": "user",
        "content": "Comment enregistrer une facture d'achat avec TVA ?",
        "timestamp": "2026-01-09T10:30:45Z"
      },
      {
        "id": "msg-2",
        "sender": "bot",
        "content": "Pour enregistrer une facture d'achat avec TVA dans le système SYSCOHADA...",
        "timestamp": "2026-01-09T10:31:30Z",
        "likes": 1
      }
    ]
  }
}
```

### Get Available Models

Récupère la liste des modèles IA disponibles.

**URL:** `GET /chat/models`

**Method:** `GET`

**Response:** `200 OK`
```json
{
  "success": true,
  "data": [
    {
      "id": "adha-1",
      "name": "Adha 1",
      "description": "Modèle de base pour la comptabilité générale",
      "capabilities": ["Comptabilité générale", "Écritures simples", "Rapprochements"],
      "contextLength": 4096
    },
    {
      "id": "adha-fisk",
      "name": "Adha Fisk",
      "description": "Spécialisé en fiscalité et déclarations",
      "capabilities": ["Fiscalité", "TVA", "Déclarations fiscales", "Optimisation fiscale"],
      "contextLength": 8192
    },
    {
      "id": "adha-o1",
      "name": "Adha O1",
      "description": "Version avancée pour l'analyse financière",
      "capabilities": ["Analyse financière", "Ratios", "Prévisions", "Tableaux de bord"],
      "contextLength": 16384
    }
  ]
}
```

### Delete Conversation

Supprime une conversation et tous ses messages.

**URL:** `DELETE /chat/conversations/{id}`

**Method:** `DELETE`

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Conversation deleted successfully"
}
```

---

## ⚠️ Endpoints Obsolètes (DEPRECATED)

> **Ces endpoints sont maintenus pour la rétrocompatibilité mais ne doivent pas être utilisés pour de nouvelles intégrations.**

### POST /:id/message ⚠️ DEPRECATED

> **Utiliser `POST /chat` à la place**

Ajoute un message à une conversation existante.

**URL:** `POST /chat/{id}/message`

**Method:** `POST`

### GET /:id/history ⚠️ DEPRECATED

> **Utiliser `GET /chat/conversations/{id}` à la place**

Récupère l'historique d'une conversation.

**URL:** `GET /chat/{id}/history`

**Method:** `GET`

### GET /:id/usage (Admin Only)

Récupère les statistiques d'utilisation de tokens pour une conversation.

**URL:** `GET /chat/{id}/usage`

**Method:** `GET`

**Rôles autorisés:** `admin`, `accountant`

**Response:** `200 OK`
```json
{
  "success": true,
  "usage": {
    "totalInputTokens": 1500,
    "totalOutputTokens": 3200,
    "totalTokens": 4700,
    "estimatedCost": 0.047
  }
}
```

### GET /context/:companyId ⚠️ DEPRECATED

Récupère le contexte comptable pour l'IA.

**URL:** `GET /chat/context/{companyId}?fiscalYear=2024&accountingStandard=SYSCOHADA`

**Method:** `GET`

**Rôles autorisés:** `admin`, `accountant`

**Query Parameters:**
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `fiscalYear` | string | ✅ | Année fiscale (ex: "2024") |
| `accountingStandard` | enum | ✅ | Standard comptable (SYSCOHADA, IFRS, etc.) |

---

## Mode d'Écriture ADHA

### État Actuel
Le mode d'écriture ADHA est géré côté frontend par le hook `useAdhaWriteMode` et côté backend par le paramètre `writeMode`. Il bascule entre :
- **Mode Chat Normal**: Conversation standard avec l'assistant
- **Mode Écriture**: Transformation des messages en propositions d'écritures comptables

### Intégration avec Agent Entries
Le mode écriture est lié au système `agentEntries` pour générer automatiquement des écritures comptables à partir des conversations.

### Requête avec Mode Écriture

### Requête avec Mode Écriture

**Paramètre `writeMode: true` dans les requêtes de message:**
```json
{
  "conversationId": "conv-123",
  "message": {
    "content": "Facture Orange 120€ TTC (100€ HT + 20€ TVA)",
    "attachment": {
      "name": "facture-orange.pdf",
      "type": "application/pdf",
      "content": "base64-encoded-content"
    }
  },
  "modelId": "adha-1",
  "writeMode": true,
  "context": ["fiscal-year-2024"]
}
```

### Réponse avec Écriture Proposée

**Réponse avec écriture proposée:**
```json
{
  "success": true,
  "data": {
    "message": {
      "id": "msg-7",
      "sender": "bot",
      "content": "J'ai analysé votre facture et propose cette écriture comptable :",
      "timestamp": "2026-01-09T15:45:30Z"
    },
    "conversationId": "conv-123",
    "journalEntry": {
      "id": "agent-123",
      "date": "2026-01-09",
      "journalType": "purchases",
      "reference": "FACTURE-ORANGE-01-2026",
      "description": "Facture téléphone Orange",
      "status": "draft",
      "source": "agent",
      "agentId": "adha-1",
      "validationStatus": "pending",
      "lines": [
        {
          "accountCode": "626100",
          "accountName": "Frais de télécommunication",
          "debit": 100,
          "credit": 0,
          "description": "Frais téléphone Orange HT"
        },
        {
          "accountCode": "445660",
          "accountName": "TVA déductible",
          "debit": 20,
          "credit": 0,
          "description": "TVA sur frais téléphone"
        },
        {
          "accountCode": "401100",
          "accountName": "Fournisseurs",
          "debit": 0,
          "credit": 120,
          "description": "Orange - Facture téléphone"
        }
      ],
      "totalDebit": 120,
      "totalCredit": 120,
      "totalVat": 20
    }
  }
}
```

## Base de Données

### Tables

#### Table `chats`
```sql
CREATE TABLE chats (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  "kiotaId" VARCHAR NOT NULL,
  title VARCHAR NOT NULL,
  "isActive" BOOLEAN DEFAULT true,
  "userId" UUID NOT NULL,
  "companyId" UUID,
  context JSONB,
  metadata JSONB,
  "createdAt" TIMESTAMP DEFAULT NOW(),
  "updatedAt" TIMESTAMP DEFAULT NOW()
);
```

#### Table `chat_messages`
```sql
CREATE TABLE chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  "chatId" UUID NOT NULL REFERENCES chats(id),
  role VARCHAR NOT NULL, -- 'user', 'assistant', 'system'
  content TEXT NOT NULL,
  "tokensUsed" INTEGER DEFAULT 0,
  metadata JSONB,
  source VARCHAR,
  likes INTEGER DEFAULT 0,
  dislikes INTEGER DEFAULT 0,
  "isEditing" BOOLEAN DEFAULT false,
  timestamp TIMESTAMP DEFAULT NOW()
);
```

### Relations
- `Chat` → `ChatMessage`: OneToMany (une conversation a plusieurs messages)
- `ChatMessage` → `Chat`: ManyToOne (un message appartient à une conversation)

## Composants Frontend Existants

### Pages
- `ChatPage`: Page plein écran pour le chat
- Intégrée dans le router avec route `/chat`

### Composants
- `ChatContainer`: Conteneur principal gérant les modes floating/fullscreen
- `ChatWindow`: Fenêtre de chat avec liste des messages
- `ChatMessage`: Composant pour afficher un message individuel
- `ConversationList`: Liste des conversations sauvegardées
- `MessageContent`: Rendu du contenu des messages avec support markdown/code
- `EmojiPicker`: Sélecteur d'emojis pour les réactions
- `TypingIndicator`: Indicateur de saisie pendant la réponse

### Hooks de Gestion d'État
- `useChatStore`: Store Zustand principal avec persistance
- `useChat`: Hook simple pour une conversation
- `useChatMode`: Gestion des modes d'affichage
- `useAdhaWriteMode`: Activation/désactivation du mode écriture

### Données Mock (Fallback)
- `mockChatResponses.ts`: Système de réponses basé sur mots-clés
- Patterns pour: code Python, formules mathématiques, graphiques, tableaux
- **Utilisation**: Seulement si API backend indisponible
- Délai simulé: 1.5 secondes

## Notes d'Implémentation

- ✅ **Backend implémenté**: API REST complète avec persistance PostgreSQL
- ✅ **Entités liées**: `Chat` ↔ `ChatMessage` via relations TypeORM
- ✅ **Architecture découplée**: Frontend → API Gateway → Accounting Service
- ✅ **Pas d'OpenAI direct**: Tout passe par l'API backend
- ✅ **Mode hors ligne**: Fallback automatique vers mock data côté frontend
- ✅ **Synchronisation**: Sauvegarde automatique en base de données
- ✅ **Toggle simple**: Chat vs Écriture ADHA (pas de sélecteur de modèle)
- ✅ **Création automatique**: Nouvelle conversation si `conversationId` absent
- ✅ **Streaming WebSocket**: Réponses IA en temps réel via WebSocket (namespace: `/chat`)
- ✅ **Endpoint Streaming**: `POST /chat/stream` pour envoi non-bloquant
- 📝 **Modèle unique**: ADHA géré côté backend, frontend n'a plus de sélecteur

---

## 🚀 Streaming en Temps Réel (WebSocket)

> **Mise à jour Janvier 2026**: Nouveau système de streaming WebSocket pour une expérience utilisateur optimale.

### Vue d'ensemble

Le système de streaming permet au frontend de recevoir les réponses de l'IA **en temps réel**, chunk par chunk, au lieu d'attendre la réponse complète. Cela améliore significativement l'expérience utilisateur avec un temps de première réponse < 500ms.

### Architecture Streaming

```
┌─────────────────┐      POST /chat/stream      ┌─────────────────────┐
│    Frontend     │ ──────────────────────────> │  Accounting Service │
│                 │      (retour immédiat)      │                     │
│                 │                              │                     │
│                 │      WebSocket /chat        │                     │
│                 │ <────────────────────────── │   ChatGateway       │
│  (receive chunks)                             │        ↑            │
└─────────────────┘                              │   StreamingConsumer │
                                                │        ↑            │
                                                │   Kafka Stream      │
                                                │        ↑            │
                                                └────────┼────────────┘
                                                         │
                                                ┌────────┴────────────┐
                                                │   ADHA AI Service   │
                                                │  (génère chunks)    │
                                                └─────────────────────┘
```

### Endpoint Streaming (Nouveau)

#### POST /chat/stream

Envoie un message et **retourne immédiatement** sans attendre la réponse IA. Les réponses arrivent via WebSocket.

**URL:** `POST /chat/stream`

**Method:** `POST`

**Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "conversationId": "conv-123",
  "message": {
    "content": "Comment calculer l'amortissement linéaire ?",
    "attachment": {
      "name": "facture.pdf",
      "type": "application/pdf",
      "content": "base64-encoded-content"
    }
  },
  "modelId": "adha-1",
  "writeMode": false,
  "context": ["fiscal-year-2024"]
}
```

**Response:** `201 Created` (retour immédiat)
```json
{
  "success": true,
  "data": {
    "messageId": "msg-uuid-123",
    "conversationId": "conv-123",
    "userMessageId": "user-msg-uuid-456"
  },
  "websocket": {
    "namespace": "/chat",
    "events": {
      "subscribe": "subscribe_conversation",
      "chunk": "adha.stream.chunk",
      "end": "adha.stream.end",
      "error": "adha.stream.error",
      "tool": "adha.stream.tool"
    }
  }
}
```

> **Note**: Si `conversationId` n'est pas fourni, une nouvelle conversation est créée et son ID est retourné.

### WebSocket Gateway

#### Configuration de Connexion

**Namespace:** `/chat`

**URL:** `wss://api.wanzo.com/accounting/chat` ou `ws://localhost:8000/accounting/chat` (via Gateway) ou `ws://localhost:3003/chat` (direct)

**CORS Origins:**
- `http://localhost:3000`
- `http://localhost:5173`
- `http://localhost:8000`
- `https://wanzo.io`
- `https://*.wanzo.io`

**Authentification:**
```javascript
// Option 1: Header Authorization
const socket = io('/chat', {
  extraHeaders: {
    Authorization: `Bearer ${token}`
  }
});

// Option 2: Query parameter
const socket = io('/chat?token=' + token);

// Option 3: Auth object
const socket = io('/chat', {
  auth: {
    token: token
  }
});
```

#### Événements Client → Serveur

| Événement | Payload | Description |
|-----------|---------|-------------|
| `subscribe_conversation` | `{ conversationId: string }` | S'abonner aux updates d'une conversation |
| `unsubscribe_conversation` | `{ conversationId: string }` | Se désabonner d'une conversation |

**Exemple:**
```javascript
// S'abonner à une conversation
socket.emit('subscribe_conversation', { conversationId: 'conv-123' });

// Réponse
socket.on('subscribe_conversation', (response) => {
  console.log(response); // { success: true, conversationId: 'conv-123' }
});
```

#### Événements Serveur → Client

| Événement | Payload | Description |
|-----------|---------|-------------|
| `adha.stream.chunk` | `StreamingChunkPayload` | Nouveau chunk de texte |
| `adha.stream.end` | `StreamingChunkPayload` | Fin du stream avec contenu complet |
| `adha.stream.error` | `StreamingChunkPayload` | Erreur pendant le streaming |
| `adha.stream.tool` | `StreamingChunkPayload` | Appel/résultat d'outil IA |

### Interface StreamingChunkPayload

```typescript
interface StreamingChunkPayload {
  requestMessageId: string;      // ID du message pour suivre le stream
  conversationId: string;        // ID de la conversation
  type: 'chunk' | 'end' | 'error' | 'tool_call' | 'tool_result' | 'cancelled' | 'heartbeat';
  content: string;               // Contenu du chunk
  chunkId: number;               // Numéro de séquence (commence à 1)
  totalChunks?: number;          // Nombre total (uniquement dans 'end')
  journalEntry?: JournalEntry;   // Écriture comptable (si writeMode=true)
  suggestedActions?: Array<{     // Actions suggérées (format standardisé)
    type: string;
    label?: string;
    payload: any;
  }>;
  processingDetails?: {
    totalChunks?: number;
    contentLength?: number;
    aiModel?: string;
    tokensUsed?: number;
    processingTime?: number;     // Temps de traitement en ms
  };
  metadata?: Record<string, any>;
}
```

### ⚠️ SÉQUENCE CRITIQUE - Ordre des Opérations

> **IMPORTANT**: Le frontend DOIT suivre cette séquence exacte pour recevoir les chunks.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  SÉQUENCE OBLIGATOIRE POUR LE STREAMING                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. CONNEXION WebSocket (une seule fois au démarrage)                   │
│     socket = io('ws://localhost:3003/chat', { auth: { token } })        │
│                                                                         │
│  2. ATTENDRE la connexion                                               │
│     socket.on('connect', () => { ... })                                 │
│                                                                         │
│  3. Si conversationId existant → S'ABONNER                              │
│     socket.emit('subscribe_conversation', { conversationId })           │
│                                                                         │
│  4. APPELER l'API /chat/stream                                          │
│     POST /chat/stream → reçoit { messageId, conversationId }            │
│                                                                         │
│  5. Si nouvelle conversation → S'ABONNER avec le nouveau conversationId │
│     socket.emit('subscribe_conversation', { conversationId: newId })    │
│                                                                         │
│  6. RECEVOIR les chunks                                                 │
│     socket.on('adha.stream.chunk', ...) → afficher progressivement      │
│     socket.on('adha.stream.end', ...) → message complet                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Exemple d'Intégration Frontend Complet

```typescript
import { io, Socket } from 'socket.io-client';

class ChatStreamingService {
  private socket: Socket;
  private currentMessage: string = '';

  constructor(token: string) {
    // 1. Connexion WebSocket
    this.socket = io('/chat', {
      auth: { token },
      transports: ['websocket']
    });

    // 2. Écouter les événements de streaming
    this.socket.on('adha.stream.chunk', this.handleChunk.bind(this));
    this.socket.on('adha.stream.end', this.handleEnd.bind(this));
    this.socket.on('adha.stream.error', this.handleError.bind(this));
    this.socket.on('adha.stream.tool', this.handleTool.bind(this));
  }

  // Envoyer un message avec streaming
  async sendMessage(content: string, conversationId?: string, writeMode = false) {
    // Reset
    this.currentMessage = '';

    // S'abonner à la conversation si on a un ID
    if (conversationId) {
      this.socket.emit('subscribe_conversation', { conversationId });
    }

    // Appel API streaming (retourne immédiatement)
    const response = await fetch('/accounting/api/v1/chat/stream', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        conversationId,
        message: { content },
        writeMode,
        modelId: 'adha-1'
      })
    });

    const result = await response.json();
    
    // S'abonner avec le nouveau conversationId si créé
    if (!conversationId && result.data.conversationId) {
      this.socket.emit('subscribe_conversation', { 
        conversationId: result.data.conversationId 
      });
    }

    return result.data;
  }

  private handleChunk(payload: StreamingChunkPayload) {
    // Accumuler le contenu
    this.currentMessage += payload.content;
    
    // Mettre à jour l'UI progressivement
    this.onChunkReceived?.(payload.content, this.currentMessage, payload.chunkId);
  }

  private handleEnd(payload: StreamingChunkPayload) {
    // Message complet reçu
    this.onMessageComplete?.(
      payload.content,
      payload.journalEntry,
      payload.processingDetails
    );
  }

  private handleError(payload: StreamingChunkPayload) {
    this.onError?.(payload.content);
  }

  private handleTool(payload: StreamingChunkPayload) {
    // L'IA utilise un outil (calcul, recherche, etc.)
    this.onToolUsed?.(payload.type, payload.content);
  }

  // Callbacks à définir par l'utilisateur
  onChunkReceived?: (chunk: string, accumulated: string, chunkId: number) => void;
  onMessageComplete?: (content: string, journalEntry?: any, details?: any) => void;
  onError?: (error: string) => void;
  onToolUsed?: (type: string, content: string) => void;
}

// Utilisation
const chatService = new ChatStreamingService(authToken);

chatService.onChunkReceived = (chunk, accumulated, chunkId) => {
  // Afficher le texte progressivement
  document.getElementById('message').textContent = accumulated;
};

chatService.onMessageComplete = (content, journalEntry, details) => {
  console.log(`Message complet en ${details?.processingTime}ms`);
  if (journalEntry) {
    // Afficher l'écriture comptable proposée
    showJournalEntry(journalEntry);
  }
};

chatService.onError = (error) => {
  showErrorToast(error);
};

// Envoyer un message
await chatService.sendMessage(
  'Créer une écriture pour facture Orange 120€ TTC',
  'conv-123',
  true // writeMode
);
```

### Exemple de Chunk de Contenu

```json
{
  "requestMessageId": "msg-uuid-123",
  "conversationId": "conv-789",
  "type": "chunk",
  "content": "Pour calculer l'amortissement",
  "chunkId": 1,
  "metadata": {
    "source": "adha_ai_service",
    "streamVersion": "1.0.0"
  }
}
```

### Exemple de Message de Fin

```json
{
  "requestMessageId": "msg-uuid-123",
  "conversationId": "conv-789",
  "type": "end",
  "content": "Pour calculer l'amortissement linéaire, vous devez diviser le coût d'acquisition par la durée d'utilisation...",
  "chunkId": 45,
  "totalChunks": 44,
  "journalEntry": {
    "id": "agent-abc123",
    "date": "2026-01-09",
    "journalType": "purchases",
    "reference": "AUTO-XY12",
    "description": "Écriture générée par ADHA",
    "status": "draft",
    "lines": [...]
  },
  "processingDetails": {
    "totalChunks": 44,
    "contentLength": 856,
    "aiModel": "adha-1",
    "processingTime": 1523
  },
  "metadata": {
    "source": "adha_ai_service",
    "streamVersion": "1.0.0",
    "streamComplete": true
  }
}
```

### Métriques de Performance

| Métrique | Valeur Typique |
|----------|----------------|
| Temps premier chunk | < 500ms |
| Chunks par réponse | 40-70 |
| Temps total | 1-3 secondes |
| Latence par chunk | ~30-50ms |

### Bonnes Pratiques

1. **Affichage progressif**: Mettre à jour l'UI à chaque chunk reçu
2. **Indicateur de saisie**: Afficher "ADHA écrit..." jusqu'au premier chunk
3. **Gestion des erreurs**: Toujours écouter `adha.stream.error`
4. **Reconnexion**: Implémenter une logique de reconnexion WebSocket
5. **Timeout**: 30s recommandé côté client
6. **Cleanup**: Se désabonner des conversations quand on quitte

### ❌ Erreurs Courantes à Éviter

| Erreur | Conséquence | Solution |
|--------|-------------|----------|
| Appeler `/chat/stream` sans connexion WebSocket | Chunks perdus | Connecter WebSocket au démarrage de l'app |
| Appeler `/chat/stream` avant `subscribe_conversation` | Chunks perdus | S'abonner AVANT l'appel API |
| Mauvais namespace (`/` au lieu de `/chat`) | Connexion échoue | Utiliser `io('/chat', ...)` |
| Token manquant | userId = 'anonymous' | Passer token via `auth.token` |
| Oublier d'écouter les événements | Rien ne s'affiche | Configurer listeners avant d'envoyer |

### 🔍 Debug: Vérifier la Connexion WebSocket

```typescript
// Code de debug pour vérifier la connexion

// ═══════════════════════════════════════════════════════════════════
// CONNEXION VIA API GATEWAY (recommandé pour production)
// ═══════════════════════════════════════════════════════════════════
const socket = io('ws://localhost:8000', {
  path: '/accounting/chat',  // ⚠️ Le path du proxy, PAS /socket.io !
  auth: { token: 'Bearer YOUR_JWT_TOKEN' },
  transports: ['websocket'],
});

// Pour d'autres services (futur):
// path: '/portfolio/chat'  → portfolio-service
// path: '/commerce/chat'   → commerce-service

// ═══════════════════════════════════════════════════════════════════
// CONNEXION DIRECTE (dev uniquement, sans passer par API Gateway)
// ═══════════════════════════════════════════════════════════════════
// const socket = io('ws://localhost:3003/chat', {
//   auth: { token: 'Bearer YOUR_JWT_TOKEN' },
//   transports: ['websocket'],
// });

socket.on('connect', () => {
  console.log('✅ WebSocket connecté, ID:', socket.id);
});

socket.on('connect_error', (error) => {
  console.error('❌ Erreur de connexion WebSocket:', error.message);
  // Causes fréquentes:
  // - "websocket error": Le proxy n'est pas configuré ou le service est down
  // - "Invalid namespace": Le path est incorrect
  // - "Authentication error": Token invalide
});

socket.on('disconnect', (reason) => {
  console.warn('⚠️ WebSocket déconnecté:', reason);
});

// Vérifier la subscription
socket.emit('subscribe_conversation', { conversationId: 'test-conv-id' }, (response) => {
  console.log('📡 Subscription response:', response);
  // Attendu: { success: true, conversationId: 'test-conv-id' }
});
```

### 📊 Logs Backend à Observer

Quand le frontend est correctement connecté, les logs backend affichent :

```
🔌 Client abc123 CONNECTED for user google-oauth2|xxx - Total connections: 1
✅ Client abc123 SUBSCRIBED to conversation conv-xyz - Room has 1 subscribers
📤 Sending chunk chunk 1 to 1 clients in room conversation:conv-xyz
✅ Sent adha.stream.chunk for conversation conv-xyz: Bonjour...
```

Si vous voyez `to 0 clients`, le frontend n'est pas connecté/abonné.

---

## 🎙️ Mode Audio Duplex (v2.4.0)

> **Nouveauté**: Conversation vocale bidirectionnelle avec ADHA pour une expérience mains-libres.

### Architecture Audio

```
┌───────────────────┐     ┌─────────────────────┐     ┌───────────────────────┐
│   Frontend        │     │  API Gateway        │     │  ADHA AI Service      │
│   (Microphone)    │────▶│  /accounting/adha   │────▶│  AudioService         │
│                   │◀────│                     │◀────│  (Whisper + TTS)      │
│   (Haut-parleur)  │     │                     │     │                       │
└───────────────────┘     └─────────────────────┘     └───────────────────────┘
```

### Endpoints Audio

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/adha-ai/audio/transcribe/` | POST | Transcription audio → texte (Whisper) |
| `/adha-ai/audio/synthesize/` | POST | Synthèse texte → audio (TTS) |
| `/adha-ai/audio/duplex/` | POST | Mode duplex complet (STT + Chat IA + TTS) |
| `/adha-ai/audio/voices/` | GET | Liste des voix disponibles |

### Modes Audio Disponibles

| Mode | Description | Usage |
|------|-------------|-------|
| `transcribe_only` | STT uniquement | Dictée vocale |
| `speak_only` | TTS uniquement | Lecture de texte |
| `full_duplex` | STT + Chat + TTS | Conversation complète |
| `stream_duplex` | Full duplex streaming | Temps réel |

### Formats Audio Supportés

- **Entrée**: WebM, MP3, WAV, M4A, FLAC, OGG
- **Sortie**: MP3, Opus, AAC, FLAC
- **Taille max**: 25 MB

### Voix TTS Disponibles

| Voix | Caractéristique |
|------|-----------------|
| `alloy` | Neutre, polyvalente |
| `echo` | Masculine, profonde |
| `fable` | Narrative, expressive |
| `onyx` | Masculine, autoritaire |
| `nova` | Féminine, naturelle ⭐ (défaut) |
| `shimmer` | Féminine, douce |

### Exemple: Mode Duplex Complet

**Request** (multipart/form-data):
```bash
POST /accounting/adha-ai/audio/duplex/
Authorization: Bearer <token>
Content-Type: multipart/form-data

audio: <fichier_audio.webm>
company_id: "company-123"
context: {"fiscalYear": "2024", "accountingStandard": "SYSCOHADA"}
voice: "nova"
language: "fr"
```

**Response**:
```json
{
  "success": true,
  "transcription": {
    "text": "Quel est le solde du compte caisse?",
    "language": "fr",
    "duration_seconds": 3.5,
    "word_count": 6
  },
  "chat_response": {
    "text": "Le solde actuel du compte caisse (571000) est de 2,450,000 CDF au 14 janvier 2026.",
    "conversation_id": "conv-xyz"
  },
  "audio_response": {
    "audio_base64": "UklGRiQA...",
    "format": "mp3",
    "duration_seconds": 5.2,
    "voice": "nova"
  },
  "metrics": {
    "total_processing_time_ms": 2800,
    "transcription_time_ms": 800,
    "chat_time_ms": 1500,
    "synthesis_time_ms": 500,
    "estimated_cost_usd": 0.0045
  }
}
```

### Intégration Frontend (React)

```typescript
// Hook pour mode audio duplex
const useAudioDuplex = (token: string) => {
  const [isRecording, setIsRecording] = useState(false);
  const [audioResponse, setAudioResponse] = useState<string | null>(null);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  
  const startRecording = async () => {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const recorder = new MediaRecorder(stream, { mimeType: 'audio/webm' });
    const chunks: Blob[] = [];
    
    recorder.ondataavailable = (e) => chunks.push(e.data);
    recorder.onstop = async () => {
      const audioBlob = new Blob(chunks, { type: 'audio/webm' });
      await sendToDuplex(audioBlob);
    };
    
    mediaRecorderRef.current = recorder;
    recorder.start();
    setIsRecording(true);
  };
  
  const sendToDuplex = async (audioBlob: Blob) => {
    const formData = new FormData();
    formData.append('audio', audioBlob, 'recording.webm');
    formData.append('company_id', 'company-123');
    formData.append('voice', 'nova');
    
    const response = await fetch('/accounting/adha-ai/audio/duplex/', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${token}` },
      body: formData
    });
    
    const data = await response.json();
    if (data.success && data.audio_response?.audio_base64) {
      playAudioResponse(data.audio_response.audio_base64);
    }
  };
  
  const playAudioResponse = (base64: string) => {
    const audio = new Audio(`data:audio/mp3;base64,${base64}`);
    audio.play();
    setAudioResponse(base64);
  };
  
  return { isRecording, startRecording, stopRecording, audioResponse };
};
```

---

## 📄 Génération de Documents (v2.4.0)

> **Nouveauté**: ADHA peut générer des documents comptables (PDF, Excel, Word) et les uploader sur Cloudinary.

### Architecture Document Generation

```
┌───────────────────┐     ┌─────────────────────┐     ┌───────────────────────┐
│   Chat Message    │────▶│  ADHA AI Service    │────▶│  Cloudinary           │
│   (writeMode)     │     │  DocumentGenerator  │     │  (Storage)            │
│                   │◀────│                     │◀────│                       │
│   URL Document    │     │  (PDF/Excel/Word)   │     │                       │
└───────────────────┘     └─────────────────────┘     └───────────────────────┘
```

### Endpoints Documents

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/adha-ai/documents/generate/` | POST | Génération générique |
| `/adha-ai/documents/report/pdf/` | POST | Rapport financier PDF |
| `/adha-ai/documents/export/excel/` | POST | Export données Excel |
| `/adha-ai/documents/journal-entry/` | POST | Écriture comptable formatée |

### Types de Documents Générables

| Type | Format | Description |
|------|--------|-------------|
| `financial_report` | PDF | Rapport financier complet |
| `journal_entry` | PDF/Excel | Écriture comptable |
| `balance_sheet` | PDF/Excel | Bilan comptable |
| `income_statement` | PDF | Compte de résultat |
| `cash_flow` | PDF/Excel | Tableau de flux de trésorerie |
| `analysis_report` | PDF | Rapport d'analyse ADHA |

### Génération via Mode Écriture

Quand `writeMode: true` et qu'ADHA génère une écriture comptable, un document peut être automatiquement créé:

**Request**:
```json
{
  "conversationId": "conv-123",
  "message": { "content": "Génère le PDF de cette écriture" },
  "writeMode": true,
  "generateDocument": {
    "enabled": true,
    "format": "pdf",
    "type": "journal_entry"
  }
}
```

**Response avec URL Document**:
```json
{
  "success": true,
  "data": {
    "message": {
      "id": "msg-456",
      "content": "Voici l'écriture comptable pour la facture Orange...",
      "timestamp": "2026-01-14T10:30:00Z"
    },
    "journalEntry": {
      "id": "je-789",
      "reference": "AUTO-A1B2",
      "lines": [...]
    },
    "document": {
      "id": "doc_1705226400",
      "format": "pdf",
      "type": "journal_entry",
      "cloudinary_url": "https://res.cloudinary.com/wanzo/adha-documents/journal_entry_20260114.pdf",
      "filename": "ecriture_comptable_20260114_103000.pdf",
      "size_bytes": 45678
    }
  }
}
```

### Export Excel des Données

**Request**:
```json
POST /accounting/adha-ai/documents/export/excel/
{
  "company_id": "company-123",
  "type": "journal_entries",
  "filters": {
    "dateFrom": "2026-01-01",
    "dateTo": "2026-01-31",
    "journalType": "purchases"
  },
  "columns": ["date", "reference", "description", "debit", "credit"]
}
```

**Response**:
```json
{
  "success": true,
  "document": {
    "id": "doc_export_123",
    "format": "xlsx",
    "cloudinary_url": "https://res.cloudinary.com/wanzo/adha-documents/export_journals_202601.xlsx",
    "rows_count": 156,
    "size_bytes": 89234
  }
}
```

---

## 📎 Pièces Jointes dans le Chat

### Upload de Pièce Jointe

Le chat supporte l'envoi de fichiers (factures, relevés bancaires, etc.) pour analyse par ADHA.

**Request** (avec pièce jointe):
```json
{
  "conversationId": "conv-123",
  "message": {
    "content": "Peux-tu analyser cette facture?",
    "attachment": {
      "name": "facture-orange-jan2026.pdf",
      "type": "application/pdf",
      "content": "JVBERi0xLjQK..."  // Base64
    }
  },
  "writeMode": true
}
```

### Formats de Pièces Jointes Supportés

| Type | Extensions | Taille Max |
|------|------------|------------|
| Documents | PDF, DOCX, TXT | 10 MB |
| Images | PNG, JPG, JPEG | 5 MB |
| Tableurs | XLSX, CSV | 5 MB |

### Analyse de Document par ADHA

ADHA peut:
1. **Extraire les données** d'une facture (montants, TVA, fournisseur)
2. **Proposer une écriture comptable** basée sur le document
3. **Vérifier la conformité** avec les règles comptables

---

## API Endpoints (Mode Synchrone)

## Error Responses

**Unauthorized (401):**
```json
{
  "success": false,
  "error": "Session expirée"
}
```

**Bad Request (400):**
```json
{
  "success": false,
  "error": "Message content cannot be empty"
}
```

**Not Found (404):**
```json
{
  "success": false,
  "error": "Conversation not found"
}
```

**Other Errors:**
```json
{
  "success": false,
  "error": "Error message description"
}
```
