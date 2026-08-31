import { BadRequestException, Controller, Get, Query } from '@nestjs/common';
import { ApiOkResponse } from '@nestjs/swagger';
import { RequirePermission } from '../auth/decorators/require-permission.decorator';
import { JobCostRow, ReportsService, TimesheetRow } from './reports.service';
import { JobCostRowDto, TimesheetRowDto } from './dto/report-row.dto';

@Controller('reports')
export class ReportsController {
  constructor(private readonly service: ReportsService) {}

  @RequirePermission('reports.read')
  @Get('timesheet')
  @ApiOkResponse({ type: [TimesheetRowDto] })
  timesheet(@Query('from') from: string, @Query('to') to: string): Promise<TimesheetRow[]> {
    if (!from || !to) throw new BadRequestException('Faltan los parámetros from y to');
    return this.service.timesheet(from, to);
  }

  @RequirePermission('reports.read')
  @Get('job-cost')
  @ApiOkResponse({ type: [JobCostRowDto] })
  jobCost(): Promise<JobCostRow[]> {
    return this.service.jobCost();
  }
}
