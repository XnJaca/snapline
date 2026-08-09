import { BadRequestException, Controller, Get, Query } from '@nestjs/common';
import { RequirePermission } from '../auth/decorators/require-permission.decorator';
import { JobCostRow, ReportsService, TimesheetRow } from './reports.service';

@Controller('reports')
export class ReportsController {
  constructor(private readonly service: ReportsService) {}

  @RequirePermission('reports.read')
  @Get('timesheet')
  timesheet(@Query('from') from: string, @Query('to') to: string): Promise<TimesheetRow[]> {
    if (!from || !to) throw new BadRequestException('Faltan los parámetros from y to');
    return this.service.timesheet(from, to);
  }

  @RequirePermission('reports.read')
  @Get('job-cost')
  jobCost(): Promise<JobCostRow[]> {
    return this.service.jobCost();
  }
}
