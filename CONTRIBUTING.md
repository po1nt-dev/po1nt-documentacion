# Guía de Contribución — Po1nt

Gracias por contribuir al ecosistema Po1nt. Esta guía establece las convenciones que seguimos como equipo.

## Flujo de Trabajo

Usamos una sola rama principal: **`main`**, que siempre debe estar en estado deployable. Los despliegues se gestionan con **tags** de versión.

### Ramas

Toda rama debe nacer desde `main` y seguir esta convención de nombres:

| Prefijo | Uso | Ejemplo |
|---------|-----|---------|
| `feature/` | Nueva funcionalidad | `feature/agregar-pago-tigo` |
| `fix/` | Corrección de bug | `fix/calculo-impuestos` |
| `hotfix/` | Corrección urgente en producción | `hotfix/timeout-remesas` |
| `release/` | Preparación de release | `release/v2.1.0` |
| `docs/` | Solo documentación | `docs/actualizar-readme` |
| `refactor/` | Refactorización sin cambio funcional | `refactor/separar-servicios` |
| `chore/` | Mantenimiento, dependencias, CI | `chore/actualizar-paquetes` |

### Ciclo de vida de una rama

1. Crear rama desde `main` con el prefijo adecuado
2. Desarrollar y hacer commits (ver convención abajo)
3. Crear Pull Request hacia `main`
4. Revisión de código por al menos 1 compañero
5. Merge a `main` (squash o merge commit según el caso)
6. Eliminar la rama después del merge

## Commits

Seguimos **Conventional Commits** en español:

```
<tipo>: <descripción corta>

[cuerpo opcional]

[notas al pie opcionales]
```

### Tipos permitidos

| Tipo | Descripción |
|------|-------------|
| `feat` | Nueva funcionalidad |
| `fix` | Corrección de error |
| `docs` | Cambios en documentación |
| `refactor` | Cambio de código sin alterar comportamiento |
| `chore` | Tareas de mantenimiento, dependencias, CI/CD |
| `test` | Agregar o modificar pruebas |
| `style` | Formato, espacios, puntos y comas (sin cambio lógico) |
| `perf` | Mejoras de rendimiento |

### Ejemplos

```
feat: agregar endpoint de consulta de saldo Tigo Money
fix: corregir timeout en llamadas a Cuscatlán
docs: actualizar instrucciones de instalación
refactor: separar lógica de validación en servicio dedicado
chore: actualizar RestSharp a v110
```

### Reglas

- Escribir en español, en imperativo: "agregar", no "agregado" ni "se agrega"
- Primera línea máximo 72 caracteres
- Si el commit necesita más contexto, usar el cuerpo del mensaje
- Referenciar tickets/issues cuando aplique: `fix: corregir cálculo (#42)`

## Pull Requests

### Antes de crear un PR

- [ ] El código compila sin errores
- [ ] Se probó localmente la funcionalidad
- [ ] Los commits siguen la convención
- [ ] La rama está actualizada con `main`

### Al crear el PR

- Usar el template de PR del repositorio
- Título descriptivo en español (máximo 72 caracteres)
- Asignar al menos un revisor

### Revisión de código

- Revisar que el código sea claro y mantenible
- Verificar que no se introduzcan vulnerabilidades de seguridad
- Comentar de forma constructiva y en español
- Aprobar solo cuando se cumplen todos los criterios

## Tags y Releases

Usamos [Semantic Versioning](https://semver.org/lang/es/):

```
v{MAJOR}.{MINOR}.{PATCH}
```

- **MAJOR**: Cambios incompatibles con versiones anteriores
- **MINOR**: Nueva funcionalidad compatible
- **PATCH**: Correcciones de errores compatibles

Ejemplo: `v2.1.0`, `v2.1.1`, `v3.0.0`

## Estilo de Código

### .NET / C#
- Seguir las [convenciones de C#](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/coding-style/coding-conventions)
- PascalCase para clases, métodos y propiedades públicas
- camelCase para variables locales y parámetros
- Usar `using` para objetos disposables
- Capturar excepciones y reportar a Sentry

### Vue / Nuxt (Frontend)
- Seguir la [guía de estilo de Vue](https://vuejs.org/style-guide/)
- Componentes en PascalCase
- Composables con prefijo `use`
- TypeScript estricto

### SQL
- Nombres de stored procedures en PascalCase con prefijo descriptivo
- Usar parámetros, nunca concatenar strings en queries

### General
- No commitear credenciales, tokens ni secrets
- No commitear archivos binarios compilados (.exe, .dll, .pdb)
- Mantener el `.gitignore` actualizado
