# po1nt-sql-queries - Repositorio de Consultas SQL

## Descripcion General

**po1nt-sql-queries** es un repositorio centralizado de consultas SQL documentadas y validadas para el sistema POS Po1nt. Contiene queries de auditoria, analisis y reporteria para la base de datos del sistema.

## Informacion del Repositorio

| Atributo | Valor |
|----------|-------|
| **Nombre** | po1nt-sql-queries |
| **Tipo** | Repositorio de Queries |
| **Base de Datos** | SQL Server (po1nt_pos) |
| **Total Queries** | 18 consultas de auditoria |

## Estructura del Repositorio

```
po1nt-sql-queries/
├── README.md                           # Documentacion principal
├── MEMORIA_TECNICA.md                  # Documentacion tecnica completa
├── LECCIONES_APRENDIDAS_2025_09_18.md  # Debugging de BD central
├── REVISION_QUERIES_2025_09_18.md      # Revision de queries
├── README_tipos.md                     # Tipos de datos
└── auditoria/                          # Queries de auditoria
    ├── A_facturacion_tienda_online.sql
    ├── B_descuentos_empleados.sql
    ├── C_cambios_precio.sql
    ├── D_ofertas.sql
    ├── E_devoluciones.sql
    ├── F_descuentos_por_funcion.sql
    ├── G_remesas.sql
    ├── H_medios_pago.sql
    ├── I_productos_escaneados.sql
    ├── J_inicio_cierre_cajero.sql
    ├── K_tablas_xyz.sql
    ├── L_pasarela_pagos.sql
    ├── M_documentos_tributarios.sql
    ├── N_cancelaciones_anulaciones.sql
    ├── O_transacciones_standby.sql
    ├── P_ingreso_retiro_fondos.sql
    ├── Q_retiro_efectivo_venta.sql
    └── R_tigomoney.sql
```

## Catalogo de Queries de Auditoria

| Archivo | Descripcion | Estado |
|---------|-------------|--------|
| A_facturacion_tienda_online.sql | Transacciones de pedidos de tienda online (tipos 40, 94, 95) | Validado |
| B_descuentos_empleados.sql | Descuentos aplicados a empleados con CustomerPostingGroup="EMP" | Validado |
| C_cambios_precio.sql | Cambios de precio manuales con ID_SuperPriceChange | Validado |
| D_ofertas.sql | Promociones y ofertas usando Promocion_ID | Validado |
| E_devoluciones.sql | Devoluciones con Estatus=1 y Devolucion_Guid | Validado |
| F_descuentos_por_funcion.sql | Promociones bancarias con Promocion_ID y Dato1-4 | Validado |
| G_remesas.sql | Remesas usando Point_TransPagoColectores | Validado |
| H_medios_pago.sql | Analisis de todos los medios de pago | Validado |
| I_productos_escaneados.sql | Productos escaneados vs manuales con Is_OPOS | Validado |
| J_inicio_cierre_cajero.sql | Control de apertura y cierre de turnos | Validado |
| K_tablas_xyz.sql | Reportes de cierre X, Y, Z con MontoNeto | Validado |
| L_pasarela_pagos.sql | Transacciones con tarjetas usando Dato1-4 | Validado |
| M_documentos_tributarios.sql | Documentos fiscales con campos MH_ del DTE | Validado |
| N_cancelaciones_anulaciones.sql | Transacciones canceladas con campos Devolucion_ | Validado |
| O_transacciones_standby.sql | Transacciones en espera con campo Transmitir | Validado |
| P_ingreso_retiro_fondos.sql | Movimientos usando MontoIngresado/MontoEgreso | Validado |
| Q_retiro_efectivo_venta.sql | Analisis de vuelto | Validado |
| R_tigomoney.sql | Transacciones TigoMoney (tipo 80) con Dato1 | Validado |

## Tipos de Pago Principales

| ID | Descripcion | Frecuencia |
|----|-------------|------------|
| 0 | Efectivo | Muy alta |
| 2 | Tarjeta de Credito | Alta |
| 4 | Tarjeta de Debito | Alta |
| 8 | Tarjeta BAC | Media |
| 15 | Gift Card | Media |
| 21 | eCard | Baja |
| 24 | Puntos | Baja |
| 80 | TigoMoney | Media |
| 94 | Venta Web Gift Card | Muy baja |
| 95 | Venta Web Tarjetas | Baja |

