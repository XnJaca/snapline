---
id: SPEC-0009
title: "Clientes y propiedades en el panel"
aliases:
  - "SPEC-0009: Clientes y propiedades en el panel"
type: spec
platform: web
status: review
goal: "Desde el panel se da de alta un cliente con su primera propiedad en un solo paso y se corrige lo que llegó mal; un cliente sin historia se borra y arrastra sus propiedades, uno con obras o documentos enviados no se borra ni por el endpoint ni por la base, y quien solo tiene `customers.read` no encuentra ningún control que escriba."
apps:
  - api
  - web
depends_on:
  - "0008-sesion-y-shell"
domain:
  - cliente
frente: administrativo
created: 2026-09-01
updated: 2026-09-01
tags:
  - spec
  - spec/review
  - web
---

# SPEC-0009: Clientes y propiedades en el panel

> **Meta**
> - Apps afectadas: `api`, `web`
> - Depende de: [[../0008-sesion-y-shell/README|SPEC-0008]]
> - Frente: `administrativo`

---

## Problema

El panel muestra clientes y no deja tocarlos. Hoy la única forma de dar de alta un
cliente es el teléfono ([[../../mobile/0006-clientes-en-el-movil/README|SPEC-0006
móvil]]), que es exactamente la fricción que el panel viene a sacar: **William
administra desde la oficina**, y cargar una dirección completa con el pulgar es lo
que hace que la gente no cargue nada.

Y es el primer eslabón de la cadena. Un proyecto necesita un cliente y una
propiedad, así que hasta que esto exista no hay obra que crear desde la web, y sin
obra no hay fotos que publicar. El panel entero cuelga de acá.

**El API ya está casi entero**: `POST`, `PATCH` y `DELETE` de cliente, más `POST` y
`PATCH` de propiedad. Lo único que abre trabajo de API es el borrado, que hoy no
comprueba nada — abajo.

## Alcance

### Entra

- **Lista de clientes** con búsqueda por nombre, correo o teléfono, y su estado
  vacío.
- **Ficha del cliente**: sus datos, sus propiedades y sus proyectos.
- **Alta de cliente con su primera propiedad en un solo paso.** El contrato lo
  soporta —`CreateCustomerDto` acepta un `site` embebido— y separarlo en dos
  pantallas obliga a cargar una dirección después, que es cuando se deja a medias.
- **Corregir** cliente y propiedad. El dato de un cliente llega mal la primera vez
  más seguido de lo que parece.
- **Agregar propiedades** a un cliente que ya existe: el mismo cliente puede tener
  tres trabajos en tres casas.
- **La escritura cuelga de `customers.write`**, que es OWNER y ADMIN. El
  `ACCOUNTANT` tiene `customers.read` y ve la lista: no puede encontrar un botón
  que lo lleve a un 403.
- **Borrar un cliente, con la comprobación en la base.** Es lo único de API que
  entra, y está detallado abajo.

### No entra

- **Invitar al cliente al portal.** Es [[../0006-portal-del-cliente/README|SPEC-0006
  web]] y su propio camino de acceso; acá solo se cargan los datos que ese camino
  después necesita.
- **Crear proyectos desde la ficha.** Llega con SPEC-0010, que es el módulo
  siguiente. Acá los proyectos del cliente se listan y se enlazan, nada más.
- **Importar clientes de QuickBooks o de un CSV.** No hay pedido real todavía.
- **Ubicar la propiedad en el mapa.** El móvil lo resuelve con
  [[../../mobile/0007-ubicacion-de-la-propiedad-en-el-mapa/README|SPEC-0007 móvil]] y el punto
  se fija donde se está parado, que es más preciso que arrastrar un pin en una
  oficina. Acá la dirección se escribe y el punto queda como está.

## Modelo de dominio afectado

- [[../../../domain/cliente|cliente]]

No introduce agregados ni campos. **Sí introduce un invariante**, detallado abajo. La forma de `address` —`line1`, `line2`, `city`,
`state`, `postal_code`, `country`— es la misma para la dirección de facturación del
cliente y para la de la propiedad: **un solo tipo, un solo formulario**, y ya está
declarada como `AddressDto` en el API.

### No se borra un cliente que tiene historia

