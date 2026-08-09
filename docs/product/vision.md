---
id: VISION
title: "Visión — Snapline"
type: product
status: vigente
created: 2026-08-08
updated: 2026-08-08
tags:
  - product
  - vision
---

# Visión

Norte del producto. **La sección "Qué NO somos" es el único gate duro de alcance**:
si una idea la contradice, no entra sin cambiar este documento primero.

Vigente desde la reunión con William del 2026-08-08. Reemplaza el alcance original.

## La tesis

Un contratista de dos cuadrillas no tiene un problema de software. Tiene el
problema de que el software que existe está hecho para empresas con oficina.

- **QuickBooks** hace todo lo que William necesita en lo comercial. Él estima a
  mano igual, porque aprenderlo cuesta más que hacerlo mal.
- **CompanyCam y Procore** documentan hacia adentro: reportes, seguros, disputas.

La apuesta son dos cosas a la vez, y ninguna funciona sola:

1. **Se usa sin entrenamiento.** Si William necesita un tutorial, ya perdimos
   contra QuickBooks.
2. **La foto termina publicada.** Es el único frente que le produce dinero en vez
   de ahorrarle tiempo.

## El ciclo

Esto es el producto. Todo lo demás son piezas que lo sostienen.

```
   obra ejecutada
        │
        ▼
   el trabajador toma la foto en sitio ──── ya viene etiquetada:
        │                                    proyecto, cliente, servicio, antes/después
        ▼
   William aprueba qué se muestra
        │
        ├──────────────▶ el cliente ve su avance ──▶ se le ofrece otro servicio
        │                                                    │
        ▼                                                    ▼
   se publica a su web sin intermediario              obra nueva del mismo cliente
        │
        ▼
   de ahí sale el contenido de redes ──▶ leads ──▶ obra nueva
```

Dos consecuencias que hay que tener presentes al construir:

**El servicio de redes deja de depender de que William mande fotos.** Hoy son
$300/mes que arrancan pidiendo material por WhatsApp — una vez llegaron más de 200
fotos de golpe, sin identificar. Con esto la fuente es estructurada y consultable,
y ese servicio escala a más clientes con el mismo esfuerzo. Eso vuelve el frente
de publicidad prioridad de diseño, no el último bullet.

**El cliente que ya pagó una obra es el lead más barato que existe.** El portal
del cliente no es cortesía: es el canal de venta cruzada.

## Los cinco frentes

Todo spec declara a cuál pertenece, en el campo `frente` del frontmatter. Lo que no
cabe en ninguno porque es cimiento va a `plataforma` — ver más abajo, y leer antes
de usarlo.

### 1. Administrativo — `administrativo`

Proyecto como unidad central: cliente → descripción → carpeta de fotos y documentos.

- Clientes con propiedades (un mismo cliente puede tener varias obras en la misma dirección)
- Proyectos con estado, fechas, dirección y servicio
- Cuadrillas y asignación por proyecto y fecha — resuelve *"no sé cuántos mandé a cada proyecto"*
- Catálogo de productos y servicios con precio y unidad — resuelve *"estimo ingresando todo a mano"*
- Estimados → facturas → pagos

### 2. Trabajadores en sitio — `campo`

La única pantalla que un trabajador debería necesitar: dónde trabajo hoy, marcar
entrada, tomar fotos, marcar salida.

- Clock in/out con geocerca y foto, funcionando sin señal — ver [[../adr/0003-asistencia-geocerca-foto/README|ADR-0003]]
- Captura de fotos vinculadas al proyecto, con permiso por rol
- Sin GPS continuo ni rutas. Solo el punto de entrada y salida, a propósito.

### 3. Cliente — `cliente`

Entra por link sin instalar nada, y puede reclamar cuenta si quiere historial y
avisos. Ver [[../adr/0004-portal-cliente-link-cuenta-opcional/README|ADR-0004]].

| Modo | Qué ve |
|---|---|
| Etapas | Inicio · En proceso · Finalizado. Nada más hasta el final. |
| Avance | Actualizaciones y fotos que William marcó como visibles. |

Por defecto **Etapas**. Mostrar avance es una decisión activa, no el default: una
foto de media obra genera más preguntas que confianza. Ver también el supuesto
abierto sobre este frente, más abajo.

### 4. Reportes — `reportes`

- Timesheets aprobados por trabajador, proyecto y período — el paquete que hoy
  William arma a mano para el contador
- Acceso de solo lectura para el contador, sin mandarle archivos
- Costo real por proyecto: horas × tarifa + materiales, contra lo estimado

### 5. Publicidad — `publicidad`

- Publicar el proyecto a su web con un botón, sin pasar por nadie
- Pares antes/después como pieza de primera clase, no una foto suelta
- Feed consultable por servicio, ciudad y fecha para producir redes
- Reseñas del cliente enganchadas al proyecto que las originó

## Lo que sostiene a los cinco — `plataforma`

**No es un sexto frente.** Los cinco de arriba describen el producto: lo que se le
vende a un contratista. Nada de `plataforma` se factura, y por sí solo no le
resuelve un problema a nadie.

