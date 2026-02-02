# Flujos de Negocio - Plataforma Po1nt

## 1. Flujo de Autenticacion

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

**Descripcion paso a paso:**
1. Usuario ingresa usuario y contrasena en la pagina de login
2. Frontend envia credenciales al microservicio de autenticacion
3. MS-Autn busca el usuario en base de datos
4. Verifica la contrasena con BCrypt
5. Genera token JWT y lo encripta con AES-256
6. Crea registro de sesion en BD
7. Retorna token encriptado al frontend
8. Frontend almacena token y redirige al usuario

---

## 2. Flujo de Sincronizacion de Productos

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

**Descripcion paso a paso:**
1. Administrador crea/actualiza producto desde portal web
2. MS-Products guarda en BD y dispara evento de sincronizacion
3. Se crea registro pendiente en terminal_sync para cada terminal
4. Terminal POS consulta periodicamente sincronizaciones pendientes
5. MS-Sync ejecuta stored procedure y retorna datos
6. Terminal procesa datos y confirma recepcion

---

## 3. Flujo de Venta en POS

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

**Descripcion paso a paso:**
1. Cajero escanea codigos de barra de productos
2. POS consulta precios y promociones en BD local
3. Sistema calcula subtotales, impuestos y descuentos
4. Cajero selecciona forma de pago (efectivo, tarjeta, etc.)
5. POS registra transaccion en BD local
6. Envia datos a microservicio de facturacion
7. Microservicio genera DTE y lo envia al Ministerio de Hacienda
8. MH retorna sello electronico
9. POS imprime recibo con sello

---

## 4. Flujo de Pago de Remesa

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

**Descripcion paso a paso:**
1. Cajero ingresa numero de referencia de remesa
2. POS consulta informacion de la remesa via microservicio
3. Microservicio consulta a Cuscatlan API
4. Se muestra info del beneficiario y monto
5. Cajero verifica identidad y confirma pago
6. Sistema busca datos completos del beneficiario
7. Se confirma el pago con el proveedor
8. Se registra transaccion y se imprime comprobante

---

## 5. Flujo de Recarga Telefonica

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

## 6. Flujo de Sincronizacion Batch (Timers)

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

## 7. Flujo de Reenvio DTE (Automatico)

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

## Resumen de Flujos

| Flujo | Componentes Involucrados | Frecuencia |
|-------|--------------------------|------------|
| Autenticacion | nuxt-front-admin, MS-Autn | Por demanda |
| Sync Productos | MS-Products, MS-Sync, Sincronizadores | Cada 5 min |
| Venta POS | po1nt-pos, ms-procesos-locales, MH | Por transaccion |
| Pago Remesa | po1nt-pos, ms-corresponsales, Cuscatlan/Airpak | Por demanda |
| Recarga Telefonica | po1nt-pos, ms-corresponsales, Operadores | Por demanda |
| Sync Batch | Sincronizadores, MS-Sync | Cada 5-7 min |
| Reenvio DTE | ws-reenviodte, ms-procesos-locales, MH | Cada 30 min (noche) |

---

*Documento generado automaticamente - Febrero 2026*
