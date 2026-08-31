import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import StyleDictionary from 'style-dictionary';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const source = JSON.parse(readFileSync(resolve(root, 'design-tokens.json'), 'utf8'));

const DART_OUT = 'apps/mobile/lib/core/theme/tokens.dart';
const SCSS_OUT = 'apps/web/src/styles/_tokens.scss';

// Dos nombres en Dart no salen mecánicamente del árbol del JSON, y se conservan
// porque los widgets ya los consumen: la familia de UI es *la* familia, y los
// pesos se usan sueltos sin el prefijo de su grupo.
const DART_ALIASES = {
  'font-family-ui': 'fontFamily',
  'font-weight-regular': 'weightRegular',
  'font-weight-medium': 'weightMedium',
  'font-weight-bold': 'weightBold',
  'font-weight-brand': 'weightBrand',
};

const camel = (kebab) => kebab.replace(/-([a-z0-9])/g, (_, c) => c.toUpperCase());
const dartName = (path) => {
  const kebab = path.join('-');
  return DART_ALIASES[kebab] ?? camel(kebab);
};

// Grupos cuyo `$comment` emite el formato por su cuenta —`color` lo usa como
// docblock de las clases de tema—, así que propagarlo además a un token lo
// duplicaría.
const FORMAT_OWNED_COMMENTS = new Set(['color']);

/**
 * Convierte nuestro árbol —valores desnudos y `$comment`— al shape que espera
 * Style Dictionary. El `$comment` de un grupo viaja con el **primer token que
 * aparece debajo**, que es donde termina emitido como docblock encabezando el
 * bloque.
 *
 * Baja por subgrupos cuando hace falta: `font` no tiene ninguna hoja directa
 * —solo `family`, `size` y `weight`— y buscar únicamente entre sus hijos perdía
 * su comentario sin avisar. Si el token que lo recibe ya traía uno propio, los
 * dos se conservan.
 */
function toTokens(node, path = [], inherited = []) {
  const out = {};
  const keys = Object.keys(node).filter((k) => !k.startsWith('$'));
  const own = FORMAT_OWNED_COMMENTS.has(path[0] ?? '') ? undefined : node.$comment;
  const pending = own ? [...inherited, own] : inherited;

  let delivered = false;
  for (const key of keys) {
    const value = node[key];
    const next = [...path, key];
    const carry = delivered ? [] : pending;

    if (value !== null && typeof value === 'object') {
      out[key] = toTokens(value, next, carry);
      // Un subgrupo siempre termina en algún token, así que el comentario ya viajó.
      if (carry.length) delivered = true;
      continue;
    }

    out[key] = { value, comment: carry.length ? carry.join('\n\n') : undefined };
    if (carry.length) delivered = true;
  }
  return out;
}

const isColor = (token) => typeof token.value === 'string' && token.value.startsWith('#');
const groupComment = (path) => {
  let node = source;
  for (const key of path) node = node?.[key];
  return node?.$comment;
};

/** `#C2410C` → `Color(0xFFC2410C)`. Sin alfa en la fuente: todos los tokens son opacos. */
const dartColor = (hex) => `Color(0xFF${hex.replace('#', '').toUpperCase()})`;

function dartValue(token, path) {
  if (isColor(token)) return dartColor(token.value);
  if (path[0] === 'font' && path[1] === 'weight') return `FontWeight.w${token.value}`;
  if (path[0] === 'font' && path[1] === 'family') return `'${token.value}'`;
  return Number.isInteger(token.value) ? `${token.value}.0` : `${token.value}`;
}

/**
 * Reflowea un `$comment` del JSON como docblock Dart de 80 columnas. Un token que
 * heredó el comentario de su grupo trae varios párrafos separados por línea en
 * blanco, y se emiten como tales.
 */
