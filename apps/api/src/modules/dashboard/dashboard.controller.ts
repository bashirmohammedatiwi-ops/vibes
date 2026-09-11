import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { Roles } from '../../common/decorators/roles.decorator';
import { AdminDashboardService } from '../admin/admin-dashboard.service';

@ApiTags('dashboard')
@ApiBearerAuth()
@Controller('dashboard')
export class DashboardController {
  constructor(private readonly dashboard: AdminDashboardService) {}

  @Get('stats')
  @Roles(UserRole.ADMIN, UserRole.STAFF)
  stats() {
    return this.dashboard.stats();
  }
}
