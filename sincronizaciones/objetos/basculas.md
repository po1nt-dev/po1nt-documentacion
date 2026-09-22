# Sincronización de Precios a Básculas

El componente es `WS-SincronizacionBascula`, ensamblado `epdPo1nt_SyncronizadorBasculas.exe`.
Lleva productos y precios desde la BD de sala hacia las básculas de pesaje de la sucursal.

## Ficha

| Aspecto | Valor real (código) |
|---------|---------------------|
| Framework | VB.NET, .NET Framework **4.5** (`epdPo1nt_SyncronizadorBasculas.vbproj:12-13`) |
| Tipo | Windows Service (`ProjectInstaller.vb` con `RunInstaller`) |
| Dónde corre | Servidor de sala / NAV |
| Intervalo | Registro `HKLM\Software\WOW6432Node\epdsoft\Po1nt_ServiceServer`, valor `intervaloTiempoSPBasculaMinutos`; **default 45 min** si la lectura falla (`.vb:24`) |
| Conexión | `ConexionDBSala` en el mismo registro (`.vb:76`) |
| Origen | BD de sala (`SatellitePOS_SUCURSAL_xx`) |
| HTTP | Ninguno: sólo SQL Server directo |

## Los tres SPs, en cascada

Se ejecutan en orden en cada ciclo (`.vb:51-68`):

| Orden | SP | Función |
|-------|----|---------|
| 1 | `prc_Envios_SELECTOS_Po1nt_insertarProductos` (`.vb:83`) | Inserta los productos nuevos |
| 2 | `prc_Envios_SELECTOS_ActualizarPrecios` (`.vb:114`) | Actualiza precios |
| 3 | `prc_Envios_SELECTOS_Po1nt_Basculas` (`.vb:147`) | Genera el JSON final (`ConvertDataTableToJson`) |

Las funciones VB que los envuelven se llaman `Sync_InsertarProductosPrecioTabla` y
`Sync_ActualizarPreciosTabla`; no confundir los nombres de las funciones con los de los SPs.

## Logs: dos rutas distintas

| Ruta | Qué escribe |
|------|-------------|
| `C:\epdsoft\Services_Server\Log\` | Sólo `OnStart` / `OnStop` (`.vb:16-19,43-46`) |
| `C:\temp\dte\LOGSPBASCULAS_yyyy-MM-dd.txt` | **Casi todo el log de negocio** (`.vb:190-197`) |

Al diagnosticar, la segunda ruta es la útil. El nombre de carpeta (`dte`) es herencia de la
plantilla, no tiene relación con facturación electrónica.

---

## ⚠️ Inconsistencia real en el nombre del servicio

El repo declara **dos nombres distintos**:

| Lugar | Valor |
|-------|-------|
| `ProjectInstaller.Designer.vb:35` | `epdPo1nt_SyncronizadorBasculas` |
| `epdPo1nt_SyncronizadorBasculas.Designer.vb:53` | **`epdPo1nt_SyncronizadorEnvioDTE`** |

El segundo es el nombre del servicio de reenvío de DTE: el proyecto se creó copiando esa
plantilla y el `ServiceName` de runtime nunca se actualizó.

En .NET, `ServiceBase.ServiceName` debe coincidir con el nombre registrado en el SCM. **El
efecto real en los servidores no está verificado** — el servicio opera en campo — pero la
inconsistencia es real y conviene corregirla junto con el equipo antes de tocar el
despliegue, no en caliente.

Al buscar el servicio en un NAV, tener presentes ambos nombres.
