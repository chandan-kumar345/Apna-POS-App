# System Architecture & Technical Design Document
# 🏗️ Apna POS Multi-Tenant Enterprise Architecture & Data Isolation

**System:** Apna POS (Point of Sale & Restaurant Management System)  
**Document Version:** 3.0.0  
**Target Architecture:** Multi-Tenant Offline-First Hybrid Cloud Architecture  
**Primary Tech Stack:** Flutter (Dart ^3.6.0) | Node.js / Express | MongoDB & Mongoose | Socket.IO | Cloud Firestore  
**Date:** October 2026  
**Status:** Approved Engineering Blueprint  

---

## 1. High-Level System Architecture & Topology

Apna POS is structured as an **Offline-First Multi-Tenant Hybrid System**. The presentation layer runs natively on client devices (Android Mobile/Tablet, Windows Desktop, POS Terminals), interfacing with an enterprise Node.js/Express API Gateway, real-time WebSocket cluster, MongoDB document store, and Cloud Firestore hybrid sync layer.

```mermaid
flowchart TD
    subgraph Client_Tier["🖥️ Client Tier (Flutter Multi-Platform Frontend)"]
        A1["POS Billing Register\n(pos_register_screen.dart)"]
        A2["Table & Floor Manager\n(table_management_screen.dart)"]
        A3["Orders & KDS Terminal\n(orders_screen.dart)"]
        A4["Neumorphic Settings Hub\n(business_settings_hub_screen.dart)"]
        
        subgraph Local_Cache["🔒 Local Isolated Storage"]
            L1["DatabaseService Cache\napna_pos_biz_{bizId}_*"]
            L2["Encrypted Secure Storage\n(Tokens, Hardware Keys)"]
        end
        A1 & A2 & A3 & A4 <--> L1
        A1 & A4 <--> L2
    end

    subgraph Gateway_Tier["🛡️ Network & Gateway Tier"]
        GW["Reverse Proxy / SSL Termination\n(Nginx / Cloudflare)"]
        MW1["Rate Limiter & DDOS Guard"]
        MW2["JWT Authentication Guard\n(authMiddleware.js)"]
        MW3["Tenant Context Interceptor\n(tenantContextMiddleware.js)"]
        GW --> MW1 --> MW2 --> MW3
    end

    subgraph Service_Tier["⚡ Backend Application Services (Node.js / Express)"]
        S_ORD["Order & KOT Service\n(orderService.js)"]
        S_PRD["Product & Menu Service\n(productService.js)"]
        S_TBL["Table & Floor Service\n(tableService.js)"]
        S_CRM["CRM & Loyalty Service\n(customerService.js)"]
        S_SET["Settings & UPI Service\n(businessService.js)"]
        
        MW3 --> S_ORD & S_PRD & S_TBL & S_CRM & S_SET
    end

    subgraph Realtime_Tier["📡 Real-Time WebSocket Cluster (Socket.IO)"]
        SOC["Socket.IO Service (socketService.js)\nJWT Handshake & Cryptographic Room Guard"]
        R_ROOM1["Room: business_BUS101 (Tenant A)"]
        R_ROOM2["Room: business_BUS202 (Tenant B)"]
        SOC --> R_ROOM1
        SOC --> R_ROOM2
    end

    subgraph Data_Tier["🍃 MongoDB Enterprise Database (Tenant Discriminator + Indexes)"]
        PLUGIN["Mongoose Global Tenant Isolation Plugin\n(tenantIsolationPlugin.js - Auto Query Injection)"]
        
        subgraph Collections["🗂️ Indexed Tenant Collections"]
            D_ORD[("orders\n{ businessId: 1, ... }")]
            D_PRD[("products\n{ businessId: 1, ... }")]
            D_TBL[("tables\n{ businessId: 1, ... }")]
            D_CUST[("customers\n{ businessId: 1, ... }")]
            D_SALE[("sales\n{ businessId: 1, ... }")]
        end
        
        S_ORD & S_PRD & S_TBL & S_CRM & S_SET --> PLUGIN --> Collections
    end

    subgraph Cloud_Sync["🔥 Cloud Firestore (Real-Time Subcollections)"]
        FS_RULE["Firestore Security Rules\n(businesses/{bizId}/* strictly checked)"]
        FS_DATA[("Firestore Documents\n/businesses/{bizId}/...")]
        FS_RULE --> FS_DATA
    end

    L1 <==>|REST API (HTTPS + X-Business-ID)| GW
    L1 <==>|WSS (JWT Auth Handshake)| SOC
    L1 <==>|Firebase SDK (Strict Token Auth)| FS_RULE
```

