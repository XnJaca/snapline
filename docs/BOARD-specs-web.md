---
id: BOARD-specs-web
title: Board — Specs web
type: board
tags:
  - board
  - kanban
  - web
kanban-plugin: board

---

## 📝 Backlog (sin empezar)


## ✏️ Borrador (escribiendo el spec)


## 🔍 Review (listo para revisar)



## ✅ Aprobado (listo para implementar)



## 🛠️ En implementación

- [ ] [[0011-gente-y-cuadrillas/README|SPEC-0011 — Gente, cuadrillas y asignación en el panel]] · el hueco que abre todo lo demás: **no existe forma de dar de alta a una persona** — sin `POST /memberships`, sin invitación y sin registro, los tres usuarios existen porque el seed los insertó por SQL. El acceso es un **código de seis dígitos** que William dicta en persona y el trabajador canjea en la app eligiendo su contraseña; regenerarlo es también el camino de la contraseña olvidada. Conecta `crews`, que está completo en el API desde SPEC-0002 y no lo llama nadie, y **cierra el arco con la asignación a la obra**: sin ella el trabajador entra y sigue sin ver ninguna obra. Cierra la mitad de DEBT-0010 que corresponde a `/crews` y salda la deuda de `crews` construido sin spec · **Revisado por `domain-guardian` y `spec-reviewer`, veredicto APROBADO en la segunda pasada.** El bloqueante que los dos encontraron por separado fue la regla 19 en el canje: el caso cubierto era «sin red el POST nunca sale» y faltaba el que rompe —la petición llega, activa la membresía y la respuesta se pierde—, que le habría dicho «código inválido» a alguien que acababa de elegir su contraseña. Se resuelve degradando a login, porque `sync_operation` vive bajo RLS y el canje es anterior a saber la empresa. El revisor de specs encontró además que la tabla afirmaba `projects.write` donde el código usa `crews.write`, y trajo el caso de temporada: se van en invierno y vuelven en primavera · **API completo** en `feature/SPEC-0011-gente-y-cuadrillas`: migración, canje, seis endpoints de gente y los DTOs que cierran la mitad de DEBT-0010. 106 unitarios y 86 e2e. Un bug que encontró el test: el segundo OWNER se creaba sin ruido porque el índice solo cubre el estado activo. **Panel completo**: las dos pestañas, el alta con su código, la ficha de la cuadrilla con miembros y asignaciones. Destapó un bug preexistente del `DatePipe` que corría un día toda fecha sin hora. **Móvil completo** con el canje en dos pasos —código primero, contraseña después— y las obras por empezar visibles · **`code-reviewer`: LISTO PARA PR** en la segunda pasada, con los siete hallazgos cerrados. Los dos que más pesaban no se veían leyendo: el selector de asignar filtraba por un estado que no existe, y el mensaje del solape **nunca llegó a nombrar la cuadrilla** porque la consulta corría dentro del `catch`, con la transacción ya abortada por la exclusión. Después de la revisión entró la decisión de @jaca de que **el capataz ve solo su cuadrilla**: `crews.read` lo incluye, así que el scope por rol es el control de acceso, y el pull ya lo acotaba mientras el REST no. 106 unitarios y 95 e2e del API, 65 del panel, 438 del móvil. Queda abrir el PR

- [ ] [[0010-obras-en-el-panel/README|SPEC-0010 — Obras en el panel]] · el segundo tramo de la cadena del panel, después de que SPEC-0009 dejara cliente y propiedad cargables. **El API no abre trabajo**: `canTransition`, `PROJECT_INVALID_TRANSITION` y `GET /time-entries?projectId=` ya existen, así que `openapi.json` no cambia y eso es criterio de aceptación. **El alta crea cliente y propiedad en línea**, porque irse a Clientes y volver pierde lo escrito; **no se expone borrar la obra**, se cancela; y **cerrarla es una pantalla, no un campo**: al marcarla terminada se pide la fecha real de fin contra el resumen de lo que llevó —horas aprobadas y por aprobar, jornadas abiertas, días de desvío contra lo previsto—, porque es la única vez que alguien mira la obra entera. Revisado por `domain-guardian` y `spec-reviewer`: el guardián encontró que `DELETE /projects/{id}` no es la misma deuda que 0009 cerró sino **una puerta trasera contra ella** —borrar una obra viva por ahí vuelve borrable a un cliente con historia—; el revisor, que el `goal` no cubría listar ni filtrar y que la sección de copy listaba las claves planas del `.arb` en vez de las anidadas del panel, que es lo que costó tres reescrituras en 0009 · **Tanda 1 de 2**: lista, alta y ficha

