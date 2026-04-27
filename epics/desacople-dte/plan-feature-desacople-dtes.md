# Plan: feature/desacople-dtes

**Fecha:** 2026-03-03
**Basado en:** `re-arquitectura-dtes.md`
**Rama:** `feature/desacople-dtes`

---

## Decisiones de Diseño Revisadas

### D1. Repositorio para `DteServiceLocal` — Repositorio independiente

**Decisión:** Crear un repositorio nuevo `dte-service-local` en lugar de colocarlo dentro de `po1nt-pos`.

**Justificación:**
- `po1nt-pos` es un mono-repo de WinForms/.NET Framework con ~25 sub-proyectos (SatelitePOS, Inventario, Colectores, Graficos, etc.). Agregar un proyecto .NET 8 Worker Service genera fricción con el toolchain existente.
- `DteServiceLocal` tiene su propio ciclo de vida: se despliega como Windows Service independiente, se actualiza sin tocar el POS, y tiene sus propias dependencias (SQLite, ASP.NET Core minimal API).
- Un repo separado facilita CI/CD independiente, versionado propio, y que el equipo trabaje sin riesgo de afectar el POS.
- La solución `Po1nt - enterprise- (2023 - Selectos).sln` en `po1nt-pos` no necesita conocer este servicio.

### D2. Timeout del Fallback — Usar el mismo timeout que el POS configura actualmente

**Hallazgo:** El timeout actual del POS hacia la API central se configura en `C:\epdsoft\Config\ParametrosGenerales.xml` en el campo `TimeoutFactElecSegundos`. El valor por defecto es **20 segundos** (línea 361 de `ws-reenviodte`). El fallback de 2 segundos propuesto originalmente es demasiado agresivo.

**Decisión:** El timeout del fallback al servicio local debe ser razonable — si `DteServiceLocal` no responde en **3 segundos**, es porque está caído. No estamos esperando a Bitworks aquí, solo verificamos que el servicio local esté vivo (health check). El timeout real hacia Bitworks lo maneja `DteServiceLocal` internamente con su propio timeout configurable (default 30s).

**Implementación revisada:**
```vb
' Health check al servicio local (rápido, solo verifica que esté vivo)
Dim url_DteLocal As String = "http://localhost:7890/health"
Try
    Dim testReq As HttpWebRequest = DirectCast(WebRequest.Create(url_DteLocal), HttpWebRequest)
    testReq.Timeout = 3000  ' 3 segundos — solo health check
    testReq.Method = "GET"
    testReq.GetResponse().Close()
    url_WebApi = "http://localhost:7890/dte/enviar"
Catch
    url_WebApi = url_Central  ' fallback silencioso a API central
End Try
```

**Dónde encontrar la configuración actual del timeout:**
- Archivo: `C:\epdsoft\Config\ParametrosGenerales.xml` → campo `TimeoutFactElecSegundos`
- Valor por defecto: `20` (segundos)
- Usado en: `ws-reenviodte` línea 396: `_request.Timeout = Convert.ToInt32(TimeoutFactElecSegundos) * 1000`

### D3. Tabla nueva para escalaciones — NO usar `BillingMH_TransactionLog`

**Hallazgo del análisis:**

La tabla `BillingMH_TransactionLog` tiene problemas serios:
- Genera **deadlocks** frecuentes (SqlException 1205), probablemente causados por el campo `Message` de tipo `varchar(max)` que impide optimización de locks a nivel de fila, provocando locks a nivel de tabla.
- Recibe 4 inserts por transacción (~800,000/día) en un ciclo de escritura intensivo.
- El proceso de reenvío (`ws-reenviodte` y `portaladministrativo-desktop`) **NO depende de esta tabla como fuente primaria**:
  - `ws-reenviodte` obtiene el JSON de `TransEncabezado.MH_Request` via SP `SatellitePOS_Get_DTE_Reenvio` (línea 245, ejecutado contra la BD local del POS).
  - `portaladministrativo-desktop` usa la misma estrategia: primero intenta `SatellitePOS_Get_DTE_Reenvio` contra la BD local del POS (línea 428), y **solo como fallback** consulta `BillingMH_TransactionLog` en el servidor central (línea 452) si `MH_Request` está vacío localmente.

**Decisión:** Crear una tabla local nueva `DTE_Escalaciones` en la BD del servidor de sala (no en `BillingMH_TransactionLog`) para errores no-reintentables. Razones:
1. **Aislamiento total** de los problemas de deadlock de `BillingMH_TransactionLog`
2. **Monitoreo independiente** del rendimiento y volumen de escalaciones
3. **Mantenimiento propio** — podemos ajustar esquema, índices, y retención sin afectar el flujo existente
4. **Migración segura** — durante la transición ambos sistemas coexisten sin interferencia

### D4. Nombres de campos y código en español

Todos los nombres de campos, tablas, variables y comentarios en el código nuevo se escribirán en español para mantener consistencia con el ecosistema existente (ej: `TransEncabezado`, `Sucursales`, `Cajeros`).

### D5. Escalaciones via sincronización de sala — NO llamada directa al API central

**Principio:** El POS debe funcionar de manera independiente. No debe depender de la disponibilidad del servidor central para reportar errores.

**Hallazgo:** `sincronizacion-sala` ya tiene un mecanismo genérico de sincronización local → central perfecto para esto:

```
TimerServerLocal (configurable)
  ↓
SP_Obtener_Sincronizaciones_Genericas_Locales  ← tabla de configuración con SPs dinámicos
  ↓
Para cada tipo de sincronización configurado:
  1. SP_Extrae_Informacion  → lee datos pendientes de cada terminal
  2. SP_Guarda_Informacion  → guarda en BD del servidor de sala
  3. SP_Actualiza_Status    → marca como sincronizado en el terminal
```

**Decisión:** Las escalaciones se escriben en una tabla local (`DTE_Escalaciones`) en la BD del POS, y el proceso `sincronizacion-sala` las recoge mediante un nuevo set de SPs genéricos registrados en `SP_Obtener_Sincronizaciones_Genericas_Locales`. Esto nos da:
- **Resiliencia**: Si el servidor de sala está caído, las escalaciones quedan en la BD local del POS hasta que se sincronicen
- **Control de cadencia**: Podemos ajustar el intervalo de sincronización sin tocar `DteServiceLocal`
- **Consistencia**: Usa el mismo patrón que ya sincroniza transacciones, cortes, etc.

**Flujo revisado de escalaciones:**
```
DteServiceLocal detecta error no-reintentable
  ↓
INSERT en DTE_Escalaciones (BD local del POS, SQL Server)
  + INSERT en DTE_RegistroEventos (SQLite, log local)
  ↓
sincronizacion-sala (TimerServerLocal, intervalo configurable)
  ↓
SP_Extrae_DTE_Escalaciones → lee escalaciones pendientes
  ↓
SP_Guarda_DTE_Escalaciones → guarda en BD del servidor de sala
  ↓
SP_Actualiza_DTE_Escalaciones_Estado → marca como sincronizada en POS
```

> Ya no se necesita el componente `CentralReporter` con llamada HTTP directa. Se reemplaza por un simple INSERT local.

### D6. Escenario de caída prolongada de Bitworks — Ciclo completo de recuperación

**Problema:** Si Bitworks se cae por horas, todos los errores son Transient. Tras 5 reintentos se agotan y se escalan al central. Cuando Bitworks regresa, ¿quién reintenta los escalados?

**Análisis del flujo completo:**

```
Bitworks cae (hora 0)
  ↓
Transacciones nuevas fallan → ErrorClassifier = Transient → Cola SQLite
  ↓
RetryWorker reintenta con backoff (2min, 10min, 30min, 2h)
  ↓
Si Bitworks sigue caído tras 5 intentos (~4.5h):
  Estado = MaxReintentosAlcanzados
  INSERT en DTE_Escalaciones (BD local)
  ↓
sincronizacion-sala sincroniza escalaciones al servidor de sala
  ↓
Bitworks regresa (hora X)
  ↓
¿Quién reintenta las escalaciones?
```

**Decisión: Dos mecanismos de recuperación complementarios:**

**Mecanismo 1 — `ws-reenviodte` (ya existente, se mantiene durante transición):**
- Sigue corriendo 1-6 AM, busca `MH_Sello IS NULL` en `TransEncabezado`
- Las transacciones que agotaron reintentos en `DteServiceLocal` siguen teniendo `MH_Sello = NULL` → `ws-reenviodte` las encuentra y reintenta via API central
- **No requiere cambio alguno** — funciona como red de seguridad

**Mecanismo 2 — RetryWorker extendido con re-escaneo periódico (nuevo):**
- El `RetryWorker` no solo procesa la cola SQLite, también hace un **re-escaneo periódico** de `DTE_Escalaciones` locales que tengan `CategoriaError = 'Transitorio'` y `EstadoEscalacion = 'MaxReintentosAlcanzados'`
- Si el `CircuitBreaker` detecta que Bitworks volvió (primer envío exitoso), cambia estado a `CircuitoCerrado`
- En ese momento, el RetryWorker re-encola las escalaciones transitorias pendientes para reintento
- Esto permite recuperación automática 24/7, no solo en la ventana nocturna de `ws-reenviodte`

**Flujo de recuperación:**
```
Bitworks regresa
  ↓
CircuitBreaker detecta primer éxito → CircuitoCerrado
  ↓
RetryWorker re-escaneo (cada 15 min):
  SELECT de DTE_Escalaciones
  WHERE CategoriaError = 'Transitorio'
    AND EstadoEscalacion = 'MaxReintentosAlcanzados'
  ↓
Re-encola en Cola SQLite (DTE_ColaReintentos) con ContadorReintentos = 0
  ↓
Reintentos normales con backoff
  ↓
Si éxito → PosDbUpdater actualiza TransEncabezado con sello
```

