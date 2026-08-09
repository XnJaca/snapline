import { ApiProperty } from '@nestjs/swagger';
import { Locale } from '../entities/app-user.entity';
import { MembershipRole } from '../entities/membership.entity';

export class AuthUserDto {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty({ enum: ['en', 'es'] })
  locale!: Locale;

  @ApiProperty({ nullable: true, type: String })
  email!: string | null;

  @ApiProperty({ nullable: true, type: String })
  phone!: string | null;
}

export class AuthMembershipDto {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty({ format: 'uuid' })
  companyId!: string;

  @ApiProperty()
  companyName!: string;

  @ApiProperty({ enum: ['OWNER', 'ADMIN', 'FOREMAN', 'WORKER', 'ACCOUNTANT'] })
  role!: MembershipRole;
}

export class AuthResultDto {
  @ApiProperty()
  accessToken!: string;

  @ApiProperty()
  refreshToken!: string;

  @ApiProperty({ description: 'Segundos de vida del accessToken' })
  expiresInSeconds!: number;

  @ApiProperty({ type: AuthUserDto })
  user!: AuthUserDto;

  @ApiProperty({
    type: AuthMembershipDto,
    description: 'La membresía a la que quedó scopeado el token.',
  })
  membership!: AuthMembershipDto;

  @ApiProperty({
    type: [AuthMembershipDto],
    description:
      'Todas las membresías activas. Una persona puede trabajar para más de un ' +
      'contratista; el token apunta a una sola y el cliente ofrece cambiar.',
  })
  memberships!: AuthMembershipDto[];
}
