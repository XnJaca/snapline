---
id: DEBT-0002
title: "El login elige la membresía sin criterio de orden"
aliases:
  - "DEBT-0002: El login elige la membresía sin criterio de orden"
type: tech-debt
status: resuelta
severity: alta
origin: "SPEC-0001"
apps:
  - api
  - mobile
trigger: "El primer usuario con membresía activa en dos empresas — o el segundo contratista en la plataforma, lo que pase antes"
created: 2026-08-08
updated: 2026-08-08
tags:
  - tech-debt
  - tech-debt/resuelta
  - auth
---

# DEBT-0002: El login elige la membresía sin criterio de orden

## Contexto

Detectado al escribir [[../specs/mobile/0001-login-movil/README|SPEC-0001]], leyendo
el contrato real de `/auth/login` para especificar la pantalla.

[[../domain/usuario-y-membresia|usuario-y-membresia]] separa `user` de `membership`
justamente porque **una persona puede trabajar para más de un contratista**, y lo
deja escrito como ejemplo borde: *"un `user`, dos `membership`, con roles y tarifas
distintas"*.

El login no contempla ese caso.

## Qué no se hizo

En `apps/api/src/auth/auth.service.ts:13`:

```ts
const [membership] = await this.membershipsForUser(user.id);
if (!membership) throw invalid;
```

Toma la primera fila del resultado. La consulta que la alimenta no tiene `ORDER BY`:

```sql
SELECT id, company_id AS "companyId", role FROM auth_memberships_for_user($1)
```

Sin orden explícito, Postgres no garantiza cuál vuelve primero, y puede cambiar
entre ejecuciones según el plan. Tampoco existe forma de que el cliente pida una
empresa: `LoginDto` solo acepta `identifier` y `password`, y `AuthResult` devuelve
una `membership` singular, no una lista.

**No es un problema de aislamiento entre tenants.** La persona tiene membresía
legítima en las dos empresas; el RLS hace su trabajo. El problema es que entra a
una de las dos sin decidirlo y sin enterarse.

## Workaround actual

Ninguno necesario todavía: William es el único contratista y nadie tiene dos
membresías. El caso no se puede producir con los datos que existen hoy.

## Costo de resolverla

Medio. Toca el contrato, así que arrastra a los tres consumidores:

1. `auth_memberships_for_user()` con orden determinista.
2. Cuando hay más de una membresía, `/auth/login` devuelve la lista de empresas y
   **no** emite tokens todavía; un segundo paso los emite para la empresa elegida.
   Con una sola membresía el flujo actual no cambia, así que el caso común no paga
   nada.
3. Regenerar `openapi.json` y los clientes.
4. En el móvil, una pantalla de selección de empresa entre login y home, más poder
   cambiar de empresa sin cerrar sesión.

## Costo de NO resolverla

El día que exista una persona con dos membresías, **sus registros de tiempo se
atribuyen a la empresa equivocada**. Y por la regla 12 las horas no se borran ni se
sobrescriben: corregir la atribución implica tocar un agregado que es deliberadamente
inmutable y que sirve de defensa legal en una disputa.

El modo de fallo es silencioso. No hay error, no hay pantalla rara: la persona entra
y ve una empresa que no esperaba, y si no mira con atención marca su jornada ahí.

Esa combinación —silencioso, sobre datos inmutables, con valor probatorio— es la
razón de la severidad alta pese a que hoy no se puede reproducir.

## Trigger

**El primer usuario con membresía activa en dos empresas**, o el segundo contratista
en la plataforma, lo que ocurra antes. Un subcontratista que trabaja para dos
generales es exactamente el perfil que lo dispara, y en el gremio es común.

## Propuesta de solución

Login en dos pasos solo cuando hace falta:

```
POST /auth/login
  1 membresía   → 200 con tokens, como hoy
  2 o más       → 200 con { memberships: [...] } y sin tokens

POST /auth/login/company    ← nuevo, solo para el segundo caso
  { identifier, password, companyId } → 200 con tokens
```

Alternativa más simple si se prefiere no partir el flujo: `LoginDto` acepta
`companyId` opcional, y sin él el servidor responde 409 con la lista de empresas
cuando hay ambigüedad. Menos endpoints, pero usa un código de estado para algo que
no es un error del cliente.

Cualquiera de las dos necesita el `ORDER BY`, que es el arreglo de un renglón y
conviene hacer ya aunque el resto espere.

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-08-08 | backlog | Registrada al escribir el SPEC-0001 |

## Resolución — 2026-08-08

Resuelto, pero el diagnóstico original era parcial: **el `ORDER BY m.created_at ASC`
ya existía** dentro de `auth_memberships_for_user()`, tanto en la migración como en
la base. El problema real era otro y más sutil:

1. **Postgres no garantiza que el orden interno de una función que devuelve conjunto
   sobreviva al `SELECT` externo.** Se apoyaba en que la función se inlinee, que es
   comportamiento del planner y no un contrato.
2. **Determinista no es lo mismo que correcto.** Aunque el orden fuera estable,
   "entra a la más antigua" seguía siendo una elección del servidor sobre algo que
   le pertenece a la persona.

Qué se hizo:

- `ORDER BY m.id ASC` **explícito en la query externa**. Ordena por id porque UUIDv7
  lleva el timestamp adentro, así que equivale a orden de creación sin tener que
  cambiar la firma de la función.
- **El login devuelve `memberships[]` con todas las activas**, cada una con
  `companyName`. El token queda scopeado a una —la más antigua, criterio explícito
  y documentado— y el cliente puede ofrecer cambiar de empresa.

Sigue abierto, en otro nivel: **no existe endpoint para cambiar de membresía** sin
volver a loguearse. Cuando aparezca la primera persona con dos contratistas, eso es
un spec.
