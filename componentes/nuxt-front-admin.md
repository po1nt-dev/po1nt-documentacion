# nuxt-front-admin - Portal Administrativo Web

## Proposito y Responsabilidades

Aplicacion web administrativa SPA para gestion centralizada:
- Gestion de productos, categorias, marcas
- Administracion de usuarios y roles
- Configuracion de parametros del sistema
- Gestion de bancos y metodos de pago
- Configuracion de promociones
- Reportes y transacciones

## Diagrama de Arquitectura Interna

```mermaid
flowchart TB
    subgraph "Pages (146)"
        A[/login]
        B[/config/*]
        C[/product/*]
        D[/user/*]
        E[/bank/*]
    end

    subgraph "Services"
        F[GenericCrud]
        G[ms-auth]
        H[ms-config]
        I[ms-product]
    end

    subgraph "Store (Pinia)"
        J[sessionStore]
        K[fullLoader]
    end

    subgraph "Utils"
        L[HttpClient]
        M[Sentry]
    end

    subgraph "Backend APIs"
        N[MS-Autn]
        O[MS-configs]
        P[MS-Products]
    end

    A --> G --> L --> N
    B --> H --> L --> O
    C --> I --> L --> P
    A --> J
```

## Estructura de Carpetas

```
nuxt-front-admin/
├── pages/                  # 146 paginas
│   ├── login.vue
│   ├── index.vue
│   ├── config/            # 56 paginas
│   ├── product/
│   ├── user/
│   ├── bank/
│   └── ...
├── components/
│   ├── forms/
│   └── shared/
├── layouts/
│   ├── default.vue
│   └── blank.vue
├── services/
│   ├── GenericCrud.ts
│   ├── ms-auth/
│   ├── ms-config/
│   └── ms-product/
├── store/
│   ├── session.ts
│   └── fullLoader.ts
├── utils/
│   ├── HttpClient.ts
│   └── Sentry.ts
├── interfaces/
├── middleware/
│   └── auth.ts
├── configs/
│   └── menuItems.ts
├── app.vue
├── nuxt.config.ts
└── package.json
```

## Tecnologias y Dependencias

| Dependencia | Version | Proposito |
|-------------|---------|-----------|
| Nuxt | 3.6.5 | Framework SSR/SPA |
| Vue | 3.x | UI Framework |
| Quasar | 2.12.4 | UI Components |
| Pinia | 2.1.6 | State Management |
| TypeScript | - | Tipado estatico |
| Vuelidate | 2.0.3 | Validacion forms |
| Leaflet | 1.0.12 | Mapas |
| Monaco Editor | 0.40.0 | Editor de codigo |

## Microservicios Consumidos

| Servicio | Variable Entorno | Proposito |
|----------|------------------|-----------|
| MS-Autn | MS_AUTH | Autenticacion, usuarios |
| MS-configs | MS_CONFIG | Configuraciones |
| MS-Products | MS_PRODUCT | Productos |
| ms-procesos-locales | MS_LOCALES | Transacciones |

## Modulos Principales

| Modulo | Ruta | Paginas | Descripcion |
|--------|------|---------|-------------|
| Config | /config/* | 56 | Configuracion sistema |
| Product | /product/* | 6 | Catalogo productos |
| User | /user/* | - | Gestion usuarios |
| Bank | /bank/* | 2 | Bancos y BINs |
| Rol | /rol/* | - | Roles y permisos |

## Variables de Entorno

| Variable | Tipo | Descripcion |
|----------|------|-------------|
| MS_AUTH | URL | URL microservicio auth |
| MS_CONFIG | URL | URL microservicio config |
| MS_PRODUCT | URL | URL microservicio productos |
| MS_LOCALES | URL | URL microservicio locales |
| NODE_ENV | string | Entorno (development/production) |
| CAPTURE_ERRORS | string | DSN Sentry |

## Autenticacion

1. Usuario ingresa credenciales en `/login`
2. POST a MS_AUTH `/Auth`
3. Token JWT almacenado en cookie
4. Middleware `auth.ts` valida token en cada navegacion
5. Header `Authorization: Bearer {token}` en cada request

## Como Ejecutar

```bash
# Instalar dependencias
npm install

# Desarrollo
npm run dev
# http://localhost:3000

# Produccion
npm run build
npm run preview
```

---