> **Nota:** Las escalaciones con `CategoriaError = 'DatosInvalidos'` o `'ErrorNegocio'` NO se re-encolan automáticamente. Requieren corrección manual (analista o portal).

### D7. Campo `EstadoEnvioDte` en `TransEncabezado` — Coordinación entre servicios

**Hallazgo crítico:** `ws-reenviodte` NO solo corre en horario nocturno 1-6 AM. La condición de hora en `EnviarDTEAutomatico()` (línea 124) tiene un bug lógico:
```vb
' horaInicioP = 1, horaFinP = 6
If Not (hora >= horaInicio Or hora <= horaFin) Then Exit Function
```
La expresión `hora >= 1 Or hora <= 6` es **verdadera para toda hora** (0 cumple `<= 6`, y 1-23 cumplen `>= 1`). El `Not(...)` nunca es `true`, así que `Exit Function` nunca se ejecuta. **`ws-reenviodte` reenvía cada 30 minutos, 24/7.**

Esto hace que el riesgo de colisión con `DteServiceLocal` sea alto. El cooldown de 3h en `MH_FechaEnvio` mitiga parcialmente, pero no es suficiente para los primeros minutos tras un fallo.

**Decisión:** Agregar un campo `EstadoEnvioDte` a `TransEncabezado` que actúe como semáforo entre los servicios.

**Valores del campo:**

| Valor | Significado | Quién lo escribe | Quién lo respeta |
|---|---|---|---|
| `NULL` | Comportamiento legacy (sin DteServiceLocal) | — | `ws-reenviodte` lo trata como candidato normal |
| `PROCESADO` | DTE enviado y sellado exitosamente | `DteServiceLocal` | Todos lo ignoran (ya tiene sello) |
| `EN_ESPERA_REINTENTO_LOCAL` | En cola de reintentos del `DteServiceLocal` | `DteServiceLocal` al encolar | `ws-reenviodte` lo **salta** |
| `ESCALADO_LOCAL` | Agotó reintentos o error no-reintentable, escalado a `DTE_Escalaciones` | `DteServiceLocal` al escalar | `ws-reenviodte` **puede** tomarlo como última red de seguridad |
| `REINTENTO_RECUPERACION` | Re-encolado tras recuperación de Bitworks | `TrabajadorReintentos` (re-escaneo) | `ws-reenviodte` lo **salta** |

**Ciclo de vida completo:**

```
Transacción nueva en POS
  │
  ▼
DteServiceLocal recibe POST /dte/enviar
  │
  ├─ Éxito → EstadoEnvioDte = 'PROCESADO'
  │
  ├─ Error Transitorio → Encola en SQLite
  │   └─ EstadoEnvioDte = 'EN_ESPERA_REINTENTO_LOCAL'
  │   │
  │   ├─ Reintento exitoso → EstadoEnvioDte = 'PROCESADO'
  │   └─ Agota reintentos → EstadoEnvioDte = 'ESCALADO_LOCAL'
  │       │
  │       └─ Bitworks regresa, re-escaneo → EstadoEnvioDte = 'REINTENTO_RECUPERACION'
  │           │
  │           ├─ Éxito → EstadoEnvioDte = 'PROCESADO'
  │           └─ Falla de nuevo → EstadoEnvioDte = 'ESCALADO_LOCAL'
  │
  └─ Error DatosInvalidos/ErrorNegocio → EstadoEnvioDte = 'ESCALADO_LOCAL'
```

**Cambio mínimo en `ws-reenviodte`** — agregar una condición al WHERE de las dos queries:

```sql
-- Query Fase 1 (línea 212-218): agregar
AND (a.EstadoEnvioDte IS NULL OR a.EstadoEnvioDte = 'ESCALADO_LOCAL')

-- Query Fase 2 (línea 1101-1105): agregar
AND (a.EstadoEnvioDte IS NULL OR a.EstadoEnvioDte = 'ESCALADO_LOCAL')
```

Esto permite:
- **Salas sin DteServiceLocal:** `EstadoEnvioDte` es `NULL` → `ws-reenviodte` sigue funcionando igual (retrocompatible)
- **Salas con DteServiceLocal:** `ws-reenviodte` salta las transacciones que están siendo gestionadas localmente
- **Fallback:** Si `DteServiceLocal` escala una transacción (`ESCALADO_LOCAL`), `ws-reenviodte` puede tomarla como última red de seguridad

**DDL:**
```sql
ALTER TABLE TransEncabezado ADD EstadoEnvioDte VARCHAR(50) NULL;
```

> No necesita índice propio — las queries existentes ya filtran por `MH_Sello` y `MH_ResponseCode` primero, y `EstadoEnvioDte` es un filtro adicional liviano sobre el resultado ya reducido.

### D8. Librería compartida `po1nt-dte` + Pantalla de analistas en `nuxt-front-admin`

**Problema:** La lógica de facturación electrónica está duplicada y dispersa:

| Componente | Dónde vive hoy | Qué hace |
|---|---|---|
| Comunicación con Bitworks (OAuth + envío HTTP) | `ms-procesos-locales/Classes/BitWork/BitWork_Connect.cs` | Selección de endpoint por `idTipoTrans`, envío POST, parseo de respuesta |
| Token OAuth2 | `ms-procesos-locales/Classes/BitWork/Token_BitWork.cs` | Obtención y renovación de token |
| Modelos de documentos DTE | `ms-procesos-locales/Classes/BitWork/` (25 archivos: Factura.cs, CreditoFiscal.cs, FacturaExportacion.cs, etc.) | Estructuras de datos para cada tipo de documento |
| Modelos Request/Response POS | `ms-procesos-locales/Classes/POS_Request.cs`, `POS_Response.cs` | Solicitud y respuesta entre POS y API |
| Clasificación de errores | No existe (se construirá) | Determinar categoría del error |

Esta lógica se necesita en **al menos 3 lugares**:
1. **`dte-service-local`** (nuevo) — envío directo a Bitworks desde cada sala
2. **`nuxt-front-admin`** (vía API backend) — pantalla de analistas para corregir y reenviar DTEs fallidos
3. **`ms-procesos-locales`** (existente, durante transición) — sigue recibiendo tráfico de salas no migradas

**Decisión:** Crear un repositorio `po1nt-dte` como paquete NuGet / librería de clases .NET 8 que centralice toda la lógica DTE reutilizable.

**Estructura de `po1nt-dte`:**

```
po1nt-dte/                              ← Nuevo repositorio
├── Po1ntDte.sln
├── src/
│   └── Po1ntDte/
│       ├── Po1ntDte.csproj             ← Class Library .NET 8
│       │
│       ├── Bitworks/
│       │   ├── ClienteBitworks.cs      ← Portado de BitWork_Connect.cs
│       │   ├── ServicioToken.cs        ← Portado de Token_BitWork.cs
│       │   └── ConfiguracionBitworks.cs
│       │
│       ├── Modelos/
│       │   ├── Documentos/
│       │   │   ├── Factura.cs
│       │   │   ├── CreditoFiscal.cs
│       │   │   ├── CreditoFiscalNotaCredito.cs
│       │   │   ├── FacturaExportacion.cs
│       │   │   ├── FacturaDevolucion.cs
│       │   │   ├── Receptor.cs
│       │   │   ├── ReceptorExportacion.cs
│       │   │   ├── DetalleDocumento.cs
│       │   │   ├── PagoDocumento.cs
│       │   │   ├── Tributos.cs
│       │   │   ├── Direccion.cs
│       │   │   └── ... (demás modelos de BitWork/)
│       │   │
│       │   ├── SolicitudDte.cs         ← Portado de POS_Request.cs
│       │   └── RespuestaDte.cs         ← Portado de POS_Response.cs
│       │
│       ├── Clasificacion/
│       │   ├── ClasificadorErrores.cs  ← NUEVO: lógica de clasificación
│       │   └── CategoriaError.cs       ← Enum: Transitorio, DatosInvalidos, ErrorNegocio
│       │
│       └── Contratos/
│           ├── IClienteBitworks.cs     ← Interfaz para inyección de dependencias
│           └── IServicioToken.cs
│
└── tests/
    └── Po1ntDte.Tests/
        ├── ClasificadorErroresTests.cs ← Crítico: probar todas las señales de error
        └── ClienteBitworksTests.cs
```

**Quién consume `po1nt-dte`:**

| Consumidor | Cómo lo referencia | Qué usa |
|---|---|---|
| `dte-service-local` | Referencia NuGet/proyecto | `ClienteBitworks`, `ClasificadorErrores`, todos los modelos |
| `nuxt-front-admin` (vía backend API) | Endpoint en `ms-procesos-locales` o microservicio nuevo que consume la librería | `ClienteBitworks` para reenvío, modelos para edición |
| `ms-procesos-locales` (transición) | Referencia NuGet/proyecto, reemplaza gradualmente `Classes/BitWork/` | Mismas clases, nueva fuente |

**Pantalla de analistas en `nuxt-front-admin`:**

`nuxt-front-admin` ya tiene variable de entorno `MS_LOCALES` apuntando a `ms-procesos-locales`, y ya muestra transacciones en `pages/config/transaction/index.vue`. La nueva pantalla se integra naturalmente.

**Página:** `pages/dte/escalaciones/index.vue`

