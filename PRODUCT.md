# Product

## Register

product

## Users

**William Ferman**, dueño de Professional Construction LLC en Maryland. Dos
cuadrillas, sin oficina y sin personal administrativo. Administra desde el
escritorio, en inglés, entre obra y obra. No es power user: si necesita un
tutorial, vuelve a hacerlo a mano en papel o en QuickBooks.

**Sus trabajadores**, probablemente en español, usando el teléfono en un techo con
sol directo o en un sótano sin luz. Marcan entrada, toman fotos, cargan horas. El
`locale` es por usuario, no por empresa.

**El cliente final**, que entra por un enlace privado sin cuenta, mira el avance de
su obra y a veces contrata otro servicio. No es un rol de membresía.

El trabajo a resolver: **cerrar el ciclo entre la obra ejecutada y la foto
publicada**, pasando por las horas, el cliente y el cobro, sin que nadie tenga que
aprender un sistema.

## Product Purpose

Software de gestión para el contratista que no tiene oficina, que además publica la
obra terminada en su web y sus redes.

Dos apuestas simultáneas, y ninguna funciona sola:

1. **Se usa sin entrenamiento.** El competidor real no es otro software: es seguir
   haciéndolo a mano.
2. **La foto termina publicada.** Es el único frente que produce dinero en vez de
   ahorrar tiempo.

El éxito se mide en que William deje de pedir fotos por WhatsApp y en que una obra
terminada llegue sola al portafolio. Ver `docs/product/vision.md`, que es la fuente
y manda sobre este archivo si se contradicen.

## Brand Personality

**Herramienta de trabajo: sobria, rápida, sin adornos.**

Densa a propósito: ver mucho de un vistazo y resolver en pocos clics vale más que
respirar. La referencia es Linear o Height, no un SaaS de marketing.

La voz es de **usted** en los dos idiomas, directa y sin jerga. Dice qué pasó y qué
hacer: *"Este cliente tiene obras, así que no se puede borrar. Cierre o borre las
obras primero."* Nunca *"Ha ocurrido un error"*.

El riesgo declarado de esta elección es que se sienta fría para alguien que no vive
en software. Se compensa con copy claro y estados vacíos que explican, no con
color ni con ilustración.

## Anti-references

Las cuatro, confirmadas el 2026-09-04:

- **QuickBooks y el software contable.** Gris, denso, formularios largos, todo del
  mismo peso visual. Es el competidor declarado y lo que William evita usar.
- **Procore y CompanyCam.** Enterprise de construcción: azul corporativo, mil
  funciones, dashboards que nadie mira. La visión dice explícitamente que no
  competimos de frente.
- **SaaS genérico de plantilla.** Gradientes violeta, tarjetas idénticas con icono
  arriba, hero con métrica gigante, eyebrow en mayúsculas sobre cada sección.
- **App consumer o de juguete.** Saturado, esquinas muy redondeadas, ilustraciones
  simpáticas, animaciones que rebotan. Esto factura obras de miles de dólares.

## Design Principles

1. **La pantalla se entiende sin que nadie la explique.** Si hace falta una
   leyenda, un tooltip o un instructivo, la pantalla está mal. El competidor es
   el papel.

2. **Densidad con jerarquía, no densidad plana.** Se muestra mucho, pero siempre
   hay un primer dato, un segundo y un tercero. Lo que QuickBooks hace mal no es
   mostrar mucho: es que todo pesa igual.

3. **Nada flota.** Todo bloque vive sobre una superficie, a ancho completo, y las
   zonas equivalentes se alinean entre elementos vecinos. El desalineamiento se
   lee como descuido antes que como estilo.

4. **El estado se dice con forma, no solo con color.** Naranja, ámbar y rojo viven
   a 35 grados de rueda: el icono y la posición son lo que los separa. Además la
   app se usa con sol directo en la pantalla.

5. **Un solo acento por pantalla.** El naranja saturado es de la acción principal
   y de nada más. Si dos cosas gritan, ninguna es la acción.

## Accessibility & Inclusion

- **Contraste AA como piso** (4.5:1 en texto normal, 3:1 en texto grande), medido
  en los dos temas por separado. El modo oscuro no se infiere del claro.
- **Los dos temas desde el primer componente.** No es cosmético: la misma app se
  usa en un techo con sol y en un sótano sin luz.
- **Ningún estado se comunica solo con color** — el icono es obligatorio.
- **`prefers-reduced-motion` respetado** en toda animación.
- **Inglés y español desde el diseño**, con el `locale` por usuario. El texto crece
  al traducir: los layouts no pueden depender del largo de una cadena.
- **Teclado completo** en el panel: es una herramienta de escritorio y se usa con
  las dos manos.