`remove()` marca `deleted_at` y no mira nada más, así que hoy borrar un cliente deja
sus obras y sus documentos apuntando a una fila borrada. **La clave foránea no lo
atrapa**: el borrado es suave y la fila sigue existiendo.

**Qué retiene y qué no:**

| Retiene | No retiene |
|---|---|
| Una obra no borrada, **en cualquier estado** | Un estimado en `DRAFT` |
| Un estimado en `SENT`, `VIEWED`, `ACCEPTED`, `DECLINED` o `EXPIRED` | Una factura en `DRAFT` |
| Una factura en `SENT`, `PARTIAL`, `PAID`, `OVERDUE` o `VOID` | |

La línea la marca **lo enviado**, no lo que existe. La regla 16 protege el documento
que salió: una factura enviada no se edita, se anula. Un `DRAFT` es editable y
borrable como cualquier fila, así que el dominio ya dice que no es historia. Una
anulada sí retiene: `VOID` no toca `deleted_at`, y anular es parte del registro.

**Una obra terminada retiene igual que una en curso.** `COMPLETED` y `CANCELLED`
conservan `deleted_at IS NULL`, así que un cliente con una obra hecha no se puede
borrar nunca. Es a propósito: cancelado no es lo mismo que borrado, y las horas
trabajadas siguen siendo horas pagables.

**`lead` y `testimonial` no retienen**, aunque tengan `customer_id`. Son agregados
propios, de marketing y prueba social, y ninguna de sus fichas declara que dependan
de que el cliente exista. Es decisión consciente, no olvido.

### Las propiedades se van con el cliente

`site` no es una relación externa: la ficha define al cliente **junto con las
propiedades donde se trabaja**, así que se borran con él, en cascada y suave.

Es seguro por construcción: **lo único que apunta a `site` es `project.site_id`**, y
un cliente con cualquier obra viva no llega a borrarse. La cascada solo alcanza
propiedades que ninguna obra usa.

Y no toca el portafolio: `published_project` guarda `city` y `service_type` como
columnas propias, copiadas al publicar. Una obra publicada sobrevive aunque el
cliente y su propiedad desaparezcan.

**Va en la base, no en el servicio.** Un `BEFORE UPDATE` sobre `customer` que salte
cuando `deleted_at` pasa de nulo a no nulo, y un `AFTER UPDATE` que cascadee el
borrado de sus `site`. Es la forma que ya usan `time_entry_no_hard_delete` y
`enforce_publish_release` en la migración `IndexesAndInvariants`. Un chequeo solo en
el servicio deja el invariante a merced del próximo camino que borre.

El servicio igual comprueba antes y tira `CUSTOMER_HAS_HISTORY`, para que el caso
común llegue con su mensaje sin depender de matchear el texto del trigger; y el
trigger se mapea en `http-exception.filter.ts` **al mismo código** (regla 8).

**A diferencia de `time_entry_no_hard_delete`, este trigger no hay que desactivarlo
en la limpieza de los tests**: el cleanup borra con `DELETE` y un `BEFORE UPDATE` no
se dispara con eso.

### Un arrastre que este spec corrige

`GET /customers/{id}/sites` filtra por el `deleted_at` de la propiedad y **nunca
comprueba que el cliente siga vivo**. Hoy, con `DELETE /customers/{id}` ya expuesto,
eso devuelve la dirección de la casa de un cliente borrado indefinidamente mientras
`GET /customers/{id}` responde 404. Se arregla acá.

> Revisado por `domain-guardian` el 2026-09-01. Su hallazgo fue justamente `site`:
> el spec definía el invariante sobre obras y documentos y no decía nada de las
> propiedades, que es lo que hacía falta cerrar antes de escribir la migración.

## Contrato de API

```http
DELETE /customers/{id}

204 No Content
409 { "code": "CUSTOMER_HAS_HISTORY",
      "message": "Este cliente tiene obras o documentos y no se puede borrar" }
```

`CUSTOMER_HAS_HISTORY` entra a `ERROR_CODES`. El cliente necesita distinguirlo de
otros 409 porque la salida es distinta: no es reintentar, es ir a cerrar las obras
primero.

