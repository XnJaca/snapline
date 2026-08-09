import { NotFoundException } from '@nestjs/common';
import { AuthService } from './auth.service';
import { AppUser } from './entities/app-user.entity';

/**
 * El idioma es del usuario, no de la membresía: una persona que trabaja para dos
 * contratistas habla el mismo idioma en los dos.
 */
describe('AuthService.updateLocale', () => {
  const usuario = {
    id: 'u1',
    name: 'Carlos Ramírez',
    locale: 'es',
    email: null,
    phone: '+15551234567',
  } as AppUser;

  function build(affected: number) {
    const users = {
      update: jest.fn().mockResolvedValue({ affected }),
      findOneOrFail: jest.fn().mockResolvedValue({ ...usuario, locale: 'en' }),
    };
    const service = new AuthService(
      users as never,
      {} as never,
      {} as never,
      {} as never,
    );
    return { service, users };
  }

  it('actualiza el idioma y devuelve el usuario', async () => {
    const { service, users } = build(1);

    const result = await service.updateLocale('u1', 'en');

    expect(result.locale).toBe('en');
    expect(result.id).toBe('u1');
    expect(users.update).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'u1' }),
      { locale: 'en' },
    );
  });

  // El id sale del token; si no existe o está borrado, no se toca nada.
  it('falla si el usuario no existe', async () => {
    const { service } = build(0);

    await expect(service.updateLocale('fantasma', 'en')).rejects.toThrow(
      NotFoundException,
    );
  });

  it('no acepta actualizar por un id que no sea el de la sesión', async () => {
    const { service, users } = build(1);

    await service.updateLocale('u1', 'es');

    // El servicio filtra siempre por el id recibido del controller, que sale
    // del token. Nunca por uno del cuerpo del request.
    const [where] = users.update.mock.calls[0] as [{ id: string }];
    expect(where.id).toBe('u1');
  });
});
