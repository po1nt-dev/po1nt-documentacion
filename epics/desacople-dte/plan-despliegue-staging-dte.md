# Plan de despliegue — Ambiente de staging para DTE desacoplado

## Componentes del sistema

```
POS Terminal                    Sala Server                    Servidor Central
─────────────                   ────────────                   ────────────────
po1nt-pos                       sincronizacion-sala            ms-procesos-locales
dte-service-local               BD: SatellitePOS_SUCURSAL_01   BD: Central
BD: SatellitePOS_MH (POSLOCAL)
BD: SQLite (cola reintentos)
```

## Pre-requisitos

- [ ] SQL Server accesible (instancia POSLOCAL para POS, instancia de sala, instancia central)
- [ ] .NET 8 SDK instalado (para dte-service-local)
- [ ] .NET Framework para po1nt-pos y sincronizacion-sala
- [ ] Repos clonados: po1nt-pos, dte-service-local, sincronizacion-sala, ms-procesos-locales

## Paso 1: Base de datos del POS (SatellitePOS_MH)

Ejecutar en orden en la BD del POS:

```bash
# Desde el directorio sincronizacion-sala/sql/
sqlcmd -S POSLOCAL -d SatellitePOS_MH -i 01_ddl_pos_EstadoEnvioDte.sql
sqlcmd -S POSLOCAL -d SatellitePOS_MH -i 02_ddl_pos_DTE_Escalaciones.sql
sqlcmd -S POSLOCAL -d SatellitePOS_MH -i 04_sp_pos_Extrae_DTE_Escalaciones.sql
sqlcmd -S POSLOCAL -d SatellitePOS_MH -i 06_sp_pos_Actualiza_DTE_Escalaciones_Estado.sql
sqlcmd -S POSLOCAL -d SatellitePOS_MH -i 08_sp_pos_Po1nt_FacturacionElectronica_update.sql
```

Verificar:
- [ ] Campo `EstadoEnvioDte` existe en `TransEncabezado`
- [ ] Tabla `DTE_Escalaciones` existe con columnas `Transmitir_Sala`, `RutaArchivoContenido`, `ContenidoSolicitud`
- [ ] SP `SP_Extrae_DTE_Escalaciones` filtra por `Transmitir_Sala = 1`
- [ ] SP `SP_Actualiza_DTE_Escalaciones_Estado` pone `Transmitir_Sala = 0`
- [ ] SP `Po1nt_FacturacionElectronica_update` actualiza `TransEncabezado` + `Po1nt_FacturacionElectronicaLog` + `Transmitir_Sala = 1`

Parametros en `SatellitePOS_Parameters`:

```sql
-- Habilitar desacople DTE local
INSERT INTO SatellitePOS_Parameters (ID_Parameter, Value_parameter, Caption, IS_Active)
VALUES (10039, '1', 'DTE Desacople Local Activo', 1);

-- URL del servicio DTE local
INSERT INTO SatellitePOS_Parameters (ID_Parameter, Value_parameter, Caption, IS_Active)
VALUES (10040, 'http://localhost:7890', 'URL Servicio DTE Local', 1);
```

## Paso 2: dte-service-local

```bash
cd dte-service-local
dotnet publish src/DteServiceLocal/DteServiceLocal.csproj -c Release -r win-x64 --self-contained -o ./publish
```

Copiar a `C:\epdsoft\DteServiceLocal\` en la maquina POS.

Configurar `appsettings.json`:
- `BdLocalPos:CadenaConexion` — connection string a la BD del POS
- `Bitworks:*` — credenciales OAuth de Bitworks (produccion o pruebas)
- `Escalaciones:Ruta` — ruta para archivos JSON de escalaciones

Crear directorios:
```cmd
mkdir C:\epdsoft\Log\DTE
mkdir C:\epdsoft\DTE\Escalaciones
```

Instalar como servicio:
```cmd
sc create DteServiceLocal binPath= "C:\epdsoft\DteServiceLocal\DteServiceLocal.exe" start= auto
sc start DteServiceLocal
```

Verificar:
- [ ] `curl http://localhost:7890/health` retorna `{"estado":"activo"}`
- [ ] Enviar un DTE de prueba y verificar que `EstadoEnvioDte` se actualiza en `TransEncabezado`

## Paso 3: Base de datos de Sala (SatellitePOS_SUCURSAL_01)

Ejecutar en la BD de sala:

```bash
sqlcmd -S SERVIDOR_SALA -d SatellitePOS_SUCURSAL_01 -i 03_ddl_sala_DTE_Escalaciones_Central.sql
sqlcmd -S SERVIDOR_SALA -d SatellitePOS_SUCURSAL_01 -i 05_sp_sala_Guarda_DTE_Escalaciones.sql
sqlcmd -S SERVIDOR_SALA -d SatellitePOS_SUCURSAL_01 -i 07_registro_sincronizacion_generica.sql
sqlcmd -S SERVIDOR_SALA -d SatellitePOS_SUCURSAL_01 -i 09_ddl_central_EstadoEnvioDte_sync.sql
```

Verificar:
- [ ] Tabla `DTE_Escalaciones_Central` existe con columna `EstadoEscalacion`
- [ ] SP `SP_Guarda_DTE_Escalaciones` usa MERGE (inserta nuevos, actualiza existentes)
- [ ] Registro en `SincronizacionesGenericasLocales` para DTE_Escalaciones
- [ ] Campo `EstadoEnvioDte` existe en `TransEncabezado` de sala/central
- [ ] SP `Sync_Aplicar_Transacciones_Manual_new` acepta parametro `@EstadoEnvioDte`

