# Po1nt Documentación

Repositorio central de documentación para el ecosistema Po1nt POS. Contiene documentación de arquitectura, diagramas de flujos de negocio, documentación de componentes y matrices de dependencias.

## Contenido

| Documento | Descripción |
|-----------|-------------|
| `RESUMEN-EJECUTIVO.md` | Resumen ejecutivo del sistema |
| `ARQUITECTURA-GENERAL.md` | Arquitectura del sistema, stack tecnológico |
| `FLUJOS-DE-NEGOCIO.md` | Diagramas de flujos (auth, sync, ventas, remesas) |
| `MATRIZ-DEPENDENCIAS.md` | Dependencias entre componentes |
| `sincronizaciones/` | **Cómo fluye la información entre ERP, central, salas y cajas, objeto por objeto** |
| `componentes/ci-cd.md` | Pipeline CI/CD con GitHub Actions y ghcr.io |
| `componentes/gestion-secrets.md` | Gestión centralizada de secrets con Infisical |

### Sincronizaciones (`sincronizaciones/`)

Sección dedicada al flujo de datos. Responde "este dato, ¿por dónde viaja, quién lo aplica
y dónde se pierde?" — que es la pregunta de cada incidente. Incluye un documento por
objeto sincronizado (productos, precios, **clientes**, **empleados**, transacciones, DTE…)
y el estado de entrega de los cambios pendientes de mergear e instalar.

Todo lo que se afirma ahí está verificado contra el código, citando `archivo:línea`.

### Documentación por Componente (`componentes/`)

Documentación detallada de cada microservicio, aplicación y servicio del ecosistema.

### Diagramas (`diagramas/`)

Diagramas de arquitectura en formato Mermaid e imágenes PNG.

## Cómo Contribuir

1. Editar los archivos Markdown correspondientes
2. Los diagramas usar formato Mermaid (se renderizan en GitHub)
3. Mantener actualizada la documentación cuando se hagan cambios en los componentes

## Contribuir

Ver [CONTRIBUTING.md](CONTRIBUTING.md) para las guías de contribución.

## Licencia

Propiedad de Po1nt — Uso interno únicamente.