**Funcionalidad:**
- **Listado** de escalaciones desde `DTE_Escalaciones_Central` (servidor de sala)
- **Filtros:** por fecha de creación, fecha de generación (BusinessDay), categoría de error (`DatosInvalidos`, `ErrorNegocio`, `Transitorio`), estado (`Pendiente`, `Sincronizada`, `Resuelta`)
- **Detalle** del error: muestra `DetalleError` y `ContenidoSolicitud` (JSON parseado)
- **Edición** de datos del receptor: NIT, NRC, correo, departamento, municipio, actividad económica — similar a `FacturacionElectronicaUpdate.vb` del portal desktop
- **Reenvío:** Tras corregir datos, el analista reenvía el DTE. El frontend llama a un endpoint backend que usa `po1nt-dte.ClienteBitworks` para enviar directamente a Bitworks
- **Actualización de estado:** Si el reenvío es exitoso, marca `EstadoEscalacion = 'Resuelta'` y actualiza `TransEncabezado` del POS con el sello (vía SP o API)

**Backend para la pantalla (endpoint en `ms-procesos-locales` o microservicio nuevo):**

```csharp
// Opción simple: nuevo controller en ms-procesos-locales
[Route("api/[controller]")]
public class DteEscalacionController : ControllerBase
{
    private readonly IClienteBitworks _clienteBitworks;  // de po1nt-dte

    [HttpGet("listar")]
    public ActionResult Listar([FromQuery] FiltroEscalaciones filtro)
    {
        // SELECT de DTE_Escalaciones_Central con filtros
    }

    [HttpPost("reenviar")]
    public ActionResult Reenviar(ReenvioEscalacionRequest req)
    {
        // 1. Deserializar ContenidoSolicitud
        // 2. Aplicar correcciones del analista (NIT, NRC, etc.)
        // 3. _clienteBitworks.Enviar(solicitudCorregida)
        // 4. Si éxito: marcar como Resuelta, actualizar TransEncabezado
        // 5. Retornar resultado
    }
}
```

**Orden de adopción de `po1nt-dte`:**

```
Fase 1 (Semana 1-2):
  Crear po1nt-dte con modelos + ClienteBitworks + ClasificadorErrores
  (portado directo de ms-procesos-locales/Classes/BitWork/)
  ↓
Fase 1 (Semana 2-3):
  dte-service-local referencia po1nt-dte
  (ya no duplica la lógica)
  ↓
Fase 2 (Semana 3):
  ms-procesos-locales referencia po1nt-dte para el nuevo endpoint de escalaciones
  (mantiene sus clases antiguas para el flujo existente de sendFact)
  ↓
Fase 4+ (posterior):
  ms-procesos-locales migra gradualmente de Classes/BitWork/ a po1nt-dte
  (a medida que salas migran a dte-service-local)
```

---

## Resumen de Cambios

| Repositorio | Tipo | Descripción |
|---|---|---|
| `po1nt-dte` | **Nuevo repositorio** | Librería de clases .NET 8 con lógica DTE compartida: ClienteBitworks, modelos de documentos, clasificador de errores |
| `dte-service-local` | **Nuevo repositorio** | Windows Service .NET 8 que consume `po1nt-dte`; endpoint sincrónico, cola SQLite para reintentos automáticos |
| `po1nt-pos` | **Modificación menor** | `FactElectronica.vb` — Health check al servicio local, fallback a API central |
| `sincronizacion-sala` | **Modificación menor** | Registrar nuevos SPs genéricos para sincronizar tabla `DTE_Escalaciones` |
| `ws-reenviodte` | **Modificación menor** | Agregar filtro `EstadoEnvioDte` a queries de selección para respetar reintentos locales |
| `ms-procesos-locales` | **Modificación menor** | Nuevo controller `DteEscalacionController` que consume `po1nt-dte` para listar/reenviar escalaciones |
| `nuxt-front-admin` | **Nuevo módulo** | Pantalla `pages/dte/escalaciones/` para que analistas vean, corrijan y reenvíen DTEs fallidos |
| BD cada POS | **DDL** | `ALTER TABLE TransEncabezado ADD EstadoEnvioDte VARCHAR(50) NULL` + crear `DTE_Escalaciones` |

---

## Principio de Diseño: Comportamiento Idéntico para el Cliente

El flujo desde el punto de vista del cajero y del cliente no cambia:

| Escenario | Comportamiento actual | Comportamiento nuevo |
|---|---|---|
| Bitworks responde OK | Imprime factura con sello ✅ | **Igual** ✅ |
| Error de datos (NIT inválido, etc.) | Muestra error, imprime sin sello ⚠️, cajero corrige manualmente | **Igual** ⚠️ + escalación automática al central para revisión por analista |
| Error de descuadre (montos) | Muestra error, imprime sin sello ⚠️ | **Igual** ⚠️ + escalación automática al central |
| Timeout / error transitorio | Muestra error, imprime sin sello ⚠️ | **Igual** ⚠️ + **reintento automático local** (24/7, no solo 1–6 AM) |

---

## Clasificación de Errores (pieza central del diseño)

No todos los errores se deben reintentar. La clasificación determina qué camino toma cada fallo.

### Taxonomía

```
Error de Bitworks
      │
      ├── TRANSITORIO → Reintento local con backoff + jitter
      │     ├── Timeout de red / conexión rechazada
      │     ├── HTTP 429 Too Many Requests
      │     ├── HTTP 500 / 502 / 503 / 504 (servidor caído)
      │     ├── ResponseCode "01" / "02" (token expirado — el TokenService lo renueva)
      │     └── ResponseCode "03" (error interno de proceso — puede ser transitorio)
      │
      └── NO-REINTENTABLE → Escalación al servidor central
            ├── DATOS INVÁLIDOS (HTTP 400 con campos específicos en el body)
            │     ├── receptor.nit  inválido/faltante
            │     ├── receptor.nrc  inválido/faltante
            │     ├── receptor.correoElectronico  inválido
            │     ├── Receptor.ActividadEconomica inválida
            │     └── Receptor.Direccion (departamento/municipio) inválida
            │
            └── ERROR DE NEGOCIO
                  ├── Descuadre de montos ("La suma de " en el body → reprocesarFactura=true)
                  ├── Documento duplicado (ya procesado en Hacienda)
                  └── Estructura de documento inválida (campos obligatorios faltantes)
```

### Lógica del `ErrorClassifier`

El clasificador inspecciona la respuesta de Bitworks (código HTTP + body) y devuelve una de tres categorías:

| `ErrorCategory` | Siguiente paso |
|---|---|
| `Transient` | Encolar en `DTE_RetryQueue` con backoff |
| `DataValidation` | Escalación inmediata al central + log local |
| `BusinessError` | Escalación inmediata al central + log local |

**Señales usadas para clasificar** (basadas en el código existente de `BitWork_Connect.cs`):

```csharp
// Ejemplos de señales del body de error de Bitworks
body.Contains("La suma de ")          → BusinessError (reprocesarFactura)
body.Contains("receptor.nit")         → DataValidation
body.Contains("receptor.nrc")         → DataValidation
body.Contains("receptor.correo")      → DataValidation
body.Contains("Receptor.ActividadEconomica") → DataValidation
body.Contains("Receptor.Direccion")   → DataValidation
httpStatusCode == 400                 → DataValidation (si no hay señal más específica)
httpStatusCode >= 500                 → Transient
httpStatusCode == 429                 → Transient
WebException (timeout/network)        → Transient
```

---

## Flujo Completo

```
POS ──── POST /dte/enviar ────► DteServiceLocal
                                      │
                               ClienteBitworks.Enviar()
                                      │
                  ┌───────────────────┼──────────────────┐
                  │                   │                   │
           CodigoRespuesta         Error              Timeout /
               = "00"           HTTP 4xx           HTTP 5xx/red
                  │                   │                   │
              Retornar         ClasificadorErrores  ClasificadorErrores
            sello al POS              │                   │
                ✅           DatosInvalidos /       Transitorio
                              ErrorNegocio                │
                                      │           DTE_ColaReintentos
                              EscalacionLocal       (backoff + jitter)
                              INSERT local SQL            │
                                      │           TrabajadorReintentos
                              Retornar error          (background)
                               al POS ⚠️                  │
                                      │           Si éxito → ActualizadorPos
                            sincronizacion-sala    Si >5 intentos → EscalacionLocal
                            sincroniza al central         │
                                                   Re-escaneo cada 15min:
                                                   Si CortaCircuito cerrado
                                                   → re-encola transitorios
```

---

## Fase 1 — Nuevo Repositorio `dte-service-local`

### 1.1 Tecnología y Stack

| Decisión | Elección | Razón |
|---|---|---|
| Lenguaje | C# | Alineado con ms-procesos-locales; el documento ya lo especifica |
| Framework | .NET 8 Worker Service | `UseWindowsService()`, SQLite moderno, async/await |
| Cola de reintentos | SQLite via `Microsoft.Data.Sqlite` | Solo para errores transitorios |
| Escalaciones | SQL Server (BD local del POS) | Se escriben localmente; `sincronizacion-sala` las sincroniza al central |
| HTTP cliente | `HttpClient` | Llamadas a Bitworks y OAuth |
| HTTP servidor | ASP.NET Core minimal API | Endpoint local para el POS |
| Serialización | `System.Text.Json` | Incluido en .NET 8 |

### 1.2 Estructura del Proyecto

