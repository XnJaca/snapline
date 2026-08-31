---
id: CHANGELOG
title: "Changelog — bitácora humana"
type: changelog
tags:
  - changelog
---

# Changelog

Bitácora por **fecha**: qué se decidió y por qué. Para "qué se deployó en cada
versión", ver `RELEASES.md` cuando exista.

Se agrega con `/changelog <descripción>`.

---

## 2026-08-31 — el panel existe, y los tokens dejan de copiarse a mano

- **`apps/web` arranca** ([[specs/web/0007-cimientos-visuales/README|SPEC-0007]]):
  Angular 22 con Material y el CDK, los dos temas, los dos idiomas por Transloco. Es
  la fase 1 del roadmap, que es lo que se le factura a William, y hasta hoy el API
  tenía 78 operaciones y ningún consumidor web.
- **Los tokens se generan, no se copian**
  ([[tech-debt/0001-tokens-a-dart-a-mano|DEBT-0001]] resuelta): `packages/tokens`
  emite el SCSS de web y el `tokens.dart` de Flutter desde `design-tokens.json`. El
  Dart generado salió con **los 71 valores idénticos** a los que estaban escritos a
  mano, que era la condición para reemplazarlo sin cambiarle la app a nadie.
- **El JSON no era la fuente única que decía ser.** El área de toque de 64dp, las dos
  familias tipográficas y el peso de marca vivían solo en el Dart — valores de diseño
  definidos en una superficie, que es lo que la regla 22 prohíbe. Se movieron al JSON
  con los comentarios que explican por qué valen lo que valen, y esos comentarios
  ahora salen como docblock del archivo generado.
- **Angular Material, decidido con el mecanismo y no solo con la preferencia**
  ([[adr/0013-componentes-angular-material/README|ADR-0013]], que cierra el §4 de
  ADR-0009): los colores entran por `mat.theme-overrides()` con los hex del JSON y su
  paleta queda como andamiaje. Es el espejo en web de haber prohibido `fromSeed` en
  Flutter. PrimeNG se descartó por traer su propio sistema de tokens, que es
  exactamente la capa extra que ADR-0009 señaló como el problema.
- **Tres bugs que los tests no vieron y el navegador sí.** Los catálogos de traducción
  daban 404 por estar en `src/assets` en vez de `public/`; forzar el tema claro dejaba
  las tarjetas oscuras porque `light-dark()` resuelve por `color-scheme` y no por
  nuestro atributo; y Material teñía de naranja los cinco niveles de superficie porque
  no estaban mapeados, contra los neutros de gris puro que ADR-0009 eligió a propósito.
- **El lint verifica la regla 21, que antes solo prometía verificar.** La regla
  configurada era `prefer-standalone`, que no tiene nada que ver con template inline.
  Ahora es `component-max-inline-declarations` en cero, comprobado con un componente
  de prueba.
- **Dos cosas que quedaron anotadas y no resueltas**: el panel no tiene sistema de
  iconos —`mat-icon` necesita una fuente que no se puede traer de un CDN y el paquete
  pesa 13 MB para usar tres
  ([[tech-debt/0009-el-panel-no-tiene-iconos|DEBT-0009]])— y las tipografías están
  duplicadas, porque Angular no lee assets fuera de su raíz y Flutter no los lee fuera
  de su paquete.
- **SPEC-0008 queda escrito y aprobado**, con la sesión en cookie `httpOnly`
  ([[adr/0014-sesion-web-en-cookie/README|ADR-0014]]). Su revisión de dominio encontró
  que `token_version`, tal como estaba descrito, habría expulsado a **toda sesión viva
  del móvil** el día del deploy: los tokens ya emitidos no llevan el claim, y comparar
  con igualdad estricta los rechazaba a todos.

---

## 2026-08-12 — el photo release sale, el EXIF se queda

