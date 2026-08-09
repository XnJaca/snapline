import { ApiProperty } from '@nestjs/swagger';
import { MembershipRole } from '../entities/membership.entity';

/** Lo que el token trae adentro: a qué empresa y con qué membresía está scopeado. */
export class SessionDto {
  @ApiProperty({ format: 'uuid' })
  companyId!: string;

  @ApiProperty({ format: 'uuid' })
  membershipId!: string;

  @ApiProperty({ format: 'uuid' })
  userId!: string;

  @ApiProperty({ enum: ['OWNER', 'ADMIN', 'FOREMAN', 'WORKER', 'ACCOUNTANT'] })
  role!: MembershipRole;
}
