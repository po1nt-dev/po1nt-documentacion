# Estado de entrega: qué falta mergear y qué falta instalar

> Corte: **2026-09-22**. La columna "mergeado" está verificada con `git` y `gh` repo por
> repo. La columna "desplegado" **no** se puede verificar desde el código: requiere entrar
> a los servidores. Lo que aquí se afirma sobre despliegue viene del registro de las
> ventanas de trabajo y está marcado como tal.

## Regla que se olvida seguido

**Mergear a `main` no despliega nada.**

- **Microservicios** (MS-Sync, MS-Products, …): el despliegue lo dispara un **PR de
  promoción `main` → `production`**. Sin ese segundo PR, el cambio está en `main` y no
  está en producción. No usar squash en esa promoción.
- **Servicios Windows de sala**: se instalan copiando el `.exe` en cada servidor de sala.
  No hay CI que los empuje.
- **`po1nt-pos`**: el binario se instala **caja por caja**.

---

## 1. Sincronización: pendientes que afectan el flujo de datos

| Repo | Rama / PR | Qué corrige | Riesgo de no pasarlo |
|------|-----------|-------------|----------------------|
| **WS-SincronizadorSalas** | `fix/sync-paginacion-lotes` — **PR #2 abierto** | Paginar el lote completo antes de confirmar | **Alto.** Es la fuga de códigos de barra: 831 códigos perdidos en 80 salas desde dic-2024, y sigue ocurriendo. Ver [`objetos/productos-precios-promociones.md`](objetos/productos-precios-promociones.md) |
| **po1nt-pos** | `fix/devolucion-cliente-por-no-fallback` — **PR #61 abierto** | Devolver una venta anterior al módulo reconstruye el cliente por `No_` | **Alto.** Sin él, la nota de crédito sale a consumidor final genérico (degrada, no da error duro) |
| **po1nt-pos** | `fix/encolar-contingencia-mh` — **PR #47 abierto** | Encolar contingencia y persistir `codigoGeneracion` para idempotencia del DTE | Medio-alto, riesgo fiscal |
| **po1nt-dte-reproceso** | `fix/sincronizar-sin-placeholder-sello` — **sin PR** | Preservar `MH_Response` y `MH_FechaRecepcion` al actualizar central | **Alto.** Sobrescribir con placeholder es la causa raíz de las notas de crédito sin DTE |
| **po1nt-dte-reproceso** | `feat/verify-sala-nueva` — **sin PR** | Verificador de instalación de sala en una pasada | Bajo; es herramienta |
| **ws-reenviodte** | `feature/desacople-dtes` — **PR #3 abierto** | Filtrar por `EstadoEnvioDte` para no colisionar con `DteServiceLocal` | Medio: doble envío |
| **sincronizacion-sala** | `feature/desacople-dtes` — **PR #3 abierto**, 12 commits | Tabla `DTE_Escalaciones` y ajustes de `Transmitir_Sala` / `EstadoEnvioDte` | Medio |
| **portaladministrativo-desktop** | `feat/EnvioPromocionesOfertas` — **PR #6 abierto** | Mostrar estado activado/desactivado de la promoción | Bajo |
| **po1nt-documentacion** | `epics/desacople-dte` — **PR #3 abierto** | Planes y scripts del epic de desacople DTE | Bajo |

### Sin nada pendiente

`epdPo1nt_Syncronizador`, `WS-SincronizacionBascula`, `MS-Sync`, `cron-jobs`,
`sincronizador-skus-n1co-point`, `ms-conciliador-cashback-n1`.

`epdPo1nt_Syncronizador` tiene siete ramas remotas antiguas, todas a 0 commits sobre
`main`: ya fusionadas u obsoletas. Se pueden borrar.

---

## 2. Trabajo en riesgo de perderse

**`po1nt-sql-queries` tiene 9 archivos sin commitear en `main`** — no están en ninguna rama
ni PR, y son el correctivo de empleados que se aplicó a la flota entera el 2026-09-21:

| Archivo | Estado |
|---------|--------|
| `22_delta_empleados_erp_a_depurada.sql` | sin trackear |
| `22c_xml_delta_para_cajas.sql` | sin trackear |
| `23_sp_customer_update_tipo5_diplomatico.sql` | sin trackear |
| `tools/migracion-clientes-sala/Generar-DeltaERP-Cajas.ps1` | sin trackear |
| `scripts/migraciones/customer/README.md` | modificado |
| `.../deploy-caja-piloto/00_RUNBOOK.md` | modificado |
| `.../deploy-caja-piloto/04_verificacion_post_deploy.sql` | modificado |
| `.../modulo-clientes/03_SatellitePOS_Customer_Update.sql` | modificado |
| `.../modulo-clientes/README.md` | modificado |

Ese código ya corrió contra central y 193 cajas. Si el árbol de trabajo se pierde, no hay
forma de reproducir la corrida.

---

## 3. Pendientes de instalar

| Qué | Dónde | Estado |
|-----|-------|--------|
| Fix de paginado (PR #2) | Servidor de sala de las 83 salas | **No instalable aún**: falta mergear |
| Script `23` (tipo diplomático) | **CJ2090** (192.168.141.31) | Pendiente: la caja estaba apagada el 21-sep. Aplicar con `Apply-SqlToCajas` cuando encienda |
| Binario A46 de `po1nt-pos` | Flota | Instalación manual caja por caja, en curso |
| `release/v44` — **PR #66** | — | Marcado **"[NO MERGEAR]"**: es el build de despliegue, no se fusiona a `main` |

---

## 4. Deuda estructural conocida (sin rama todavía)

| Tema | Detalle |
|------|---------|
| **Eco de replicación** | `Transmitir DEFAULT (0)` + MERGE de bajada que no lo setea → 98,6 % de los upserts en central son eco, 4,9 M de tareas vivas. Fix de una línea, **sin implementar en el flujo legado** |
| **`sync_types` 1086** | `delete-Customers` existe como tipo pero **su SP no existe**: las bajas no tienen camino |
| **Plan F1–F4 de empleados** | Sin F1 (ingesta continua ERP→Depurada) y F2 (canal central→cajas nuevas), cada ventana exige repetir el delta a mano |
| **Throughput `TOP 1`** | `SP_Sync_CustomerPOS_Servicio` sube un cliente por ciclo: ~288/día/caja. Una caja con backlog no se pone al día |
| **Gemelos DUI de jurídicas** | Rechazo de crédito fiscal en Hacienda; depende de que Selectos confirme la limpieza |
| **Catch-up de V2** | Una caja que entra al mesh después no recibe las altas de app previas |