---

## 2. Multi-Tenancy Strategy & Architectural Pattern

### 2.1 Evaluated Architectural Patterns

| Architecture Model | Implementation Mechanism | Pros | Cons | Apna POS Decision |
| :--- | :--- | :--- | :--- | :--- |
| **Model 1: Database-per-Tenant** | Each business has an isolated MongoDB database (e.g., `apna_pos_biz_001`). | Highest physical isolation; zero accidental cross-querying. | Connection pool exhaustion in Node.js with hundreds of tenants; expensive scaling. | Reserved for Enterprise White-Label Franchise tiers. |
| **Model 2: Collection-per-Tenant** | Dynamic collection names per tenant (e.g., `orders_biz_001`). | Separation of physical files on disk. | High MongoDB namespace overhead; schema migrations are extremely complex. | Rejected. |
| **Model 3: Shared Database, Shared Collections with Discriminator Key + Compound B-Tree Indexing + Global Mongoose Guard** | Every document contains an indexed `businessId: ObjectId`. A global Mongoose plugin automatically injects `{ businessId }` into all queries. | Highly efficient connection pooling; predictable indexing; horizontal sharding on `{ businessId: "hashed" }`. | Requires foolproof middleware and plugin guard to eliminate IDOR. | **Selected & Standardized for Core Platform.** |

### 2.2 The Zero-Trust Mongoose Tenant Isolation Plugin

To guarantee that no developer omission can ever cause a cross-tenant data leak, a global Mongoose plugin (`tenantIsolationPlugin.js`) is installed across all tenant-scoped schemas.

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Controller / Service Code
    participant Plugin as Mongoose Tenant Plugin
    participant Query as Mongoose Query / Pipeline
    participant Mongo as MongoDB Engine

    Dev->>Plugin: Order.find({ orderType: 'dineIn' }) [Context: tenantId = '66f4a1...']
    activate Plugin
    Plugin->>Plugin: Inspect Query Context
    alt Tenant Context Present
        Plugin->>Query: Inject { businessId: '66f4a1...', orderType: 'dineIn' }
        Query->>Mongo: Execute Scoped Query with Index Scan
        Mongo-->>Dev: Returns Tenant-Only Documents
    else Tenant Context Missing & Not SuperAdmin
        Plugin-->>Dev: THROW ApiError.forbidden('TENANT_CONTEXT_MISSING')
        Note over Plugin,Dev: Operation aborted; zero database access permitted
    end
    deactivate Plugin