```
dte-service-local/              ← Repositorio independiente
├── DteServiceLocal.csproj
├── Program.cs
├── appsettings.json
│
├── Api/
│   └── DteEndpoints.cs            ← POST /dte/enviar (sincrónico) + GET /health
│
├── Bitworks/
│   ├── ClienteBitworks.cs         ← HTTP client (portado de BitWork_Connect.cs)
│   ├── ServicioTokenBitworks.cs   ← OAuth2 (portado de Token_BitWork.cs)
│   └── Modelos/
│       ├── SolicitudDte.cs        ← Igual a POS_Request
│       └── RespuestaDte.cs        ← Igual a POS_Response (CodigoRespuesta, sello, etc.)
│
├── ClasificacionErrores/
│   ├── ClasificadorErrores.cs     ← Clasifica: Transitorio / DatosInvalidos / ErrorNegocio
│   └── CategoriaError.cs          ← Enum
│
├── Cola/
│   ├── ColaReintentos.cs          ← SQLite CRUD (solo errores Transitorios)
│   └── ElementoCola.cs
│
├── MotorReintentos/
│   ├── TrabajadorReintentos.cs    ← IHostedService: procesa cola + re-escaneo escalaciones
│   ├── CalculadorBackoff.cs
│   └── GeneradorJitter.cs         ← Equal Jitter
│
├── LimitadorTasa/
│   ├── CuboTokens.cs              ← 10 req/s, burst 20
│   └── CortaCircuito.cs           ← Pausa si Bitworks está caído; detecta recuperación
│
├── BdLocal/
│   ├── ActualizadorPos.cs         ← Actualiza TransEncabezado cuando reintento tiene éxito
│   └── EscalacionLocal.cs         ← INSERT en DTE_Escalaciones (SQL Server local del POS)
│
└── Logs/
    └── LogRotativo.cs             ← Logs locales, rotación 7 días
```

### 1.3 Endpoint Principal: `POST /dte/enviar`

**Lógica:**

```
1. Recibir solicitud del POS
2. ClienteBitworks.Enviar(solicitud)
3. Si CodigoRespuesta = "00"
   └─► Retornar respuesta con sello al POS ✅
4. Si CodigoRespuesta = "00" pero sello vacío:
   └─► Clasificar como Transitorio (caso especial detectado en ws-reenviodte Fase 2)
5. Si error:
   a. ClasificadorErrores.Clasificar(codigoHttp, cuerpoRespuesta)
   b. Si Transitorio:
      - ColaReintentos.Encolar(solicitud, ContadorReintentos=0, ProximoReintento = AHORA + Backoff(1))
      - Retornar error al POS (misma respuesta de error)
   c. Si DatosInvalidos o ErrorNegocio:
      - EscalacionLocal.Insertar(solicitud, detalleError)  ← INSERT en DTE_Escalaciones (SQL Server local)
      - Retornar error al POS (misma respuesta de error)
```

> El POS siempre recibe una respuesta completa (sello o error), igual que hoy. La clasificación y el enrutamiento ocurren internamente. Las escalaciones se escriben localmente y `sincronizacion-sala` las sincroniza al servidor de sala.

### 1.4 Esquema SQLite (cola de reintentos + log local)

```sql
CREATE TABLE DTE_ColaReintentos (
    Id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    GuidTransaccion     TEXT    NOT NULL UNIQUE,
    Contenido           TEXT    NOT NULL,       -- JSON de la solicitud DTE
    TipoTransaccion     INTEGER NOT NULL,       -- idTipoTrans (1,2,3,5,7,13,14)
    IdCaja              INTEGER NOT NULL,
    IdSucursal          INTEGER NOT NULL,
    ContadorReintentos  INTEGER DEFAULT 0,
    ProximoReintento    TEXT    NOT NULL,
    Estado              INTEGER DEFAULT 0,      -- 0=Pendiente, 1=Procesando, 2=Completado, 3=MaxReintentosAlcanzados
    UltimoError         TEXT,
    FechaCreacion       TEXT    DEFAULT CURRENT_TIMESTAMP,
    FechaActualizacion  TEXT    DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_cola_proximo ON DTE_ColaReintentos(Estado, ProximoReintento);

CREATE TABLE DTE_RegistroEventos (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    GuidTransaccion TEXT    NOT NULL,
    TipoEvento      INTEGER NOT NULL,   -- 0=Envio, 1=IntentoReintento, 2=Exito, 3=ErrorTransitorio, 4=Escalado
    Mensaje         TEXT,
    FechaCreacion   TEXT    DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_log_fecha ON DTE_RegistroEventos(FechaCreacion);
```

### 1.4b Esquema SQL Server (escalaciones en BD local del POS)

Esta tabla se crea en la BD local de cada POS (`SatellitePOS_MH`). `sincronizacion-sala` la recoge periódicamente.

```sql
CREATE TABLE DTE_Escalaciones (
    Id                  INT IDENTITY(1,1) PRIMARY KEY,
    GuidTransaccion     VARCHAR(100)  NOT NULL,
    IdSucursal          INT           NOT NULL,
    IdCaja              INT           NOT NULL,
    IdCajero            INT           NOT NULL,
    TipoTransaccion     INT           NOT NULL,
    CategoriaError      VARCHAR(50)   NOT NULL,  -- 'Transitorio', 'DatosInvalidos', 'ErrorNegocio'
    DetalleError        VARCHAR(2000) NOT NULL,   -- Descripción corta del error (NO varchar(max))
    ContenidoSolicitud  VARCHAR(8000) NULL,       -- JSON de la solicitud (tamaño acotado)
    ContadorReintentos  INT           DEFAULT 0,
    BusinessDay         DATETIME      NOT NULL,
    EstadoEscalacion    VARCHAR(50)   DEFAULT 'Pendiente',  -- 'Pendiente', 'Sincronizada', 'ReEncolada', 'Resuelta'
    FechaCreacion       DATETIME      DEFAULT GETDATE(),
    FechaSincronizacion DATETIME      NULL,
    CONSTRAINT UQ_DTE_Escalaciones_Guid UNIQUE (GuidTransaccion)
);

CREATE INDEX idx_escalaciones_pendientes ON DTE_Escalaciones(EstadoEscalacion, FechaCreacion);
```

> **Nota sobre diseño:** Se usa `VARCHAR(2000)` y `VARCHAR(8000)` en lugar de `VARCHAR(MAX)` para evitar el problema de locks a nivel de tabla que sufre `BillingMH_TransactionLog`. Los campos de tamaño acotado permiten que SQL Server optimice los locks a nivel de fila.

### 1.5 TrabajadorReintentos (errores transitorios + re-escaneo de escalaciones)

**Ciclo principal** cada `IntervaloTrabajadorMs` (default: 5s). Procesa items con `Estado=0` y `ProximoReintento <= AHORA`.

```
CICLO PRINCIPAL (cada 5s):
  1. SELECT items pendientes de DTE_ColaReintentos (SQLite)

  2. Para cada item:
     a. Marcar Estado=1 (Procesando)
     b. Si CortaCircuito.EstaAbierto() → skip (Estado=0, sin modificar ProximoReintento)
     c. Si !CuboTokens.IntentarConsumir() → skip
     d. ClienteBitworks.Enviar(item.Contenido)

     e. Si CodigoRespuesta="00" y sello NO vacío:
        - Marcar Estado=2 (Completado)
        - ActualizadorPos.ActualizarSello(...)
        - Log: TipoEvento=2 (Exito)

     f. Si CodigoRespuesta="00" pero sello vacío:
        - Tratar como Transitorio (caso especial)

     g. Si error:
        - ClasificadorErrores.Clasificar(respuesta)

        - Si Transitorio:
            · ContadorReintentos += 1
            · Si ContadorReintentos >= MaxReintentos (5):
                  Marcar Estado=3 (MaxReintentosAlcanzados)
                  EscalacionLocal.Insertar(item, "Transitorio", detalleError)
            · Si ContadorReintentos < MaxReintentos:
                  ProximoReintento = AHORA + CalculadorBackoff(ContadorReintentos) + Jitter
                  Marcar Estado=0 con nuevo ProximoReintento

        - Si DatosInvalidos o ErrorNegocio (puede ocurrir en reintento también):
            · Marcar Estado=3 (no reintentar más)
            · EscalacionLocal.Insertar(item, categoriaError, detalleError)
            · Log: TipoEvento=4 (Escalado)
```

**Ciclo de re-escaneo** cada `IntervaloReEscaneoMin` (default: 15 min):

```
RE-ESCANEO (cada 15 min, solo si CortaCircuito.EstaCerrado()):
  1. SELECT de DTE_Escalaciones (SQL Server local del POS)
     WHERE CategoriaError = 'Transitorio'
       AND EstadoEscalacion IN ('Pendiente', 'Sincronizada')

  2. Para cada escalación transitoria:
     a. Re-encolar en DTE_ColaReintentos (SQLite) con ContadorReintentos = 0
     b. Actualizar EstadoEscalacion = 'ReEncolada' en DTE_Escalaciones
     c. Log: TipoEvento=1 (ReEncolado)
```

> **Nota:** Un error puede cambiar de categoría entre intentos. Por ejemplo, un error "03" transitorio puede revelar en el segundo intento un error "400 receptor.nit" subyacente. Por eso el clasificador corre en cada intento del TrabajadorReintentos también.

> **Nota sobre recuperación de Bitworks:** Cuando el CortaCircuito detecta que Bitworks volvió (primer envío exitoso), el re-escaneo automáticamente recupera las escalaciones transitorias y las re-encola. Esto garantiza que ninguna transacción se pierda por una caída temporal de Bitworks, sin depender de `ws-reenviodte` ni de la ventana nocturna 1-6 AM.

### 1.6 Algoritmo Backoff (solo para errores Transient)

| RetryCount | Base delay | Equal Jitter | Ventana resultante |
|---|---|---|---|
| 1 | 2 min | [1, 2] min | Falla transitoria breve |
| 2 | 10 min | [5, 10] min | |
| 3 | 30 min | [15, 30] min | |
| 4 | 2 h | [1h, 2h] | |
| 5 → escalación | — | — | CentralReporter |

### 1.7 EscalacionLocal (reemplaza CentralReporter)

**Cambio de diseño:** Ya no se llama a un API central directamente. En su lugar, se escribe en la tabla `DTE_Escalaciones` de la BD local del POS (SQL Server). Esto garantiza que el POS funcione independientemente del servidor central.

