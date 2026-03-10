-- ============================================================================
-- Script: 09_ddl_central_EstadoEnvioDte_sync.sql
-- Ejecutar en: BD de sala (SatellitePOS_SUCURSAL_01) y BD central
-- Proposito: Agregar campo EstadoEnvioDte a TransEncabezado en sala/central
--            y modificar el SP Sync_Aplicar_Transacciones_Manual_new para
--            recibir y guardar el nuevo campo.
--            Esto permite que el estado del DTE (PROCESADO, ESCALADO_LOCAL,
--            EN_ESPERA_REINTENTO_LOCAL, etc.) se sincronice desde cada POS
--            al servidor de sala y central via epdPo1nt_Syncronizador.
-- Epica: po1nt-dev/po1nt-documentacion#2
-- ============================================================================

-- Paso 1: Agregar EstadoEnvioDte a TransEncabezado (sala/central)
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'TransEncabezado' AND COLUMN_NAME = 'EstadoEnvioDte'
)
BEGIN
    ALTER TABLE TransEncabezado ADD EstadoEnvioDte VARCHAR(50) NULL;
    PRINT 'Campo EstadoEnvioDte agregado a TransEncabezado (sala/central)';
END
ELSE
BEGIN
    PRINT 'Campo EstadoEnvioDte ya existe en TransEncabezado (sala/central)';
END
GO

-- Paso 2: Modificar Sync_Aplicar_Transacciones_Manual_new
-- IMPORTANTE: Este SP ya existe. Agregar el parametro @EstadoEnvioDte
-- con valor default NULL para compatibilidad hacia atras.
--
-- Buscar la definicion actual del SP con:
--   sp_helptext 'Sync_Aplicar_Transacciones_Manual_new'
--
-- Agregar a la lista de parametros:
--   @EstadoEnvioDte VARCHAR(50) = NULL
--
-- Agregar al INSERT/UPDATE de TransEncabezado:
--   EstadoEnvioDte = @EstadoEnvioDte
--
-- Ejemplo de la modificacion (adaptar segun la definicion actual del SP):
--
-- ALTER PROCEDURE Sync_Aplicar_Transacciones_Manual_new
--     @idTransaccion BIGINT,
--     ... (parametros existentes) ...
--     @DifRetencion MONEY,
--     @EstadoEnvioDte VARCHAR(50) = NULL,   -- << AGREGAR
--     @tokenTerminal VARCHAR(100)
-- AS
-- BEGIN
--     ... (logica existente) ...
--     -- En el INSERT o UPDATE de TransEncabezado, agregar:
--     -- EstadoEnvioDte = @EstadoEnvioDte
-- END

PRINT 'PENDIENTE: Modificar Sync_Aplicar_Transacciones_Manual_new para incluir @EstadoEnvioDte';
PRINT 'Ver comentarios en este script para instrucciones.';
GO
