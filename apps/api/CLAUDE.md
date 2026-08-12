# CLAUDE.md — api/

Backend de Snapline. NestJS + PostgreSQL + TypeORM. Las reglas duras están en el
`CLAUDE.md` raíz; acá va lo específico de esta carpeta.

## Levantar en desarrollo

```bash
pnpm install
cp .env.example .env
pnpm db:up            # Postgres 18 en el puerto 5544
pnpm migration:run
pnpm seed             # empresa, owner, trabajador, cliente y proyecto de prueba
pnpm dev              # http://localhost:3000/api
```

`pnpm db:reset` borra el volumen y reconstruye desde cero.

## Dos roles de base de datos

| Rol | Uso | RLS |
|---|---|---|
| `snapline_app` (`DB_USERNAME`) | Runtime de la API | **Aplica** |
| `snapline_migrator` (`DB_MIGRATION_USERNAME`) | Migraciones, seeds, CLI | Bypassa |

Nunca correr migraciones con el rol de runtime. Ver ADR-0006.

## Multi-tenancy

`TenantContextInterceptor` abre una transacción por request y setea
`app.company_id` con `SET LOCAL`. Las policies leen ese GUC; sin él no devuelven
filas.

- En contexto de request, usar los repos normales — participan solos.
- **No** abrir transacciones nativas (`dataSource.transaction`, `createQueryRunner`):
  no heredan el GUC. Usar `@Transactional()` de `typeorm-transactional`.
- Fuera de request (crons, listeners, seeds), envolver en `TenantService.runAs()`.
- `runUnscoped()` es grep-able a propósito: la lista debe ser corta y justificable.

**El login es la única excepción**: es anterior al contexto de tenant, así que lee
membresías con `auth_memberships_for_user()`, una función `SECURITY DEFINER`
acotada a resolver la sesión.

## Migraciones

Escritas a mano, no generadas. El esquema necesita cosas que TypeORM no emite:
índices parciales, constraint de exclusión por rango, triggers, RLS.

Reglas:

1. **El set corre limpio desde cero.** No hay baselines ni fake-apply.
2. **Toda tabla nueva con `company_id` nace con `ENABLE` + `FORCE ROW LEVEL SECURITY`
   y su policy en la misma migración que la crea.** Sin roll-out posterior.
3. Objetos no modelados por entities van en migraciones a mano.
4. `pnpm check:drift` verifica que las entities coincidan con las tablas.
   Solo mira columnas: el esquema es deliberadamente más rico que las entities, así
   que `schema:log` siempre reporta FK, CHECK e índices — eso no es drift.

## Entities

- FK: `@ManyToOne` + `@JoinColumn({ name })` + `@RelationId`. **Nunca** un `@Column`
  explícito para el mismo FK.
- **`@RelationId` no se puede usar en un `where`.** Filtrar por la relación:
  `where: { project: { id } }`, no `where: { projectId }`.
- Relaciones obligatorias llevan `{ nullable: false }`, o el drift check falla.
- Tipos de columna siempre explícitos.
- `id` sin default: lo genera el cliente con `newId()` (UUIDv7).
- Dinero en `bigint` con transformer a number, sufijo `_cents`.

## Endpoints

Default deny. Todo handler declara `@RequirePermission('...')` o `@Public()`; sin
decorator responde 403 con el nombre del handler. Los permisos viven en
`src/auth/permissions.ts`.

## Bruno

Colección en `requests/`. Abrirla como colección y elegir el environment `local`.

| Carpeta | Qué tiene |
|---|---|
| `auth/` | Login, refresh y los casos de credenciales |
| `owner/` | Lo que hace William. Auto-login en `folder.bru` |
| `worker/` | Marcaje y captura de fotos |
| `edge-cases/` | **Un request por invariante del dominio** |

`edge-cases/` es el que importa: si alguno empieza a pasar cuando debería fallar,
se rompió una regla dura.

Convención de nombres: `{recurso}.bru` lista, `-create`, `-update`, `-delete`,
`-{caso-borde}`.

## Antes de abrir PR

```bash
pnpm typecheck
pnpm lint
pnpm test
pnpm check:drift      # si tocaste entities o migraciones
```

ESLint corre con flat config en `eslint.config.mjs`: `js.configs.recommended` más
`tseslint.configs.recommended`, sin reglas con tipos. Un nombre que empieza con `_`
queda exento de `no-unused-vars` — es el descarte deliberado de
`const { site: _site, ...rest } = dto`, no un olvido.

Endurecerlo a `recommendedTypeChecked` es una decisión aparte: cuesta una pasada de
arreglos y todavía no se hizo.

## Qué NO hacer

- `synchronize: true` ni `dropSchema: true`, en ningún entorno.
- Aceptar del cliente valores que el servidor debe derivar: `withinGeofence`,
  `distanceM`, totales de factura.
- Borrar `time_entry`. Hay un trigger que lo bloquea.
