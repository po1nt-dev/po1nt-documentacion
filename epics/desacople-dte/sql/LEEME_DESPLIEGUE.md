# Scripts SQL — Desacople de DTEs

## Orden de ejecucion

### En BD de cada POS (SatellitePOS_MH)
1. `01_ddl_pos_EstadoEnvioDte.sql` — Campo EstadoEnvioDte en TransEncabezado
2. `02_ddl_pos_DTE_Escalaciones.sql` — Tabla DTE_Escalaciones (con Transmitir_Sala y RutaArchivoContenido)
3. `04_sp_pos_Extrae_DTE_Escalaciones.sql` — SP de extraccion (usa Transmitir_Sala=1)
4. `06_sp_pos_Actualiza_DTE_Escalaciones_Estado.sql` — SP de actualizacion (pone Transmitir_Sala=0)
5. `08_sp_pos_Po1nt_FacturacionElectronica_update.sql` — SP que actualiza TransEncabezado + log cuando DTE se emite

### En BD del servidor de sala (SatellitePOS_SUCURSAL_01)
6. `03_ddl_sala_DTE_Escalaciones_Central.sql` — Tabla DTE_Escalaciones_Central (con EstadoEscalacion)
7. `05_sp_sala_Guarda_DTE_Escalaciones.sql` — SP de guardado (MERGE: inserta nuevos, actualiza existentes)
8. `07_registro_sincronizacion_generica.sql` — Registro para sincronizacion automatica

### En BD de sala y central (para sync de EstadoEnvioDte via epdPo1nt_Syncronizador)
9. `09_ddl_central_EstadoEnvioDte_sync.sql` — Campo EstadoEnvioDte en TransEncabezado + modificar SP Sync_Aplicar_Transacciones_Manual_new

## Notas
- Los scripts son idempotentes (verifican existencia antes de crear)
- Se usa VARCHAR(8000) en vez de VARCHAR(MAX) para evitar deadlocks
- El SP de guardado usa MERGE para manejar re-sincronizaciones (cuando un registro cambia de estado en el POS, Transmitir_Sala se pone en 1 y se re-envia)
- Despues de ejecutar el script 07, sincronizacion-sala recogera automaticamente las escalaciones
