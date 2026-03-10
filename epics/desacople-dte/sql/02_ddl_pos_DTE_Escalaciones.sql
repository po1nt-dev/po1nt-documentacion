-- ============================================================================
-- Script: 02_ddl_pos_DTE_Escalaciones.sql
-- Ejecutar en: BD de cada POS (SatellitePOS_MH)
-- Proposito: Crear tabla DTE_Escalaciones para errores no-reintentables
-- Nota: Se usa VARCHAR(8000), NO VARCHAR(MAX),
--       para evitar los deadlocks que sufre BillingMH_TransactionLog.
-- Epica: po1nt-dev/po1nt-documentacion#2
-- Issue: po1nt-dev/sincronizacion-sala#2
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'DTE_Escalaciones')
BEGIN
    CREATE TABLE DTE_Escalaciones (
        Id                      INT IDENTITY(1,1) PRIMARY KEY,
        GuidTransaccion         VARCHAR(100)  NOT NULL,
        IdSucursal              INT           NOT NULL,
        IdCaja                  INT           NOT NULL,
        IdCajero                INT           NOT NULL DEFAULT 0,
        TipoTransaccion         INT           NOT NULL,
        CategoriaError          VARCHAR(50)   NOT NULL,    -- 'Transitorio', 'DatosInvalidos', 'ErrorNegocio'
        DetalleError            VARCHAR(8000) NULL,
        RutaArchivoContenido    VARCHAR(500)  NULL,        -- Ruta al JSON completo en disco
        ContadorReintentos      INT           DEFAULT 0,
        BusinessDay             DATETIME      NOT NULL,
        EstadoEscalacion        VARCHAR(50)   DEFAULT 'Pendiente',  -- 'Pendiente','Sincronizada','Resuelta','Corregida'
        Transmitir_Sala         BIT           NOT NULL DEFAULT 1,
        FechaCreacion           DATETIME      DEFAULT GETDATE(),
        FechaSincronizacion     DATETIME      NULL,
        CONSTRAINT UQ_DTE_Escalaciones_Guid UNIQUE (GuidTransaccion)
    );

    CREATE INDEX idx_escalaciones_transmitir
        ON DTE_Escalaciones(Transmitir_Sala, FechaCreacion);

    PRINT 'Tabla DTE_Escalaciones creada exitosamente';
END
ELSE
BEGIN
    PRINT 'Tabla DTE_Escalaciones ya existe';
END
GO
