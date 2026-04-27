-- ============================================================================
-- Script: 04_sp_pos_Extrae_DTE_Escalaciones.sql
-- Ejecutar en: BD de cada POS (SatellitePOS_MH)
-- Proposito: Extraer escalaciones pendientes de sincronizacion.
--            Usa Transmitir_Sala=1 para detectar registros nuevos o modificados.
--            Llamado por sincronizacion-sala via ProcesarGenericoLocales.
-- Epica: po1nt-dev/po1nt-documentacion#2
-- Issue: po1nt-dev/sincronizacion-sala#2
-- ============================================================================

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'SP_Extrae_DTE_Escalaciones')
    DROP PROCEDURE SP_Extrae_DTE_Escalaciones;
GO

CREATE PROCEDURE SP_Extrae_DTE_Escalaciones
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id,
        GuidTransaccion,
        IdSucursal,
        IdCaja,
        IdCajero,
        TipoTransaccion,
        CategoriaError,
        DetalleError,
        ContadorReintentos,
        BusinessDay,
        EstadoEscalacion,
        FechaCreacion
    FROM DTE_Escalaciones
    WHERE Transmitir_Sala = 1
    ORDER BY FechaCreacion ASC;
END
GO

PRINT 'SP_Extrae_DTE_Escalaciones creado exitosamente';
GO
