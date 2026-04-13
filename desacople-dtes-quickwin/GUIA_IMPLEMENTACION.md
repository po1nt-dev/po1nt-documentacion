# Guia de Implementacion: Desacople DTEs — Quickwin

## Resumen

Esta feature implementa reintentos locales de DTEs en la caja POS, reduciendo la dependencia de la tabla BillingMH_TransactionLog central. El flujo es:

```
POS → dte-service-local (localhost:7890) → ms-procesos-locales (sendFactDesacople) → Bitworks
```

**Beneficios:**
- Reintentos automaticos locales (2min, 10min, 30min, 2h)
- 0 registros en BillingMH_TransactionLog en transacciones exitosas
- Solo 1 registro de error cuando hay errores de datos (NIT, direccion, etc.)
- Errores de conexion/timeout se reintentan localmente sin guardar log

---

## Prerequisitos

- Visual Studio 2022 con .NET 8 SDK
- SQL Server local con BD `SatellitePOS_MH`
- Acceso a ms-procesos-locales (local o remoto)

---

## Paso 1: Scripts SQL en BD del POS (SatellitePOS_MH)

Ejecutar en orden en la BD `SatellitePOS_MH` de la caja piloto:

```
sincronizacion-sala/sql/desacople-quickwin/01_ddl_pos_EstadoEnvioDte.sql
sincronizacion-sala/sql/desacople-quickwin/02_ddl_pos_BillingMH_TransactionLog_local.sql
sincronizacion-sala/sql/desacople-quickwin/03_parametros_pos_desacople.sql
```

**Verificacion:**
```sql
-- Verificar columna EstadoEnvioDte
SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TransEncabezado' AND COLUMN_NAME = 'EstadoEnvioDte';

-- Verificar tabla BillingMH_TransactionLog local
SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME = 'BillingMH_TransactionLog';

-- Verificar parametros
SELECT ID_Parameter, Value1 FROM SatellitePOS_Parameters
WHERE ID_Parameter IN ('10039', '10040');
```

---

## Paso 2: Desplegar ms-procesos-locales

### Rama: `feature/desacople-dtes-quickwin`

**Cambio:** Nuevo endpoint `POST /api/FacturacionElectronica/sendFactDesacople`

1. Hacer checkout de la rama `feature/desacople-dtes-quickwin`
2. Build y desplegar (mismo proceso que el servicio actual)
3. El endpoint original `sendFact` sigue funcionando sin cambios

**Verificacion:**
```
curl -X POST http://procesos-locales.satellitepos.com/api/FacturacionElectronica/sendFactDesacople \
  -H "Content-Type: application/json" \
  -d "{}"
```
Debe responder (con error de validacion, pero no 404).

---

## Paso 3: Desplegar dte-service-local

### Rama: `feature/desacople-dtes-quickwin`

**Configuracion (`appsettings.json`):**
```json
{
    "ProcesosLocales": {
        "Url": "http://procesos-locales.satellitepos.com",
        "TimeoutSegundos": 30
    },
    "BdLocalPos": {
        "CadenaConexion": "Data Source=.;Initial Catalog=SatellitePOS_MH;user id=sa;password=XXXXX;TrustServerCertificate=True;"
    }
}
```

> **IMPORTANTE:** Ajustar `ProcesosLocales:Url` segun el ambiente:
> - Local (debug): `http://localhost:5115`
> - Produccion: `http://procesos-locales.satellitepos.com`

1. Hacer checkout de la rama `feature/desacople-dtes-quickwin`
2. Editar `appsettings.json` con la URL correcta y credenciales de BD
3. Build: `dotnet build`
4. Ejecutar: `dotnet run` (o instalar como Windows Service)

**Verificacion:**
```
curl http://localhost:7890/health
```
Debe responder: `{"estado":"activo"}`

---

## Paso 4: Activar desacople en el POS

En la BD `SatellitePOS_MH` de la caja piloto:

```sql
-- Activar desacople
UPDATE SatellitePOS_Parameters SET Value1 = '1' WHERE ID_Parameter = '10039';

-- Verificar URL del servicio local (default: http://localhost:7890)
SELECT Value1 FROM SatellitePOS_Parameters WHERE ID_Parameter = '10040';
```

> **NO es necesario reiniciar el POS.** El parametro se lee en cada transaccion.

---

## Paso 5: Desplegar ws-reenviodte (opcional)