- **Publicar una obra ya no pide permiso al cliente**
  ([[tech-debt/0005-photo-release-se-quita|DEBT-0005]], y la entrada del 2026-08-12
  en [[DECISIONES]]): el contratista está autorizado a fotografiar la obra en la
  que trabaja y no hay dónde subir un papel firmado, así que el campo que en la
  práctica bloqueaba a todos se fue entero — columnas, dos triggers, endpoint,
  código de error y la ficha del móvil.
- **No eran cuatro lugares, eran once.** El `domain-guardian` los encontró antes de
  escribir la migración: la deuda no listaba el segundo trigger, la FK al documento,
  el endpoint, el código `PHOTO_RELEASE_REQUIRED` con su test, dos requests de
  Bruno, tres fichas de dominio ni los dos specs Implementados que lo afirmaban.
- **`PUBLIC` no se quedó sin invariante en la base.** Sacando el trigger tal cual,
  publicar pasaba a depender de que ningún endpoint futuro se saltee una validación
  de aplicación. En su lugar entra `enforce_exif_stripped`: una foto no llega a
  `PUBLIC` con el EXIF adentro, que es la fuga concreta —las coordenadas de la casa
  del cliente— y ya estaba declarada como invariante sin estar aplicada. La regla 17
  se reescribió con eso y conservó su número.
- **Dos cosas que este cambio destapó y no causó**: la escalera
  `INTERNAL → CLIENT → PUBLIC` no está aplicada en ningún lado —hoy se salta a
  `PUBLIC` directo— y *"revocar el release despublica en cascada"* nunca se
  implementó. Lo segundo se resuelve solo al no haber gate; lo primero queda anotado.
- **El edge case del EXIF estaba mintiendo.** Aseguraba un rechazo 400 que no
  ocurre: subir a `PUBLIC` limpia sola en vez de rechazar, a propósito. Ahora
  verifica lo que de verdad importa — que no existe camino a `PUBLIC` con EXIF
  adentro.
- **El diagrama del flujo del sistema quedó legible fuera de Obsidian.** Su JSON
  estaba en `compressed-json`, contra la convención que pide `compress: false`
  justamente para poder editarlo — la caja que decía *"Aceptar estimado + photo
  release"* no se podía corregir sin abrir el plugin.
- **El API tiene lint, por primera vez.** El script `eslint "src/**/*.ts"` venía del
  scaffold de Nest y nunca tuvo ni config ni dependencia: fallaba con
  `command not found`, así que la regla 25 —*typecheck y lint verdes antes del PR*—
  se venía cumpliendo a medias sin que nadie lo notara. Flat config con
  `tseslint.configs.recommended`, 15 hallazgos, todos arreglados.
- **Dos cosas que el lint destapó y no eran ruido.** El fixture de
  `document-lines.spec.ts` aceptaba overrides y los descartaba —un test de impuestos
  creía estar probando un item gravable—; y `voidInvoice` recibe un `reason`
  obligatorio que **no guarda en ningún lado**, porque no hay columna donde
  ([[tech-debt/0006-razon-de-anulacion-se-descarta|DEBT-0006]]). Pedir un motivo y
  tirarlo es peor que no pedirlo: quien lo escribe cree que quedó registrado.

---

## 2026-08-11 — la propiedad en el mapa

- **Toda propiedad puede tener su punto y su radio de geocerca**
  ([[specs/mobile/0007-ubicacion-de-la-propiedad-en-el-mapa/README|SPEC-0007]]):
  tocando el mapa, arrastrando el marcador o con la ubicación de quien está parado
  en la obra. Nunca tecleando coordenadas. Con esto `evaluateGeofence` deja de
  comparar contra nulo — la geocerca del marcaje ya tiene contra qué evaluar.
- **Google Maps, decidido con datos que invalidaron el análisis previo**
  ([[adr/0012-proveedor-de-mapas/README|ADR-0012]]): los SDK móviles son gratis y
  sin límite desde marzo de 2025, y los tiles públicos de OSM no son una opción
  comercial — su política permite retirar el acceso sin aviso y `flutter_map` es
  su mayor consumidor. Geocoding queda afuera porque no hace falta, no por costo.
