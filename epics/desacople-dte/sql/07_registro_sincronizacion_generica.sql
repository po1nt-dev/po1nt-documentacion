-- ============================================================================
-- Script: 07_registro_sincronizacion_generica.sql
-- Ejecutar en: BD del servidor de sala (SatellitePOS_SUCURSAL_01)
-- Proposito: Registrar los SPs de DTE_Escalaciones en la tabla de
--            sincronizaciones genericas para que sincronizacion-sala
--            los ejecute automaticamente con su TimerServerLocal.
--
--            sincronizacion-sala usa SP_Obtener_Sincronizaciones_Genericas_Locales
--            para obtener esta lista y luego ejecuta:
--              1. SP_Extrae_DTE_Escalaciones      (en cada terminal)
--              2. SP_Guarda_DTE_Escalaciones       (en servidor de sala)
--              3. SP_Actualiza_DTE_Escalaciones_Estado (en cada terminal)
--
-- Epica: po1nt-dev/po1nt-documentacion#2
-- Issue: po1nt-dev/sincronizacion-sala#2
-- ============================================================================

-- Verificar si ya existe el registro
IF NOT EXISTS (
    SELECT 1 FROM SincronizacionesGenericasLocales
    WHERE SP_Extrae_Informacion = 'SP_Extrae_DTE_Escalaciones'
)
BEGIN
    INSERT INTO SincronizacionesGenericasLocales (
        SP_Extrae_Informacion,
        SP_Guarda_Informacion,
        SP_Actualiza_Status,
        Campo_Id_Tabla
    ) VALUES (
        'SP_Extrae_DTE_Escalaciones',
        'SP_Guarda_DTE_Escalaciones',
        'SP_Actualiza_DTE_Escalaciones_Estado',
        'Id'
    );

    PRINT 'Registro de sincronizacion generica para DTE_Escalaciones agregado';
END
ELSE
BEGIN
    PRINT 'Registro de sincronizacion generica para DTE_Escalaciones ya existe';
END
GO