function docblock(text, indent = '  ') {
  if (!text) return '';

  const wrap = (paragraph) => {
    const lines = [];
    let line = '';
    for (const word of paragraph.split(/\s+/)) {
      if ((line + ' ' + word).trim().length > 76 - indent.length) {
        lines.push(line.trim());
        line = word;
      } else line = `${line} ${word}`;
    }
    if (line.trim()) lines.push(line.trim());
    return lines;
  };

  return (
    text
      .split('\n\n')
      .map(wrap)
      .flatMap((lines, i) => (i === 0 ? lines : ['', ...lines]))
      .map((l) => (l ? `${indent}/// ${l}` : `${indent}///`))
      .join('\n') + '\n'
  );
}

const HEADER = `// GENERADO por packages/tokens desde design-tokens.json en la raíz.
// No editar a mano: los cambios se pierden al regenerar con \`pnpm tokens:generate\`.
// Ver ADR-0009 y ADR-0013.`;

StyleDictionary.registerFormat({
  name: 'snapline/dart',
  format: ({ dictionary }) => {
    const scalars = dictionary.allTokens.filter((t) => t.path[0] !== 'color' && t.path[0] !== 'primitive');
    const themed = (mode) => dictionary.allTokens.filter((t) => t.path[0] === 'color' && t.path[1] === mode);

    // Un token se lee por familia, no en una lista corrida: `primary`, `on-primary`
    // y `primary-container` son el mismo rol y van juntos.
    const family = (t) =>
      t.path[0] === 'color'
        ? t.path.slice(2).join('-').replace(/^on-/, '').replace(/-container$/, '')
        : t.path.slice(0, -1).join('.');

    const emit = (tokens, transform) =>
      tokens
        .map((t, i) => {
          const gap = i > 0 && family(t) !== family(tokens[i - 1]) ? '\n' : '';
          return `${gap}${docblock(t.comment)}  static const ${transform(t)} = ${dartValue(t, t.path)};`;
        })
        .join('\n');

    return `${HEADER}

import 'package:flutter/material.dart';

${docblock('Escala, tipografía y medidas. Nada fuera de `core/theme` consume esta clase: los widgets leen el tema.', '')}abstract final class Tokens {
${emit(scalars, (t) => dartName(t.path))}
}

${docblock(groupComment(['color']), '')}abstract final class LightTokens {
${emit(themed('light'), (t) => camel(t.path.slice(2).join('-')))}
}

${docblock('Capa semántica del tema oscuro. Mismos roles, otros valores.', '')}abstract final class DarkTokens {
${emit(themed('dark'), (t) => camel(t.path.slice(2).join('-')))}
}
`;
  },
});

// Nuestros roles semánticos contra el vocabulario de Material 3. Es el mismo mapeo
// que el tema de Flutter ya aplica: `error` es danger, `outline` es border y
// `on-surface-variant` es el texto atenuado. Lo que no aparece acá —warning y
// success— M3 no lo tiene, y sale como variable propia (ADR-0013 §3).
const M3_ROLES = {
  primary: 'primary',
  'on-primary': 'on-primary',
  'primary-container': 'primary-container',
  'on-primary-container': 'on-primary-container',
  surface: 'surface',
  'on-surface': 'on-surface',
  'surface-variant': 'surface-variant',
  background: 'background',
  'on-background': 'on-background',
  'text-muted': 'on-surface-variant',
  border: 'outline',
  danger: 'error',
  'on-danger': 'on-error',
  'danger-container': 'error-container',
  'on-danger-container': 'on-error-container',
};

/**
 * M3 tiene cinco niveles de superficie que nuestra paleta no nombra. Si no se
 * declaran, Material los deriva de su paleta base **con tinte naranja**, y ahí
 * aparece la deriva: el panel tendría tarjetas rosadas contra los neutros de gris
 * puro que ADR-0009 eligió a propósito.
 *
 * El mapeo es el mismo que `apps/mobile/lib/core/theme/app_theme.dart` ya aplica
 * en su `ColorScheme`. Los dos tienen que moverse juntos.
 */
