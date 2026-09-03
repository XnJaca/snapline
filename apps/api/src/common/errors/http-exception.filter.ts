import { ArgumentsHost, Catch, ExceptionFilter, HttpException, Logger } from '@nestjs/common';
import { Request, Response } from 'express';
import { QueryFailedError } from 'typeorm';
import { defaultCodeFor, ErrorCode } from './error-codes';
import { ErrorResponseDto, FieldErrorDto } from './error-response.dto';

// Los invariantes viven en la base (ADR-0006). Cuando saltan, el cliente merece
// el mismo código estable que si los hubiera atajado el servicio.
//
// Ojo con la clave: los índices y CHECK traen su nombre en el mensaje, pero un
// RAISE EXCEPTION de un trigger solo trae el texto que se escribió. Por eso acá
// se matchea contra fragmentos del mensaje, no contra nombres de objeto.
const DB_ERROR_SIGNATURES: { match: string; code: ErrorCode; status: number; message: string }[] = [
  { match: 'sin limpiar el EXIF', code: 'EXIF_NOT_STRIPPED', status: 400,
    message: 'La foto todavía tiene EXIF: publicarla expondría la ubicación' },
  { match: 'time_entry no se borra', code: 'FORBIDDEN', status: 403,
    message: 'Los registros de tiempo no se borran: se corrigen dejando rastro' },
  { match: 'uq_time_entry_single_open', code: 'TIME_ENTRY_ALREADY_OPEN', status: 409,
    message: 'Ya hay un registro de tiempo abierto para esa persona' },
  { match: 'uq_membership_single_owner', code: 'CONFLICT', status: 409,
    message: 'La empresa ya tiene un OWNER activo' },
  { match: 'crew_member_no_overlap', code: 'CONFLICT', status: 409,
    message: 'Esa persona ya pertenece a una cuadrilla en ese rango de fechas' },
  { match: 'time_entry_rate_frozen_on_approval', code: 'PAY_RATE_MISSING', status: 400,
    message: 'No se puede aprobar sin tarifa definida' },
  { match: 'el cliente tiene historia y no se borra', code: 'CUSTOMER_HAS_HISTORY', status: 409,
    message: 'Este cliente tiene obras o documentos y no se puede borrar' },
  { match: 'uq_media_checksum', code: 'CONFLICT', status: 409,
    message: 'Esa foto ya está registrada en el proyecto' },
  { match: 'published_project_company_id_slug_key', code: 'ALREADY_PUBLISHED', status: 409,
    message: 'Ya existe una publicación con ese slug' },
];

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const req = ctx.getRequest<Request>();
    const res = ctx.getResponse<Response>();

    const { status, code, message, details } = this.normalize(exception);

    if (status >= 500) {
      this.logger.error(`${req.method} ${req.url} → ${code}`, (exception as Error)?.stack);
    }

    const body: ErrorResponseDto = {
      statusCode: status,
      code,
      message,
      details,
      path: req.url,
      timestamp: new Date().toISOString(),
    };
    res.status(status).json(body);
  }

  private normalize(e: unknown): { status: number; code: ErrorCode; message: string; details: FieldErrorDto[] } {
    if (e instanceof HttpException) {
      const status = e.getStatus();
      const payload = e.getResponse();

      if (typeof payload === 'string') {
        return { status, code: defaultCodeFor(status), message: payload, details: [] };
      }

      const p = payload as Record<string, unknown>;

      // Ya viene de ApiError: trae su código.
      if (typeof p.code === 'string') {
        return {
          status,
          code: p.code as ErrorCode,
          message: String(p.message),
          details: (p.details as FieldErrorDto[]) ?? [],
        };
      }

      // ValidationPipe: message es un array de strings. Se parte en details para
      // que message nunca cambie de tipo.
      if (Array.isArray(p.message)) {
        return {
          status,
          code: 'VALIDATION_FAILED',
          message: 'Los datos enviados no son válidos',
          details: p.message.map((m) => this.toFieldError(String(m))),
        };
      }

      return { status, code: defaultCodeFor(status), message: String(p.message ?? e.message), details: [] };
    }

    if (e instanceof QueryFailedError) {
      const raw = String(e.message);
      const hit = DB_ERROR_SIGNATURES.find((sig) => raw.includes(sig.match));
      if (hit) {
        return { status: hit.status, code: hit.code, message: hit.message, details: [] };
      }
      this.logger.warn(`Restricción de base sin mapear: ${raw.slice(0, 160)}`);
      return { status: 409, code: 'CONFLICT', message: 'La operación viola una restricción de datos', details: [] };
    }

    return { status: 500, code: 'INTERNAL_ERROR', message: 'Error interno', details: [] };
  }

  /** class-validator devuelve "campo mensaje"; se separa el campo. */
  private toFieldError(text: string): FieldErrorDto {
    const [field, ...rest] = text.split(' ');
    return rest.length ? { field, message: rest.join(' ') } : { field: '', message: text };
  }
}
