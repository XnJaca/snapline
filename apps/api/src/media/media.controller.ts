import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiCreatedResponse, ApiOkResponse } from '@nestjs/swagger';
import { RequirePermission } from '../auth/decorators/require-permission.decorator';
import { CurrentTenant } from '../auth/decorators/current-tenant.decorator';
import { TenantContext } from '../tenant/tenant-context';
import { MediaService } from './media.service';
import { MediaAssetDto, RegisterAssetDto, RegisterAssetResponseDto, SetTagsDto, SetVisibilityDto, SignedUrlDto } from './dto/media.dto';
import { MediaAsset } from './entities/media-asset.entity';

@Controller('media')
export class MediaController {
  constructor(private readonly service: MediaService) {}

  @RequirePermission('media.read')
  @Get()
  @ApiOkResponse({ type: MediaAssetDto, isArray: true })
  list(@Query('projectId', ParseUUIDPipe) projectId: string): Promise<MediaAssetDto[]> {
    return this.service.list(projectId);
  }

  @RequirePermission('media.capture')
  @Post()
  @ApiCreatedResponse({ type: RegisterAssetResponseDto })
  register(
    @Body() dto: RegisterAssetDto,
    @CurrentTenant() tenant: TenantContext,
  ): Promise<RegisterAssetResponseDto> {
    return this.service.register(dto, tenant);
  }

  @RequirePermission('media.read')
  @Get(':id/url')
  @ApiOkResponse({ type: SignedUrlDto })
  downloadUrl(@Param('id', ParseUUIDPipe) id: string): Promise<SignedUrlDto> {
    return this.service.downloadUrl(id);
  }

  @RequirePermission('media.capture')
  @Get(':id/upload-url')
  @ApiOkResponse({ type: SignedUrlDto })
  uploadUrl(@Param('id', ParseUUIDPipe) id: string): Promise<SignedUrlDto> {
    return this.service.uploadUrl(id);
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

  @RequirePermission('media.delete')
  @Delete(':id')
  @HttpCode(204)
  remove(@Param('id', ParseUUIDPipe) id: string): Promise<void> {
    return this.service.remove(id);
  }

  // Etiquetar es parte de capturar: quien toma la foto sabe si es el antes.
  @RequirePermission('media.capture')
  @Post(':id/tags')
  @HttpCode(200)
  @ApiOkResponse({ type: MediaAssetDto })
  setTags(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SetTagsDto,
    @CurrentTenant() tenant: TenantContext,
  ): Promise<MediaAssetDto> {
    return this.service.setTags(id, dto, tenant);
  }
}
