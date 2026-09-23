# Sincronización de Transacciones, Cortes, Cajeros y Pagos de Terceros

Todo lo que **sube** de la caja hacia la sala y hacia central lo mueve un solo componente:
`epdPo1nt_Syncronizador`, un Windows Service instalado en el servidor de sala / NAV.

No usa HTTP: abre conexiones SQL y ejecuta stored procedures remotos.

## Identidad del servicio

| Aspecto | Valor |
|---------|-------|
| Ensamblado | `epdPo1nt_Syncronizador` |
| `ServiceName` instalado | `epdPo1nt_Syncronizador` — **aquí sí coincide** con el repo y el ensamblado |
| Framework | **.NET Framework 2.0** (`epdPo1nt_Syncronizador.vbproj:14`), runtime forzado a `v2.0.50727` |
| Configuración | `HKLM\Software\epdsoft\Po1nt_ServiceServer` |
| Log | `C:\epdsoft\Services_Server\Log\ServiceSyncSend_Log_yyyMMdd_HH.txt` |

Conexiones salientes: cada caja de la sala (`POSLOCAL` → IP), más dos SQL Server centrales:
`192.168.15.90` (`satellite-pos`, alias "Desarrollo") y `192.168.15.83` (`po1nt_pos`,
alias "Producción").

---

## Los 13 timers

Todos leen su intervalo del registro con `try/catch`; el valor del código es el fallback.

| Timer | Intervalo | Clave de registro | Dirección | Qué mueve |
|-------|-----------|-------------------|-----------|-----------|
| `TimerTransaccionesNew` | 1 min | `Intervalo_SubirTransaccionesSala_Minute`* | caja → central | `TransEncabezado` con `Transmitir=1` → `Sync_Aplicar_Transacciones_Manual_new` |
| `TimerTransacionesSalaNuevo` | 1 min | propia | caja → sala | `TransEncabezado` con `Tramitir_Sala=1` (sic) → `SatellitePOS_InsertTransaccionSale` |
| `TimerSubirPagosTerceros` | 2 min | propia | caja → sala/central | `SP_Sync_TransPagoColectores_Servicio` → `Sync_Aplicar_TransPagosColectores_Manual` |
| `TimerSubirClientesV2` | — | — | caja ↔ caja | Réplica V2, sólo entre cajas de esquema nuevo |
| `TimerCajeros` | 5 min | `Intervalo_Cajeros_Minute` | **bidireccional** | caja→sala: `SP_Sync_Cajeros_Server_Central_Servicio` → `Sync_GuardarCajeros_Servicio`; sala→caja: `SP_Sync_CreateUsuariosCajeros_Servicio` → `POS_Sync_CreateUsuariosCajeros_Servicio` |
| `TimerSubirClientes` | 5 min | `Intervalo_SubirClientes_Minute` | caja → sala/central | Ver [`clientes.md`](clientes.md) |
| `TimerSubirClientesSala` / `TimerClientesServerTerminales` | — | — | sala ↔ caja | Colas `Sync_CustomerSala_Aplicate` / `Sync_Customer_Aplicate`, con guard `EsCajaEsquemaNuevo` |
| `TimerCortesCaja` | 15 min | `Intervalo_CortesCaja_Minute` | caja → sala/central | `SP_Sync_SatellitePOS_HistoricoCortes_Servicio` → `Sync_Aplicar_HistoricoCortes_Manual` |
| `TimerAperturaEfectivo` | — | ⚠️ ver abajo | caja → sala | Aperturas de efectivo |
| `TimerTransMediosPago` | — | ⚠️ ver abajo | caja → sala | Medios de pago |
| `TimerSatellitePOS_Audit` | — | ⚠️ ver abajo | caja → sala | Auditoría |
| `TimerSubirTransacciones` | — | — | — | **CÓDIGO MUERTO** |

### ⚠️ Tres timers comparten una clave de registro

`TimerAperturaEfectivo`, `TimerTransMediosPago` y `TimerSatellitePOS_Audit` leen **los tres
la misma clave** `Intervalo_SubirTransaccionesSala_Minute`
(`epdPo1nt_Syncronizador.vb:88,93,98`), en vez de tener la suya.

**Consecuencia:** no se pueden afinar por separado. Bajar el intervalo de uno acelera los
tres a la vez, con el costo de carga que eso implica en cajas ya apretadas.

### Código muerto

`TimerSubirTransacciones` tiene un handler completo (`:156-185`) pero su `.Start()` está
comentado (`:123`) y no se habilita por ninguna otra vía. Sus tres funciones exclusivas
—`POS_Obtener_Transacciones`, `POS_Guardar_SALA_Transacciones`, `POS_Subir_SERVER_Transacciones`—
son inalcanzables. Es el antecesor de `TimerTransaccionesNew`.

La rama "Desarrollo" de `TimerTransaccionesNew` (`IS_ServerNew=0`) hace `Return ""` sin
conectar (`:313-315`): está deshabilitada de facto.

---

## La llave del cliente en la venta

Desde la fase 2 del módulo de clientes, `Sync_Aplicar_Transacciones_Manual_new` acepta tres
parámetros adicionales con `DEFAULT NULL` (patrón `EstadoEnvioDte`):
`CustomerDetailCode`, `IdTipoDocumento`, `NumeroDocumento`.

El lado VB los pasa con guard `row.Table.Columns.Contains`, de modo que **tolera cajas que
todavía no tienen esas columnas**. Ese patrón condicional es obligatorio para cualquier
columna nueva en este camino: la flota nunca está toda en la misma versión.

`transacciones.ID_Cliente` en central sigue siendo el `No_`, no el `CustomerDetailCode`.
El CDC viaja en columna propia; **no se sobreescribió `ID_Cliente`** para no romper los 21
SPs de reportería que lo usan.

---

## Modo de fallo característico

Si el servidor de sala está caído o el servicio detenido, **no se acumula nada visible en
central**: las cajas simplemente quedan con `Transmitir=1` sin consumir y el backlog crece
en silencio, caja por caja. No hay alerta.

Un síntoma clásico: ventas que "no existen" en central aunque el tiquete se imprimió. Ver
también el flujo de pago del POS, donde un fallo al guardar puede dejar tiquete impreso sin
venta registrada.

## Cortes

Para obtener el sobrante por medio de pago de los cortes Y ya emitidos, la fuente es
`SatellitePOS_HistoricoCortes` en la caja, que es la misma tabla que
`SP_Sync_SatellitePOS_HistoricoCortes_Servicio` sube cada 15 minutos.
