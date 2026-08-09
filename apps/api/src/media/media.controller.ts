import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { RequirePermission } from '../auth/decorators/require-permission.decorator';
import { CurrentTenant } from '../auth/decorators/current-tenant.decorator';
import { TenantContext } from '../tenant/tenant-context';
import { MediaService } from './media.service';
import { RegisterAssetDto, SetVisibilityDto } from './dto/media.dto';
import { MediaAsset } from './entities/media-asset.entity';

@Controller('media')
export class MediaController {
  constructor(private readonly service: MediaService) {}

  @RequirePermission('media.read')
  @Get()
  list(@Query('projectId', ParseUUIDPipe) projectId: string): Promise<MediaAsset[]> {
    return this.service.list(projectId);
  }

  @RequirePermission('media.capture')
  @Post()
  register(@Body() dto: RegisterAssetDto, @CurrentTenant() tenant: TenantContext) {
    return this.service.register(dto, tenant);
  }

  @RequirePermission('media.read')
  @Get(':id/url')
  downloadUrl(@Param('id', ParseUUIDPipe) id: string) {
    return this.service.downloadUrl(id);
  }

  @RequirePermission('media.capture')
  @Post(':id/uploaded')
  @HttpCode(200)
  markUploaded(@Param('id', ParseUUIDPipe) id: string): Promise<MediaAsset> {
    return this.service.markUploaded(id);
  }

  @RequirePermission('media.visibility')
  @Post(':id/strip-exif')
  @HttpCode(200)
  stripExif(@Param('id', ParseUUIDPipe) id: string): Promise<MediaAsset> {
    return this.service.stripExif(id);
  }

  @RequirePermission('media.visibility')
  @Post(':id/visibility')
  @HttpCode(200)
  setVisibility(@Param('id', ParseUUIDPipe) id: string, @Body() dto: SetVisibilityDto): Promise<MediaAsset> {
    return this.service.setVisibility(id, dto);
  }
}