- **El identificador de la app es `com.snapline.app`**, elegido a propósito en la
  última ventana barata: una vez publicada, el bundle no se cambia — se publica
  otra app. Reemplaza el default de Flutter que nadie había decidido.
- **Dos bugs de sincronización que ningún test veía**, encontrados probando en un
  iPhone real. El sincronizador escribía con `customStatement`, que no notifica
  streams: la fila quedaba bien en la base y la pantalla mostraba lo viejo — un
  borrado del servidor ni siquiera sacaba la fila de la lista. Y el disparo del
  sync moría pausado: **Riverpod 3 pausa los providers cuyos widgets quedan
  tapados por una ruta opaca**, y se guarda justo desde pantallas que tapan al
  shell; además, al invalidarse un provider sus recursos se cancelan aunque el
  rebuild quede diferido. La suscripción vive ahora en un provider sin
  dependencias, que nada invalida ni pausa. Cada capa quedó con su test de
  regresión, verificado que falla contra el diseño viejo.
- **El gate del photo release se va** ([[tech-debt/0005-photo-release-se-quita|DEBT-0005]],
  severidad alta): la decisión de publicar es del contratista y no hay dónde subir
  un permiso firmado. Vive en cuatro lugares y cada semana suma código que lo
  asume — por eso es deuda con trigger y no un TODO.
- **El seed corre las veces que haga falta**: buscaba nada e insertaba a ciegas,
  así que la segunda corrida moría en la primera fila. Ahora busca por clave
  natural. Y el cliente de prueba tiene una segunda propiedad sin punto, que es
  el estado de todo lo cargado antes de este spec.
- **"Guardado en el teléfono"** reemplaza a "Sin subir todavía": dice dónde está
  el dato en vez de anunciar una falta que se lee como fallo.

## 2026-08-10 — obras en el móvil

- **Se crean y se corrigen obras desde el teléfono**
  ([[specs/mobile/0005-proyectos-en-el-movil/README|SPEC-0005]]), con la tab de
  Detalle que SPEC-0003 había dejado en placeholder. El alta **no manda a otra
  pantalla**: cliente y propiedad se eligen con "＋ nuevo" en línea, que abre los
  formularios de SPEC-0006 y no una copia. Era la razón de hacer ese spec primero.
- **El diagrama del dominio no alcanzaba para derivar la escalera de estados.**
  Leído literal, de `ON_HOLD` no salía ninguna flecha —una obra en pausa quedaba
  trabada para siempre— y solo se podía cancelar desde `IN_PROGRESS`, cuando el
  caso más común de cancelar es el más temprano: el cliente no aceptó el estimado.
  Se preguntó en vez de deducirlo y la tabla completa quedó en la ficha.
- **Y el primer intento de implementarla rompió justo eso.** `isBackwards`
  comparaba índices de un orden lineal donde `ON_HOLD` va después de
  `IN_PROGRESS`, así que **reanudar una obra pausada se descartaba como retroceso**:
  el servidor respondía `applied`, el móvil sacaba la operación de la bandeja, y la
  obra volvía a pausada sin aviso. Lo encontró el `code-reviewer` y se verificó
  contra el API antes de tocar nada. El arreglo no fue corregir el orden: **la
  escalera es una rama, no una fila**, y cualquier índice lineal vuelve a mentir.
  `canTransition` es ahora la única fuente.
- **Editar el cliente de una obra tampoco hacía nada**, y en silencio: el
  repositorio no lo escribía y `UpdateProjectDto` no lo declara, así que
  `whitelist` lo borraba antes del `UPDATE`. Decidido que **se fija al crear**, con
  su invariante en la ficha: una obra tiene horas, fotos y facturas colgando, y
  cambiarle el cliente reasigna todo eso a otra persona. Si se eligió mal, se
  cancela y se crea de nuevo — el mismo criterio de la regla 16 con las facturas.