**El error no promete un conteo.** La respuesta dice que hay historia, no cuánta:
inventar "tiene 3 obras" obligaría a un campo que el envelope no tiene, y sería
mentira cuando lo que retiene es una factura sin obra asociada. El panel distingue
**obras** de **documentos** porque la ficha ya tiene cargadas las obras del cliente;
si no hay ninguna, dice que lo retienen documentos.

**Las obras del cliente salen de filtrar `GET /projects` en el navegador.** No hay
`GET /customers/{id}/projects` ni query param, y el `customerId` viaja en cada
proyecto. Es lo que ya hace la pantalla de Horas para resolver nombres. **El trigger
para bajarlo al servidor es la primera empresa con más obras de las que entran en
una pantalla**; anotarlo acá evita que se descubra con datos reales.

## Comportamiento sin señal

No aplica: `platform: web`. El panel es de oficina.

Lo que sí se define es que **un formulario enviado sin red no pierde lo escrito**:
el error es de conexión, con el botón para reintentar, y los campos quedan como
estaban. Cargar una dirección completa dos veces es la forma más rápida de que
alguien deje de usar el panel.

Reusa lo que SPEC-0008 ya construyó: `toApiFailure` distingue "no hubo respuesta" de
"hubo respuesta con error" mirando `status === 0`, y el interceptor ya refresca y
reintenta. Esto no arma su propia detección.

## UI

```
┌─ Clientes ──────────────────────── [buscar…] [+ Nuevo cliente] ┐
├────────────────────────────────────────────────────────────────┤
│ Martinez Residence      +1 555 987 6543   Referido   2 obras   │
│ Nguyen Residence        +1 555 331 2244   Web        1 obra    │
│ Whitaker Home           +1 555 447 8890   Recurrente 2 obras   │
└────────────────────────────────────────────────────────────────┘

┌─ Martinez Residence ─────────────────────────── [Corregir] ────┐
│  Contacto        martinez@example.com · +1 555 987 6543        │
│  Origen          Referido                                      │
│                                                                │
│  Propiedades                              [+ Agregar]          │
│   100 Main St, Baltimore MD 21201          · geocerca 150 m    │
│   9800 Georgia Ave, Silver Spring MD 20902 · sin punto         │
│                                                                │
│  Obras                                                         │
│   Techo Martinez     En progreso                               │
│   Baño Martinez      En progreso                               │
│                                                                │
│                                          [Borrar cliente]      │
└────────────────────────────────────────────────────────────────┘
```

**Borrar vive en la ficha y no en la lista**, al pie y separado del resto: es la
única acción destructiva de la pantalla y no se pone al lado de las que no lo son.
Pide confirmación **nombrando al cliente**, y cuando el API lo rechaza el mensaje
dice qué lo retiene, no un texto genérico.

**Lo obligatorio se dice con palabras en el label, no con un asterisco.** Es el
criterio que SPEC-0006 móvil fijó y que ahí funcionó.

## Criterios de aceptación

- [ ] Crear un cliente con su primera propiedad en un solo envío deja las dos
      cosas creadas, y la propiedad queda colgada de ese cliente.
- [ ] Un cliente sin correo y sin teléfono se puede crear: los dos son opcionales
      en el dominio. Lo que no se puede es invitarlo al portal, y eso se dice
      donde se intente, no en el alta.
- [ ] La dirección se captura completa —calle, ciudad, estado, código postal y
      país— y el país sale de una lista, no se teclea.
- [ ] Corregir un cliente aplica el cambio encima y no crea una segunda fila.
- [ ] Un `ACCOUNTANT` ve la lista y la ficha, y **no encuentra ningún control de
      escritura**: ni "Nuevo cliente", ni "Corregir", ni "Agregar propiedad".
- [ ] Un formulario que falla por red conserva lo escrito y ofrece reintentar, y
      no se confunde con un error de validación.
- [ ] La búsqueda filtra por nombre, correo y teléfono, y su estado vacío se
      distingue del estado vacío de "todavía no hay clientes".
- [ ] **Cero cadenas quemadas** (regla 24), en `en` y en `es`, con la misma voz de
      usted que el resto del producto.
- [ ] El teléfono se guarda normalizado a E.164 con el mismo mecanismo que el móvil:
      el país se elige y el número se normaliza **en el cliente**, porque
      `CreateCustomerDto` no valida formato. Es la mitad de
      [[../../../tech-debt/0003-telefono-sin-normalizar|DEBT-0003]] que sigue
      abierta, y este spec no la cierra.
