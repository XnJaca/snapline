import { Global, Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppUser } from './entities/app-user.entity';
import { Membership } from './entities/membership.entity';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { WebAuthController } from './web-auth.controller';

@Global()
@Module({
  imports: [
    TypeOrmModule.forFeature([AppUser, Membership]),
    JwtModule.registerAsync({
      useFactory: () => ({
        secret: process.env.JWT_SECRET ?? 'dev-only-change-me',
        signOptions: { issuer: 'snapline' },
      }),
    }),
  ],
  controllers: [AuthController, WebAuthController],
  providers: [AuthService],
  exports: [AuthService, JwtModule],
})
export class AuthModule {}