```

#### Plugin Operational Mechanics:
1. **Query Pre-Hook (`find`, `findOne`, `findOneAndUpdate`, `updateMany`, `deleteMany`, `countDocuments`):**  
   Automatically executes:
   ```javascript
   schema.pre(['find', 'findOne', 'findOneAndUpdate', 'updateMany', 'deleteMany', 'countDocuments'], function() {
     const tenantId = this.options?._tenantId;
     if (!tenantId && !this.options?._bypassTenantCheck) {
       throw new Error('[Security Exception] Query executed without explicit tenant context');
     }
     if (tenantId) {
       this.where({ businessId: tenantId });
     }
   });
   ```
2. **Aggregation Pre-Hook (`aggregate`):**  
   Inspects the pipeline array. Injects `{ $match: { businessId: tenantId } }` as the first pipeline stage.
3. **Save Pre-Hook (`save`, `validate`):**  
   Validates that `doc.businessId` is non-null, matches the active tenant context, and cannot be mutated on existing documents.

---

## 3. Cryptographic Identity & Context Propagation

### 3.1 JWT Token Claims Standard

The JWT access token issued at `/api/v1/auth/login` contains the following cryptographic payload:

```json
{
  "sub": "66f4a1000000000000000001",
  "businessId": "66f4a1000000000000000002",
  "outletId": "66f4a1000000000000000003",
  "role": "cashier",
  "staffId": "66f4a1000000000000000004",
  "permissions": ["pos_billing", "orders_read", "table_shift"],
  "iat": 1728211200,
  "exp": 1728297600,
  "jti": "d3b07384-d113-40a2-a9b0-9f5b66d6a693"
}
```

### 3.2 Dual-Check Inbound HTTP Request Pipeline

Every client request carries:
* `Authorization: Bearer <AccessToken>`
* `X-Business-ID: <CurrentBusinessId>`
* `X-Device-ID: <UUID>`

```mermaid
sequenceDiagram
    autonumber
    actor Client as Flutter POS Terminal
    participant Gateway as Express Gateway (Nginx)
    participant AuthMW as authMiddleware.js
    participant TenantMW as tenantContextMiddleware.js
    participant Service as Business Service

    Client->>Gateway: POST /api/v1/orders<br/>Headers: [Bearer Token, X-Business-ID: B-101]
    Gateway->>AuthMW: Validate Bearer JWT Token
    AuthMW->>AuthMW: Verify Signature & Decode Claims
    AuthMW->>TenantMW: req.user = decoded; req.businessId = decoded.businessId
    
    TenantMW->>TenantMW: Verify X-Business-ID against req.businessId
    alt Headers Match (B-101 == B-101)
        TenantMW->>Service: Forward request with bound req.businessId
        Service-->>Client: 201 Created (Order processed within Tenant sandbox)
    else Tenant Mismatch (Attacker Spoofing: B-101 != B-999)
        TenantMW-->>Client: 403 Forbidden [Code: TENANT_MISMATCH_FORBIDDEN]
        Note over TenantMW: Security alert logged to SIEM
    end
```

---

## 4. Real-Time WebSocket Isolation Architecture (Socket.IO)

### 4.1 Identified Vulnerability in Prior Version
In the legacy implementation, `socketService.js` accepted an unverified `join_business` event from clients and fell back to unauthenticated connections when tokens expired, allowing potential room spoofing:
```javascript
// LEGACY FLAW: Insecure room joining
socket.on('join_business', (data) => {
  const bId = data?.businessId;
  this.joinBusinessRoom(socket, bId); // UNVERIFIED!
});
```

### 4.2 Hardened Cryptographic Handshake & Room Boundaries

Under the hardened architecture:
1. **Mandatory Handshake Verification:** Handshake without a cryptographically valid JWT signature is rejected immediately with an authentication error.
2. **Deterministic Room Binding:** Upon authentication, the socket is bound *exclusively* to rooms derived from `decoded.businessId`.
3. **Rejection of Arbitrary Room Join:** The client cannot emit `join_business` with an arbitrary ID. Any `join_business` attempt must match `socket.businessId`, otherwise the socket is disconnected.

```mermaid
flowchart TD
    Conn["Client Connects to WSS"] --> Handshake{"JWT Token Valid in Handshake?"}
    Handshake -- No --> Reject["❌ Disconnect (401 Unauthorized)"]
    Handshake -- Yes --> Verify{"Decoded Token has businessId?"}
    Verify -- No --> Reject
    Verify -- Yes --> Bind["🔒 Bind socket.businessId = decoded.businessId\nsocket.role = decoded.role"]
    Bind --> JoinCore["Join Room: business_{businessId}"]
    JoinCore --> SubRooms{"Role Filter"}
    SubRooms -- Cashier / Admin --> JoinPOS["Join Room: business_{businessId}:pos"]
    SubRooms -- Waiter / Admin --> JoinWaiter["Join Room: business_{businessId}:waiter"]
    SubRooms -- Chef / Admin --> JoinKDS["Join Room: business_{businessId}:kds"]

    ClientReq["Client emits 'join_business' with payload { businessId: targetId }"]
    ClientReq --> CheckTarget{"targetId === socket.businessId?"}
    CheckTarget -- Yes --> Allow["✅ Maintain existing room membership"]
    CheckTarget -- No --> Alert["🚨 Attack Detected: Force Disconnect & Audit Alert"]