Existe porque hay trabajo sin el cual ningún frente funciona y que no pertenece a
ninguno: iniciar sesión, elegir idioma, el tema, y la estructura de navegación
sobre la que cuelgan todas las pantallas. Antes de tener esta categoría esos specs
se declaraban `campo` por descarte, que era mentira y hacía que el índice por
frente no significara nada.

**Un spec va acá solo si no puede ir a ninguno de los cinco.** Si sirve a un frente
concreto, es de ese frente aunque tenga trabajo de base adentro. La pregunta que lo
decide: *¿se le podría cobrar a William por esto?* Si la respuesta es sí, no es
`plataforma`.

## Qué NO somos

**Gate duro.** Una idea que contradiga esto no entra sin modificar este documento.

- **No calculamos nómina.** Producimos timesheets aprobados y horas × tarifa.
  Retenciones, impuestos y pagos los hace el contador. Esa línea no se cruza.
- **No cobramos con tarjeta** en la primera versión. Registramos el pago recibido.
- **No hacemos tracking continuo de ubicación.** Solo el punto de clock-in y clock-out.
- **No hacemos inventario, compras ni órdenes de cambio.**
- **No calculamos sales tax por jurisdicción.** Tasa configurable y bandera por línea.
- **No competimos de frente con CompanyCam.** Mapa en vivo, firma de documentos y
  medición con cámara son años de desarrollo que no se alcanzan y no hacen falta.
  La diferencia es el destino de la foto, no la cantidad de funciones.

## Evidencia y supuestos

Del brief comercial (`brief.md`, documento interno).

### Validado

- **Contratistas pagan por esta categoría.** CompanyCam cobra $63/mes por un usuario,
  hasta $199 en tiers superiores, facturado anual.
- **Hay demanda comercial en el gremio.** A William lo llaman agencias todos los días.
- **La competencia no hace marketing.** Ninguno de los cuatro planes de CompanyCam
  incluye publicar en la web del contratista. El hueco está confirmado en su tabla de precios.
- **El desorden de gente es real y es de él**, no una hipótesis nuestra: dos cuadrillas,
  sin control de horas ni asistencia, y todo se junta a mano para el contador.

### Contradicción abierta — el portal del cliente

El brief registra que este frente fue **refutado con evidencia directa**: preguntado
sin rodeos, William respondió *"no mandamos fotos"* y que el cliente solo ve el
resultado final. Y no es por falta de herramienta — CompanyCam ofrece avance en
vivo desde su plan más barato y aun así no es parte de cómo trabajan.

El frente 3 entró a la propuesta por decisión de producto, no porque William lo
pidiera. Eso puede estar bien: es el canal de venta cruzada y el cliente ya pagado
es el lead más barato. Pero **conviene saber que se está construyendo contra la
evidencia disponible**, no a favor.

Mitigación ya incorporada: el default es **Etapas**, no Avance. El frente se
sostiene aunque William nunca active la vista detallada.

### Sin validar

- Que William **use** la app. Dijo que sí sabiendo que era gratis, y un sí gratis
  vale menos que un sí pagado.
- Que sus contactos existan y conviertan. Ofreció "muchos contactos"; todavía no
  hay un solo nombre.
- Que otros contratistas tengan el mismo dolor. Muestra de uno.

## Lo que decide si el producto avanza

Dos señales que no requieren escribir código:

1. ¿William manda las fotos **con el nombre del trabajo escrito**, dos o tres veces
   seguidas, sin que se lo recuerden? Si no hace ni eso en WhatsApp, ninguna app lo arregla.
2. ¿**Presenta a un contacto real** del gremio? Ahí se prueba la distribución, que
   es el problema difícil del producto.

Un sí por chat es una opinión. Estas dos son evidencia.

## Preguntas abiertas para William

Cosas que decidimos **no** resolver razonando de este lado, porque se contestan en
cinco minutos con él y cualquier respuesta nuestra sería una suposición cara.

**¿Hay alguien más que administre, además de vos?**

El rol `ADMIN` está definido como *"la persona de oficina"*, y este documento dice
que el problema de William es justamente que el software existente está hecho
**para empresas con oficina**. La contradicción es real.

Existe igual porque el dominio fija *"una empresa tiene exactamente un `OWNER`
activo"*: si aparece una segunda persona con poderes administrativos, hoy `ADMIN`
es el único camino. Mientras no se sepa, el rol queda **definido pero sin usar** —
el seed no crea ninguno. Sacarlo del enum después, con datos adentro, cuesta una
migración; dejarlo sin usar no cuesta nada.

**¿Tus cuadrillas tienen un encargado fijo?**

El `FOREMAN` no es decorativo: su poder real es **fichar por su gente**, que ya
existe en `time-entries.service.ts` (`method: 'FOREMAN'` cuando el marcaje es por
otro). Sirve cuando el capataz llega con cuatro personas y alguna no tiene
smartphone. Si en la práctica cada quien marca lo suyo, el rol sobra y hay que
sacarlo del móvil antes de construirle pantallas.
