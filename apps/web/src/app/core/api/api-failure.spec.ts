import { HttpErrorResponse } from '@angular/common/http';
import { toApiFailure } from './api-failure';

/**
 * Confundir "no hubo respuesta" con "hubo respuesta con error" es lo que hace que
 * una caída de red se muestre como contraseña equivocada.
 */
describe('toApiFailure', () => {
  it('status 0 es falta de conexión, no un error del API', () => {
    const sinRed = new HttpErrorResponse({ status: 0, error: new ProgressEvent('error') });

    expect(toApiFailure(sinRed)).toEqual({ kind: 'network' });
  });

  it('lee el código estable del envelope de ADR-0011', () => {
    const rechazo = new HttpErrorResponse({
      status: 401,
      error: { code: 'INVALID_CREDENTIALS', message: 'Credenciales inválidas' },
    });

    expect(toApiFailure(rechazo)).toEqual({
      kind: 'http', status: 401, code: 'INVALID_CREDENTIALS', message: 'Credenciales inválidas',
    });
  });

  it('una respuesta de error sin envelope no se queda sin código', () => {
    const roto = new HttpErrorResponse({ status: 502, error: '<html>bad gateway</html>' });

    expect(toApiFailure(roto)).toMatchObject({ kind: 'http', code: 'INTERNAL_ERROR' });
  });
});
