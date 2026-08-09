import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { INestApplication } from '@nestjs/common';
import { OpenAPIObject } from '@nestjs/swagger';
import { ErrorResponseDto } from './common/errors/error-response.dto';

// Fuente única del contrato: de acá salen los tipos de TS y los modelos de Dart.
export function buildOpenApi(app: INestApplication): OpenAPIObject {
  const config = new DocumentBuilder()
    .setTitle('Snapline API')
    .setDescription('Gestión para contratistas. Ver docs/product/vision.md')
    .setVersion('0.0.1')
    .addBearerAuth({ type: 'http', scheme: 'bearer', bearerFormat: 'JWT' }, 'bearer')
    .build();

  // Los operationId tienen que ser únicos en todo el spec: sin el prefijo del
  // controller, los list/get/create de cada recurso chocan entre sí.
  const doc = SwaggerModule.createDocument(app, config, {
    extraModels: [ErrorResponseDto],
    operationIdFactory: (controller, method) =>
      `${controller.replace(/Controller$/, '')}_${method}`,
  });

  // Todos los errores tienen la misma forma (ADR-0011): se declara una vez y se
  // aplica a cada operación en vez de repetir @ApiResponse en 67 handlers.
  const error = { $ref: '#/components/schemas/ErrorResponseDto' };
  for (const path of Object.values(doc.paths)) {
    for (const op of Object.values(path)) {
      if (typeof op !== 'object' || op === null || !('responses' in op)) continue;
      const responses = (op as { responses: Record<string, unknown> }).responses;
      for (const status of ['400', '401', '403', '404', '409', '500']) {
        responses[status] ??= {
          description: 'Error', content: { 'application/json': { schema: error } },
        };
      }
    }
  }
  return doc;
}

export function mountSwagger(app: INestApplication): void {
  SwaggerModule.setup('api/docs', app, buildOpenApi(app));
}
