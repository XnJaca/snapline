import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Membership } from '../auth/entities/membership.entity';
import { Project } from '../projects/entities/project.entity';
import { TimeEntry } from './entities/time-entry.entity';
import { TimeEntryEdit } from './entities/time-entry-edit.entity';
import { TimeEntriesService } from './time-entries.service';
import { TimeEntriesController } from './time-entries.controller';

@Module({
  imports: [TypeOrmModule.forFeature([TimeEntry, TimeEntryEdit, Project, Membership])],
  controllers: [TimeEntriesController],
  providers: [TimeEntriesService],
  exports: [TimeEntriesService],
})
export class TimeEntriesModule {}
