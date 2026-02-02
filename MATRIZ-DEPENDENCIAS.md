# Matriz de Dependencias - Plataforma Po1nt

## Tabla de Dependencias entre Componentes

| Componente | Depende de | Es consumido por |
|------------|------------|------------------|
| **nuxt-front-admin** | MS-Autn, MS-configs, MS-Products, MS-Locales | - |
| **po1nt-pos** | ms-procesos-locales, BD Local, shared-libs | po1nt-carga-apps |
| **MS-Autn** | shared-libs, SQL Server | nuxt-front-admin |
| **MS-configs** | shared-libs, MS-Sync, SQL Server | nuxt-front-admin |
| **MS-Products** | shared-libs, MS-Sync, SQL Server | nuxt-front-admin |
| **MS-Sync** | shared-libs, SQL Server | Sincronizadores, MS-configs, MS-Products |
| **MS-Logger** | shared-libs, SQL Server | po1nt-pos, otros MS |
| **ms-procesos-locales** | shared-libs, BitWork, MH API | po1nt-pos |
| **ms-corresponsales** | shared-libs, Proveedores externos | po1nt-pos |
| **shared-libs** | Dapper, SQL Server, Prometheus | Todos los microservicios |
| **Sincronizadores** | MS-Sync API, SQL Server | - |
| **cron-jobs** | SQL Server | - |
| **JOB-Migrations** | EF Core, SQL Server | - |
| **po1nt-monitoring** | Prometheus, Grafana, AKS | Terminales POS |

## Diagrama de Dependencias

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

## Componentes Criticos (Alta Dependencia)

Los siguientes componentes son **criticos** porque muchos otros dependen de ellos:

### 1. shared-libs
- **Dependientes**: Todos los microservicios (7)
- **Impacto de falla**: Sistema completo inoperante
- **Mitigacion**: Libreria estatica, se compila con cada servicio

### 2. SQL Server
- **Dependientes**: Todos los componentes (22)
- **Impacto de falla**: Sistema completo inoperante
- **Mitigacion**: Alta disponibilidad, backups, replicacion

### 3. MS-Sync
- **Dependientes**: MS-configs, MS-Products, Sincronizadores
- **Impacto de falla**: Sincronizacion detenida, datos desactualizados
- **Mitigacion**: Cola de eventos persistente en BD

### 4. MS-Autn
- **Dependientes**: nuxt-front-admin, middleware en todos los MS
- **Impacto de falla**: Usuarios no pueden autenticarse
- **Mitigacion**: Tokens con duracion de 20 minutos

## Matriz de Comunicacion

| Origen | Destino | Protocolo | Puerto | Tipo |
|--------|---------|-----------|--------|------|
| nuxt-front-admin | MS-Autn | HTTP/REST | 5017 | Sincrono |
| nuxt-front-admin | MS-configs | HTTP/REST | 61673 | Sincrono |
| nuxt-front-admin | MS-Products | HTTP/REST | 5107 | Sincrono |
| po1nt-pos | ms-procesos-locales | HTTP/REST | 5115 | Sincrono |
| po1nt-pos | ms-corresponsales | HTTP/REST | 5225 | Sincrono |
| Sincronizadores | MS-Sync | HTTP/REST | 5117 | Sincrono |
| ms-procesos-locales | MH API | HTTPS | 443 | Sincrono |
| ms-corresponsales | Proveedores | HTTPS | 443 | Sincrono |
| Todos MS | SQL Server | TDS | 1433 | Sincrono |
| Windows Exporter | Pushgateway | HTTP | 9091 | Push |

## Dependencias de Base de Datos

| Componente | Base de Datos | Tipo Acceso |
|------------|---------------|-------------|
| MS-Autn | po1nt_pos | Dapper |
| MS-configs | selectos3 | Dapper |
| MS-Products | selectos3 | Dapper |
| MS-Sync | selectos3 | Dapper |
| MS-Logger | Logs | Dapper |
| ms-procesos-locales | satellite-pos | Dapper |
| ms-corresponsales | PagosExternos | Dapper |
| po1nt-pos | SatellitePOS_MH | DataSets |
| Sincronizadores | SatellitePOS_SUCURSAL_01 | ADO.NET |
| JOB-Migrations | satellite4 | EF Core |

## Dependencias de Servicios Externos

| Componente | Servicio Externo | Proposito |
|------------|------------------|-----------|
| ms-procesos-locales | Ministerio de Hacienda | DTEs |
| ms-procesos-locales | BitWork | Facturacion |
| ms-corresponsales | PuntoXpress | Colectores |
| ms-corresponsales | Cuscatlan | Remesas |
| ms-corresponsales | Airpak | Remesas |
| ms-corresponsales | TigoMoney | Dinero movil |
| ms-corresponsales | Claro/Tigo/Movistar | Recargas |
| Todos MS | Sentry | Error tracking |
| po1nt-monitoring | Azure AKS | Hosting |

## Orden de Despliegue Recomendado

Para un despliegue desde cero, seguir este orden:

1. **SQL Server** - Base de datos
2. **JOB-Migrations** - Esquema de BD
3. **shared-libs** - Libreria base (compilar)
4. **MS-Autn** - Autenticacion
5. **MS-Sync** - Sincronizacion
6. **MS-configs** - Configuracion
7. **MS-Products** - Productos
8. **MS-Logger** - Logging
9. **ms-procesos-locales** - Facturacion
10. **ms-corresponsales** - Pagos terceros
11. **nuxt-front-admin** - Portal web
12. **po1nt-pos** - Aplicacion POS
13. **Sincronizadores** - Windows Services
14. **po1nt-monitoring** - Monitoreo

---

*Documento generado automaticamente - Febrero 2026*
