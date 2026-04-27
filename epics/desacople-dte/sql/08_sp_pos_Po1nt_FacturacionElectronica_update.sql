-- ============================================================================
-- Script: 08_sp_pos_Po1nt_FacturacionElectronica_update.sql
-- Ejecutar en: BD de cada POS (SatellitePOS_MH)
-- Proposito: Actualizar TransEncabezado y Po1nt_FacturacionElectronicaLog
--            con los datos de respuesta del DTE (sello, codigo generacion, etc.)
--            Llamado por dte-service-local al emitir exitosamente un DTE
--            (tanto en primer intento como en reintentos).
--            Tambien pone Transmitir_Sala=1 para re-sincronizar.
-- Epica: po1nt-dev/po1nt-documentacion#2
-- ============================================================================

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'Po1nt_FacturacionElectronica_update')
    DROP PROCEDURE Po1nt_FacturacionElectronica_update;
GO

CREATE PROCEDURE Po1nt_FacturacionElectronica_update
    @REC                 VARCHAR(100),
    @MH_Sello            VARCHAR(500),
    @MH_CodigoGeneracion VARCHAR(100),
    @MH_FechaRecepcion   VARCHAR(50),
    @MH_NumeroControl    VARCHAR(100),
    @MH_Estado           VARCHAR(50),
    @MH_ResponseCode     VARCHAR(10),
    @MH_Response         VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    -- Actualizar TransEncabezado con datos del sello
    UPDATE TransEncabezado
    SET MH_Sello            = @MH_Sello,
        MH_CodigoGeneracion = @MH_CodigoGeneracion,
        MH_FechaRecepcion   = @MH_FechaRecepcion,
        MH_NumeroControl    = @MH_NumeroControl,
        MH_Estado           = @MH_Estado,
        MH_ResponseCode     = @MH_ResponseCode,
        MH_Response         = @MH_Response,
        EstadoEnvioDte      = 'PROCESADO',
        Transmitir_Sala     = 1
    WHERE Guid = @REC;

    -- Actualizar log de facturacion electronica con la respuesta
    UPDATE Po1nt_FacturacionElectronicaLog
    SET MH_Sello            = @MH_Sello,
        MH_CodigoGeneracion = @MH_CodigoGeneracion,
        MH_FechaRecepcion   = @MH_FechaRecepcion,
        MH_NumeroControl    = @MH_NumeroControl,
        MH_Estado           = @MH_Estado,
        MH_ResponseCode     = @MH_ResponseCode,
        MH_Response         = @MH_Response
    WHERE REC = @REC;
END
GO

PRINT 'Po1nt_FacturacionElectronica_update creado exitosamente';
GO