- **Terminar y cancelar piden confirmación.** Son las dos transiciones de las que
  no se vuelve, así que un toque por error dejaba la obra sin salida. Se eligió
  confirmar antes que permitir reabrir, para no romper la garantía de que
  "terminada" sea confiable para el reporte y para publicar. Pausar y reanudar no
  preguntan: se hacen a cada rato.
- **Una obra que no está en marcha abre en Detalle** y no en Avance. Escribiendo
  ese test apareció que `initialIndex` se lee una sola vez, al crear el
  controlador de tabs, y ahí la obra todavía no había salido de Drift.
- **La ficha del detalle cortaba las etiquetas.** Con la etiqueta en una columna de
  ancho fijo, "Nombre de la obra" se partía en tres líneas y "Propiedad" quedaba
  como "Propieda / d". Apilada sobre su valor entra en una línea, y como el mismo
  bug estaba en la ficha de cliente, salió a un widget compartido.
- **Tocar afuera cierra el teclado, en toda la app.** No se puede con
  `GestureDetector` —el gesto lo gana el hijo y el `onTap` del ancestro nunca
  dispara—, así que va con `Listener` sobre los eventos de puntero. Y excluye los
  toques sobre otro campo, o el teclado parpadea al saltar de uno al siguiente.
- **Un bug en los datos de prueba escondía cobertura.** `seedProject` armaba la
  dirección con tres campos y `AddressDto` exige `postalCode`, así que se
  descartaba y la propiedad salía vacía — con los tests pasando igual.

## 2026-08-10

- **El teléfono ahora sabe de qué país es**, y no es un adorno: es lo único que
  permite validarlo. Diez dígitos son un número correcto en Estados Unidos y no
  en Guatemala, así que sin país lo único comprobable era que hubiera algo
  escrito. Entra `phone_form_field`, con los datos de libphonenumber portados a
  **Dart puro** —valida sin señal— y sus textos ya en `en` y `es`. Se guarda
  E.164, que cierra desde el cliente la mitad del alta que
  [[tech-debt/0003-telefono-sin-normalizar|DEBT-0003]] había dejado abierta. Lo
  que sigue pendiente es el alta de `user` en el API, que es otra cosa.
- **El país de la dirección se elige, no se teclea.** El contrato lo quiere en
  ISO de dos letras: quien escribía "Mexico" a mano mandaba algo que el servidor
  rechaza al sincronizar. La lista es corta a propósito —Estados Unidos, Canadá y
  América Latina—: 240 países obligan a buscar en un selector que se usa en cada
  alta.
- **Lo obligatorio se dice con palabras, no con un asterisco.** "Nombre
  (obligatorio)" en el propio label. Un asterisco lo entiende quien ya conoce la
  convención, y la promesa es que la app se usa sin entrenamiento.
- **`showHelpSheet` es un componente**, no un modal suelto. El primero explica
  qué es el portal del cliente, porque el aviso de "sin correo ni teléfono no se
  puede invitar" daba una noticia sobre algo que nunca se había nombrado.
- **Tres arreglos de forma que se ven en el teléfono y no en captura.** El pie de
  los formularios respeta el área segura de abajo: sin eso el botón queda bajo la
  barra gestual, se ve entero, y el toque en su mitad inferior se lo lleva el
  sistema — parece que la app ignora el tap. Los campos bajaron de 72 a 56 de
  alto, que era lo que hacía entrar un formulario de diez a la mitad de pantalla.
- **Los 64dp de ADR-0009 no se fueron, se movieron de lugar.** Eran la altura de
  todo botón sólido y su razón es del marcaje —"un dedo con guante no acierta un
  botón de 48"—, que no aplica al "Guardar" de un formulario de oficina. Ahora se
  piden con `FieldActionButton`, donde valen.
- **Un test de migración de la base local.** Subir el esquema de v1 a v2 corre en
  el teléfono al abrir la app: si la migración recreara las tablas en vez de
  agregar columnas, **se llevaría la bandeja con la jornada sin sincronizar**.
  Verificado que las filas y la bandeja sobreviven.

