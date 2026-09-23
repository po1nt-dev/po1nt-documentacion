# Sincronizadores - Servicios de sala

> **Para entender el flujo de datos**, ver la sección
> [`sincronizaciones/`](../sincronizaciones/README.md), que documenta cada objeto
> sincronizado de punta a punta. Este archivo es sólo la ficha de identidad de cada
> componente.

## Vision General

Conjunto de componentes que sincronizan datos entre el servidor central, los servidores de
sala y las cajas. **No todos son Windows Services** y **no todos los nombres del repo
coinciden con el servicio instalado** — dos confusiones que cuestan tiempo en cada
incidente.

## Tabla de identidad

| Repo | Ensamblado | `ServiceName` instalado | Tipo |
|------|-----------|--------------------------|------|
| `epdPo1nt_Syncronizador` | `epdPo1nt_Syncronizador` | `epdPo1nt_Syncronizador` | Windows Service |
| `WS-SincronizadorSalas` | `epdPo1nt_SyncronizadorProductos` | **`epdPo1nt_SyncronizadorProductosUpd`** | Windows Service |
| `sincronizacion-sala` | `SatellitePOS_SincronizacionSala` | — | **App WinForms** |
| `WS-SincronizacionBascula` | `epdPo1nt_SyncronizadorBasculas` | `epdPo1nt_SyncronizadorBasculas` ⚠️ | Windows Service |
| `ws-reenviodte` | `epdPo1nt_SyncronizadorEnvioDTE` | **`epdPo1nt_EnvioAutomaticoDTE`** | Windows Service (**deprecado**) |
| `po1nt-dte-reproceso` | `Po1ntDteReproceso` | `Po1ntDteReproceso` | Windows Service (`sc create`) |

---

### epdPo1nt_Syncronizador
**Proposito**: subida de transacciones, cortes, cajeros, clientes y pagos de terceros;
además réplica V2 de clientes entre cajas.

| Caracteristica | Valor |
|----------------|-------|
| Framework | .NET Framework **2.0** |
| Lenguaje | VB.NET |
| Tipo | Windows Service |
| Corre en | Servidor de sala / NAV |
| Registro | `HKLM\Software\epdsoft\Po1nt_ServiceServer` |
| Log | `C:\epdsoft\Services_Server\Log\ServiceSyncSend_Log_yyyMMdd_HH.txt` |

13 timers. Los principales: `TimerTransaccionesNew` (1 min), `TimerSubirPagosTerceros`
(2 min), `TimerCajeros` y `TimerSubirClientes` (5 min), `TimerCortesCaja` (15 min).

⚠️ `TimerAperturaEfectivo`, `TimerTransMediosPago` y `TimerSatellitePOS_Audit` comparten la
clave `Intervalo_SubirTransaccionesSala_Minute`. `TimerSubirTransacciones` es código muerto.

Detalle: [`sincronizaciones/objetos/transacciones-cortes-cajeros.md`](../sincronizaciones/objetos/transacciones-cortes-cajeros.md)

---

### WS-SincronizadorSalas
**Proposito**: bajar productos, códigos de barra, precios y promociones, y repartirlos a
las cajas.

| Caracteristica | Valor |
|----------------|-------|
| Framework | .NET Framework 4.5 |
| Lenguaje | VB.NET |
| Tipo | Windows Service |
| Corre en | Servidor de sala / NAV |

**Timers** (⚠️ **intervalos hardcodeados en `OnStart`**, no configurables por registro
pese a lo que decía la documentación anterior):
- `TimerProductosBajarServer` — 5 min
- `TimerProductosEnviarTerminales` — 7 min
- `TimerOfertasYPromociones` — declarado pero **nunca habilitado**
- `TimerPreciosProductos` — declarado **sin handler**: muerto

**API**: `http://po1nt-sync.selectos.com/api/Event/sync`, paginado `?page=N&per_page=10000`.

Detalle: [`sincronizaciones/objetos/productos-precios-promociones.md`](../sincronizaciones/objetos/productos-precios-promociones.md)

---

### sincronizacion-sala
**Proposito**: sincronización de tipos "genéricos" (SP dinámico por nombre) y ETL local
entre cajas. **Excluye** explícitamente productos, barcodes, precios y promociones: de esos
se encarga `WS-SincronizadorSalas`.

