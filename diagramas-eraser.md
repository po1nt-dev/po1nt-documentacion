# Diagramas - Plataforma Po1nt (Formato Eraser)

Coleccion completa de diagramas de arquitectura y flujos del sistema Po1nt.
Formato: [Eraser Diagram-as-Code](https://docs.eraser.io/docs/diagram-as-code)

---

## Tabla de Contenidos

1. [Diagramas de Arquitectura](#diagramas-de-arquitectura)
2. [Diagramas de Componentes](#diagramas-de-componentes)
3. [Diagramas de Flujo (Secuencia)](#diagramas-de-flujo-secuencia)

---

# Diagramas de Arquitectura

## 1. Arquitectura de Alto Nivel

Vista general del sistema Po1nt mostrando las capas principales.

```eraser
// Arquitectura de Alto Nivel - Po1nt

// Interfaz de Usuario
Interfaz de Usuario [icon: layout] {
    Portal Admin Web [icon: monitor, label: "Nuxt 3"]
    Aplicacion POS [icon: desktop, label: "Windows Desktop"]
    Portal Desktop [icon: desktop, label: "Windows Forms"]
}

// Capa de Microservicios
Capa de Microservicios [icon: server] {
    MS-Autn [icon: shield, label: "Autenticacion"]
    MS-configs [icon: settings, label: "Configuracion"]
    MS-Products [icon: package, label: "Productos"]
    MS-Sync [icon: refresh-cw, label: "Sincronizacion"]
    MS-Logger [icon: file-text, label: "Logging"]
    ms-procesos-locales [icon: file-check, label: "Facturacion DTE"]
    ms-corresponsales [icon: credit-card, label: "Pagos Terceros"]
}

// Servicios de Sincronizacion
Sincronizadores [icon: clock, label: "Windows Services"]

// Almacenamiento
Almacenamiento [icon: database] {
    SQL Server Central [icon: database, label: "po1nt_pos"]
    SQL Server Sucursales [icon: database, label: "SatellitePOS_MH"]
}

// Integraciones Externas
Integraciones Externas [icon: globe] {
    Ministerio Hacienda [icon: building, label: "DTE"]
    Proveedores Pago [icon: dollar-sign, label: "TigoMoney/Airpak"]
}

// Conexiones
Portal Admin Web > MS-Autn
Portal Admin Web > MS-configs
Portal Admin Web > MS-Products
Aplicacion POS > SQL Server Sucursales
Aplicacion POS > ms-procesos-locales
Portal Desktop > SQL Server Central

MS-Autn > SQL Server Central
MS-configs > SQL Server Central
MS-Products > SQL Server Central
MS-Sync > SQL Server Central
MS-Logger > SQL Server Central
ms-procesos-locales > SQL Server Central
ms-corresponsales > SQL Server Central

Sincronizadores > SQL Server Central
Sincronizadores > SQL Server Sucursales

ms-procesos-locales > Ministerio Hacienda
ms-corresponsales > Proveedores Pago
```

---

## 2. Componentes con Tecnologias

Diagrama detallado mostrando cada componente con su stack tecnologico.

```eraser
// Componentes con Tecnologias - Po1nt
direction down

// Frontend
Frontend [icon: layout, color: blue] {
    nuxt-front-admin [icon: monitor, label: "Nuxt 3 + Vue 3 + TypeScript"]
    po1nt-pos [icon: desktop, label: "VB.NET + WinForms"]
    portaladministrativo-desktop [icon: desktop, label: "C# + WinForms"]
}

// API Gateway / Microservicios
Microservicios [icon: server, color: orange] {
    MS-Autn [icon: shield, label: ".NET 7 + JWT + BCrypt"]
    MS-configs [icon: settings, label: ".NET 7 + Dapper"]
    MS-Products [icon: package, label: ".NET 7 + Dapper"]
    MS-Sync [icon: refresh-cw, label: ".NET 7 + RestSharp"]
    MS-Logger [icon: file-text, label: ".NET 7 + Dapper"]
    ms-procesos-locales [icon: file-check, label: ".NET 7 + BitWork"]
    ms-corresponsales [icon: credit-card, label: ".NET 7 + RestSharp"]
}

// Libreria Compartida
Libreria [icon: code, color: purple] {
    shared-libs [icon: code, label: ".NET 7 + Dapper + Prometheus"]
}

// Sincronizadores Windows
Sincronizadores [icon: clock, color: orange] {
    epdPo1nt_Syncronizador [icon: clock, label: "VB.NET"]
    WS-SincronizadorSalas [icon: clock, label: "VB.NET + Timers"]
    WS-SincronizacionBascula [icon: clock, label: "VB.NET"]
    sincronizacion-sala [icon: clock, label: "VB.NET + HTTP"]
    ws-reenviodte [icon: clock, label: "VB.NET + DTE API"]
}

// Jobs y Migraciones
Jobs [icon: terminal, color: orange] {
    cron-jobs [icon: terminal, label: ".NET 7"]
    JOB-Migrations [icon: database, label: ".NET 7 + EF Core"]
    job-corresponsales-migrations [icon: database, label: ".NET 7 + EF Core"]
}

// Monitoreo
Monitoreo [icon: activity, color: green] {
    po1nt-monitoring [icon: activity, label: "Prometheus + Grafana + Tempo"]
}

// Base de Datos
Base de Datos [icon: database, color: green] {
    SQL Server Central [icon: database, label: "po1nt_pos / selectos3"]
    SQL Server Sucursales [icon: database, label: "SatellitePOS_MH"]
}

// Integraciones Externas
Externos [icon: globe, color: red] {
    Ministerio Hacienda [icon: building, label: "API DTE"]
    PuntoXpress [icon: credit-card, label: "Colectores"]
    Cuscatlan Airpak [icon: dollar-sign, label: "Remesas"]
    TigoMoney [icon: smartphone, label: "Dinero Movil"]
}

// Conexiones Frontend -> Microservicios
nuxt-front-admin > MS-Autn
nuxt-front-admin > MS-configs
nuxt-front-admin > MS-Products
po1nt-pos > SQL Server Sucursales
po1nt-pos > ms-procesos-locales
portaladministrativo-desktop > SQL Server Central

// Conexiones Microservicios -> shared-libs
MS-Autn > shared-libs
MS-configs > shared-libs
MS-Products > shared-libs
MS-Sync > shared-libs
MS-Logger > shared-libs
ms-procesos-locales > shared-libs
ms-corresponsales > shared-libs

// Conexion shared-libs -> BD
shared-libs > SQL Server Central

// Conexiones Sincronizadores
epdPo1nt_Syncronizador > SQL Server Central
epdPo1nt_Syncronizador > SQL Server Sucursales
WS-SincronizadorSalas > SQL Server Central
WS-SincronizadorSalas > SQL Server Sucursales
WS-SincronizacionBascula > SQL Server Central
sincronizacion-sala > SQL Server Central
ws-reenviodte > SQL Server Central

// Conexiones Jobs
cron-jobs > SQL Server Central
JOB-Migrations > SQL Server Central
job-corresponsales-migrations > SQL Server Central

// Conexion Monitoreo
po1nt-monitoring > SQL Server Central

// Conexiones Externas
ms-procesos-locales > Ministerio Hacienda
ms-corresponsales > PuntoXpress
ms-corresponsales > Cuscatlan Airpak
ms-corresponsales > TigoMoney
```

---

## 3. Flujo de Datos Principal

Flujo de datos desde el origen hasta la salida.

```eraser
// Flujo de Datos Principal - Po1nt
direction right

// Origen
Origen [icon: arrow-right, color: blue] {
    Portal Admin [icon: monitor]
    POS Desktop [icon: desktop]
}

// Procesamiento
Procesamiento [icon: cpu, color: orange] {
    Microservicios [icon: server, label: ".NET 7"]
    Sincronizadores [icon: clock, label: "Windows Services"]
}

// Almacenamiento
Almacenamiento [icon: database, color: green] {
    BD Central [icon: database]
    BD Sucursales [icon: database]
}

// Salida
Salida [icon: arrow-right, color: purple] {
    Terminales POS [icon: desktop]
    Reportes [icon: file-text]
    DTE Hacienda [icon: building]
}

// Conexiones
Portal Admin > Microservicios: HTTP/JSON
POS Desktop > BD Sucursales: SQL
Microservicios > BD Central: Dapper
Sincronizadores > BD Central: SQL
Sincronizadores > BD Sucursales: SQL
BD Central > BD Sucursales: Sync
BD Sucursales > Terminales POS: Data
BD Central > Reportes: Query
Microservicios > DTE Hacienda: API
```

---

## 4. Diagrama de Dependencias

Dependencias entre componentes del sistema.

```eraser
// Diagrama de Dependencias - Po1nt
direction down

// Frontend
Frontend [color: blue] {
    nuxt-front-admin [icon: monitor]
}

// Microservicios Core
Microservicios Core [color: orange] {
    MS-Autn [icon: shield]
    MS-configs [icon: settings]
    MS-Products [icon: package]
    MS-Sync [icon: refresh-cw]
    MS-Logger [icon: file-text]
}

// Microservicios Negocio
Microservicios Negocio [color: orange] {
    ms-procesos-locales [icon: file-check]
    ms-corresponsales [icon: credit-card]
}

// Libreria Base
Libreria Base [color: purple] {
    shared-libs [icon: code]
}

// Aplicaciones Desktop
Aplicaciones Desktop [color: blue] {
    po1nt-pos [icon: desktop]
    portaladministrativo [icon: desktop]
}

// Sincronizadores
Sincronizadores [color: orange] {
    epdPo1nt_Syncronizador [icon: clock]
    WS-SincronizadorSalas [icon: clock]
    WS-SincronizacionBascula [icon: clock]
    ws-reenviodte [icon: clock]
}

// Infraestructura
Infraestructura [color: green] {
    SQL Server [icon: database]
    po1nt-monitoring [icon: activity]
}

// Externos
Externos [color: red] {
    Ministerio Hacienda [icon: building]
    Proveedores Pago [icon: dollar-sign]
}

// Dependencias Frontend
nuxt-front-admin > MS-Autn
nuxt-front-admin > MS-configs
nuxt-front-admin > MS-Products

// Dependencias Microservicios Core
MS-Autn > shared-libs
MS-configs > shared-libs
MS-configs > MS-Sync
MS-Products > shared-libs
MS-Products > MS-Sync
MS-Sync > shared-libs
MS-Logger > shared-libs

// Dependencias shared-libs
shared-libs > SQL Server

// Dependencias Microservicios Negocio
ms-procesos-locales > shared-libs
ms-procesos-locales > Ministerio Hacienda
ms-corresponsales > shared-libs
ms-corresponsales > Proveedores Pago

// Dependencias Desktop
po1nt-pos > ms-procesos-locales
po1nt-pos > ms-corresponsales
po1nt-pos > SQL Server
portaladministrativo > SQL Server

// Dependencias Sincronizadores
epdPo1nt_Syncronizador > MS-Sync
epdPo1nt_Syncronizador > SQL Server
WS-SincronizadorSalas > MS-Sync
WS-SincronizadorSalas > SQL Server
WS-SincronizacionBascula > SQL Server
ws-reenviodte > ms-procesos-locales
ws-reenviodte > SQL Server

// Dependencias Monitoreo
po1nt-monitoring > SQL Server
```

---

# Diagramas de Componentes

## 5. MS-Sync - Arquitectura Interna

Estructura interna del microservicio de sincronizacion.

```eraser
// MS-Sync - Arquitectura Interna
direction down

// Controllers
Controllers [color: blue] {
    EventController [icon: code]
    SyncController [icon: code]
}

// Repositories
Repositories [color: orange] {
    TerminalSyncRepository [icon: database]
    SyncTypeRepository [icon: database]
}

// Models
Models [color: purple] {
    Terminal [icon: file]
    TerminalSync [icon: file]
    SyncType [icon: file]
    Event [icon: file]
}

// Database Tables
Database [color: green] {
    terminals [icon: database]
    terminal_sync [icon: database]
    sync_types [icon: database]
}

// Conexiones
EventController > TerminalSyncRepository
SyncController > TerminalSyncRepository
SyncController > SyncTypeRepository
TerminalSyncRepository > terminals
TerminalSyncRepository > terminal_sync
SyncTypeRepository > sync_types
```

---

## 6. Sincronizadores - Interaccion

Interaccion entre los diferentes sincronizadores Windows.

```eraser
// Sincronizadores - Interaccion
direction down

// Sincronizadores
Sincronizadores [color: orange] {
    epdPo1nt_Syncronizador [icon: clock]
    WS-SincronizadorSalas [icon: clock]
    WS-SincronizacionBascula [icon: clock]
    sincronizacion-sala [icon: clock]
    ws-reenviodte [icon: clock]
}

// APIs
APIs [color: blue] {
    MS-Sync API [icon: server]
    Ministerio Hacienda [icon: building]
}

// Bases de Datos
Bases de Datos [color: green] {
    BD Central [icon: database]
    BD Sucursales [icon: database]
}

// Conexiones
epdPo1nt_Syncronizador > BD Central
epdPo1nt_Syncronizador > BD Sucursales
WS-SincronizadorSalas > MS-Sync API
WS-SincronizadorSalas > BD Sucursales
MS-Sync API > BD Central
WS-SincronizacionBascula > BD Central
sincronizacion-sala > MS-Sync API
ws-reenviodte > BD Central
ws-reenviodte > Ministerio Hacienda
```

---

# Diagramas de Flujo (Secuencia)

## 7. Flujo de Autenticacion

Proceso de login de usuario en el portal administrativo.

```eraser
// Flujo de Autenticacion - Sequence Diagram

Usuario [icon: user]
Frontend [icon: monitor, label: "Nuxt"]
MS-Autn [icon: shield]
SQL Server [icon: database]

Usuario > Frontend: Ingresa credenciales
Frontend > MS-Autn: POST /api/Auth
MS-Autn > SQL Server: SELECT user WHERE username
SQL Server > MS-Autn: User data

activate MS-Autn
MS-Autn > MS-Autn: BCrypt.Verify(password)
MS-Autn > MS-Autn: Crypto.Encrypt(JWT)
deactivate MS-Autn

MS-Autn > SQL Server: INSERT session
MS-Autn > Frontend: {token, type: Bearer, duration: 20}

activate Frontend
Frontend > Frontend: Almacena token en cookie
deactivate Frontend

Frontend > Usuario: Redirige a dashboard
```

---

## 8. Flujo de Sincronizacion de Productos

Proceso de crear un producto y sincronizarlo a las terminales.

```eraser
// Flujo de Sincronizacion de Productos - Sequence Diagram

Admin [icon: user, label: "Nuxt"]
MS-Products [icon: package]
SyncEvent [icon: refresh-cw]
SQL Server [icon: database]
MS-Sync [icon: refresh-cw]
Terminal POS [icon: desktop]

Admin > MS-Products: POST /api/products
MS-Products > SQL Server: INSERT products
MS-Products > SyncEvent: SyncEvent.save(create-product)
SyncEvent > SQL Server: INSERT terminal_sync (pendiente)
MS-Products > Admin: 200 OK

// Cada 5 minutos
Terminal POS > MS-Sync: GET /api/Event/sync
MS-Sync > SQL Server: SELECT terminal_sync pendientes
MS-Sync > Terminal POS: [{type: products, guid}]

Terminal POS > MS-Sync: GET /api/Sync/products
MS-Sync > SQL Server: EXEC SP_Sync_Products
SQL Server > MS-Sync: DataTable productos
MS-Sync > SQL Server: UPDATE date_send
MS-Sync > Terminal POS: JSON productos

activate Terminal POS
Terminal POS > Terminal POS: Procesa productos
deactivate Terminal POS

Terminal POS > MS-Sync: POST /api/Sync/products
MS-Sync > SQL Server: UPDATE date_confirm
```

---

## 9. Flujo de Venta en POS

Proceso completo de una venta con facturacion electronica.

```eraser
// Flujo de Venta en POS - Sequence Diagram

Cajero [icon: user]
POS [icon: desktop, label: "po1nt-pos"]
BD Local [icon: database]
ms-locales [icon: file-check, label: "ms-procesos-locales"]
MH [icon: building, label: "Ministerio Hacienda"]

Cajero > POS: Escanea productos
POS > BD Local: SELECT precio, promocion
BD Local > POS: Datos producto

activate POS
POS > POS: Calcula totales
deactivate POS

Cajero > POS: Selecciona forma pago
Cajero > POS: Finaliza venta
POS > BD Local: INSERT transaccion
POS > ms-locales: POST /api/FacturacionElectronica/sendFact

activate ms-locales
ms-locales > ms-locales: Genera estructura DTE
deactivate ms-locales

ms-locales > MH: Envia factura electronica
MH > ms-locales: Sello y codigo
ms-locales > BD Local: UPDATE transaccion (sello)
ms-locales > POS: DTE confirmado

activate POS
POS > POS: Imprime recibo
deactivate POS

POS > Cajero: Venta completada
```

---

## 10. Flujo de Pago de Remesa

Proceso de pago de remesa internacional.

```eraser
// Flujo de Pago de Remesa - Sequence Diagram

Cajero [icon: user]
POS [icon: desktop, label: "po1nt-pos"]
MS Corresponsales [icon: credit-card, label: "ms-corresponsales"]
Cuscatlan [icon: dollar-sign, label: "Cuscatlan API"]
SQL Server [icon: database]

Cajero > POS: Ingresa datos remesa
POS > MS Corresponsales: POST /api/CuscaTransferInfo
MS Corresponsales > Cuscatlan: TransferInfo request
Cuscatlan > MS Corresponsales: Datos de remesa
MS Corresponsales > POS: Info beneficiario, monto

Cajero > POS: Confirma pago
POS > MS Corresponsales: POST /api/CuscaLookupPerson
MS Corresponsales > Cuscatlan: Busca beneficiario
Cuscatlan > MS Corresponsales: Datos persona

POS > MS Corresponsales: POST /api/CuscaConfirmSimplifiedPayment
MS Corresponsales > Cuscatlan: Confirma pago
Cuscatlan > MS Corresponsales: Confirmacion
MS Corresponsales > SQL Server: INSERT PxTransactions
MS Corresponsales > POS: Recibo remesa

activate POS
POS > POS: Imprime comprobante
deactivate POS
```

---

## 11. Flujo de Recarga Telefonica

Proceso de recarga de saldo telefonico.

```eraser
// Flujo de Recarga Telefonica - Sequence Diagram

Cajero [icon: user]
POS [icon: desktop, label: "po1nt-pos"]
MS Corresponsales [icon: credit-card, label: "ms-corresponsales"]
Operador [icon: smartphone, label: "Tigo/Claro API"]
SQL Server [icon: database]

Cajero > POS: Selecciona operador y monto
POS > MS Corresponsales: GET /api/BalanceCompanies
MS Corresponsales > Operador: Consulta saldo agente
Operador > MS Corresponsales: Saldo disponible
MS Corresponsales > POS: Saldo OK

Cajero > POS: Ingresa numero telefono
POS > MS Corresponsales: POST /api/RechargeCompanies
MS Corresponsales > Operador: Ejecuta recarga
Operador > MS Corresponsales: Confirmacion recarga
MS Corresponsales > SQL Server: INSERT transaccion
MS Corresponsales > POS: Recarga exitosa

activate POS
POS > POS: Imprime comprobante
deactivate POS
```

---

## 12. Flujo de Sincronizacion Batch

Sincronizacion periodica via Windows Services.

```eraser
// Flujo de Sincronizacion Batch - Sequence Diagram

Timer Service [icon: clock]
MS-Sync API [icon: server, label: "MS-Sync API"]
BD Central [icon: database]
BD Local [icon: database]

// Cada 5 minutos
Timer Service > MS-Sync API: GET /api/Event/sync (token)
MS-Sync API > BD Central: Query cambios pendientes
BD Central > MS-Sync API: Lista cambios

// Loop: Por cada cambio
Timer Service > MS-Sync API: GET /api/Sync/{tipo}
MS-Sync API > BD Central: EXEC SP_{tipo}
BD Central > MS-Sync API: DataTable
MS-Sync API > Timer Service: JSON datos

Timer Service > BD Local: EXEC SP_Apply_{tipo}
BD Local > Timer Service: Aplicado

Timer Service > MS-Sync API: POST /api/Sync/{tipo} (confirmar)
MS-Sync API > BD Central: UPDATE date_confirm
```

---

## 13. Flujo de Reenvio DTE

Reenvio automatico de facturas electronicas fallidas.

```eraser
// Flujo de Reenvio DTE - Sequence Diagram

ws-reenviodte [icon: clock]
SQL Server [icon: database]
ms-locales [icon: file-check, label: "ms-procesos-locales"]
MH [icon: building, label: "Ministerio Hacienda"]

// Horario: 1:00 AM - 6:00 AM, cada 30 min
activate ws-reenviodte
ws-reenviodte > ws-reenviodte: Timer cada 30 min
deactivate ws-reenviodte

ws-reenviodte > SQL Server: SELECT transacciones sin sello
SQL Server > ws-reenviodte: Lista transacciones fallidas

// Loop: Por cada transaccion
ws-reenviodte > ms-locales: POST /api/FacturacionElectronica/sendFact
ms-locales > MH: Envia DTE

alt [label: Si exito] {
    MH > ms-locales: Sello electronico
    ms-locales > SQL Server: UPDATE transaccion (sello)
}
else [label: Si fallo] {
    MH > ms-locales: Error
    ms-locales > SQL Server: INSERT log error
}

activate ws-reenviodte
ws-reenviodte > ws-reenviodte: Escribe log resultados
deactivate ws-reenviodte
```

---

## 14. Flujo de Sincronizacion MS-Sync

Detalle del proceso de sincronizacion en el microservicio.

```eraser
// Flujo de Sincronizacion MS-Sync - Sequence Diagram

Terminal [icon: desktop]
MS-Sync [icon: refresh-cw]
SQL Server [icon: database]

Terminal > MS-Sync: GET /api/Event/sync
MS-Sync > SQL Server: Query terminal_sync pendientes
SQL Server > MS-Sync: Lista sincronizaciones
MS-Sync > Terminal: [{type, guid, ruta}]

Terminal > MS-Sync: GET /api/Sync/{type}
MS-Sync > SQL Server: EXEC SP_{procedimiento}
SQL Server > MS-Sync: DataTable
MS-Sync > SQL Server: UPDATE date_send
MS-Sync > Terminal: JSON data

Terminal > MS-Sync: POST /api/Sync/{type}
MS-Sync > SQL Server: UPDATE date_confirm
MS-Sync > Terminal: 200 OK
```

---

# Uso en Eraser

Para usar estos diagramas en Eraser:

1. Ir a [eraser.io](https://www.eraser.io/)
2. Crear un nuevo diagrama
3. Seleccionar "Diagram as Code"
4. Copiar el contenido del bloque de codigo (sin los backticks)
5. Pegar en el editor de Eraser

## Iconos Disponibles

Eraser soporta una amplia variedad de iconos. Los mas usados en estos diagramas:

| Icon | Uso |
|------|-----|
| `user` | Usuarios/Actores |
| `monitor` | Aplicaciones web |
| `desktop` | Aplicaciones desktop |
| `server` | Servidores/APIs |
| `database` | Bases de datos |
| `shield` | Autenticacion/Seguridad |
| `settings` | Configuracion |
| `package` | Productos/Paquetes |
| `refresh-cw` | Sincronizacion |
| `file-text` | Logs/Documentos |
| `file-check` | Facturacion |
| `credit-card` | Pagos |
| `clock` | Timers/Servicios |
| `building` | Entidades externas |
| `dollar-sign` | Dinero/Transacciones |
| `smartphone` | Dispositivos moviles |
| `activity` | Monitoreo |
| `code` | Codigo/Librerias |
| `globe` | Integraciones externas |

---

*Documentacion de Diagramas - Plataforma Po1nt*
*Total de diagramas: 14*
*Formato: Eraser Diagram-as-Code*
*Documentacion Eraser: https://docs.eraser.io/docs/diagram-as-code*