- [ ] [[0009-clientes-y-propiedades/README|SPEC-0009 — Clientes y propiedades en el panel]] · el primer módulo que deja **escribir** desde el panel, y el primer eslabón de la cadena: sin cliente y propiedad no hay obra que crear, y sin obra no hay foto que publicar. El API está entero, así que es pantalla contra endpoints probados. Trae un invariante: **un cliente con obras, estimados o facturas no se borra**, con la comprobación en la base y no en el panel, porque hoy `remove()` no mira nada y la clave foránea no lo atrapa — el borrado es suave y la fila sigue existiendo. Revisado por `domain-guardian` y `spec-reviewer`: el guardián encontró que las **propiedades** quedaban vivas y alcanzables al borrar al cliente, y se resolvió con cascada; el revisor, que el `goal` no cubría el borrado y que el criterio prometía un conteo que la 409 no puede dar


## 🎉 Implementado

- [x] [[0008-sesion-y-shell/README|SPEC-0008 — Sesión y shell del panel]] · PR #33 mergeado. Cookie `httpOnly` con su camino propio en el API y `membership.token_version`, que es lo que hace que cerrar sesión invalide algo: el refresh es un JWT sin estado y antes «salir» solo significaba que el navegador borró su copia. El claim ausente cuenta como 0, o el deploy expulsaba a toda sesión viva del móvil. La navegación sale de `membership.permissions[]`, sin replicar la tabla de roles. **El alcance del contenido creció a conciencia**: los ocho ejes leen los endpoints que ya existían, con carga, error y vacío; escribir sigue afuera. Cerró DEBT-0009 con `MatIconRegistry` y abrió DEBT-0010. 53 e2e contra Postgres, 80 unitarios del API y 33 del panel. **Dos correcciones al spec y tres bugs que solo se vieron en el navegador**

- [x] [[0007-cimientos-visuales/README|SPEC-0007 — Cimientos visuales del panel]] · PR #29 mergeado. Angular 22 + Material con los tokens por `theme-overrides`, `packages/tokens` generando SCSS y Dart, los dos temas y los dos idiomas. 10 tests. Cerró DEBT-0001 con los 71 valores idénticos a los que estaban a mano, y trajo ADR-0013. Tres bugs salieron de probar en el navegador, no de los tests: los catálogos en la carpeta equivocada, `light-dark()` resolviendo por `color-scheme` y no por el atributo, y Material tiñendo de naranja los cinco niveles de superficie. **Queda pendiente el único criterio que pide mirar**: los mismos tokens lado a lado en el teléfono y en el navegador

- [x] [[0001-catalogo-de-servicios/README|SPEC-0001 — Catálogo de Servicios]] · ítems con costo, para ver margen. **Retroactivo**
- [x] [[0002-cuadrillas-y-asignacion/README|SPEC-0002 — Cuadrillas y Asignación]] · pertenencia con fechas, sin solapes. **Retroactivo**
- [x] [[0003-estimados-facturas-y-pagos/README|SPEC-0003 — Estimados, Facturas y Pagos]] · reemplazo de QuickBooks. Bloqueado para uso real hasta hablar con el contador. **Retroactivo**
- [x] [[0004-reportes-para-el-contador/README|SPEC-0004 — Reportes para el Contador]] · timesheet con tarifa congelada. **Retroactivo**
- [x] [[0005-publicacion-y-portafolio/README|SPEC-0005 — Publicación y Portafolio]] · publicar con un botón + feed público anónimo. **Retroactivo**
- [x] [[0006-portal-del-cliente/README|SPEC-0006 — Portal del Cliente]] · magic link, default en Etapas. **Retroactivo**


## 🚧 Bloqueado


%% kanban:settings
```
{"kanban-plugin":"board","show-checkboxes":true}
```
%%