```

### 4.3 Real-Time Event Dispatch Partitioning Matrix

| Socket Event Name | Destination Room | Target Audience | Data Isolation Guarantee |
| :--- | :--- | :--- | :--- |
| `order:created` | `business_${bizId}:kds`, `business_${bizId}:pos` | Kitchen & Cashiers | Emitted exclusively to rooms prefixed with the order's verified `businessId`. |
| `table:updated` | `business_${bizId}` | All outlet terminals | Floor grid state broadcast strictly to that business's active devices. |
| `cart:synced` | `business_${bizId}:pos` | POS terminals | Live draft table carts synchronized only across cashiers of that tenant. |
| `stock:low_alert`| `business_${bizId}:pos` | Store Managers | Stock depletion alerts stay within the originating restaurant. |
| `subscription:changed` | `business_${bizId}` | Tenant Owner | Subscription unlock events reach only the owner's subscribed devices. |

---

## 5. Cloud Firestore Security Rules Architecture

For deployments utilizing Cloud Firestore for real-time offline sync, documents are organized under a strict hierarchical multi-tenant structure:

```
/databases/{database}/documents
  └── /businesses/{businessId}
        ├── /profile/{profileDoc}
        ├── /orders/{orderId}
        ├── /tables/{tableId}
        ├── /products/{productId}
        ├── /categories/{categoryId}
        └── /customers/{customerId}
```

### 5.1 Hardened Firestore Security Rules Definition

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Global Helper: Check if user is authenticated with Firebase Auth
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Global Helper: Check if token businessId matches the document's businessId
    function isTenantMember(businessId) {
      return isAuthenticated() && 
        request.auth.token.businessId == businessId;
    }
    
    // Global Helper: Check if user has Owner / Admin role in the tenant
    function isTenantAdmin(businessId) {
      return isTenantMember(businessId) && 
        (request.auth.token.role == 'owner' || request.auth.token.role == 'admin');
    }

    // Business Root Document
    match /businesses/{businessId} {
      allow read: if isTenantMember(businessId);
      allow write: if isTenantAdmin(businessId);
      
      // Nested Tenant Subcollections
      match /{subcollection}/{document=**} {
        allow read: if isTenantMember(businessId);
        allow write: if isTenantMember(businessId);
      }
    }

    // User Profile Rules (Users can only read/write their own profile)
    match /users/{userId} {
      allow read, write: if isAuthenticated() && request.auth.uid == userId;
    }

    // Default Fallback: DENY ALL OTHER ACCESS (Zero Trust)
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## 6. Client-Side Flutter Cache & Local Storage Partitioning

### 6.1 Vulnerability in Legacy `DatabaseService`
In the legacy Flutter implementation:
```dart
// LEGACY FLAW: Scoped by userId instead of businessId
String _userKey(String baseKey) {
  final uid = currentUser?.id ?? 'guest';
  return 'apna_pos_${uid}_$baseKey';
}
```
*Issue:* If multiple staff members in the same restaurant logged in with different credentials, their live table carts and inventory caches split into fragmented silos. Conversely, if one user logged into multiple businesses, datasets risked cross-pollination.

### 6.2 Hardened Two-Tier Storage Key Architecture

The hardened `DatabaseService` enforces a strict two-tier storage key strategy:

```mermaid
flowchart TD
    Storage["Device Local Storage (SharedPreferences)"]
    
    subgraph Tier1["Tier 1: Device / User Session Sandbox"]
        U1["apna_pos_usr_{userId}_auth_token"]
        U2["apna_pos_usr_{userId}_security_pin"]
        U3["apna_pos_usr_{userId}_profile"]
    end
    
    subgraph Tier2["Tier 2: Business Tenant Sandbox (currentBusinessId)"]
        B1["apna_pos_biz_{bizId}_restaurant"]
        B2["apna_pos_biz_{bizId}_menu"]
        B3["apna_pos_biz_{bizId}_categories"]
        B4["apna_pos_biz_{bizId}_tables"]
        B5["apna_pos_biz_{bizId}_live_table_carts"]
        B6["apna_pos_biz_{bizId}_orders"]
        B7["apna_pos_biz_{bizId}_inventory"]
        B8["apna_pos_biz_{bizId}_customers"]
        B9["apna_pos_biz_{bizId}_loyalty"]
    end

    Storage --> Tier1
    Storage --> Tier2