### Rama: `feature/desacople-dtes-quickwin`

Solo necesario si ws-reenviodte esta corriendo en la caja piloto.

**Cambio:** Excluye DTEs con `EstadoEnvioDte IN ('EN_ESPERA_REINTENTO_LOCAL', 'PROCESADO')` de los reintentos nocturnos.

---

## Rollback de DTE_Escalaciones (si aplica)

Si los scripts de la rama anterior `feature/desacople-dtes` fueron ejecutados:

```
sincronizacion-sala/sql/desacople-quickwin/99_rollback_DTE_Escalaciones.sql
```

---

## Pruebas

### Prueba 1: Venta exitosa con desacople

1. Asegurar que `dte-service-local` y `ms-procesos-locales` estan corriendo
2. Asegurar parametro 10039 = "1"
3. Realizar una venta normal en el POS
4. **Verificar:**
   - En `TransEncabezado`: el campo `MH_Sello` debe tener valor, `EstadoEnvioDte` = 'PROCESADO'
   - En `BillingMH_TransactionLog` central: NO debe haber registros nuevos para esta transaccion
   - En logs de dte-service-local (`C:\epdsoft\Log\DTE\`): debe mostrar "Exito Guid=... Sello=..."

### Prueba 2: Error de datos (NIT invalido)

1. Realizar una venta con datos de cliente invalidos (NIT incorrecto)
2. **Verificar:**
   - En `BillingMH_TransactionLog` central: 1 registro con TypeTransacction='RESPONSE'
   - En `BillingMH_TransactionLog` local: 1 registro con TypeTransacction='RESPONSE'
   - En `TransEncabezado`: `EstadoEnvioDte` = 'ESCALADO_LOCAL'
   - En logs: "Error ... Categoria=DatosInvalidos"

### Prueba 3: Reintento por error de conexion

1. Detener `ms-procesos-locales` (simular caida)
2. Realizar una venta
3. **Verificar:**
   - El POS completa la venta (no se bloquea)
   - En `TransEncabezado`: `EstadoEnvioDte` = 'EN_ESPERA_REINTENTO_LOCAL'
   - En `BillingMH_TransactionLog`: NO hay registros nuevos
   - En logs: "Excepcion de red ... encolando reintento"
4. Reiniciar `ms-procesos-locales`
5. Esperar ~2 minutos
6. **Verificar:**
   - En `TransEncabezado`: `EstadoEnvioDte` cambia a 'PROCESADO', `MH_Sello` tiene valor
   - En logs: "Reintento exitoso Guid=..."

### Prueba 4: Fallback a flujo original

1. Detener `dte-service-local`
2. Realizar una venta
3. **Verificar:**
   - El POS usa el endpoint central `sendFact` (flujo original)
   - En `BillingMH_TransactionLog` central: 4 registros (ORIGIN, REQUEST, RES-BITW, RESPONSE) como antes
   - Esto confirma que el fallback funciona

### Prueba 5: Desactivar desacople

1. Ejecutar: `UPDATE SatellitePOS_Parameters SET Value1 = '0' WHERE ID_Parameter = '10039'`
2. Realizar una venta
3. **Verificar:** El POS usa el flujo original (4 registros en BillingMH_TransactionLog)

---

## Monitoreo

### Logs de dte-service-local
```
C:\epdsoft\Log\DTE\DTE_Log_YYYY-MM-DD.txt
```

### Cola de reintentos (SQLite)
```
C:\epdsoft\dte-cola-reintentos.db
```
Consultar con cualquier visor SQLite:
```sql
SELECT GuidTransaccion, ContadorReintentos, Estado, ProximoReintento
FROM DTE_ColaReintentos WHERE Estado = 0;
```

### Errores escalados localmente
```sql
SELECT TOP 10 * FROM BillingMH_TransactionLog
WHERE TypeBill = 'DTE-LOCAL'
ORDER BY ID DESC;
```

---

## Ramas por repositorio

| Repositorio | Rama |
|---|---|
| ms-procesos-locales | `feature/desacople-dtes-quickwin` |
| dte-service-local | `feature/desacople-dtes-quickwin` |
| ws-reenviodte | `feature/desacople-dtes-quickwin` |
| sincronizacion-sala | `feature/desacople-dtes-quickwin` |
| po1nt-pos | `feature/desacople-dtes` (sin cambios adicionales) |
