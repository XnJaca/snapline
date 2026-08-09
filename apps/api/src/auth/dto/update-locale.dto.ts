import { ApiProperty } from '@nestjs/swagger';
import { IsIn } from 'class-validator';
import { Locale } from '../entities/app-user.entity';

export class UpdateLocaleDto {
  // El locale vive en el usuario y no en la membresía: la persona habla un
  // idioma, no uno por empresa.
  @ApiProperty({ enum: ['en', 'es'] })
  @IsIn(['en', 'es'])
  locale!: Locale;
}