## 2026-08-09 — clientes en el móvil

- **Clientes dejó de ser un placeholder** ([[specs/mobile/0006-clientes-en-el-movil/README|SPEC-0006]]):
  se busca por nombre, empresa o teléfono sobre la base local, la ficha muestra
  sus datos con sus propiedades y sus obras, y se da de alta o se corrige un
  cliente con su propiedad sin esperar cobertura.
- **SPEC-0006 va antes que SPEC-0005, y no al revés.** El alta de obra reutiliza
  los formularios mínimos de cliente y propiedad, que son de este spec: sin
  ellos, "crear cliente, propiedad y obra sin salir del alta" no se puede
  cumplir. Los formularios quedan como `CustomerFields(minimal:)` y
  `showSiteFormSheet`, definidos una vez para que no divergan.
- **El bug que apareció escribiendo el caso crítico del spec.** El servidor
  ordena el lote por `occurredAt`, y crear un cliente con su propiedad **en el
  mismo toque las empataba al milisegundo**: con empate, la propiedad podía
  aplicarse antes que su cliente y el servidor la rechaza por cliente
  inexistente. El primer intento fue desempatar en el móvil por `clientId`, y el
  test lo tumbó — tres UUIDv7 del mismo milisegundo comparten el prefijo de
  tiempo y el resto es aleatorio. Se arregla donde importa: `enqueue` corre el
  empate exacto un milisegundo, así el orden le llega bien al que de verdad
  ordena. Una operación anterior encolada después conserva su instante, que es lo
  que hace que una salida no pueda aplicarse antes que su entrada.
- **`site.update` existe.** SPEC-0004 lo nombró sin criterio y sin implementar,
  así que corregir una dirección no tenía camino ni por REST ni por la bandeja.
  Entra con su `PATCH /customers/:id/sites/:siteId`, su operación de sync y sus
  dos requests de Bruno.
- **Dos criterios de SPEC-0004 estaban marcados `[x]` sin estarlo**, encontrados
  verificando el código y no el changelog: no existía el test que recorre
  `lib/features/` buscando imports de `lib/api/clients/`, y la colección de
  Bruno no tiene **ninguna** request de `/sync`. El test ya existe; el criterio
  de Bruno volvió a `[ ]` con la nota de qué falta.
- **El photo release se ve, no se toca.** Es lo único que habilita publicar
  (regla 17) y otorgarlo necesita el documento firmado, así que la pantalla lo
  muestra con su chip y no ofrece ni otorgarlo ni revocarlo — revocar despublica
  en cascada, y eso no está implementado.
- **Un desborde de 32px que solo se vio en test.** Un `StatusChip` impone su
  ancho intrínseco y no cede, así que en la misma fila que el contacto reventaba
  con los textos en español. Los chips de la card pasaron a `Wrap`: si no
  entran, bajan de línea.
- **El botón de guardar quedó fijo al pie del formulario.** Al final de quince
  campos hay que ir a buscarlo scrolleando, y esta app se usa con guantes.

## 2026-08-09

- **La app funciona sin señal, de verdad.** Verificado en un teléfono real con
  el internet apagado: la cartera sigue ahí porque las pantallas leen de Drift y
  nunca de la red. Falta que las escrituras tengan su pantalla, pero la capa que
  las sostiene está ([[specs/mobile/0004-capa-local-y-sincronizacion/README|SPEC-0004]]).
- **Dos agujeros que estaban en `main`, encontrados verificando el código y no
  leyéndolo.** `POST /sync` gateaba el endpoint entero con `time.clock`, así que
  un `WORKER` daba de alta clientes y proyectos saltándose `customers.write`;
  ahora cada operación del lote declara su permiso. Y con dos throttlers
  declarados, `@nestjs/throttler` los evalúa los dos en cada request: el perfil
  de 8/min pensado para login **estaba limitando la app entera**.
