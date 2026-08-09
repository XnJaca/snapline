import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MediaAsset } from '../media/entities/media-asset.entity';
import { BeforeAfterPair } from '../media/entities/before-after-pair.entity';
import { Project } from '../projects/entities/project.entity';
import { PublishedProject } from './entities/published-project.entity';
import { PublishedProjectAsset } from './entities/published-project-asset.entity';
import { SocialPost } from './entities/social-post.entity';
import { SocialPostAsset } from './entities/social-post-asset.entity';
import { Testimonial } from './entities/testimonial.entity';
import { PublishingService } from './publishing.service';
import { PublicPortfolioController, PublishingController } from './publishing.controller';

@Module({
  imports: [TypeOrmModule.forFeature([
    PublishedProject, PublishedProjectAsset, SocialPost, SocialPostAsset,
    Testimonial, BeforeAfterPair, MediaAsset, Project,
  ])],
  controllers: [PublishingController, PublicPortfolioController],
  providers: [PublishingService],
})
export class PublishingModule {}
