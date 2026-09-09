import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Crew } from './entities/crew.entity';
import { CrewMember } from './entities/crew-member.entity';
import { ProjectAssignment } from '../projects/entities/project-assignment.entity';
import { CrewsService } from './crews.service';
import { CrewsController } from './crews.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Crew, CrewMember, ProjectAssignment])],
  controllers: [CrewsController],
  providers: [CrewsService],
})
export class CrewsModule {}
