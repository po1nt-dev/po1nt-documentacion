-- ============================================================================
-- Script: 03_ddl_sala_DTE_Escalaciones_Central.sql
-- Ejecutar en: BD del servidor de sala (SatellitePOS_SUCURSAL_01)
-- Proposito: Crear tabla donde sincronizacion-sala deposita las escalaciones
-- Epica: po1nt-dev/po1nt-documentacion#2
-- Issue: po1nt-dev/sincronizacion-sala#2
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'DTE_Escalaciones_Central')
BEGIN
    CREATE TABLE DTE_Escalaciones_Central (
        Id                      INT IDENTITY(1,1) PRIMARY KEY,
        GuidTransaccion         VARCHAR(100)  NOT NULL,
        IdSucursal              INT           NOT NULL,
        IdCaja                  INT           NOT NULL,
        IdCajero                INT           NOT NULL DEFAULT 0,
        TipoTransaccion         INT           NOT NULL,
        CategoriaError          VARCHAR(50)   NOT NULL,
        DetalleError            VARCHAR(8000) NULL,
        ContadorReintentos      INT           DEFAULT 0,
        BusinessDay             DATETIME      NOT NULL,
        EstadoEscalacion        VARCHAR(50)   DEFAULT 'Pendiente',
        FechaCreacionOriginal   DATETIME      NOT NULL,
        FechaSincronizacion     DATETIME      DEFAULT GETDATE(),
        CONSTRAINT UQ_DTE_Escalaciones_Central_Guid UNIQUE (GuidTransaccion)
    );

    CREATE INDEX idx_escalaciones_central_fecha
        ON DTE_Escalaciones_Central(FechaSincronizacion);

    CREATE INDEX idx_escalaciones_central_categoria
        ON DTE_Escalaciones_Central(CategoriaError, FechaCreacionOriginal);

    PRINT 'Tabla DTE_Escalaciones_Central creada exitosamente';
END
ELSE
BEGIN
    PRINT 'Tabla DTE_Escalaciones_Central ya existe';
END
GO
