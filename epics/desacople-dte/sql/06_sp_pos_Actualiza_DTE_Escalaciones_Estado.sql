-- ============================================================================
-- Script: 06_sp_pos_Actualiza_DTE_Escalaciones_Estado.sql
-- Ejecutar en: BD de cada POS (SatellitePOS_MH)
-- Proposito: Marcar escalaciones como sincronizadas despues de que
--            sincronizacion-sala las haya guardado en el servidor de sala.
--            Pone Transmitir_Sala=0 para que no se vuelvan a enviar
--            (hasta que un cambio de estado las reactive).
--            Llamado por sincronizacion-sala via ProcesarGenericoLocales.
--            Recibe IDs separados por comas.
-- Epica: po1nt-dev/po1nt-documentacion#2
-- Issue: po1nt-dev/sincronizacion-sala#2
-- ============================================================================

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'SP_Actualiza_DTE_Escalaciones_Estado')
    DROP PROCEDURE SP_Actualiza_DTE_Escalaciones_Estado;
GO

CREATE PROCEDURE SP_Actualiza_DTE_Escalaciones_Estado
    @Ids VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE DTE_Escalaciones
    SET Transmitir_Sala = 0,
        FechaSincronizacion = GETDATE()
    WHERE Id IN (
        SELECT CAST(value AS INT)
        FROM STRING_SPLIT(@Ids, ',')
        WHERE RTRIM(LTRIM(value)) <> ''
    );
END
GO

PRINT 'SP_Actualiza_DTE_Escalaciones_Estado creado exitosamente';
GO
