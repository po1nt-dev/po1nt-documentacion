-- ============================================================================
-- Script: 05_sp_sala_Guarda_DTE_Escalaciones.sql
-- Ejecutar en: BD del servidor de sala (SatellitePOS_SUCURSAL_01)
-- Proposito: Guardar escalaciones recibidas desde los terminales POS.
--            Llamado por sincronizacion-sala via ProcesarGenericoLocales.
--            Recibe datos como XML (formato estandar del mecanismo generico).
--            Usa MERGE para insertar nuevos y actualizar existentes
--            (cuando un registro cambia de estado, Transmitir_Sala=1 y se
--            re-sincroniza con los datos mas recientes).
-- Epica: po1nt-dev/po1nt-documentacion#2
-- Issue: po1nt-dev/sincronizacion-sala#2
-- ============================================================================

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'SP_Guarda_DTE_Escalaciones')
    DROP PROCEDURE SP_Guarda_DTE_Escalaciones;
GO

CREATE PROCEDURE SP_Guarda_DTE_Escalaciones
    @XML VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @xmlDoc XML = CAST(@XML AS XML);

    MERGE DTE_Escalaciones_Central AS target
    USING (
        SELECT
            T.c.value('(GuidTransaccion)[1]',     'VARCHAR(100)')  AS GuidTransaccion,
            T.c.value('(IdSucursal)[1]',          'INT')           AS IdSucursal,
            T.c.value('(IdCaja)[1]',              'INT')           AS IdCaja,
            T.c.value('(IdCajero)[1]',            'INT')           AS IdCajero,
            T.c.value('(TipoTransaccion)[1]',     'INT')           AS TipoTransaccion,
            T.c.value('(CategoriaError)[1]',      'VARCHAR(50)')   AS CategoriaError,
            T.c.value('(DetalleError)[1]',        'VARCHAR(8000)') AS DetalleError,
            T.c.value('(ContadorReintentos)[1]',  'INT')           AS ContadorReintentos,
            T.c.value('(BusinessDay)[1]',         'DATETIME')      AS BusinessDay,
            T.c.value('(EstadoEscalacion)[1]',    'VARCHAR(50)')   AS EstadoEscalacion,
            T.c.value('(FechaCreacion)[1]',       'DATETIME')      AS FechaCreacion
        FROM @xmlDoc.nodes('/datos/row') AS T(c)
    ) AS source
    ON target.GuidTransaccion = source.GuidTransaccion
    WHEN MATCHED THEN
        UPDATE SET
            EstadoEscalacion    = source.EstadoEscalacion,
            DetalleError        = source.DetalleError,
            ContadorReintentos  = source.ContadorReintentos,
            FechaSincronizacion = GETDATE()
    WHEN NOT MATCHED THEN
        INSERT (
            GuidTransaccion, IdSucursal, IdCaja, IdCajero, TipoTransaccion,
            CategoriaError, DetalleError,
            ContadorReintentos, BusinessDay, EstadoEscalacion, FechaCreacionOriginal
        )
        VALUES (
            source.GuidTransaccion, source.IdSucursal, source.IdCaja, source.IdCajero,
            source.TipoTransaccion, source.CategoriaError, source.DetalleError,
            source.ContadorReintentos, source.BusinessDay,
            source.EstadoEscalacion, source.FechaCreacion
        );
END
GO

PRINT 'SP_Guarda_DTE_Escalaciones creado exitosamente';
GO