**Responsabilidades:**

1. **Errores no-reintentables (inmediato):** `DatosInvalidos` / `ErrorNegocio` desde el primer intento o desde un reintento
2. **Máximo de reintentos alcanzado:** errores transitorios que no se resolvieron tras 5 intentos

**Cómo reporta:** INSERT local en SQL Server (BD del POS):

```sql
INSERT INTO DTE_Escalaciones (
    GuidTransaccion, IdSucursal, IdCaja, IdCajero, TipoTransaccion,
    CategoriaError, DetalleError, ContenidoSolicitud,
    ContadorReintentos, BusinessDay, EstadoEscalacion
) VALUES (
    @GuidTransaccion, @IdSucursal, @IdCaja, @IdCajero, @TipoTransaccion,
    @CategoriaError, @DetalleError, @ContenidoSolicitud,
    @ContadorReintentos, @BusinessDay, 'Pendiente'
)
```

**Flujo de sincronización al central:**
```
DTE_Escalaciones (BD local POS, EstadoEscalacion='Pendiente')
  ↓
sincronizacion-sala (TimerServerLocal, intervalo configurable)
  ↓
SP_Extrae_DTE_Escalaciones → lee escalaciones pendientes de cada terminal
  ↓
SP_Guarda_DTE_Escalaciones → INSERT en tabla del servidor de sala
  ↓
SP_Actualiza_DTE_Escalaciones_Estado → UPDATE EstadoEscalacion='Sincronizada' en el POS
```

> **Ventaja:** Si el servidor de sala no está disponible, las escalaciones quedan en la BD local sin perderse. Se sincronizan cuando la conectividad se restaure.

### 1.8 Configuración (`appsettings.json`)

```json
{
  "ServicioDte": {
    "Puerto": 7890,
    "RutaBdSqlite": "C:\\epdsoft\\dte-cola-reintentos.db"
  },
  "Cola": {
    "MaxReintentos": 5,
    "DiasLimpieza": 7,
    "IntervaloTrabajadorMs": 5000,
    "IntervaloReEscaneoMin": 15,
    "TamanioLote": 10
  },
  "LimitadorTasa": {
    "PeticionesPorSegundo": 10,
    "RafagaMaxima": 20
  },
  "Bitworks": {
    "UrlProduccion": "https://invoices-dtes.azurewebsites.net/api/accounts/selectos_prod",
    "UrlPruebas": "https://invoices-dtes.azurewebsites.net/api/accounts/selectos_pos_2",
    "UrlOAuth": "https://oauth-seguridad-fe.azurewebsites.net/connect/token",
    "ClientIdProduccion": "Selectos_Dte",
    "ClientSecretProduccion": "Hc&z69d5bb5",
    "ClientIdPruebas": "Selectos_Dte_Pos_2",
    "ClientSecretPruebas": "$3l3ct0s$2024",
    "TimeoutSegundos": 30
  },
  "BdLocalPos": {
    "CadenaConexion": "Data Source=POSLOCAL;Initial Catalog=SatellitePOS_MH;user id=sa;password=Navision12;"
  },
  "Logs": {
    "Ruta": "C:\\epdsoft\\Log\\DTE",
    "DiasRetencion": 7,
    "TamanioMaximoArchivoMB": 10
  }
}
```

> **Nota:** Ya no hay sección `Central` con ApiUrl/Token. Las escalaciones se escriben localmente en `DTE_Escalaciones` (SQL Server del POS) y `sincronizacion-sala` las sincroniza.

### 1.9 Instalación como Windows Service

```cmd
sc create "Po1nt_DteServiceLocal" binPath="C:\epdsoft\DteServiceLocal\DteServiceLocal.exe" start=auto
sc description "Po1nt_DteServiceLocal" "Servicio local de envío DTE - Selectos"
sc start "Po1nt_DteServiceLocal"
```

---

## Fase 2 — Cambios en `sincronizacion-sala` y Stored Procedures

### 2.1 Nuevos Stored Procedures para sincronización de escalaciones

Se registran 3 SPs nuevos en la tabla de configuración de sincronizaciones genéricas (`SP_Obtener_Sincronizaciones_Genericas_Locales`) para que `sincronizacion-sala` los ejecute automáticamente con su `TimerServerLocal`.

**SP 1 — Extracción (ejecutado contra BD de cada terminal):**
```sql
CREATE PROCEDURE SP_Extrae_DTE_Escalaciones
AS
BEGIN
    SELECT Id, GuidTransaccion, IdSucursal, IdCaja, IdCajero, TipoTransaccion,
           CategoriaError, DetalleError, ContenidoSolicitud,
           ContadorReintentos, BusinessDay, FechaCreacion
    FROM DTE_Escalaciones
    WHERE EstadoEscalacion = 'Pendiente'
    ORDER BY FechaCreacion ASC
END
```

**SP 2 — Guardado (ejecutado contra BD del servidor de sala):**
```sql
CREATE PROCEDURE SP_Guarda_DTE_Escalaciones
    @XML VARCHAR(MAX)
AS
BEGIN
    -- Inserta las escalaciones recibidas en la tabla del servidor de sala
    INSERT INTO DTE_Escalaciones_Central (
        GuidTransaccion, IdSucursal, IdCaja, IdCajero, TipoTransaccion,
        CategoriaError, DetalleError, ContenidoSolicitud,
        ContadorReintentos, BusinessDay, FechaCreacionOriginal, FechaSincronizacion
    )
    SELECT
        T.c.value('GuidTransaccion[1]', 'VARCHAR(100)'),
        T.c.value('IdSucursal[1]', 'INT'),
        T.c.value('IdCaja[1]', 'INT'),
        T.c.value('IdCajero[1]', 'INT'),
        T.c.value('TipoTransaccion[1]', 'INT'),
        T.c.value('CategoriaError[1]', 'VARCHAR(50)'),
        T.c.value('DetalleError[1]', 'VARCHAR(2000)'),
        T.c.value('ContenidoSolicitud[1]', 'VARCHAR(8000)'),
        T.c.value('ContadorReintentos[1]', 'INT'),
        T.c.value('BusinessDay[1]', 'DATETIME'),
        T.c.value('FechaCreacion[1]', 'DATETIME'),
        GETDATE()
    FROM @XML.nodes('/datos/row') AS T(c)
END
```

**SP 3 — Actualización de estado (ejecutado contra BD de cada terminal):**
```sql
CREATE PROCEDURE SP_Actualiza_DTE_Escalaciones_Estado
    @Ids VARCHAR(MAX)  -- IDs separados por comas
AS
BEGIN
    UPDATE DTE_Escalaciones
    SET EstadoEscalacion = 'Sincronizada',
        FechaSincronizacion = GETDATE()
    WHERE Id IN (SELECT value FROM STRING_SPLIT(@Ids, ','))
END
```

### 2.2 Registro en tabla de sincronizaciones genéricas

```sql
INSERT INTO SincronizacionesGenericasLocales (
    SP_Extrae_Informacion, SP_Guarda_Informacion, SP_Actualiza_Status, Campo_Id_Tabla
) VALUES (
    'SP_Extrae_DTE_Escalaciones',
    'SP_Guarda_DTE_Escalaciones',
    'SP_Actualiza_DTE_Escalaciones_Estado',
    'Id'
)
```

> Este registro hace que `sincronizacion-sala` automáticamente recoja las escalaciones de cada terminal y las deposite en el servidor de sala, usando el mecanismo genérico existente (`ProcesarGenericoLocales`). No se modifica código de `sincronizacion-sala`, solo se agregan SPs y un registro de configuración.

### 2.3 Qué consume las escalaciones

Las escalaciones depositadas en `DTE_Escalaciones_Central` (servidor de sala) son consumidas por:

| Consumidor | Tipo de error | Acción |
|---|---|---|
| `ws-reenviodte` (red de seguridad) | Errores transitorios que agotaron reintentos | Busca `MH_Sello IS NULL` en `TransEncabezado` — las encuentra y reintenta |
| `TrabajadorReintentos` (re-escaneo) | Errores transitorios locales | Cuando Bitworks regresa, re-encola automáticamente |
| Pantalla de analistas (`nuxt-front-admin`) | `DatosInvalidos` / `ErrorNegocio` | Analista filtra por fecha/categoría/estado, corrige datos del receptor, y reenvía via `po1nt-dte.ClienteBitworks`. Ver decisión D8 |

> `ms-procesos-locales` recibe un nuevo controller `DteEscalacionController` que consume la librería `po1nt-dte` para listar y reenviar escalaciones desde la pantalla web.

---

## Fase 3 — Cambios en `po1nt-pos` / `FactElectronica.vb`

### 3.1 Cambio de URL

El parámetro `10037` (webApi URL) ya es configurable desde BD. Solo se actualiza el valor al momento del despliegue:

- **Antes:** `http://procesos-locales.satellitepos.com/api/FacturacionElectronica/sendFact`
- **Después:** `http://localhost:7890/dte/send`

**Sin cambio de código** para las salas donde `DteServiceLocal` ya esté instalado.

### 3.2 Fallback a API central (rollout gradual)

Agregar en `FactElectronica.vb` un bloque de fallback transparente. Si el servicio local no responde en 3 segundos (health check), usa la API central sin que el cajero lo note.

> **¿Por qué 3 segundos?** El timeout actual del POS hacia la API central es de **20 segundos** (configurable en `C:\epdsoft\Config\ParametrosGenerales.xml` → `TimeoutFactElecSegundos`). El health check solo verifica que `DteServiceLocal` esté corriendo — no espera a Bitworks. 3 segundos es suficiente para un GET local.

