import { ApiError } from '../common/errors/api-error';
import { AuthService } from './auth.service';

/**
 * El contador que hace que cerrar sesión signifique algo. Un JWT autofirmado no
 * se revoca: o se compara contra estado, o vale sus 30 días completos.
 */
describe('AuthService — token_version', () => {
  const membership = {
    id: 'm1',
    companyId: 'c1',
    companyName: 'Professional Construction',
    role: 'OWNER' as const,
    tokenVersion: 3,
  };

  function build(claims: Record<string, unknown>) {
    const users = { findOne: jest.fn().mockResolvedValue({ id: 'u1', name: 'William', locale: 'en', email: 'w@test.local', phone: null }) };
    const memberships = { increment: jest.fn().mockResolvedValue({ affected: 1 }) };
    const dataSource = { query: jest.fn().mockResolvedValue([membership]) };
    const jwt = {
      verifyAsync: jest.fn().mockResolvedValue(claims),
      signAsync: jest.fn().mockResolvedValue('token.nuevo'),
    };
    const tenants = { runAs: jest.fn((_ctx: unknown, work: () => Promise<unknown>) => work()) };
    const service = new AuthService(
      users as never,
      memberships as never,
      dataSource as never,
      jwt as never,
      tenants as never,
    );
    return { service, memberships, jwt, tenants };
  }

  const refresh = { sub: 'u1', companyId: 'c1', membershipId: 'm1', role: 'OWNER', typ: 'refresh' };

  it('emite el claim con la versión de la membresía', async () => {
    const { service, jwt } = build({ ...refresh, tv: 3 });

    await service.refresh('cookie');

    const [claims] = jwt.signAsync.mock.calls[0] as [{ tv: number }];
    expect(claims.tv).toBe(3);
  });

  it('rechaza el refresh cuya versión quedó vieja', async () => {
    const { service } = build({ ...refresh, tv: 2 });

    await expect(service.refresh('cookie')).rejects.toMatchObject({ code: 'TOKEN_INVALID' });
  });

  /**
   * El criterio que el `?? 0` hace posible: ningún token emitido antes del deploy
   * lleva el claim, y con igualdad estricta se caerían todas las sesiones vivas.
   */
  it('un token sin el claim vale como versión 0 y sigue sirviendo', async () => {
    const { service } = build({ ...refresh });
    (service as unknown as { dataSource: { query: jest.Mock } }).dataSource.query
      .mockResolvedValue([{ ...membership, tokenVersion: 0 }]);

    await expect(service.refresh('cookie')).resolves.toMatchObject({ accessToken: 'token.nuevo' });
  });

  it('y si esa membresía ya cerró sesión alguna vez, el token viejo no entra', async () => {
    const { service } = build({ ...refresh });

    await expect(service.refresh('cookie')).rejects.toBeInstanceOf(ApiError);
  });

  it('cerrar sesión sube el contador de esa membresía, dentro de su empresa', async () => {
    const { service, memberships, tenants } = build({ ...refresh, tv: 3 });

    await service.logout('cookie');

    expect(memberships.increment).toHaveBeenCalledWith({ id: 'm1' }, 'tokenVersion', 1);
    const [ctx] = tenants.runAs.mock.calls[0] as [{ companyId: string }, unknown];
    expect(ctx.companyId).toBe('c1');
  });

  it('es idempotente: sin cookie o con una ilegible no toca nada ni falla', async () => {
    const { service, memberships } = build({});
    await expect(service.logout(null)).resolves.toBeUndefined();

    const roto = build({});
    roto.jwt.verifyAsync.mockRejectedValue(new Error('firma inválida'));
    await expect(roto.service.logout('basura')).resolves.toBeUndefined();

    expect(memberships.increment).not.toHaveBeenCalled();
    expect(roto.memberships.increment).not.toHaveBeenCalled();
  });

  // Un access token no cierra sesión: solo el refresh, que es el que la sostiene.
  it('no acepta un token que no sea de refresh', async () => {
    const { service, memberships } = build({ ...refresh, typ: undefined });

    await service.logout('access');

    expect(memberships.increment).not.toHaveBeenCalled();
  });
});