## Paso 4: sincronizacion-sala

Este es el servicio que sincroniza datos POS → Sala. Se ejecuta como Windows Service o app de escritorio.

1. Abrir en Visual Studio y compilar
2. Configurar via registro de Windows (`HKEY_LOCAL_MACHINE\Software\epdsoft`):
   - Connection string a BD de sala
   - IP/nombre de cada terminal POS
   - Intervalo de sincronizacion
3. Instalar/ejecutar el servicio

Verificar:
- [ ] El servicio arranca sin errores
- [ ] Puede conectar a cada terminal POS
- [ ] Ejecuta `SP_Extrae_DTE_Escalaciones` en los POS
- [ ] Inserta en `DTE_Escalaciones_Central` en la sala
- [ ] Marca `Transmitir_Sala = 0` en el POS despues de sincronizar

Test de sincronizacion:
1. Forzar una escalacion en el POS (enviar un DTE con datos invalidos)
2. Esperar al ciclo de sincronizacion (o reiniciar el servicio)
3. Verificar que el registro aparece en `DTE_Escalaciones_Central` de la sala

## Paso 5: ms-procesos-locales (Servidor Central)

Este es el API central que expone los endpoints para ver y reenviar escalaciones.

1. Clonar y compilar:
   ```bash
   cd ms-procesos-locales
   dotnet build
   ```

2. Configurar connection string a la BD central (que puede ser la misma de sala o una BD dedicada)

3. Verificar endpoints:
   - [ ] `GET /api/DteEscalacion/listar` — lista escalaciones con filtros
   - [ ] `GET /api/DteEscalacion/{id}` — detalle de una escalacion
   - [ ] `POST /api/DteEscalacion/reenviar` — reenviar con correcciones

4. Crear las tablas necesarias en la BD central si son diferentes a las de sala

## Paso 6: po1nt-pos

1. Compilar el branch `feature/desacople-dtes` en Visual Studio
2. Desplegar el ejecutable en la maquina POS
3. Verificar:
   - [ ] Al hacer una venta, el DTE se envia via dte-service-local (puerto 7890)
   - [ ] Si el servicio local no responde, cae al API central
   - [ ] Si hay error de datos (NIT invalido), aparece la pantalla de correccion

## Pruebas end-to-end

### Escenario 1: DTE exitoso
1. Hacer una venta en el POS
2. Verificar que `EstadoEnvioDte = 'PROCESADO'` en `TransEncabezado`
3. Verificar que `MH_Sello`, `MH_CodigoGeneracion`, etc. estan llenos
4. Verificar que `Po1nt_FacturacionElectronicaLog` se actualizo

### Escenario 2: Error transitorio con reintento exitoso
1. Desconectar internet temporalmente al enviar un DTE
2. Verificar `EstadoEnvioDte = 'EN_ESPERA_REINTENTO_LOCAL'`
3. Reconectar internet
4. Esperar a que el worker reintente (max 2 minutos)
5. Verificar que cambia a `PROCESADO` y se llenan los campos MH_*

### Escenario 3: Error no reintentable → escalacion → sincronizacion
1. Enviar DTE con NIT invalido y cancelar la correccion
2. Verificar `EstadoEnvioDte = 'ESCALADO_LOCAL'`
3. Verificar registro en `DTE_Escalaciones` con `Transmitir_Sala = 1`
4. Esperar ciclo de sincronizacion-sala
5. Verificar registro en `DTE_Escalaciones_Central` de la sala
6. Verificar `Transmitir_Sala = 0` en el POS

### Escenario 4: Correccion desde POS
1. Enviar DTE con datos invalidos
2. Corregir en la pantalla de correccion del POS
3. Verificar que DTE se emite exitosamente
4. Verificar que `DTE_Escalaciones.EstadoEscalacion = 'Corregida'` y `Transmitir_Sala = 1`
5. Verificar que se sincroniza al central con el nuevo estado

### Escenario 5: Reenvio desde pantalla central
1. Tener una escalacion sincronizada en el central
2. Usar `POST /api/DteEscalacion/reenviar` con datos corregidos
3. Verificar que se emite exitosamente
4. Verificar que se marca como 'Resuelta'

## Pendientes

- [x] Modificar `FactElectronica.vb` en po1nt-pos para actualizar `DTE_Escalaciones` cuando el usuario corrige un DTE (poner `EstadoEscalacion = 'Corregida'`, `Transmitir_Sala = 1`)
- [x] Agregar `EstadoEnvioDte` al sync de TransEncabezado en epdPo1nt_Syncronizador (`POS_Subir_SERVER_TransaccionesNew`)
- [ ] Modificar SP `Sync_Aplicar_Transacciones_Manual_new` en sala/central para aceptar `@EstadoEnvioDte VARCHAR(50) = NULL` y guardarlo
- [ ] Verificar que `SP_Sync_TransEncabezado_Servicio` (usado por el path XML viejo) incluye `EstadoEnvioDte` en su SELECT
- [ ] Verificar que el nombre de tabla `Po1nt_FacturacionElectronicaLog` es correcto (confirmar con `SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE '%Facturacion%'` en la BD del POS)
- [ ] Verificar que `TransEncabezado` tiene columna `Transmitir_Sala` (deberia existir ya como parte del esquema original)
- [ ] Configurar ms-procesos-locales para que al resolver una escalacion, propague el estado de vuelta al POS (opcional, fase 2)