```vb
' Antes de EditTrans:
Dim url_DteLocal As String = "http://localhost:7890/health"
Dim url_Envio_Local As String = "http://localhost:7890/dte/enviar"
Dim url_Central As String = url_WebApi

Try
    Dim testReq As HttpWebRequest = DirectCast(WebRequest.Create(url_DteLocal), HttpWebRequest)
    testReq.Timeout = 3000  ' 3 segundos — solo health check, no espera Bitworks
    testReq.Method = "GET"
    testReq.GetResponse().Close()
    url_WebApi = url_Envio_Local
Catch
    url_WebApi = url_Central  ' fallback silencioso a API central
End Try

EditTrans:
' ... resto sin cambios ...
```

### 3.3 Qué NO cambia en `FactElectronica.vb`

- Manejo de `ResponseCode = "00"` (éxito, actualiza TransEncabezado con sello)
- Manejo de errores de validación (diálogo de corrección al cajero, `GoTo EditTrans`)
  > El diálogo sigue siendo útil: si el cajero corrige datos y reenvía, el segundo intento va directo a Bitworks (no necesita reintentos). La corrección automática vía `CentralReporter` cubre el caso donde el cajero cierra el error sin corregir.
- Timeout configurable (`TimeoutFactElecSegundos`)
- Log local en `C:\temp\dte\`
- Llamada a `Po1nt_FacturacionElectronica_update`

---

## Secuencia de Implementación

```
Semana 1-2 │ Fase 0: Librería compartida po1nt-dte (nuevo repositorio)
           │   ├── Portar modelos de documentos DTE (25 archivos de Classes/BitWork/)
           │   ├── Portar ClienteBitworks (de BitWork_Connect.cs)
           │   ├── Portar ServicioToken (de Token_BitWork.cs)
           │   ├── Portar SolicitudDte / RespuestaDte (de POS_Request/POS_Response)
           │   ├── Crear ClasificadorErrores + CategoriaError (NUEVO)
           │   ├── Interfaces: IClienteBitworks, IServicioToken
           │   └── Pruebas unitarias (especialmente ClasificadorErrores)
           │
Semana 2-3 │ Fase 1: Desarrollo dte-service-local (nuevo repositorio)
           │   ├── Referencia a po1nt-dte (no duplica lógica)
           │   ├── Endpoint sincrónico POST /dte/enviar + GET /health
           │   ├── ColaReintentos SQLite + TrabajadorReintentos
           │   ├── CalculadorBackoff + GeneradorJitter
           │   ├── CuboTokens + CortaCircuito
           │   ├── ActualizadorPos + EscalacionLocal
           │   └── Re-escaneo de escalaciones transitorias
           │
Semana 3-4 │ Fase 2: SPs + DDL + configuración de sincronización
           │   ├── ALTER TABLE TransEncabezado ADD EstadoEnvioDte VARCHAR(50) NULL
           │   ├── Crear tabla DTE_Escalaciones en BD de cada POS
           │   ├── Crear tabla DTE_Escalaciones_Central en BD del servidor de sala
           │   ├── SP_Extrae/Guarda/Actualiza_DTE_Escalaciones
           │   ├── Registrar en SP_Obtener_Sincronizaciones_Genericas_Locales
           │   └── Modificar queries en ws-reenviodte (filtro EstadoEnvioDte)
           │
Semana 4   │ Fase 3: Cambio en FactElectronica.vb (health check + fallback)
           │   └── Pruebas end-to-end en staging
           │
Semana 4-5 │ Fase 4: Pantalla de analistas
           │   ├── ms-procesos-locales: DteEscalacionController (referencia po1nt-dte)
           │   │   ├── GET /api/DteEscalacion/listar (filtros: fecha, categoría, estado)
           │   │   └── POST /api/DteEscalacion/reenviar (corregir datos + reenvío directo)
           │   └── nuxt-front-admin: pages/dte/escalaciones/
           │       ├── index.vue — listado con filtros y tabla
           │       └── [id].vue — detalle, edición de receptor, reenvío
           │
Semana 6   │ Piloto en sala Gigante
           │   └── Monitoreo 1 semana:
           │       · Tasa éxito en primer intento
           │       · Volumen de reintentos por categoría (Transitorio vs Escalados)
           │       · Tiempo de resolución de reintentos transitorios
           │       · Volumen y latencia de sincronización de escalaciones
           │       · Comportamiento del re-escaneo tras recuperación de Bitworks
           │       · Uso de la pantalla de analistas
           │
Semana 7-10│ Rollout gradual: 25 salas/semana
           │
+1 mes     │ Monitoreo post-deploy
           │
Eventual   │ Descomisionar ws-reenviodte
           │ ms-procesos-locales migra de Classes/BitWork/ a po1nt-dte
```

---

## Archivos a Crear/Modificar

### Nuevos (repositorio `po1nt-dte/` — librería compartida)
- `Po1ntDte.csproj` — Class Library .NET 8
- `Bitworks/ClienteBitworks.cs` — portado de `BitWork_Connect.cs`
- `Bitworks/ServicioToken.cs` — portado de `Token_BitWork.cs`
- `Bitworks/ConfiguracionBitworks.cs`
- `Modelos/Documentos/` — portado de los 25 archivos de `Classes/BitWork/` (Factura.cs, CreditoFiscal.cs, etc.)
- `Modelos/SolicitudDte.cs` — portado de `POS_Request.cs`
- `Modelos/RespuestaDte.cs` — portado de `POS_Response.cs`
- `Clasificacion/ClasificadorErrores.cs`, `Clasificacion/CategoriaError.cs`
- `Contratos/IClienteBitworks.cs`, `Contratos/IServicioToken.cs`
- `tests/Po1ntDte.Tests/ClasificadorErroresTests.cs`

### Nuevos (repositorio `dte-service-local/`)
- `DteServiceLocal.csproj` — referencia a `po1nt-dte`
- `Program.cs`
- `appsettings.json`
- `Api/DteEndpoints.cs` — POST /dte/enviar + GET /health
- `Cola/ColaReintentos.cs`, `Cola/ElementoCola.cs`
- `MotorReintentos/TrabajadorReintentos.cs`, `MotorReintentos/CalculadorBackoff.cs`, `MotorReintentos/GeneradorJitter.cs`
- `LimitadorTasa/CuboTokens.cs`, `LimitadorTasa/CortaCircuito.cs`
- `BdLocal/ActualizadorPos.cs`, `BdLocal/EscalacionLocal.cs`
- `Logs/LogRotativo.cs`

### Nuevos (Stored Procedures en BD)
- `SP_Extrae_DTE_Escalaciones` — en BD de cada POS
- `SP_Guarda_DTE_Escalaciones` — en BD del servidor de sala
- `SP_Actualiza_DTE_Escalaciones_Estado` — en BD de cada POS
- Script DDL para crear tabla `DTE_Escalaciones` en cada POS
- Script DDL para crear tabla `DTE_Escalaciones_Central` en servidor de sala
- INSERT de configuración en tabla de sincronizaciones genéricas

### Nuevos (en `ms-procesos-locales/`)
- `Controllers/DteEscalacionController.cs` — listar y reenviar escalaciones, referencia `po1nt-dte`
- `Classes/DteEscalacion/FiltroEscalaciones.cs`, `ReenvioEscalacionRequest.cs`

### Nuevos (en `nuxt-front-admin/`)
- `pages/dte/escalaciones/index.vue` — listado con filtros (fecha, categoría, estado)
- `pages/dte/escalaciones/[id].vue` — detalle, edición de receptor, reenvío
- `services/dteEscalacion.ts` — llamadas al backend

### Modificados
- `po1nt-pos/SatelitePOS/90 - Otros/FactElectronica.vb` — health check al servicio local + fallback
- `ws-reenviodte/.../epdPo1nt_SyncronizadorEnvioDTE.vb` — agregar filtro `EstadoEnvioDte` a las dos queries de selección (Fase 1 línea ~212 y Fase 2 línea ~1101)
- `ms-procesos-locales/ms-procesos-locales.csproj` — agregar referencia a `po1nt-dte`

### DDL en BD de cada POS
- `ALTER TABLE TransEncabezado ADD EstadoEnvioDte VARCHAR(50) NULL`

---

## Riesgos y Mitigaciones

| Riesgo | Mitigación |
|---|---|
| Clasificador asigna categoría equivocada | El clasificador tiene reglas explícitas basadas en señales conocidas del body; el fallback es `Transitorio` (reintentar) para no perder transacciones; y si agota reintentos, escala igualmente |
| DteServiceLocal caído | Health check GET /health con timeout 3s; fallback automático a API central |
| Error de datos que también ocurre en cajero | El cajero puede corregir vía el diálogo existente; si no lo hace, `EscalacionLocal` lo registra y `sincronizacion-sala` lo lleva al central |
| Duplicados: DteServiceLocal + ws-reenviodte intentan la misma transacción | Campo `EstadoEnvioDte` en `TransEncabezado` actúa como semáforo: `ws-reenviodte` salta transacciones con `EN_ESPERA_REINTENTO_LOCAL` o `REINTENTO_RECUPERACION`. Solo toma `NULL` (salas legacy) o `ESCALADO_LOCAL` (última red de seguridad). Ver decisión D7 |
| SQLite corruption | WAL mode (`PRAGMA journal_mode=WAL`) |
| Thundering herd entre salas | GeneradorJitter por instancia distribuye reintentos |
| Servidor de sala no disponible al sincronizar escalaciones | Las escalaciones quedan en `DTE_Escalaciones` (BD local del POS) con `EstadoEscalacion='Pendiente'` hasta que `sincronizacion-sala` las recoja — no se pierden |
| Caída prolongada de Bitworks | El TrabajadorReintentos agota 5 intentos (~4.5h) y escala localmente (`EstadoEnvioDte = 'ESCALADO_LOCAL'`). Cuando Bitworks regresa, el re-escaneo periódico (cada 15 min) detecta CortaCircuito cerrado, cambia a `REINTENTO_RECUPERACION` y re-encola. `ws-reenviodte` puede tomar los `ESCALADO_LOCAL` como última red de seguridad |
| Deadlocks en tabla de escalaciones | `DTE_Escalaciones` usa `VARCHAR(2000)` y `VARCHAR(8000)` en lugar de `VARCHAR(MAX)`, evitando el problema de locks a nivel de tabla que sufre `BillingMH_TransactionLog` |
| Colisión portal manual + DteServiceLocal | Analista reenvía desde `nuxt-front-admin` o `portaladministrativo-desktop` mientras TrabajadorReintentos reintenta. Bajo riesgo: Bitworks maneja idempotencia por `codigoGeneracion`; la pantalla web muestra `EstadoEnvioDte` para que el analista vea si la transacción está siendo gestionada localmente antes de actuar |

---

## Análisis de Repositorios: Rol en el Flujo DTE

Análisis exhaustivo de todos los repositorios del ecosistema Po1nt y su relación con el envío, reenvío y reprocesamiento de facturación electrónica (DTE).

### Clasificación Rápida

| Repositorio | Relación con DTE | Impacto en re-arquitectura |
|---|---|---|
| `ms-procesos-locales` | **CRÍTICO** — Intermediario principal POS↔Bitworks | Alto: `DteServiceLocal` absorbe parte de su responsabilidad |
| `ws-reenviodte` | **CRÍTICO** — Reenvío automático nocturno de DTEs fallidos | Alto: `DteServiceLocal` lo reemplaza gradualmente |
| `portaladministrativo-desktop` | **IMPORTANTE** — Pantalla manual de reenvío y corrección DTE | Medio: Seguirá funcionando, pero debe coexistir con escalaciones |
| `MS-Sync` | Sin relación directa | Ninguno |
| `MS-Logger` | Sin relación directa | Ninguno |
| `WS-SincronizadorSalas` | Sin relación directa | Ninguno |
| `sincronizacion-sala` | Sin relación directa | Ninguno |

---

### R1. `ms-procesos-locales` — API Central (AppServer)

**Tecnología:** ASP.NET Core Web API | **Rol:** Intermediario principal entre POS y Bitworks

#### Endpoints DTE

| Endpoint | Controller | Función |
|---|---|---|
| `POST /api/FacturacionElectronica/sendFact` | `FacturacionElectronicaController.cs` (1513 líneas) | Envío inicial de DTE — maneja TODOS los tipos de documento |
| `POST /api/FacturacionElectronicaReenvioDTE/reenvioFact` | `FacturacionElectronicaReenvioDTEController.cs` | Reenvío de DTEs fallidos — extrae REQUEST previo de `BillingMH_TransactionLog` |
| `POST /api/FacturacionElectronicaReenvio/reenvioFact` | `FacturacionElectronicaReenvioController.cs` | Implementación paralela/duplicada del reenvío |

#### Tipos de Transacción Soportados (idTipoTrans)

| idTipoTrans | Tipo de Documento | Endpoint Bitworks |
|---|---|---|
| 1, 2 | FACTURA (Invoice) | `/facturas` |
| 3 | CREDITOFISCAL (Crédito Fiscal) | `/credito_fiscal` |
| 5 | FACTURA_DIPLOMATICO | `/facturas` |
| 7 | FACTURAEXPORTACION | `/factura_exportacion` |
| 13 | DEV-FACTURA (Anulación) | `/eventos_invalidacion` |
| 14 | CCF-NOTA (Nota de Crédito) | `/nota_credito` |

#### Operaciones de BD por Transacción

Cada llamada a `sendFact` genera **4 inserts** en `BillingMH_TransactionLog` via `SP_Po1nt_SaveBillingMH_TransactionLog`:

1. **ORIGIN** — POS_Request original
2. **REQUEST** — JSON DTE formateado enviado a Bitworks
3. **RES-BITW** — Respuesta cruda de Bitworks
4. **RESPONSE** — POS_Response serializado

El método `insertLog()` tiene protección contra deadlocks (3 reintentos, 50ms sleep, SqlException 1205) y **nunca rompe la venta** — si el log falla, la transacción continúa.

#### Comunicación con Bitworks (`BitWork_Connect.cs`)

- **Token OAuth2** via `Token_BitWork.cs`: Siempre solicita token fresco antes de cada transacción
- **URLs Base:**
  - DEV: `https://invoices-dtes.azurewebsites.net/api/accounts/selectos_pos_2`
  - PROD: `https://invoices-dtes.azurewebsites.net/api/accounts/selectos_prod`
