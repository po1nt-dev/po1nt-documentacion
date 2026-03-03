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