- **El pull mentía dos veces.** Declaraba sus colecciones como `[Object]`, así
  que el cliente Dart las tipaba `dynamic` y descartaba la respuesta en
  silencio. Y aunque se tiparan, la consulta era `SELECT *` crudo: devolvía
  `display_name` donde el contrato promete `displayName`. Un contrato que miente
  es peor que uno sin tipos.
- **Falta `site.create` fue el hallazgo de dos revisores por separado.** Sin él
  no había forma de agregar una propiedad a un cliente que ya existe, que es el
  caso de todos los días: William ya cargó a Martínez y arranca otro trabajo en
  otra dirección.
- **La idempotencia dejó de apoyarse en que el recurso no exista.** Ese criterio
  funciona para las altas y **rompe con las correcciones**, donde el recurso
  siempre está. Pasa a una tabla de operaciones aplicadas, con el id que genera
  el dispositivo.
- **La bandeja de salida.** Una escritura sin señal se encola en una tabla —no
  en memoria, para sobrevivir a que maten la app— y llega al servidor
  exactamente una vez aunque se reintente.
- **Dos preguntas para William** en [[product/vision|vision]]: si hay alguien más
  que administre —el rol `ADMIN` dice "la persona de oficina" y la visión dice
  que el problema es el software hecho para empresas con oficina— y si sus
  cuadrillas tienen encargado fijo, que es lo único que justifica al `FOREMAN`.
- **La cartera muestra solo obras vivas.** Lo terminado y lo cancelado se
  consulta, no se vigila: sale de la pantalla principal y vive detrás de "ver
  todas", con filtro por los siete estados del dominio. "Activo" no existe como
  estado — es todo lo que no está `COMPLETED` ni `CANCELLED`.
- **La cuenta es una pantalla, no una hoja**, con el selector de tema adentro.
  Ahí van a entrar las configuraciones que falten cuando tengan su spec.
- **Tres fugas de naranja que solo se vieron en captura**: Material pinta con
  `primary` los `TextButton`, los iconos de `FilterChip` y el segmento activo de
  un `SegmentedButton`. Los tres quedaban compitiendo con la acción primaria.
  Corregido en el tema, que es donde tenía que estar.
- **Decidido: offline-first de verdad, sin parche.** Proyectos y Clientes van a
  leer de Drift y no del API directo, así que la capa local (`lib/data/`) se
  construye antes que las pantallas. Sin deuda registrada porque no se posterga
  nada.

## 2026-08-08 — sesión de móvil

- **La app tiene esqueleto** ([[specs/mobile/0003-arquitectura-de-navegacion/README|SPEC-0003]]):
  barra inferior por rol y el proyecto como contenedor, con Avance, Fotos, Horas
  y Detalle adentro de cada obra. El dueño ve ejes de negocio; el trabajador, dos
  pestañas. Todo son placeholders a propósito: la estructura primero, para que
  cada spec de pantalla llegue a un lugar ya definido.
- **Fotos y Horas dejaron de ser pestañas globales.** Viven dentro de la obra,
  que es donde significan algo. Una lista global de fotos sueltas es exactamente
  lo que rompe al proyecto como contenedor.
- **Cada destino declara su permiso y el servidor dice cuáles tiene.** Un permiso
  que cambia en el servidor no deja una pestaña que lleve a un `403`, y el móvil
  no replica la tabla de roles en ningún lado.
- **La pestaña activa no usa `primary`.** Va en `primaryContainer`, y las tabs de
  proyecto igual: con el naranja saturado, cualquier pantalla con CTA tendría dos
  naranjas y ninguno sería la acción. Verificado en los dos temas.
- **`shared_preferences` entra al proyecto**, solo para recordar la última
  pestaña. La sesión sigue siendo lo único que vive en Keychain.
- **`HomeScreen` se fue.** Quién está adentro y cómo salir pasaron al menú de
  cuenta de la barra.
