# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

po1nt-documentacion is the central documentation repository for the entire Po1nt POS ecosystem. It contains architecture documentation, business flow diagrams, component documentation, dependency matrices, and Mermaid/Excalidraw diagrams.

## Structure

```
po1nt-documentacion/
├── README.md                    # Overview and reading guide
├── RESUMEN-EJECUTIVO.md         # Executive summary
├── ARQUITECTURA-GENERAL.md      # System architecture
├── FLUJOS-DE-NEGOCIO.md         # Business flow diagrams
├── MATRIZ-DEPENDENCIAS.md       # Component dependencies
├── sincronizaciones/            # How data flows; one file per synced object
│   ├── README.md                # Index and one-page map
│   ├── 01-canales.md            # The three sync channels — start here
│   ├── estado-entrega.md        # What is unmerged and what is uninstalled
│   └── objetos/                 # clientes, empleados, productos, dte, ...
├── componentes/                 # Per-component documentation
│   ├── ms-autn.md
│   ├── ms-configs.md
│   ├── ms-products.md
│   └── ...
└── diagramas/                   # Architectural diagrams
    ├── mermaid/
    └── imgs/
```

## Key Conventions

- Documentation in Spanish
- Mermaid for diagrams (rendered in GitHub)
- Each component has its own file in `componentes/`
- Each synced object has its own file in `sincronizaciones/objetos/`

## `componentes/` vs `sincronizaciones/`

Two axes over the same system — put new content in the right one:

| Question | Where it belongs |
|----------|------------------|
| *What is this service, what stack, where does it run?* | `componentes/` |
| *This piece of data — where does it travel, who applies it, where is it lost?* | `sincronizaciones/` |

`sincronizaciones/` is organised by **object** (clientes, empleados, productos, precios,
promociones, transacciones, DTE, básculas, SKUs), not by component, because a single object
usually crosses several services and that is where the failures hide.

### Rule for `sincronizaciones/`

Everything stated there must be **verified against the code**, citing `archivo:línea` for
concrete findings. Where a repo's README and its code disagree, the code wins and the
contradiction gets recorded. Anything unverified must say so explicitly instead of being
asserted.

This matters because the previous version of `componentes/sincronizadores.md` was written
from assumptions and sent people down the wrong path for months: hardcoded intervals
documented as configurable, a WinForms app described as a Windows Service, and a deprecated
service presented as active.

When a sync component changes, update **both** its file in `componentes/` and the affected
object files in `sincronizaciones/objetos/` — plus `estado-entrega.md` if something is left
merged-but-not-deployed.
