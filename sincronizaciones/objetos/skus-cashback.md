# Sincronización de SKUs de Cashback N1Co

Dos componentes distintos, con propósitos distintos: uno **carga** el catálogo, el otro
**audita** que las transacciones hayan llegado.

---

## `sincronizador-skus-n1co-point` — la carga

Aplicación de consola **manual**, sin timer ni tarea programada.

| Aspecto | Valor real (código) |
|---------|---------------------|
| Ensamblado | `SincronizadorSKUs` |
| Framework | C#, .NET 8.0 |
| Invocación | `dotnet run -- <ruta-archivo.xlsx>` (`Program.cs:32-46`), o publicado: `./SincronizadorSKUs CatalogoCashbackSKUSuperSelectos_AAAAMMDD.xlsx` |
| Argumentos | Exactamente 1: la ruta del `.xlsx`. Sin él, imprime uso y retorna 1 |
| Dónde corre | Máquina del operador |
| HTTP | Ninguno |

### Qué hace, en dos pasos

| Paso | Origen → destino | Detalle |
|------|------------------|---------|
| **B** | Excel → central | Lee la columna `EAN13` y compara contra `[dbo].[N1Co_SKU_Process]` en `point_pos` (`DatabaseService.cs:24,39-64`) |
| **D** | Central → terminales | Lee las terminales de `[dbo].[terminals] INNER JOIN [dbo].[places]` (`DatabaseService.cs:122-151`) y escribe `[dbo].[N1Co_SKU_Process]` en el `SatellitePOS_MH` de cada una (`DatabaseService.cs:177-248`) |

Cubre las fases **B** y **D** de un pipeline de cinco; A, C y E las hacen otras
herramientas. Todo es SQL en línea: **no usa stored procedures**.

Salida: `Console.WriteLine` más un reporte CSV (`ReporteService.GenerarCsv`, `Program.cs:83`),
en la carpeta del Excel de entrada. No hay archivo de log.

### ⚠️ Corrección respecto de su documentación

El `README.md` y el `CLAUDE.md` del repo afirman que **sólo inserta** y que "los registros
existentes nunca se modifican". **Eso ya no es cierto**: el código también actualiza
(`ActualizarSkusCentralAsync`, `DatabaseService.cs:66-92`; `ActualizarSkusEnTerminalAsync`,
líneas 222-248), desde el commit `2394480` *"leer fechas del Excel y actualizar SKUs
existentes en central y terminales"*, posterior a la redacción de esos documentos.

Importa porque cambia el riesgo de correr la herramienta dos veces: ya no es idempotente en
el sentido de "no toca lo que existe".

---

## `ms-conciliador-cashback-n1` — el auditor

No sincroniza: **repara**. Es el healer del cashback por SKU.

| Aspecto | Valor |
|---------|-------|
| Framework | .NET 8, `BackgroundService` |
| Intervalo | Tick cada 300 s, configurable |
| Lectura | BD de POS de Selectos (`po1nt_pos`), **sólo lectura**, con Dapper |
| Acción | `POST /internal/sku-cashback/verify-and-heal` en el backend de finanzas de n1co |
| API admin | `/health`, `/status`, `/trigger`, `/reset-checkpoint` |
| Despliegue | MicroK8s, clusters `po1nt-prod` / `po1nt-dr`, namespace `po1nt` |
| Otros | Polly para reintentos, Datadog APM |

Existe porque el flujo en vivo (webhook InSwitch → Hangfire → BigQuery) pierde
transacciones; el conciliador las detecta comparando contra la BD del POS y pide al backend
que las recupere.

Es el único componente de esta sección que corre en Kubernetes y el único con endpoints de
operación propios.