- **`apps/mobile` existe.** Flutter con Riverpod 3, Drift, go_router, Dio y cliente
  generado desde `openapi.json`. Decidido en [[adr/0008-arquitectura-flutter/README|ADR-0008]],
  que también corrige el generador de ADR-0007: `swagger_parser` en vez de
  `openapi-generator`, porque el segundo exige una JVM que no está instalada.
- **Sistema de diseño cerrado** en [[adr/0009-sistema-de-diseno-y-tokens/README|ADR-0009]]:
  `design-tokens.json` en la raíz como fuente única, naranja de obra sobre neutros de
  gris puro, Inter para interfaz y Bricolage Grotesque **solo** para el wordmark.
  Los 34 pares de contraste pasan AA en los dos temas.
- **La regla del naranja.** El acento está a 17 grados del rojo de error y a 18 del
  ámbar de las banderas: el tono no alcanza para distinguirlos, así que lo hace la
  forma. Naranja sólido solo para la acción primaria; los estados siempre en chip
  tenue con icono obligatorio.
- **Login implementado y verificado** ([[specs/mobile/0001-login-movil/README|SPEC-0001]]):
  se entra con teléfono o correo indistintamente, la app toma el idioma del usuario, y
  reabrir no pide credenciales. 27 tests unitarios y 5 de integración contra el API real.
- **Un token vencido nunca borra la sesión.** Lo que se pierde sin sesión válida es
  sincronizar, no capturar — regla 9.
- **`frente: plataforma`** agregado a [[product/vision|vision]]. Los cinco frentes
  describen el producto; login, idioma, tema y navegación son cimiento y no se le
  facturan a nadie. Antes se declaraban `campo` por descarte.
- **`PATCH /auth/me/locale`** en `apps/api`, con permiso `profile.write` para todos
  los roles. Existe para que las notificaciones push salgan en el idioma correcto,
  que se traduce con el `locale` de la cuenta.
- **El login devuelve `membership.permissions`.** El móvil deja de replicar la tabla
  de roles: cada destino declara su permiso y el servidor dice cuáles tiene. Un
  permiso nuevo llega a un teléfono que no se actualizó.
- **Tres deudas registradas**, dos ya resueltas por la sesión del backend:
  [[tech-debt/0001-tokens-a-dart-a-mano|DEBT-0001]] (tokens a Dart a mano),
  [[tech-debt/0002-login-elige-membresia-arbitraria|DEBT-0002]] y
  [[tech-debt/0003-telefono-sin-normalizar|DEBT-0003]].
- **Cuatro agentes de revisión** en `.claude/agents/`: `spec-reviewer`,
  `domain-guardian` y `contract-watcher` traídos de ACDEMIC y adaptados, más el
  `code-reviewer` que ya estaba. Encontraron dos bloqueantes reales en el SPEC-0001
  y uno en el SPEC-0003 que ningún humano habría visto leyendo el documento.

## 2026-08-08

- **Alcance reestructurado tras la reunión con William.** De "fotos que se publican"
  a plataforma de cinco frentes: administrativo, campo, cliente, reportes, publicidad.
  Publicar hacia afuera sigue siendo la premisa de venta; operaciones la alimenta.
  Ver [[product/vision|vision]] y [[product/roadmap|roadmap]].
- **Cuatro decisiones cerradas**: reemplazar QuickBooks, Flutter móvil + Angular admin,
  asistencia por geocerca con foto, portal de cliente por link con cuenta opcional.
- **Modelo de dominio definido antes de la primera migración.** Trece agregados con sus
  invariantes en [[domain/README|domain/]].
- **Sistema de documentación montado**: vault de Obsidian con specs, ADRs, dominio,
  deuda técnica y boards. Portado del que ya funciona en ACDEMIC.

## 2026-08-07

- Proyecto iniciado. Decisiones de arquitectura base y estado comercial en [[DECISIONES]].
- Nombre de trabajo `snapline`, pendiente de verificar. Ver [[NOMBRE]].
