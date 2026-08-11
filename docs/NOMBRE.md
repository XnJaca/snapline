# Nombre — estado y verificación pendiente

`snapline` es un **nombre de trabajo**. Sirve para el directorio y el repo; no está confirmado como marca.

## Por qué Snapline

Doble sentido exacto para el producto: *snap* una foto, y el *snap line* (cordel de tiza) es la herramienta con la que se marca la línea en la obra. Corto, fácil de decir en inglés y español.

## Nombres descartados (2026-08-07)

| Nombre | Motivo |
|---|---|
| **Obralink** | ConTech chilena fundada en 2019, respaldada por Cemex Ventures. Dominios `.com` y `.app`, apps publicadas en App Store y Google Play, bundle `com.obralink.*` registrado. Mismo rubro y mismo idioma. Descartado sin discusión. |
| **Faena** | Faena Tech — gestión de obra en tiempo real. Misma categoría. |
| **Chalkline** | chalkline.build — workspace con AI para constructoras comerciales. |
| **Trueline** | TrueLine Consulting Group vende sistemas AI a contratistas, más varias constructoras con ese nombre. |
| **Rafter** | Saturado de calculadoras de techos en ambos stores. |
| **Plomada** | Ya existe "Medir y Alinear - 3D Plomada" en Google Play. |
| **JobShot / BuiltBy / Showsite** | Tomados. |

## Riesgo conocido de Snapline

**Graco tiene SNAPLINE™** para sistemas de marcaje de canchas deportivas. Es otra clase de producto y no hay conflicto en software de construcción, pero la marca existe y conviene saberlo.

También existen: un manejador de capturas de pantalla, un POS para bares (snapline.info) y un add-on de Blender. Ninguno en este rubro, pero **`snapline.com` casi con seguridad está tomado**.

## Verificación pendiente — antes de registrar nada

Google no es la autoridad. Los tres lugares que sí lo son:

- [ ] **App Store Connect** — reservar el nombre. Es lo único que confirma disponibilidad en iOS; si está tomado, el envío se rechaza.
- [ ] **Google Play Console** — verificar el bundle `com.snapline.app`, que es el
      que la app declara desde el 2026-08-10 en Android y en iOS. Si estuviera
      tomado, hay que renombrar **antes** de la primera subida.
- [ ] **USPTO TESS** (tmsearch.uspto.gov) — buscar marcas registradas en la clase de software. Aquí se aclara de verdad lo de Graco.
- [ ] **Dominio** — probar `snapline.app`, `getsnapline.com`, `snapline.build`.

## Alternativas si Snapline no pasa

- **Aplomo** — "a plomo" es que está bien vertical, y "aplomo" es también seguridad y temple. Doble sentido bonito, muy poco probable que esté tomado. Contra: un angloparlante no lo entiende.
- **Remate** — el acabado final de una obra. Vocabulario real del gremio hispano.

Mientras no haya bundle ID publicado, renombrar cuesta un `mv` y un buscar-reemplazar.

> **El identificador ya está elegido: `com.snapline.app`**, en Android y en iOS
> (2026-08-10). Reemplaza al `com.snapline.snapline` que generaba Flutter por
> defecto y que nadie había decidido.
>
> Salió al restringir la clave de Google Maps, que exige declarar el paquete. La
> ventana era esa: **una vez publicada la app, el identificador no se cambia — se
> publica otra**, y se pierde a todo el que la tenía instalada. El bundle no
> necesita un dominio que se posea, así que no depende de cuál de los tres se
> consiga.
