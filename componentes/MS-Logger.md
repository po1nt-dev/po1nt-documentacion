# MS-Logger - Microservicio de Logging Centralizado

## Descripcion General

**MS-Logger** es el microservicio encargado de la recoleccion y almacenamiento centralizado de logs y transacciones del sistema Po1nt. Proporciona una API REST para que otros componentes del sistema registren eventos, acciones y transacciones de forma centralizada.

## Informacion del Servicio

| Atributo | Valor |
|----------|-------|
| **Nombre** | MS-Logger |
| **Tecnologia** | ASP.NET Core 7.0 |
| **Lenguaje** | C# |
| **Puerto** | Configurado via Kestrel |
| **Base de Datos** | SQL Server (interno) |

## Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│                    Clientes                             │
│  (MS-Autn, MS-configs, MS-Products, po1nt-pos, etc.)   │
└─────────────────────────┬───────────────────────────────┘
                          │ HTTP POST
                          ▼
┌─────────────────────────────────────────────────────────┐
│                     MS-Logger                           │
├─────────────────────────────────────────────────────────┤
│  LogController        │  TransactionController          │
│  POST /api/Log        │  POST /api/Transaction          │
├─────────────────────────────────────────────────────────┤
│  LoggerRepository     │  TransactionRepository          │
└─────────────────────────┬───────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                    SQL Server                           │
│                    (logs table)                         │
└─────────────────────────────────────────────────────────┘
```

## Dependencias

- **shared-libs**: Utiliza MSDefault, User model y utilidades compartidas
- **Sentry**: Monitoreo de errores
- **Swagger**: Documentacion de API

## Estructura del Proyecto

```
MS-Logger/
├── Controllers/
│   ├── LogController.cs          # Endpoint para guardar logs
│   └── TransactionController.cs  # Endpoint para guardar transacciones
├── Models/
│   └── Log.cs                    # Modelo de log
├── Repositories/
│   ├── LoggerRepository.cs       # Acceso a datos de logs
│   └── TransactionRepository.cs  # Acceso a datos de transacciones
├── Properties/
│   └── launchSettings.json
├── Program.cs                    # Punto de entrada
├── MS-Logger.csproj
└── MS-Logger.sln
```

## API Endpoints

### POST /api/Log

Guarda un registro de log en la base de datos.

**Request Body:**
```json
{
  "action_name": "string",
  "status": true,
  "uuid": "string",
  "detail": {}
}
```

**Response (200):**
```json
{
  "message": "Log guardado"
}
```

**Response (500):**
```json
{
  "message": "Error al crear log"
}
```

### POST /api/Transaction

Guarda una transaccion completa como JSON raw.

**Request Body:** Raw JSON de la transaccion

**Response (200):**
```json
{
  "message": "Transaction saved successfully"
}
```

**Response (400):**
```json
{
  "message": "Transaction not saved"
}
```

## Modelo de Datos

### Tabla: logs

```sql
CREATE TABLE logs (
  id bigint primary key identity,
  action_name VARCHAR(255) NOT NULL,
  status bit NOT NULL,
  uuid VARCHAR(255) NOT NULL,
  terminal int not null,
  place int not NULL,
  detail VARCHAR(MAX) NOT NULL
);
```

| Campo | Tipo | Descripcion |
|-------|------|-------------|
| id | bigint | Identificador unico autoincremental |
| action_name | VARCHAR(255) | Nombre de la accion registrada |
| status | bit | Estado del log (1=exitoso, 0=fallido) |
| uuid | VARCHAR(255) | Identificador unico de sesion/usuario |
| terminal | int | ID del terminal POS |
| place | int | ID de la sucursal/lugar |
| detail | VARCHAR(MAX) | Detalle del log en formato JSON |

## Modelo Log (C#)

```csharp
public class Log
{
    [Required]
    public string action_name { get; set; }
    [Required]
    public Boolean status { get; set; }
    [Required]
    public string uuid { get; set; }
    [Required]
    public dynamic detail { get; set; }
}
```

## Integracion con shared-libs

El microservicio utiliza las utilidades compartidas de shared-libs:

```csharp
using shared_libs.Utils;

var app = builder.Build();
MSDefault.init(app, "ms-logger");
```

Esto proporciona:
- Configuracion estandar de Swagger
- Middleware de autenticacion
- Metricas de Prometheus (si habilitado)
- Configuracion de CORS

## Casos de Uso

1. **Logging de acciones de usuario**: Registro de operaciones realizadas por usuarios en el sistema
2. **Auditoria**: Trazabilidad de cambios y operaciones criticas
3. **Debugging**: Registro de eventos para diagnostico de problemas
4. **Transacciones**: Almacenamiento de transacciones completas para analisis posterior

## Configuracion

### Variables de Entorno

| Variable | Descripcion |
|----------|-------------|
| ASPNETCORE_ENVIRONMENT | Entorno de ejecucion (Development/Production) |
| CONNECTION_STRING | Cadena de conexion a SQL Server |
| SENTRY_DSN | DSN de Sentry para monitoreo de errores |

## CI/CD

El servicio incluye configuracion de GitLab CI para despliegue automatizado:
- `.gitlab-ci.yml`: Pipeline de CI/CD

## Notas de Implementacion

- El servicio extrae informacion del usuario autenticado del contexto HTTP (`HttpContext.Items["user"]`)
- Los campos `terminal` y `place` se obtienen automaticamente del token JWT del usuario
- El campo `detail` acepta cualquier objeto JSON dinamico
- Las transacciones se guardan como JSON raw sin parsing
