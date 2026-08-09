import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { RequirePermission } from '../auth/decorators/require-permission.decorator';
import { CurrentTenant } from '../auth/decorators/current-tenant.decorator';
import { TenantContext } from '../tenant/tenant-context';
import { ProjectsService } from './projects.service';
import { AssignCrewDto, CreateProjectDto, UpdateProjectDto } from './dto/project.dto';
import { Project } from './entities/project.entity';
import { ProjectAssignment } from './entities/project-assignment.entity';

@Controller('projects')
export class ProjectsController {
  constructor(private readonly service: ProjectsService) {}

  @RequirePermission('projects.read')
  @Get()
  list(): Promise<Project[]> {
    return this.service.list();
  }

  @RequirePermission('projects.read')
  @Get(':id')
  get(@Param('id', ParseUUIDPipe) id: string): Promise<Project> {
    return this.service.get(id);
  }

  @RequirePermission('projects.write')
  @Post()
  create(@Body() dto: CreateProjectDto, @CurrentTenant() tenant: TenantContext): Promise<Project> {
    return this.service.create(dto, tenant);
  }

  @RequirePermission('projects.write')
  @Patch(':id')
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateProjectDto): Promise<Project> {
    return this.service.update(id, dto);
  }

  @RequirePermission('projects.write')
  @Delete(':id')
  @HttpCode(204)
  remove(@Param('id', ParseUUIDPipe) id: string): Promise<void> {
    return this.service.remove(id);
  }

  @RequirePermission('crews.write')
  @Post(':id/assignments')
  assign(@Param('id', ParseUUIDPipe) id: string, @Body() dto: AssignCrewDto, @CurrentTenant() tenant: TenantContext): Promise<ProjectAssignment> {
    return this.service.assign(id, dto, tenant);
  }

  @RequirePermission('projects.read')
  @Get(':id/assignments')
  assignments(@Param('id', ParseUUIDPipe) id: string): Promise<ProjectAssignment[]> {
    return this.service.listAssignments(id);
  }
}
