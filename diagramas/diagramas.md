# Diagramas - Plataforma Po1nt

Coleccion completa de diagramas de arquitectura y flujos del sistema Po1nt.

---

## Tabla de Contenidos

1. [Diagramas de Arquitectura](#diagramas-de-arquitectura)
   - [Arquitectura de Alto Nivel](#1-arquitectura-de-alto-nivel)
   - [Componentes con Tecnologias](#2-componentes-con-tecnologias)
   - [Flujo de Datos Principal](#3-flujo-de-datos-principal)
   - [Diagrama de Dependencias](#4-diagrama-de-dependencias)
2. [Diagramas de Componentes](#diagramas-de-componentes)
   - [MS-Sync Arquitectura Interna](#5-ms-sync---arquitectura-interna)
   - [Sincronizadores Interaccion](#6-sincronizadores---interaccion)
3. [Diagramas de Flujo (Secuencia)](#diagramas-de-flujo-secuencia)
   - [Flujo de Autenticacion](#7-flujo-de-autenticacion)
   - [Flujo de Sincronizacion de Productos](#8-flujo-de-sincronizacion-de-productos)
   - [Flujo de Venta en POS](#9-flujo-de-venta-en-pos)
   - [Flujo de Pago de Remesa](#10-flujo-de-pago-de-remesa)
   - [Flujo de Recarga Telefonica](#11-flujo-de-recarga-telefonica)
   - [Flujo de Sincronizacion Batch](#12-flujo-de-sincronizacion-batch)
   - [Flujo de Reenvio DTE](#13-flujo-de-reenvio-dte)
   - [Flujo de Sincronizacion MS-Sync](#14-flujo-de-sincronizacion-ms-sync)

---

# Diagramas de Arquitectura

## 1. Arquitectura de Alto Nivel

Vista general del sistema Po1nt mostrando las capas principales.

```mermaid
flowchart TB
    subgraph "Interfaz de Usuario"
        A[Portal Admin Web<br/>Nuxt 3]
        B[Aplicacion POS<br/>Windows Desktop]
        C[Portal Desktop<br/>Windows Forms]
    end

    subgraph "Capa de Microservicios"
        D[MS-Autn<br/>Autenticacion]
        E[MS-configs<br/>Configuracion]
        F[MS-Products<br/>Productos]
        G[MS-Sync<br/>Sincronizacion]
        H[MS-Logger<br/>Logging]
        I[ms-procesos-locales<br/>Facturacion DTE]
        J[ms-corresponsales<br/>Pagos Terceros]
    end

    subgraph "Servicios de Sincronizacion"
        K[Sincronizadores<br/>Windows Services]
    end

    subgraph "Almacenamiento"
        L[(SQL Server<br/>Base de Datos Central)]
        M[(SQL Server<br/>BD Sucursales)]
    end

    subgraph "Integraciones Externas"
        N[Ministerio Hacienda<br/>DTE]
        O[Proveedores Pago<br/>TigoMoney/Airpak]
    end

    A --> D
    A --> E
    A --> F
    B --> M
    B --> I
    C --> L

    D --> L
    E --> L
    F --> L
    G --> L
    H --> L
    I --> L
    J --> L

    K --> L
    K --> M

    I --> N
    J --> O
```

---

## 2. Componentes con Tecnologias

Diagrama detallado mostrando cada componente con su stack tecnologico.

```mermaid
flowchart TB
    subgraph "Frontend"
        style Frontend fill:#e1f5fe
        A[nuxt-front-admin<br/>Nuxt 3 + Vue 3 + TypeScript]
        B[po1nt-pos<br/>VB.NET + WinForms]
        C[portaladministrativo-desktop<br/>C# + WinForms]
    end

    subgraph "API Gateway / Microservicios"
        style API fill:#fff3e0
        D[MS-Autn<br/>.NET 7 + JWT + BCrypt]
        E[MS-configs<br/>.NET 7 + Dapper]
        F[MS-Products<br/>.NET 7 + Dapper]
        G[MS-Sync<br/>.NET 7 + RestSharp]
        H[MS-Logger<br/>.NET 7 + Dapper]
        I[ms-procesos-locales<br/>.NET 7 + BitWork]
        J[ms-corresponsales<br/>.NET 7 + RestSharp]
    end

    subgraph "Libreria Compartida"
        style Libreria fill:#f3e5f5
        K[shared-libs<br/>.NET 7 + Dapper + Prometheus]
    end

    subgraph "Sincronizadores Windows"
        style Sincronizadores fill:#fff3e0
        L[epdPo1nt_Syncronizador<br/>VB.NET + SQL Server]
        M[WS-SincronizadorSalas<br/>VB.NET + Timers]
        N[WS-SincronizacionBascula<br/>VB.NET + SQL Server]
        O[sincronizacion-sala<br/>VB.NET + HTTP]
        P[ws-reenviodte<br/>VB.NET + DTE API]
    end

    subgraph "Jobs y Migraciones"
        style Jobs fill:#fff3e0
        Q[cron-jobs<br/>.NET 7 + SQL Server]
        R[JOB-Migrations<br/>.NET 7 + EF Core]
        S[job-corresponsales-migrations<br/>.NET 7 + EF Core]
    end

    subgraph "Monitoreo"
        style Monitoreo fill:#e8f5e9
        T[po1nt-monitoring<br/>Prometheus + Grafana + Tempo]
    end

    subgraph "Base de Datos"
        style Base fill:#e8f5e9
        U[(SQL Server Central<br/>po1nt_pos / selectos3)]
        V[(SQL Server Sucursales<br/>SatellitePOS_MH)]
    end

    subgraph "Integraciones Externas"
        style Integraciones fill:#fce4ec
        W[Ministerio Hacienda<br/>API DTE]
        X[PuntoXpress<br/>Colectores]
        Y[Cuscatlan/Airpak<br/>Remesas]
        Z[TigoMoney<br/>Dinero Movil]
    end

    A --> D & E & F
    B --> V
    B --> I
    C --> U

    D --> K
    E --> K
    F --> K
    G --> K
    H --> K
    I --> K
    J --> K

    K --> U

    L --> U & V
    M --> U & V
    N --> U
    O --> U & V
    P --> U

    Q --> U
    R --> U
    S --> U

    T --> U

    I --> W
    J --> X & Y & Z
```

---

## 3. Flujo de Datos Principal

Flujo de datos desde el origen hasta la salida.

```mermaid
flowchart LR
    subgraph "Origen"
        A[Portal Admin]
        B[POS Desktop]
    end

    subgraph "Procesamiento"
        C[Microservicios<br/>.NET 7]
        D[Sincronizadores<br/>Windows Services]
    end

    subgraph "Almacenamiento"
        E[(BD Central)]
        F[(BD Sucursales)]
    end

    subgraph "Salida"
        G[Terminales POS]
        H[Reportes]
        I[DTE/Hacienda]
    end

    A -->|HTTP/JSON| C
    B -->|SQL| F
    C -->|Dapper| E
    D -->|SQL| E
    D -->|SQL| F
    E -->|Sync| F
    F -->|Data| G
    E -->|Query| H
    C -->|API| I
```

---

## 4. Diagrama de Dependencias

Dependencias entre componentes del sistema.

```mermaid
flowchart TB
    subgraph "Frontend"
        style Frontend fill:#e1f5fe
        A[nuxt-front-admin]
    end

    subgraph "Microservicios Core"
        style Core fill:#fff3e0
        B[MS-Autn]
        C[MS-configs]
        D[MS-Products]
        E[MS-Sync]
        F[MS-Logger]
    end

    subgraph "Microservicios Negocio"
        style Negocio fill:#fff3e0
        G[ms-procesos-locales]
        H[ms-corresponsales]
    end

    subgraph "Libreria Base"
        style Base fill:#f3e5f5
        I[shared-libs]
    end

    subgraph "Aplicaciones Desktop"
        style Desktop fill:#e1f5fe
        J[po1nt-pos]
        K[portaladministrativo]
    end

    subgraph "Sincronizadores"
        style Sync fill:#fff3e0
        L[epdPo1nt_Syncronizador]
        M[WS-SincronizadorSalas]
        N[WS-SincronizacionBascula]
        O[ws-reenviodte]
    end

    subgraph "Infraestructura"
        style Infra fill:#e8f5e9
        P[(SQL Server)]
        Q[po1nt-monitoring]
    end

    subgraph "Externos"
        style Externos fill:#fce4ec
        R[Ministerio Hacienda]
        S[Proveedores Pago]
    end

    A --> B & C & D
    B --> I --> P
    C --> I
    C --> E
    D --> I
    D --> E
    E --> I
    F --> I
    G --> I
    G --> R
    H --> I
    H --> S
    J --> G & H
    J --> P
    K --> P
    L & M & N --> E
    L & M & N & O --> P
    O --> G
    Q --> P
```

---

# Diagramas de Componentes

## 5. MS-Sync - Arquitectura Interna

Estructura interna del microservicio de sincronizacion.

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

---

## 6. Sincronizadores - Interaccion

Interaccion entre los diferentes sincronizadores Windows.

```mermaid
flowchart TB
    subgraph "Sincronizadores"
        A[epdPo1nt_Syncronizador]
        B[WS-SincronizadorSalas]
        C[WS-SincronizacionBascula]
        D[sincronizacion-sala]
        E[ws-reenviodte]
    end

    subgraph "APIs"
        F[MS-Sync API]
        G[Ministerio Hacienda]
    end

    subgraph "Bases de Datos"
        H[(BD Central)]
        I[(BD Sucursales)]
    end

    A --> H & I
    B --> F --> H
    B --> I
    C --> H
    D --> F
    E --> H & G
```

---

# Diagramas de Flujo (Secuencia)

## 7. Flujo de Autenticacion

Proceso de login de usuario en el portal administrativo.

```mermaid
sequenceDiagram
    participant U as Usuario
    participant F as Frontend (Nuxt)
    participant A as MS-Autn
    participant DB as SQL Server

    U->>F: Ingresa credenciales
    F->>A: POST /api/Auth {username, password}
    A->>DB: SELECT user WHERE username
    DB-->>A: User data
    A->>A: BCrypt.Verify(password)
    A->>A: Crypto.Encrypt(JWT)
    A->>DB: INSERT session
    A-->>F: {token, type: "Bearer", duration: 20}
    F->>F: Almacena token en cookie
    F-->>U: Redirige a dashboard
```

---

## 8. Flujo de Sincronizacion de Productos

Proceso de crear un producto y sincronizarlo a las terminales.

```mermaid
sequenceDiagram
    participant A as Admin (Nuxt)
    participant P as MS-Products
    participant S as SyncEvent
    participant DB as SQL Server
    participant Sync as MS-Sync
    participant T as Terminal POS

    A->>P: POST /api/products {producto}
    P->>DB: INSERT products
    P->>S: SyncEvent.save({action: "create-product"})
    S->>DB: INSERT terminal_sync (pendiente)
    P-->>A: 200 OK

    Note over T,Sync: Cada 5 minutos
    T->>Sync: GET /api/Event/sync
    Sync->>DB: SELECT terminal_sync pendientes
    Sync-->>T: [{type: "products", guid}]
    T->>Sync: GET /api/Sync/products
    Sync->>DB: EXEC SP_Sync_Products
    DB-->>Sync: DataTable productos
    Sync->>DB: UPDATE date_send
    Sync-->>T: JSON productos
    T->>T: Procesa productos
    T->>Sync: POST /api/Sync/products
    Sync->>DB: UPDATE date_confirm
```

---

## 9. Flujo de Venta en POS

Proceso completo de una venta con facturacion electronica.

```mermaid
sequenceDiagram
    participant C as Cajero
    participant POS as po1nt-pos
    participant DB as BD Local
    participant L as ms-procesos-locales
    participant MH as Ministerio Hacienda

    C->>POS: Escanea productos
    POS->>DB: SELECT precio, promocion
    DB-->>POS: Datos producto
    POS->>POS: Calcula totales
    C->>POS: Selecciona forma pago
    C->>POS: Finaliza venta
    POS->>DB: INSERT transaccion
    POS->>L: POST /api/FacturacionElectronica/sendFact
    L->>L: Genera estructura DTE
    L->>MH: Envia factura electronica
    MH-->>L: Sello y codigo
    L->>DB: UPDATE transaccion (sello)
    L-->>POS: DTE confirmado
    POS->>POS: Imprime recibo
    POS-->>C: Venta completada
```

---

## 10. Flujo de Pago de Remesa

Proceso de pago de remesa internacional.

```mermaid
sequenceDiagram
    participant C as Cajero
    participant POS as po1nt-pos
    participant MS as ms-corresponsales
    participant CU as Cuscatlan API
    participant DB as SQL Server

    C->>POS: Ingresa datos remesa
    POS->>MS: POST /api/CuscaTransferInfo
    MS->>CU: TransferInfo request
    CU-->>MS: Datos de remesa
    MS-->>POS: Info beneficiario, monto

    C->>POS: Confirma pago
    POS->>MS: POST /api/CuscaLookupPerson
    MS->>CU: Busca beneficiario
    CU-->>MS: Datos persona

    POS->>MS: POST /api/CuscaConfirmSimplifiedPayment
    MS->>CU: Confirma pago
    CU-->>MS: Confirmacion
    MS->>DB: INSERT PxTransactions
    MS-->>POS: Recibo remesa
    POS->>POS: Imprime comprobante
```

---

## 11. Flujo de Recarga Telefonica

Proceso de recarga de saldo telefonico.

```mermaid
sequenceDiagram
    participant C as Cajero
    participant POS as po1nt-pos
    participant MS as ms-corresponsales
    participant T as Tigo/Claro API
    participant DB as SQL Server

    C->>POS: Selecciona operador y monto
    POS->>MS: GET /api/BalanceCompanies
    MS->>T: Consulta saldo agente
    T-->>MS: Saldo disponible
    MS-->>POS: Saldo OK

    C->>POS: Ingresa numero telefono
    POS->>MS: POST /api/RechargeCompanies
    MS->>T: Ejecuta recarga
    T-->>MS: Confirmacion recarga
    MS->>DB: INSERT transaccion
    MS-->>POS: Recarga exitosa
    POS->>POS: Imprime comprobante
```

---

## 12. Flujo de Sincronizacion Batch

Sincronizacion periodica via Windows Services.

```mermaid
sequenceDiagram
    participant T as Timer Service
    participant API as MS-Sync API
    participant DBC as BD Central
    participant DBL as BD Local
    participant SP as Stored Procedures

    Note over T: Cada 5 minutos
    T->>API: GET /api/Event/sync (token)
    API->>DBC: Query cambios pendientes
    DBC-->>API: Lista cambios

    loop Por cada cambio
        T->>API: GET /api/Sync/{tipo}
        API->>DBC: EXEC SP_{tipo}
        DBC-->>API: DataTable
        API-->>T: JSON datos
        T->>DBL: EXEC SP_Apply_{tipo}
        DBL-->>T: Aplicado
        T->>API: POST /api/Sync/{tipo} (confirmar)
        API->>DBC: UPDATE date_confirm
    end
```

---

## 13. Flujo de Reenvio DTE

Reenvio automatico de facturas electronicas fallidas.

```mermaid
sequenceDiagram
    participant S as ws-reenviodte
    participant DB as SQL Server
    participant L as ms-procesos-locales
    participant MH as Ministerio Hacienda

    Note over S: 1:00 AM - 6:00 AM
    S->>S: Timer cada 30 min
    S->>DB: SELECT transacciones sin sello
    DB-->>S: Lista transacciones fallidas

    loop Por cada transaccion
        S->>L: POST /api/FacturacionElectronica/sendFact
        L->>MH: Envia DTE
        alt Exito
            MH-->>L: Sello electronico
            L->>DB: UPDATE transaccion (sello)
        else Fallo
            MH-->>L: Error
            L->>DB: INSERT log error
        end
    end

    S->>S: Escribe log resultados
```

---

## 14. Flujo de Sincronizacion MS-Sync

Detalle del proceso de sincronizacion en el microservicio.

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

---

*Documentacion de Diagramas - Plataforma Po1nt*
*Total de diagramas: 14*
*Formato: Mermaid*
