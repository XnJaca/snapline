import { Module } from '@nestjs/common';
import { CustomersModule } from '../customers/customers.module';
import { ProjectsModule } from '../projects/projects.module';
import { MediaModule } from '../media/media.module';
import { TimeEntriesModule } from '../time-entries/time-entries.module';
import { SyncService } from './sync.service';
import { SyncController } from './sync.controller';

@Module({
  imports: [CustomersModule, ProjectsModule, MediaModule, TimeEntriesModule],
  controllers: [SyncController],
  providers: [SyncService],
})
export class SyncModule {}