```

#### Deterministic Storage Key Helper:
```dart
/// Tier 2: Resolves tenant-isolated key for business operational datasets
String _businessKey(String baseKey) {
  final bId = currentBusinessId.trim();
  return 'apna_pos_biz_${bId}_$baseKey';
}

/// Tier 1: Resolves user-isolated key for credential/session data
String _userKey(String baseKey) {
  final uId = (currentUser?.id != null && currentUser!.id.isNotEmpty) 
      ? currentUser!.id.trim() 
      : 'guest';
  return 'apna_pos_usr_${uId}_$baseKey';
}
```

### 6.3 Secure Store Switch & Logout Purge Protocol
When switching businesses or logging out:
1. All in-memory operational lists are immediately cleared:
   ```dart
   menuItems.clear();
   tables.clear();
   orders.clear();
   customers.clear();
   inventoryItems.clear();
   _holdOrders.clear();
   _liveTableCarts.clear();
   ```
2. The UI notifies listeners with clean empty states.
3. The new business dataset is loaded exclusively using `_businessKey(...)`.

---

## 7. MongoDB Collections & Compound Indexing Matrix

Every collection is indexed with `businessId` as the leading compound index prefix to ensure sub-millisecond query execution and zero table scans.

| Collection | Leading Compound Indexes | Purpose & Query Optimization |
| :--- | :--- | :--- |
| `businesses` | `{ _id: 1, ownerId: 1 }` | Fast tenant profile lookup |
| `products` | `{ businessId: 1, isAvailable: 1, category: 1 }`<br/>`{ businessId: 1, productId: 1 }` (Unique)<br/>`{ businessId: 1, name: "text" }` | Instant POS menu rendering, category tabs, and product search |
| `categories` | `{ businessId: 1, name: 1 }` (Unique)<br/>`{ businessId: 1, displayOrder: 1 }` | Ordered category list for POS top bar |
| `tables` | `{ businessId: 1, tableNumber: 1 }` (Unique)<br/>`{ businessId: 1, floor: 1, status: 1 }` | Floor-wise table occupancy grid |
| `orders` | `{ businessId: 1, createdAt: -1 }`<br/>`{ businessId: 1, orderNumber: 1 }`<br/>`{ businessId: 1, status: 1, createdAt: -1 }`<br/>`{ businessId: 1, tableNumber: 1 }` | Orders screen, live kitchen status, bill settlements |
| `carts` | `{ businessId: 1, tableNumber: 1 }`<br/>`{ businessId: 1, updatedAt: -1 }` | Multi-device draft cart synchronization |
| `customers` | `{ businessId: 1, phone: 1 }` (Unique)<br/>`{ businessId: 1, lastVisit: -1 }`<br/>`{ businessId: 1, name: 1 }` | Autocomplete suggestions and customer loyalty lookups |
| `inventories` | `{ businessId: 1, productId: 1 }`<br/>`{ businessId: 1, currentStock: 1 }` | Low-stock notifications and auto stock decrement |
| `sales` | `{ businessId: 1, date: -1 }`<br/>`{ businessId: 1, paymentMethod: 1 }` | End-of-day sales summary, tax ledger, analytics |
| `printlogs` | `{ businessId: 1, printedAt: -1 }`<br/>`{ businessId: 1, orderId: 1 }` | Audit trail for duplicate bill printing |
| `staffs` | `{ businessId: 1, phone: 1 }`<br/>`{ businessId: 1, role: 1 }` | Staff role verification and security PIN authentication |

---

## 8. Resilience, Disaster Recovery & High Availability

1. **Daily Automated Encrypted Snapshots:** Automated daily backups of MongoDB with AES-256 encryption at rest. Backups are tagged with tenant retention policies.
2. **Point-in-Time Recovery (PITR):** MongoDB oplog streaming enabled to support restore to any second within the past 7 days.
3. **Graceful Network Degradation:** If internet drops:
   - POS terminal continues billing locally into SQLite / SharedPreferences.
   - Sockets transition to offline queue buffer.
   - Upon reconnect, `DatabaseService.syncUnsyncedOrders()` pushes offline bills using transactional idempotency keys (`idempotencyKey: "${businessId}_${orderNumber}_${timestamp}"`), preventing duplicate bill creation.

---
*Architected and certified by Apna POS Systems Engineering Team.*