- **Códigos de Respuesta:**
  - `"00"` = Aprobado (retorna sello, numeroControl, codigoGeneracion, fechaRecepcion, urlMH)
  - `"01"` = Error de validación de token
  - `"02"` = Error de re-validación de token (expirado)
  - `"03"` = Error interno de proceso
  - `"50"` = Error general de Bitworks
- **Detección de error de descuadre:** Si el body contiene `"La suma de "` → `reprocesarFactura = true` (flag seteado pero el `goto` está **comentado**, no se reprocesa automáticamente)

#### Stored Procedures DTE

| SP | Función |
|---|---|
| `SP_Po1nt_SaveBillingMH_TransactionLog` | Inserta log de transacción DTE |
| `SP_Po1nt_GetBillingMH_TransactionLog` | Obtiene request previo para reprocesamiento (por REC + isProduction + businessDay) |
| `SP_Po1nt_GetBillingMH_TransactionLogRequest` | Obtiene registro REQUEST para reenvío (por REC + isProduction) |

#### Impacto de la Re-arquitectura

- `DteServiceLocal` absorbe la comunicación directa con Bitworks (OAuth + envío)
- El endpoint `sendFact` deja de recibir tráfico de las salas donde `DteServiceLocal` esté instalado
- El endpoint de reenvío sigue siendo necesario para `ws-reenviodte` durante la transición
- **Los 4 inserts por transacción desaparecen** para salas migradas → reducción masiva de IOPS
- El nuevo endpoint `POST /api/DteEscalacion/reportar` recibe solo errores no-reintentables (~5% del volumen)

---

### R2. `ws-reenviodte` — Servicio de Reenvío por Sala

**Tecnología:** VB.NET Windows Service (.NET Framework 4.5) | **Rol:** Reenvío automático nocturno de DTEs fallidos

#### Comportamiento Principal

- **Timer:** Cada 30 minutos (configurable via registro)
- **Ventana de ejecución:** Nominalmente 1-6 AM, pero **bug en condición lógica hace que ejecute 24/7** (ver decisión D7)
- **Conexión:** Lee de BD local de cada POS terminal via SQL Server
- **API destino:** `http://po1nt-procesos-locales.selectos.com/api/FacturacionElectronica/sendFact`
- **Delay entre envíos:** 500ms fijo (sin backoff exponencial)

#### Dos Fases de Reenvío

**Fase 1 — Errores y sellos faltantes** (`llenarTablaAutomatico`):

Busca en `TransEncabezado` transacciones con:
```sql
WHERE idTipoTrans IN (1, 2, 3, 5, 7)
  AND (MH_ResponseCode LIKE '%Error%'
       OR MH_Sello IS NULL OR MH_Sello = '' OR MH_Sello LIKE '%Error%')
  AND Devolucion_cajero IS NULL
  AND BusinessDay BETWEEN @fechaInicio AND @fechaFin  -- últimos 2-3 días
```

**Fase 2 — ResponseCode '00' sin sello** (`llenarTablaAutomaticoCodigo00SinSello`):

Caso especial donde Hacienda responde OK pero no devuelve sello:
```sql
WHERE MH_ResponseCode='00' AND MH_Sello=''
```
Usa endpoint diferente: `/api/FacturacionElectronicaReenvio/reenvioFact`

#### Lógica de Cooldown (Anti-Hammering)

| Condición | Acción |
|---|---|
| `MH_FechaEnvio IS NULL` | Reenviar inmediatamente |
| `DATEDIFF(HOUR, MH_FechaEnvio, GETDATE()) > 3` | Reenviar (cooldown 3h cumplido) |
| `DATEDIFF(MINUTE, Fecha, GETDATE()) < 20` | Reenviar (transacción reciente <20 min) |
| Ninguna de las anteriores | Skip (esperar cooldown) |

#### Auto-Corrección de Datos

Cuando el reenvío falla con errores de validación, el servicio intenta **auto-corregir**:
- `receptor.nit` → Busca NIT del DUI en `satellitepos_customer`
- `receptor.nrc` → Busca NRC del cliente
- `Receptor.Direccion` → Consulta departamento/municipio via SP `Po1nt_GetDataMH`
- `receptor.ActividadEconomica` → Busca giro del cliente
- Si corrige datos, reintenta una vez más (flag `repe = 1`, label `EditTrans`)

#### Campos de TransEncabezado Leídos/Escritos

| Campo | Lectura | Escritura | Descripción |
|---|---|---|---|
| `MH_Sello` | ✅ | ✅ | Sello electrónico o mensaje de error |
| `MH_ResponseCode` | ✅ | ✅ | Código de respuesta ("00" = éxito) |
| `MH_CodigoGeneracion` | | ✅ | Código de generación de Hacienda |
| `MH_FechaRecepcion` | | ✅ | Fecha de recepción en Hacienda |
| `MH_NumeroControl` | | ✅ | Número de control |
| `MH_Estado` | | ✅ | Estado del documento |
| `MH_FechaEnvio` | ✅ | ✅ | Timestamp del último intento (controla cooldown 3h) |
| `Guid` | ✅ | | Identificador único de transacción |
| `idTipoTrans` | ✅ | | Tipo de transacción |

