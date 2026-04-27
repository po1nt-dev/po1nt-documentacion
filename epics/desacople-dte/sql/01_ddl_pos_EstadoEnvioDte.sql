-- ============================================================================
-- Script: 01_ddl_pos_EstadoEnvioDte.sql
-- Ejecutar en: BD de cada POS (SatellitePOS_MH)
-- Proposito: Agregar campo EstadoEnvioDte a TransEncabezado
-- Epica: po1nt-dev/po1nt-documentacion#2
-- Issue: po1nt-dev/sincronizacion-sala#2
-- ============================================================================

-- Verificar si el campo ya existe antes de agregarlo
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'TransEncabezado' AND COLUMN_NAME = 'EstadoEnvioDte'
)
BEGIN
    ALTER TABLE TransEncabezado ADD EstadoEnvioDte VARCHAR(50) NULL;
    PRINT 'Campo EstadoEnvioDte agregado a TransEncabezado';
END
ELSE
BEGIN
    PRINT 'Campo EstadoEnvioDte ya existe en TransEncabezado';
END
GO
