---
id: ADR-0006
title: "TypeORM con RLS de Postgres desde la primera migración"
aliases:
  - "ADR-0006: TypeORM con RLS de Postgres desde la primera migración"
type: adr
status: aceptado
supersedes: null
superseded_by: null
related_specs: []
created: 2026-08-08
updated: 2026-08-08
deciders:
  - jaca
tags:
  - adr
  - adr/aceptado
---

# ADR-0006: TypeORM con RLS de Postgres desde la primera migración

## Contexto

La regla 6 exige `company_id` en toda tabla y el scope en el repositorio. La
pregunta es **dónde vive la garantía**: si solo vive en el código de aplicación,
un `findOne({ id })` olvidado filtra datos entre contratistas competidores. Es el
fallo más caro que puede tener este producto.

Hay un precedente directo: ACDEMIC arrancó con el aislamiento solo en la capa de
aplicación y terminó necesitando un roll-out de **Row-Level Security a 34 tablas**,
con plan de migración por tabla, auditoría de todo lo que las tocaba, y dos gates
de CI para que no se filtrara nada nuevo. Ese trabajo fue caro y es evitable
haciéndolo desde el principio.

## Decisión

**TypeORM 0.3 + `typeorm-transactional`**, mismo stack que ACDEMIC, con Postgres
como backstop estructural:

**Toda tabla con `company_id` nace con `ENABLE` + `FORCE ROW LEVEL SECURITY` y su
policy en la misma migración que la crea.** Sin excepción y sin roll-out posterior.

Dos roles de base de datos separados:

| Rol | Uso | RLS |
|---|---|---|
| `snapline_app` | Runtime de la API | **Aplica** — no es superuser ni owner |
| `snapline_migrator` | Migraciones, seeds, CLI | Bypassa — necesita DDL |

El contexto de tenant se propaga con `SET LOCAL app.company_id` dentro de la
transacción del request. Si el GUC no está seteado, la policy no devuelve filas:
**falla cerrado**, no abierto.

## Alternativas consideradas

### Alternativa A — Prisma

Mejor DX y migraciones más simples de leer.

**Por qué no:** este esquema necesita constraints que Prisma no modela y hay que
escribir como SQL crudo igual — trigger de photo release, índices parciales,
constraint de exclusión para rangos de fechas de cuadrilla, función de numeración
con lock de fila, y las policies de RLS. Si la mitad del esquema es SQL a mano, el
ORM aporta menos. Y salir del stack que ya se conoce cuesta tiempo que no hay.

### Alternativa B — Solo scope en la aplicación, sin RLS

Es lo que hace la mayoría, y es más rápido de arrancar.

**Por qué no:** existe la evidencia de ACDEMIC de que no alcanza. Un `TenantScopedRepository`
protege lo que pasa por él; no protege el `queryRunner` de un scheduler, el JOIN
de un `relations: []`, ni al programador con prisa. RLS cuesta una migración hoy y
34 después.

## Consecuencias

### Positivas

- El aislamiento entre empresas es estructural: aunque el código falle, la base no
  devuelve la fila.
- Cero deuda de roll-out. La tabla 40 nace protegida igual que la 1.
- Mismo stack que ACDEMIC: las convenciones, los errores ya cometidos y el criterio
  de migraciones se reutilizan.

### Negativas / Costos

- Dos roles de base de datos que administrar en cada entorno.
- No se pueden abrir transacciones nativas (`dataSource.transaction`,
  `createQueryRunner`) en contexto de request: no heredan el GUC y fallan cerrado.
  Se usa `runInTransaction()` de `typeorm-transactional`.
- Todo lo que corra fuera de un request (cron, listeners, seeds) necesita un bypass
  explícito y auditable.

### Riesgos

- **Olvidar la policy en una tabla nueva.** Mitigación: es parte de la definición
  de "migración terminada" y el `code-reviewer` lo verifica en el pase B.
- **Correr migraciones con el rol de runtime.** Fallan por falta de permisos, que
  es el modo correcto de fallar.

## Impacto en el modelo

Todos los agregados. Ver [[../../domain/README|reglas transversales]].

## Referencias

- Precedente: `acdemic/docs/adr/0016-tenant-scoped-repository/rollout-plan.md`
- Convenciones heredadas: `acdemic/apps/api/CLAUDE.md`
