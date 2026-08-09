import { HttpException } from '@nestjs/common';
import { ErrorCode } from './error-codes';

export interface FieldError {
  field: string;
  message: string;
}

/**
 * Excepción con código estable. Se usa en vez de las de Nest cuando el cliente
 * necesita distinguir *este* rechazo de otro del mismo status.
 */
export class ApiError extends HttpException {
  constructor(
    readonly code: ErrorCode,
    message: string,
    status: number,
    readonly details: FieldError[] = [],
  ) {
    super({ code, message, details }, status);
  }

  static badRequest(code: ErrorCode, message: string, details: FieldError[] = []): ApiError {
    return new ApiError(code, message, 400, details);
  }
  static unauthorized(code: ErrorCode, message: string): ApiError {
    return new ApiError(code, message, 401);
  }
  static forbidden(code: ErrorCode, message: string): ApiError {
    return new ApiError(code, message, 403);
  }
  static notFound(code: ErrorCode, message: string): ApiError {
    return new ApiError(code, message, 404);
  }
  static conflict(code: ErrorCode, message: string): ApiError {
    return new ApiError(code, message, 409);
  }
  static unavailable(code: ErrorCode, message: string): ApiError {
    return new ApiError(code, message, 503);
  }
}
