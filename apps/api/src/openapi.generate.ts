import 'reflect-metadata';
import { writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { NestFactory } from '@nestjs/core';
import { initializeTransactionalContext } from 'typeorm-transactional';
import { AppModule } from './app.module';
import { buildOpenApi } from './openapi';

// Escribe openapi.json en la raíz del monorepo, que es lo que consumen
// packages/contracts y el generador de Dart.
async function generate(): Promise<void> {
  initializeTransactionalContext();
  const app = await NestFactory.create(AppModule, { logger: false });
  await app.init();

  // Desde dist/: dist -> apps/api -> apps -> raíz del monorepo
  const out = resolve(__dirname, '../../../openapi.json');
  writeFileSync(out, JSON.stringify(buildOpenApi(app), null, 2) + '\n');
  console.log(`openapi.json escrito en ${out}`);

  await app.close();
}

generate().catch((e) => { console.error(e); process.exit(1); });
