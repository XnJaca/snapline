import { IsNotEmpty, IsString, MinLength } from 'class-validator';

export class LoginDto {
  // Email o teléfono: muchos trabajadores no usan email.
  @IsString()
  @IsNotEmpty()
  identifier!: string;

  @IsString()
  @MinLength(8)
  password!: string;
}