| Caracteristica | Valor |
|----------------|-------|
| Framework | .NET Framework 4.7 |
| Lenguaje | VB.NET |
| Tipo | **Aplicación Windows Forms — no es un servicio** |
| Registro | `HKLM\Software\WinPOSLocal\Sincronizacion` (`TimerSpeed`, `TimerSpeedLocal`) |

⚠️ Al ser una app de escritorio, **alguien debe dejarla abierta** en el equipo de sala. Si
se cierra, la bajada de clientes de esa sala se detiene sin alerta.

**APIs**: `/api/Sync/device` y `/api/Event/sync`. Un `POST` a
`po1nt-procesos-locales.selectos.com/api/SubirCustomer/SubirEstandar` tiene el host
**hardcodeado** (`Sincronizacion.vb:841`), ignorando el registro.

---

### WS-SincronizacionBascula
**Proposito**: sincronizar productos y precios a las básculas de pesaje.

| Caracteristica | Valor |
|----------------|-------|
| Framework | .NET Framework 4.5 |
| Lenguaje | VB.NET |
| Tipo | Windows Service |
| Intervalo | Registro `HKLM\Software\WOW6432Node\epdsoft\Po1nt_ServiceServer\intervaloTiempoSPBasculaMinutos`, default 45 min |
| Log de negocio | `C:\temp\dte\LOGSPBASCULAS_yyyy-MM-dd.txt` |

**Stored Procedures**: `prc_Envios_SELECTOS_Po1nt_insertarProductos`,
`prc_Envios_SELECTOS_ActualizarPrecios`, `prc_Envios_SELECTOS_Po1nt_Basculas`.

⚠️ El `ServiceName` de runtime dice `epdPo1nt_SyncronizadorEnvioDTE` (herencia de plantilla)
mientras el instalador registra `epdPo1nt_SyncronizadorBasculas`.

Detalle: [`sincronizaciones/objetos/basculas.md`](../sincronizaciones/objetos/basculas.md)

---

### po1nt-dte-reproceso
**Proposito**: drenar la cola `DTE_ColaEnvio` de cada caja y reenviar los DTE pendientes.
**Reemplaza a `ws-reenviodte`.**

| Caracteristica | Valor |
|----------------|-------|
| Framework | .NET Framework 4.5 |
| Lenguaje | C# |
| Tipo | Windows Service (`sc create`) + modo consola `--console` |
| Corre en | Servidor NAV de cada sucursal |
| Intervalo | `Polling.IntervaloMinutos` en `appsettings.json` (5) |
| Endpoint | `POST /api/FacturacionElectronica/sendFactDesacople` |

Detalle: [`sincronizaciones/objetos/dte.md`](../sincronizaciones/objetos/dte.md)

---

### ws-reenviodte — DEPRECADO
**Estado**: detenido y deshabilitado en 49 NAVs desde el cutover del **2026-05-08**;
deprecación formal el **2026-05-27**. Su lógica vive ahora en `po1nt-dte-reproceso` y en el
comando `po1nt-cli dte reenviar-contingencia`.

No reactivarlo sin leer antes `po1nt-dte-reproceso/docs/plan-anti-duplicidad.md`: llama a
`/sendFact` en vez de `/sendFactDesacople` y **puede generar duplicados en el Ministerio de
Hacienda**.

---

## Diagrama de Interaccion

Ver [`diagramas/mermaid/06-sincronizadores-interaccion.mmd`](../diagramas/mermaid/06-sincronizadores-interaccion.mmd).

## Configuracion

No hay una única convención. Las rutas reales de registro son:

| Componente | Ruta |
|------------|------|
| `epdPo1nt_Syncronizador`, `WS-SincronizadorSalas` | `HKLM\Software\epdsoft\Po1nt_ServiceServer` |
| `WS-SincronizacionBascula`, parte de `ws-reenviodte` | `HKLM\Software\WOW6432Node\epdsoft\Po1nt_ServiceServer` |
| `sincronizacion-sala`, `portaladministrativo-desktop` | `HKLM\Software\WinPOSLocal` |
| `po1nt-dte-reproceso` | `appsettings.json` (no usa registro) |
