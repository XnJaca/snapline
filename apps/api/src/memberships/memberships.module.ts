import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Membership } from '../auth/entities/membership.entity';
import { AppUser } from '../auth/entities/app-user.entity';
import { CrewMember } from '../crews/entities/crew-member.entity';
import { MembershipsService } from './memberships.service';
import { MembershipsController } from './memberships.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Membership, AppUser, CrewMember])],
  controllers: [MembershipsController],
  providers: [MembershipsService],
  exports: [MembershipsService],
})
export class MembershipsModule {}
