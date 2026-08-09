import { ArgumentsHost, BadRequestException, HttpException } from '@nestjs/common';
import { QueryFailedError } from 'typeorm';
import { HttpExceptionFilter } from './http-exception.filter';
import { ApiError } from './api-error';
import { ErrorResponseDto } from './error-response.dto';

function capture(exception: unknown): ErrorResponseDto {
  let body!: ErrorResponseDto;
  const host = {
    switchToHttp: () => ({
      getRequest: () => ({ method: 'POST', url: '/api/x' }),
      getResponse: () => ({ status: () => ({ json: (b: ErrorResponseDto) => { body = b; } }) }),
    }),
  } as unknown as ArgumentsHost;

  new HttpExceptionFilter().catch(exception, host);
  return body;
}

describe('envelope de errores', () => {
  it('message es SIEMPRE string, incluso en validación', () => {
    const validacion = capture(new BadRequestException({
      message: ['displayName should not be empty', 'email must be an email'],
      statusCode: 400,
    }));
    const simple = capture(ApiError.notFound('NOT_FOUND', 'Proyecto no encontrado'));

    expect(typeof validacion.message).toBe('string');
    expect(typeof simple.message).toBe('string');
  });

  it('los errores de validación van a details, no dentro de message', () => {
    const r = capture(new BadRequestException({
      message: ['displayName should not be empty'], statusCode: 400,
    }));

    expect(r.code).toBe('VALIDATION_FAILED');
    expect(r.details).toEqual([{ field: 'displayName', message: 'should not be empty' }]);
  });

  it('details siempre existe, aunque esté vacío', () => {
    expect(capture(ApiError.forbidden('PERMISSION_DENIED', 'no')).details).toEqual([]);
    expect(capture(new HttpException('texto plano', 418)).details).toEqual([]);
  });

  it('ApiError conserva su código estable', () => {
    const r = capture(ApiError.conflict('TIME_ENTRY_ALREADY_OPEN', 'ya abierto'));
    expect(r).toMatchObject({ statusCode: 409, code: 'TIME_ENTRY_ALREADY_OPEN' });
  });

  it('sin código explícito cae en el genérico del status', () => {
    expect(capture(new HttpException('x', 404)).code).toBe('NOT_FOUND');
    expect(capture(new HttpException('x', 409)).code).toBe('CONFLICT');
  });

  it('un invariante que salta en la base llega con el mismo código que el servicio', () => {
    // El trigger no pone su nombre en el mensaje: solo el texto del RAISE.
    const trigger = new QueryFailedError('UPDATE media_asset', [],
      new Error('media_asset abc: no puede ser PUBLIC, el cliente no otorgó photo release'));
    const indice = new QueryFailedError('INSERT time_entry', [],
      new Error('duplicate key value violates unique constraint "uq_time_entry_single_open"'));

    expect(capture(trigger)).toMatchObject({ code: 'PHOTO_RELEASE_REQUIRED', statusCode: 400 });
    expect(capture(indice)).toMatchObject({ code: 'TIME_ENTRY_ALREADY_OPEN', statusCode: 409 });
  });

  it('una restricción sin mapear no se traga: cae en CONFLICT', () => {
    const r = capture(new QueryFailedError('x', [], new Error('violates constraint "algo_nuevo"')));
    expect(r.code).toBe('CONFLICT');
  });

  it('un error inesperado nunca filtra el stack', () => {
    const r = capture(new Error('connection string: postgres://user:pass@host'));
    expect(r).toMatchObject({ statusCode: 500, code: 'INTERNAL_ERROR', message: 'Error interno' });
    expect(JSON.stringify(r)).not.toContain('pass@host');
  });
});