## Tipos de Transaccion

| ID | Descripcion | Documento Fiscal |
|----|-------------|------------------|
| 1 | Factura Consumidor Final | FCF |
| 3 | Credito Fiscal | CCF |
| 5 | Factura Diplomatico | Exportacion |
| 7 | Factura Exportacion | Zona Franca |

## Estados de Transaccion

| Valor | Descripcion |
|-------|-------------|
| 0 | Normal (completada) |
| 1 | Devuelta/Anulada |

## Tablas Principales Referenciadas

### transacciones
- `idTransaccion`: ID unico de la transaccion
- `Guid`: Identificador global unico
- `Estatus`: 0=Normal, 1=Anulada
- `BusinessDay`: Dia de negocio
- `Devolucion_Guid`: Referencia a transaccion original devuelta
- `MH_*`: Campos del Ministerio de Hacienda

### MediosPago
- `idTipoPago`: Tipo de medio de pago
- `Dato1-4`: Campos auxiliares
- `IDSupervisor_descuento`: Supervisor autorizador
- `Total`: Monto pagado

### transacciones_Detalle
- `Promocion_ID`: ID de promocion aplicada
- `Descuento`: Monto de descuento
- `ID_SuperPriceChange`: Supervisor de cambio de precio
- `Is_OPOS`: 1=Escaneado, 0=Manual

### Point_TransPagoColectores
- `CodigoColector`: Codigo del servicio (50001=Cuscatlan, 50002=Western Union)
- `Categoria`: Tipo de servicio
- `MontoPagado`: Monto procesado
- `NoAutorizacion`: Numero de autorizacion

## Uso de las Consultas

### Conexion a Base de Datos
```bash
sqlcmd -S [SERVIDOR] -U [USUARIO] -P "[PASSWORD]" -d po1nt_pos
```

### Ejecutar Query
```bash
sqlcmd -S [SERVIDOR] -U [USUARIO] -P "[PASSWORD]" -d po1nt_pos -i auditoria/A_facturacion_tienda_online.sql
```

### Exportar a CSV
```bash
sqlcmd -S [SERVIDOR] -U [USUARIO] -P "[PASSWORD]" -d po1nt_pos -i auditoria/A_facturacion_tienda_online.sql -o resultado.csv -s","
```

## Estructura Estandar de Queries

Cada archivo SQL sigue este formato:

```sql
/******************************************************
* SISTEMA: POS - po1nt
* MODULO: Auditoria
* FECHA: [Fecha]
* AUTOR: Equipo de Ingenieria PO1NT
******************************************************/

-- DESCRIPCION
-- [Proposito de la consulta]

-- TABLAS UTILIZADAS
-- [Lista de tablas]

-- CAMPOS FILTRADOS (WHERE)
-- [Filtros aplicados]

-- CAMPOS RETORNADOS (SELECT)
-- [Campos devueltos]

-- CONSULTA SQL PRINCIPAL
[Query]

-- NOTAS DE USO
[Consideraciones]
```

## Validaciones Realizadas

Todas las consultas han sido validadas contra:
1. **Estructura de BD**: Verificacion de existencia de campos
2. **Stored Procedures**: Comparacion con logica existente
3. **Datos reales**: Pruebas con registros de produccion
4. **Codigo fuente**: Revision de archivos .vb y .cs

## Consideraciones de Performance

- Todas las consultas incluyen filtros por `BusinessDay`
- Se recomienda usar `TOP` para analisis exploratorio
- Optimizadas para usar indices existentes
- Para analisis historicos largos, ejecutar en horarios de baja carga

## Documentacion Tecnica

- **MEMORIA_TECNICA.md**: Arquitectura del sistema, descubrimientos, campos clave
- **LECCIONES_APRENDIDAS_2025_09_18.md**: Debugging de BD central, correccion de JOINs
- **REVISION_QUERIES_2025_09_18.md**: Revision y actualizacion de queries