const M3_DERIVED = {
  light: {
    'surface-container-lowest': 'surface',
    'surface-container-low': 'background',
    'surface-container': 'background',
    'surface-container-high': 'surface-variant',
    'surface-container-highest': 'surface-variant',
    'outline-variant': 'border',
    'surface-tint': 'primary',
  },
  dark: {
    'surface-container-lowest': 'background',
    'surface-container-low': 'background',
    'surface-container': 'surface',
    'surface-container-high': 'surface-variant',
    'surface-container-highest': 'surface-variant',
    'outline-variant': 'border',
    'surface-tint': 'primary',
  },
};

StyleDictionary.registerFormat({
  name: 'snapline/scss',
  format: ({ dictionary }) => {
    const scalars = dictionary.allTokens.filter((t) => t.path[0] !== 'color' && t.path[0] !== 'primitive');
    const themed = (mode) => dictionary.allTokens.filter((t) => t.path[0] === 'color' && t.path[1] === mode);
    const role = (t) => t.path.slice(2).join('-');

    const unitless = new Set(['weight', 'family']);
    const cssValue = (t) => {
      if (typeof t.value === 'string') return t.value;
      if (t.path[0] === 'font' && unitless.has(t.path[1])) return `${t.value}`;
      return `${t.value}px`;
    };

    const vars = scalars.map((t) => `  --sl-${t.path.join('-')}: ${cssValue(t)};`).join('\n');

    // Solo lo que M3 sabe nombrar: el resto no tiene lugar en theme-overrides.
    const matMap = (mode) => {
      const byRole = new Map(themed(mode).map((t) => [role(t), t.value]));
      const direct = themed(mode)
        .filter((t) => M3_ROLES[role(t)])
        .map((t) => `  ${M3_ROLES[role(t)]}: ${t.value},`);
      const derived = Object.entries(M3_DERIVED[mode]).map(
        ([target, from]) => `  ${target}: ${byRole.get(from)},`,
      );
      return [...direct, '', '  // Derivados, para que Material no los tiña', ...derived].join('\n');
    };

    // Y lo que no: las banderas de asistencia y `text`, que en M3 es on-surface.
    const ownVars = (mode, indent = '  ') =>
      themed(mode)
        .filter((t) => !M3_ROLES[role(t)])
        .map((t) => `${indent}--sl-${role(t)}: ${t.value};`)
        .join('\n');

    return `${HEADER}

// El mapa alimenta mat.theme-overrides(): Material recibe estos valores en vez de
// derivar su propia paleta. Es el espejo en web de prohibir fromSeed en Flutter,
// y por eso los nombres son los de M3 y no los nuestros.
$sl-light: (
${matMap('light')}
);

$sl-dark: (
${matMap('dark')}
);

// Lo que el vocabulario de M3 no cubre. Se consume como var(--sl-warning-container),
// nunca como literal.
:root {
${vars}
${ownVars('light')}
}

:root[data-theme='dark'] {
${ownVars('dark')}
}

@media (prefers-color-scheme: dark) {
  :root:not([data-theme='light']) {
${ownVars('dark', '    ')}
  }
}
`;
  },
});

const sd = new StyleDictionary({
  tokens: toTokens(source),
  platforms: {
    dart: { transformGroup: 'js', buildPath: `${root}/`, files: [{ destination: DART_OUT, format: 'snapline/dart' }] },
    scss: { transformGroup: 'js', buildPath: `${root}/`, files: [{ destination: SCSS_OUT, format: 'snapline/scss' }] },
  },
  log: { verbosity: 'silent' },
});

mkdirSync(resolve(root, dirname(SCSS_OUT)), { recursive: true });
await sd.buildAllPlatforms();

// Style Dictionary no normaliza el salto final; que falte ensucia el diff siguiente.
for (const out of [DART_OUT, SCSS_OUT]) {
  const path = resolve(root, out);
  const text = readFileSync(path, 'utf8');
  if (!text.endsWith('\n')) writeFileSync(path, `${text}\n`);
}

console.log(`tokens → ${DART_OUT}\ntokens → ${SCSS_OUT}`);
