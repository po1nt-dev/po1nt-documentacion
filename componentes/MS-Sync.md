# MS-Sync - Microservicio de Sincronizacion

## Proposito y Responsabilidades

Orquestador de sincronizacion de datos entre plataforma central y terminales POS:
- Gestionar sincronizaciones pendientes por terminal
- Ejecutar stored procedures dinamicos por tipo de sync
- Confirmar recepcion de sincronizaciones
- Recibir transacciones desde terminales

## Diagrama de Arquitectura Interna

```mermaid
flowchart TB
    subgraph "Controllers"
        A[EventController]
        B[SyncController]
    end

    subgraph "Repositories"
        C[TerminalSyncRepository]
        D[SyncTypeRepository]
    end

    subgraph "Models"
        E[Terminal]
        F[TerminalSync]
        G[SyncType]
        H[Event]
    end

    subgraph "Database"
        I[(terminals)]
        J[(terminal_sync)]
        K[(sync_types)]
    end

    A --> C --> I & J
    B --> C & D --> J & K
```

## Estructura de Carpetas

```
MS-Sync/
├── Controllers/
│   ├── EventController.cs     # GET /api/Event/sync
│   └── SyncController.cs      # GET/POST /api/Sync/{type}
├── Models/
│   ├── Event.cs
│   ├── SyncType.cs
│   ├── Terminal.cs
│   └── TerminalSync.cs
├── Repositories/
│   ├── TerminalSyncRepository.cs
│   └── SyncTypeRepository.cs
├── Program.cs
└── MS-Sync.csproj
```

## APIs Expuestas

### GET /api/Event/sync
Obtiene sincronizaciones pendientes para una terminal

**Headers:** `token: {terminal_token}`

**Response:**
```json
[
  {
    "ruta": "/api/Sync/{type}",
    "tipo": "products",
    "procedimiento": "SP_Sync_Products",
    "guid": "abc-123"
  }
]
```

### GET /api/Sync/{type}
Obtiene datos de sincronizacion ejecutando SP dinamico

**Headers:**
- `token: {terminal_token}`
- `sync_Guid_Central: {guid}`

### POST /api/Sync/{type}
Confirma recepcion de sincronizacion

### POST /api/Sync/transactions
Recibe transacciones desde terminal (XML)

## Flujo de Sincronizacion

```mermaid
sequenceDiagram
    participant T as Terminal
    participant S as MS-Sync
    participant DB as SQL Server

    T->>S: GET /api/Event/sync
    S->>DB: Query terminal_sync pendientes
    DB-->>S: Lista sincronizaciones
    S-->>T: [{type, guid, ruta}]

    T->>S: GET /api/Sync/{type}
    S->>DB: EXEC SP_{procedimiento}
    DB-->>S: DataTable
    S->>DB: UPDATE date_send
    S-->>T: JSON data

    T->>S: POST /api/Sync/{type}
    S->>DB: UPDATE date_confirm
    S-->>T: 200 OK
```

## Configuracion Requerida

| Variable | Tipo | Descripcion |
|----------|------|-------------|
| DEFAULT_CONNECTION | string | SQL Server |
| ENCRYPTION_KEY | base64 | Decrypt tokens |
| ENABLE_METRICS | 0/1 | Prometheus |

## Tablas Principales

### terminal_sync
```sql
- id
- terminal_id
- sync_type_id
- date_pending
- date_send
- date_confirm
- sync_guid
- processData
```

### sync_types
```sql
- id
- name
- dll
- procedureName
- procedureParams
```

---
