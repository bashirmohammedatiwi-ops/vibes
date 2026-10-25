import { Body, Controller, Get, Post, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { RequireStaffPermissions } from '../../common/decorators/staff-permissions.decorator';
import { HomeLayoutService } from './home-layout.service';

@ApiTags('home')
@Controller('home')
export class HomeLayoutController {
  constructor(private readonly home: HomeLayoutService) {}

  @Public()
  @Get('layout')
  layout() {
    return this.home.layout();
  }
}

@ApiTags('admin')
@ApiBearerAuth()
@Roles(UserRole.ADMIN, UserRole.STAFF)
@Controller('admin/home-layout')
export class AdminHomeLayoutController {
  constructor(private readonly home: HomeLayoutService) {}

  @Get()
  get() {
    return this.home.admin();
  }

  @Put()
  @RequireStaffPermissions('content.write')
  update(@CurrentUser() user: AuthUser, @Body() body: Record<string, unknown>) {
    return this.home.update(user, body);
  }

  @Post('reset')
  @RequireStaffPermissions('content.write')
  reset(@CurrentUser() user: AuthUser) {
    return this.home.reset(user);
  }
}
