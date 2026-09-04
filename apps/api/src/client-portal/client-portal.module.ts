import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Project } from '../projects/entities/project.entity';
import { MediaAsset } from '../media/entities/media-asset.entity';
import { ServiceOffer } from '../leads/entities/service-offer.entity';
import { Lead } from '../leads/entities/lead.entity';
import { ClientAccess } from './entities/client-access.entity';
import { ProjectUpdate } from '../projects/entities/project-update.entity';
import { ProjectUpdateAsset } from '../projects/entities/project-update-asset.entity';
import { ClientPortalService } from './client-portal.service';
import { ClientAccessController, ClientPortalController } from './client-portal.controller';

@Module({
  imports: [TypeOrmModule.forFeature([
    ClientAccess, ProjectUpdate, ProjectUpdateAsset, Project, MediaAsset, ServiceOffer, Lead,
  ])],
  controllers: [ClientAccessController, ClientPortalController],
  providers: [ClientPortalService],
})
export class ClientPortalModule {}
