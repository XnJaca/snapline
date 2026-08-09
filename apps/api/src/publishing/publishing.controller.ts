import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { RequirePermission } from '../auth/decorators/require-permission.decorator';
import { Public } from '../auth/decorators/public.decorator';
import { CurrentTenant } from '../auth/decorators/current-tenant.decorator';
import { TenantContext } from '../tenant/tenant-context';
import { PublishingService } from './publishing.service';
import { BeforeAfterDto, CreateTestimonialDto, MarkContentUsedDto, PublishProjectDto } from './dto/publishing.dto';
import { PublishedProject } from './entities/published-project.entity';
import { BeforeAfterPair } from '../media/entities/before-after-pair.entity';
import { Testimonial } from './entities/testimonial.entity';
import { SocialPost } from './entities/social-post.entity';

@Controller()
export class PublishingController {
  constructor(private readonly service: PublishingService) {}

  @RequirePermission('projects.publish')
  @Post('projects/:id/publish')
  publish(@Param('id', ParseUUIDPipe) id: string, @Body() dto: PublishProjectDto, @CurrentTenant() tenant: TenantContext): Promise<PublishedProject> {
    return this.service.publish(id, dto, tenant);
  }

  @RequirePermission('projects.publish')
  @Post('published/:id/unpublish')
  @HttpCode(200)
  unpublish(@Param('id', ParseUUIDPipe) id: string): Promise<PublishedProject> {
    return this.service.unpublish(id);
  }

  @RequirePermission('projects.read')
  @Get('published')
  list(): Promise<PublishedProject[]> {
    return this.service.list();
  }

  @RequirePermission('media.visibility')
  @Post('projects/:id/before-after')
  addPair(@Param('id', ParseUUIDPipe) id: string, @Body() dto: BeforeAfterDto, @CurrentTenant() tenant: TenantContext): Promise<BeforeAfterPair> {
    return this.service.addPair(id, dto, tenant);
  }

  @RequirePermission('media.read')
  @Get('projects/:id/before-after')
  pairs(@Param('id', ParseUUIDPipe) id: string): Promise<BeforeAfterPair[]> {
    return this.service.listPairs(id);
  }

  @RequirePermission('projects.write')
  @Post('testimonials')
  createTestimonial(@Body() dto: CreateTestimonialDto, @CurrentTenant() tenant: TenantContext): Promise<Testimonial> {
    return this.service.createTestimonial(dto, tenant);
  }

  @RequirePermission('projects.publish')
  @Post('testimonials/:id/approve')
  @HttpCode(200)
  approveTestimonial(@Param('id', ParseUUIDPipe) id: string): Promise<Testimonial> {
    return this.service.approveTestimonial(id);
  }

  @RequirePermission('projects.read')
  @Get('social-feed')
  socialFeed(): Promise<unknown[]> {
    return this.service.socialFeed();
  }

  @RequirePermission('projects.publish')
  @Post('social-posts')
  markUsed(@Body() dto: MarkContentUsedDto, @CurrentTenant() tenant: TenantContext): Promise<SocialPost> {
    return this.service.markContentUsed(dto, tenant);
  }
}

/** Anónimo: es lo que consume el sitio público en Astro. */
@Controller('public')
export class PublicPortfolioController {
  constructor(private readonly service: PublishingService) {}

  @Public()
  @Get(':companySlug/portfolio')
  portfolio(@Param('companySlug') companySlug: string): Promise<unknown[]> {
    return this.service.publicPortfolio(companySlug);
  }
}
