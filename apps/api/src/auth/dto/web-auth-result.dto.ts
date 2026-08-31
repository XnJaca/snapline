import { OmitType } from '@nestjs/swagger';
import { AuthResultDto } from './auth-result.dto';

/**
 * Lo mismo que el móvil recibe, **menos el refresh token**: en web viaja en una
 * cookie `httpOnly` y nunca en el cuerpo, que es el punto entero de ADR-0014.
 *
 * No se reusa `AuthResultDto` porque ahí el campo es obligatorio: devolverlo
 * vacío lo dejaría en `openapi.json` como siempre presente.
 */
export class WebAuthResultDto extends OmitType(AuthResultDto, ['refreshToken'] as const) {}
