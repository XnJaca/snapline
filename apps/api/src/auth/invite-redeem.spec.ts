import * as bcrypt from 'bcryptjs';
import { AuthService } from './auth.service';

/**
 * El canje es la única puerta de entrada de alguien nuevo, y la única escritura
 * del sistema que ocurre antes de saber la empresa.
 */
describe('AuthService — canje de invitación', () => {
  // Los dos tests que establecen contraseña hashean de verdad, con el costo 12
  // de producción: casi un segundo cada uno, y bajo la carga de la suite completa
  // se pasaban de los 5s por default. Un rojo intermitente enseña a ignorar los
  // rojos, así que el tiempo se declara en vez de dejarlo al azar.
  jest.setTimeout(20_000);

  const membership = {
    id: 'm1',
    companyId: 'c1',
    companyName: 'Professional Construction',
    role: 'WORKER' as const,
    tokenVersion: 0,
  };

  const HOY = new Date('2026-09-04T12:00:00Z');
  const EN_UNA_SEMANA = new Date('2026-09-11T12:00:00Z');
  const AYER = new Date('2026-09-03T12:00:00Z');

  interface Invite {
    id: string;
    companyId: string;
    role: 'WORKER';
    inviteCodeHash: string;
    inviteExpiresAt: Date;
    inviteAttempts: number;
  }

  function build(opts: { passwordHash?: string | null; invites: Invite[] }) {
    const user = {
      id: 'u1', name: 'Carlos', locale: 'es',
      email: null, phone: '+13015550142',
      passwordHash: opts.passwordHash ?? null,
    };
    const users = {
      createQueryBuilder: jest.fn(() => ({
        addSelect: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        getOne: jest.fn().mockResolvedValue(user),
      })),
      findOneOrFail: jest.fn().mockResolvedValue(user),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    const memberships = {
      update: jest.fn().mockResolvedValue({ affected: 1 }),
      increment: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    const dataSource = {
      query: jest.fn((sql: string) =>
        Promise.resolve(sql.includes('auth_invites_for_user') ? opts.invites : [membership]),
      ),
    };
    const jwt = { signAsync: jest.fn().mockResolvedValue('token') };
    const tenants = { runAs: jest.fn((_ctx: unknown, work: () => Promise<unknown>) => work()) };

    const service = new AuthService(
      users as never, memberships as never, dataSource as never, jwt as never, tenants as never,
    );
    return { service, users, memberships, tenants };
  }

  async function invite(code: string, over: Partial<Invite> = {}): Promise<Invite> {
    return {
      id: 'm1', companyId: 'c1', role: 'WORKER',
      inviteCodeHash: await bcrypt.hash(code, 4),
      inviteExpiresAt: EN_UNA_SEMANA,
      inviteAttempts: 0,
      ...over,
    };
  }

  beforeAll(() => jest.useFakeTimers({ now: HOY, doNotFake: ['setTimeout'] }));
  afterAll(() => jest.useRealTimers());

  it('activa la membresía y establece la contraseña elegida', async () => {
    const { service, users, memberships } = build({ invites: [await invite('482915')] });

    await service.redeemInvite('301-555-0142', '482915', 'clave-nueva');

    expect(users.update).toHaveBeenCalledWith(
      { id: 'u1' },
      expect.objectContaining({ passwordHash: expect.any(String) }),
    );
    expect(memberships.update).toHaveBeenCalledWith(
      { id: 'm1' },
      expect.objectContaining({ status: 'ACTIVE', inviteCodeHash: null }),
    );
  });

  it('escribe la activación dentro del contexto de la empresa que devolvió la lectura', async () => {
    const { service, tenants } = build({ invites: [await invite('482915')] });

    await service.redeemInvite('+13015550142', '482915', 'clave-nueva');

    // Sin runAs el UPDATE no atraviesa RLS: no falla, no escribe.
    expect(tenants.runAs).toHaveBeenCalledWith(
      expect.objectContaining({ companyId: 'c1', membershipId: 'm1' }),
      expect.any(Function),
    );
  });

  it('no le pide contraseña nueva a quien ya trabaja para otro contratista', async () => {
    const yaTiene = await bcrypt.hash('la-de-siempre', 4);
    const { service, users, memberships } = build({ passwordHash: yaTiene, invites: [await invite('482915')] });

    await service.redeemInvite('+13015550142', '482915');

    expect(users.update).not.toHaveBeenCalled();
    expect(memberships.update).toHaveBeenCalledWith({ id: 'm1' }, expect.objectContaining({ status: 'ACTIVE' }));
  });

  it('un código vencido se distingue de uno inválido', async () => {
    const { service } = build({ invites: [await invite('482915', { inviteExpiresAt: AYER })] });

    await expect(service.redeemInvite('+13015550142', '482915', 'x'.repeat(8)))
      .rejects.toMatchObject({ code: 'INVITE_CODE_EXPIRED' });
  });

  it('un código equivocado suma el intento en todas las invitaciones vivas', async () => {
    const { service, memberships } = build({
      invites: [
        await invite('482915'),
        await invite('111111', { id: 'm2', companyId: 'c2' }),
      ],
    });

    await expect(service.redeemInvite('+13015550142', '999999', 'x'.repeat(8)))
      .rejects.toMatchObject({ code: 'INVITE_CODE_INVALID' });

    // Sumárselo a una sola deja la otra sin contar: fuerza bruta gratis para
    // quien tenga una segunda invitación abierta.
    expect(memberships.increment).toHaveBeenCalledWith({ id: 'm1' }, 'inviteAttempts', 1);
    expect(memberships.increment).toHaveBeenCalledWith({ id: 'm2' }, 'inviteAttempts', 1);
  });

  it('bloquea a los diez intentos, incluso con el código correcto', async () => {
    const { service } = build({ invites: [await invite('482915', { inviteAttempts: 10 })] });

    await expect(service.redeemInvite('+13015550142', '482915', 'x'.repeat(8)))
      .rejects.toMatchObject({ code: 'INVITE_TOO_MANY_ATTEMPTS' });
  });

  it('el reintento de un canje ya aplicado devuelve la sesión, no un error', async () => {
    // La petición llegó, activó la membresía y la respuesta se perdió: el código
    // ya no existe y la contraseña recién elegida sí (regla 19).
    const yaCanjeado = await bcrypt.hash('clave-nueva', 4);
    const { service } = build({ passwordHash: yaCanjeado, invites: [] });

    const result = await service.redeemInvite('+13015550142', '482915', 'clave-nueva');

    expect(result.accessToken).toBe('token');
  });

  it('sin invitación viva y con la contraseña equivocada, sigue siendo inválido', async () => {
    const otra = await bcrypt.hash('otra-cosa', 4);
    const { service } = build({ passwordHash: otra, invites: [] });

    await expect(service.redeemInvite('+13015550142', '482915', 'clave-nueva'))
      .rejects.toMatchObject({ code: 'INVITE_CODE_INVALID' });
  });

  it('canjear sin elegir contraseña, sin tener una, no activa nada', async () => {
    const { service, memberships } = build({ invites: [await invite('482915')] });

    await expect(service.redeemInvite('+13015550142', '482915'))
      .rejects.toMatchObject({ code: 'VALIDATION_FAILED' });
    expect(memberships.update).not.toHaveBeenCalled();
  });
});
