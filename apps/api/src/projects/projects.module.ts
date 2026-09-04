import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Site } from '../customers/entities/site.entity';
import { Project } from './entities/project.entity';
import { ProjectAssignment } from './entities/project-assignment.entity';
import { ProjectStatusChange } from './entities/project-status-change.entity';
import { ProjectUpdate } from './entities/project-update.entity';
import { ProjectUpdateAsset } from './entities/project-update-asset.entity';
import { MediaAsset } from '../media/entities/media-asset.entity';
import { MediaModule } from '../media/media.module';
import { ProjectsService } from './projects.service';
import { ProjectsController } from './projects.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Project, ProjectAssignment, ProjectStatusChange,
      ProjectUpdate, ProjectUpdateAsset, MediaAsset, Site,
    ]),
    // La nota que va al cliente eleva sus fotos, y esa regla vive en MediaService.
    MediaModule,
  ],
  controllers: [ProjectsController],
  providers: [ProjectsService],
  exports: [ProjectsService],
})
export class ProjectsModule {}