- [ ] Tests del panel para el alta con propiedad embebida, para el filtrado por
      permiso y para el fallo de red que conserva el formulario.
- [ ] Borrar un cliente sin obras ni documentos responde 204, lo saca de la lista y
      **sus propiedades quedan borradas con él**.
- [ ] Borrar un cliente con una obra **terminada** responde 409
      `CUSTOMER_HAS_HISTORY`, igual que con una en curso.
- [ ] **Un estimado en `DRAFT` no retiene**: el cliente que solo tiene eso se borra.
      Uno en `SENT` sí retiene, y una factura `VOID` también.
- [ ] El panel distingue si lo retienen **obras** o **documentos**, y no muestra un
      conteo que no tenga de dónde salir.
- [ ] Borrar pide confirmación nombrando al cliente.
- [ ] **El trigger lo impide aunque la comprobación del servicio no esté.** Se
      verifica con un `UPDATE` directo contra la base, no por el endpoint.
- [ ] **La cascada también vive en la base**: un `UPDATE` directo que borre al
      cliente deja sus propiedades borradas, sin pasar por el servicio.
- [ ] `GET /customers/{id}/sites` deja de devolver propiedades de un cliente
      borrado.
- [ ] Una obra ya publicada sigue en el portafolio después de borrar a su cliente:
      `published_project` copió la ciudad y el tipo de servicio.
- [ ] Corregir un cliente que otra persona acaba de borrar dice que ya no existe y
      vuelve a la lista, en vez de un 404 crudo.
- [ ] `openapi.json` regenerado con el código de error nuevo (regla 8).

## Riesgos / consideraciones

- **El teléfono sin normalizar es [[../../../tech-debt/0003-telefono-sin-normalizar|DEBT-0003]].**
  El móvil normaliza al leer y al escribir desde SPEC-0006; el panel tiene que hacer
  lo mismo o la misma persona entra dos veces con dos formatos.
- **El radio de geocerca por default es una constante**
  ([[../../../tech-debt/0004-radio-de-geocerca-hardcodeado|DEBT-0004]]). Acá se
  muestra y se puede corregir, pero el default sigue viniendo del código.
- **El invariante del borrado se agrega sobre datos que ya existen.** La migración
  tiene que correr sobre una base donde puede haber clientes borrados con obras
  vivas. El trigger es `BEFORE UPDATE` y solo mira borrados nuevos, así que no toca
  lo que ya está; si hay filas inconsistentes de antes, siguen ahí y se ven, que es
  mejor que arreglarlas a ciegas en una migración.

## ADRs relacionados

- [[../../../adr/0007-openapi-como-contrato/README|ADR-0007]] — `AddressDto` declarado, no `jsonb` suelto
- [[../../../adr/0011-envelope-de-errores/README|ADR-0011]] — los errores que el formulario traduce

---

## Historial

| Fecha | Estado | Nota |
|-------|--------|------|
| 2026-09-01 | borrador | Revisado por `domain-guardian` y `spec-reviewer`. El guardián encontró lo que faltaba: el invariante hablaba de obras y documentos y no decía nada de las **propiedades**, que quedaban vivas y alcanzables por `GET /customers/{id}/sites` después de borrar al cliente. Se resuelve con cascada, que es como la ficha ya modela el agregado. El revisor de specs encontró cuatro huecos: el `goal` no cubría el borrado —lo único que abre trabajo de API—, la maqueta no tenía control de borrar, el criterio prometía un conteo que la 409 no puede dar, y el spec afirmaba el invariante y a la vez lo dejaba abierto. Se decide además que **solo retiene lo enviado**: un `DRAFT` es editable y borrable, así que no es historia |
| 2026-09-01 | borrador | Se decide que el borrado lleve su comprobación **en la base** y no en el panel: es la única de las tres opciones que sostiene el invariante para cualquier consumidor. Eso mete `api` en el alcance |
| 2026-09-01 | borrador | Creado. Primer módulo de la secuencia del panel —clientes, proyectos, fotos, publicar— que sale de que el panel muestre ocho ejes de solo lectura y no deje crear nada |