#### SPs Llamados

| SP | Función |
|---|---|
| `Po1nt_FacturacionElectronica_Insert` | Inserta log ANTES de enviar |
| `Po1nt_FacturacionElectronica_update` | Actualiza TransEncabezado con respuesta de Hacienda |
| `SatellitePOS_Get_DTE_Reenvio` | Obtiene datos DTE completos para reenvío |

#### Impacto de la Re-arquitectura

- **`DteServiceLocal` reemplaza este servicio gradualmente:**
  - Reintentos 24/7 (no solo 1-6 AM)
  - Backoff exponencial con jitter (no delay fijo de 500ms)
  - Rate limiting (no ráfagas)
  - Clasificación de errores (transitorios vs no-reintentables)
- **Riesgo de duplicados durante transición:** Ambos servicios pueden intentar la misma transacción
  - Mitigación: `ws-reenviodte` respeta cooldown de 3h via `MH_FechaEnvio`; `DteServiceLocal` actualiza `MH_FechaEnvio` al reintentar → evita colisión
- **Descomisionamiento eventual** una vez todas las salas migren

---

### R3. `portaladministrativo-desktop` — Portal Administrativo + WinSQL

**Tecnología:** C# WinForms (portal) + VB.NET WinForms (WinSQL) | **Rol:** Gestión manual de DTEs fallidos

#### Funcionalidad DTE

El portal incluye un botón **"Re-Envío DTE"** (visible solo para roles Admin y Supervisor) que lanza `WinSQL.exe`, una aplicación separada con tres pantallas DTE:

**1. `DTE_Re_Procesos.vb` — Pantalla principal de reenvío** (79KB, ~900 líneas)
- Busca DTEs sin sello en todas las cajas de la sala
- Filtro: `WHERE MH_Sello LIKE '%Error%' OR MH_Sello IS NULL`
- Muestra: NoCaja, Guid, Fecha, Cajero, Total, ErrorMSG, Sucursal, TipoTrans
- Permite reenvío manual unitario (seleccionar fila → reenviar)
- Tiene modo automático (`EnviarDTEAutomatico()`) que itera todas las sucursales
- Exporta resultados a CSV
- Cuenta DTEs exitosos vs fallidos

**2. `FacturacionElectronicaUpdate.vb` — Corrección de datos** (357 líneas)
- Edita datos del receptor: NIT, DUI, NRC, Razón Social, Email
- Selección de Departamento y Municipio
- Valida datos y reprocesa DTE con información corregida

**3. `MostrarDetalleErrorDTE.vb` — Detalle de errores** (129 líneas)
- Parsea respuesta JSON de Hacienda
- Muestra: ResponseCode, ResponseMessage, errores de Receptor, HMMMessages, Observaciones

#### Bases de Datos Consultadas

| Servidor | Base de Datos | Uso |
|---|---|---|
| POS local (por IP) | `SatellitePOS_MH`, `SatellitePOS_MH_*` | Lee TransEncabezado de cada caja |
| SERVERSALA | `SatellitePOS_SUCURSAL_01` | Registro de conexiones |
| 192.168.15.83 | `po1nt_pos` | Lee `BillingMH_TransactionLog` (REQUEST previo) |

#### SP Usados

- `SatellitePOS_Get_DTE_Reenvio` — Obtiene MH_Request JSON para reenvío
- `SP_SelectGiros` — Lista giros/actividades económicas
- `SP_SelectDepartamentos` — Lista departamentos
- `SP_SelectMunicipality` — Lista municipios

#### Impacto de la Re-arquitectura

- **Sigue funcionando sin cambios** — Lee directamente de TransEncabezado de cada POS
- **Complementa las escalaciones:** Cuando `DteServiceLocal` escala un error no-reintentable al central, un analista podría usar esta pantalla para corregir datos y reenviar manualmente
- **Coexistencia:** El portal y `DteServiceLocal` operan sobre los mismos campos (`MH_Sello`, `MH_FechaEnvio`, etc.) — no hay conflicto porque el portal es acción manual bajo demanda
- **Oportunidad futura:** Esta pantalla podría evolucionar para mostrar las escalaciones recibidas por `CentralReporter`, creando una cola de trabajo para analistas

---

### R4. `MS-Sync` — Servicio de Sincronización

**Tecnología:** .NET 7 ASP.NET Core Web API | **Rol:** Orquestación genérica de sincronización POS ↔ Central

**Relación con DTE: NINGUNA.** Este servicio es un framework genérico de sincronización que:
- Gestiona estado de sincronización en tabla `terminal_sync`
- Ejecuta stored procedures dinámicamente (nombres almacenados en `sync_types`)
- Endpoints: `GET/POST /api/sync/{type}`, `GET /api/event/sync`, `POST /api/sync/transactions`
- Sincroniza productos, precios, promociones, configuraciones — **nunca datos DTE**

**Impacto:** Ninguno. No requiere cambios.

---

### R5. `MS-Logger` — Servicio de Logging

**Tecnología:** .NET 7 ASP.NET Core Web API | **Rol:** Registro centralizado de transacciones y logs de auditoría

**Relación con DTE: NINGUNA.** Registra transacciones POS genéricas (headers, line items, pagos) pero:
- No genera ni valida DTEs
- No interactúa con Hacienda ni Bitworks
- No escribe en `BillingMH_TransactionLog` ni `TransEncabezado`
- Endpoints: `POST /api/log`, `POST /api/transaction`

**Impacto:** Ninguno. No requiere cambios.

---

### R6. `WS-SincronizadorSalas` — Sincronizador de Productos

**Tecnología:** VB.NET Windows Service (.NET Framework 4.5) | **Rol:** Sincroniza catálogo de productos Central → Salas

**Relación con DTE: NINGUNA.** Sincroniza exclusivamente:
- Productos, códigos de barra, precios
- Promociones y ofertas (headers + detalle + mix & match)
- Timer cada 5 min (bajar del central) y cada 7 min (enviar a terminales)
- API: `http://po1nt-sync.selectos.com/api/Event/sync`

**Impacto:** Ninguno. No requiere cambios.

---

### R7. `sincronizacion-sala` — Sincronización de Sala

**Tecnología:** VB.NET WinForms / Windows Service (.NET Framework 4.6.2) | **Rol:** Sincroniza datos operativos Terminal ↔ Servidor de sala

**Relación con DTE: NINGUNA.** Sincroniza:
- Transacciones de venta (datos genéricos, no fiscales)
- Cortes de caja y cierres
- Productos, terminales, códigos de barra, familias
- Timer cada 10 segundos (extracción) con SPs dinámicos

**Impacto:** Ninguno. No requiere cambios.

---

### Resumen de Interacciones durante la Transición

```
                         ANTES                              DESPUÉS (con DteServiceLocal)
                         ─────                              ──────────────────────────────

POS (FactElectronica.vb)                        POS (FactElectronica.vb)
        │                                               │
        ▼                                               ▼ (fallback a central si local no responde)
ms-procesos-locales                             DteServiceLocal (localhost:7890)
  ├── sendFact → Bitworks                         ├── BitworksClient → Bitworks directo
  ├── 4 inserts en BillingMH_TransactionLog       ├── ErrorClassifier
  └── retorna sello al POS                        ├── Si OK → retorna sello al POS
                                                  ├── Si Transient → SQLite queue + retorno error al POS
ws-reenviodte (1-6 AM)                           ├── Si DataValidation/Business → CentralReporter + retorno error
  ├── Lee TransEncabezado sin sello               └── RetryWorker (background, 24/7)
  ├── Envía via ms-procesos-locales                       │
  ├── Auto-corrige datos si puede                         ▼
  └── Actualiza MH_Sello, MH_FechaEnvio          ms-procesos-locales
                                                    └── POST /api/DteEscalacion/reportar (solo errores)
portaladministrativo-desktop (manual)
  ├── Busca DTEs sin sello                        ws-reenviodte (se mantiene durante transición)
  ├── Reenvía manualmente                           └── Cooldown 3h via MH_FechaEnvio evita colisión
  └── Corrige datos del receptor
                                                  portaladministrativo-desktop (sin cambios)
                                                    └── Sigue funcionando — lee TransEncabezado directamente
```

### Notas del Análisis de Repositorios

> Los riesgos identificados durante el análisis de repositorios ya están mitigados en el plan principal:
> - **Colisión ws-reenviodte:** Resuelta con campo `EstadoEnvioDte` (decisión D7)
> - **Colisión portal manual:** Cubierta en tabla de riesgos principal (idempotencia por `codigoGeneracion` + `EstadoEnvioDte`)
> - **Auto-corrección de datos en ws-reenviodte:** DteServiceLocal escala via `EscalacionLocal`; la corrección se hace en el portal o futuro sistema de analistas (decisión D5)
> - **ResponseCode 00 sin sello:** Detectado en endpoint `POST /dte/enviar`, clasificado como Transitorio (sección 1.3)
> - **goto reprocesarFactura comentado:** `ClasificadorErrores` clasifica "La suma de" como `ErrorNegocio` y escala (sección Clasificación de Errores)
> - **6 tipos de documento:** `ClienteBitworks` porta la lógica completa de selección de endpoint por `idTipoTrans` desde `BitWork_Connect.cs`

---

## Fuera de Alcance (Esta Feature)

- Reducción de logs en `ms-procesos-locales` (baja prioridad)
- Métricas Prometheus para `DteServiceLocal`
- Descomisionamiento de `ws-reenviodte`
- Migración de datos históricos
- Migración completa de `ms-procesos-locales/Classes/BitWork/` a `po1nt-dte` (gradual, posterior al rollout)
