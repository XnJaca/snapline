import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Project } from '../projects/entities/project.entity';
import { MediaAsset } from './entities/media-asset.entity';
import { MediaService } from './media.service';
import { MediaController } from './media.controller';

@Module({
  imports: [TypeOrmModule.forFeature([MediaAsset, Project])],
  controllers: [MediaController],
  providers: [MediaService],
  exports: [MediaService],
})
export class MediaModule {}
