import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';

/**
 * Regla 7: todo handler HTTP declara @RequirePermission o @Public.
 *
 * El guard ya falla cerrado en runtime, pero un endpoint sin declarar solo se
 * descubre cuando alguien lo llama. Esto lo caza antes del PR.
 */
const HTTP_DECORATORS = /@(Get|Post|Patch|Put|Delete|Head|Options)\s*\(/;
const DECLARES = /@(RequirePermission|Public)\s*\(/;

function controllerFiles(dir: string, found: string[] = []): string[] {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) controllerFiles(full, found);
    else if (entry.endsWith('.controller.ts')) found.push(full);
  }
  return found;
}

/** Cada handler es el bloque de decoradores + firma que precede a un método. */
function undeclaredHandlers(source: string, file: string): string[] {
  const lines = source.split('\n');
  const offenders: string[] = [];

  for (let i = 0; i < lines.length; i++) {
    if (!HTTP_DECORATORS.test(lines[i])) continue;

    // Mirar hacia arriba hasta el decorador o llave anterior.
    let start = i;
    while (start > 0 && /^\s*@/.test(lines[start - 1])) start--;

    const block = lines.slice(start, i + 1).join('\n');
    if (!DECLARES.test(block)) {
      const method = lines[i + 1]?.trim().split('(')[0] ?? '?';
      offenders.push(`${file.split('/src/')[1]} → ${method}() (línea ${i + 1})`);
    }
  }
  return offenders;
}

describe('default deny', () => {
  const files = controllerFiles(resolve(__dirname, '..'));

  it('encuentra controllers para revisar', () => {
    expect(files.length).toBeGreaterThan(0);
  });

  it('ningún handler HTTP queda sin @RequirePermission ni @Public', () => {
    const offenders = files.flatMap((f) => undeclaredHandlers(readFileSync(f, 'utf-8'), f));

    expect(offenders).toEqual([]);
  });
});
