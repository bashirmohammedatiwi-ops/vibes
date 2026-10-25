import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Put, Query } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { RequireStaffPermissions } from '../../common/decorators/staff-permissions.decorator';
import { NadeemService, NadeemSessionInput } from './nadeem.service';

/** تطبيق الزبون — إعدادات نديم وتسجيل الجلسات. */
@ApiTags('nadeem')
@Controller('nadeem')
export class NadeemController {
  constructor(private readonly nadeem: NadeemService) {}

  @Public()
  @Get('config')
  config() {
    return this.nadeem.config();
  }

  @Public()
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Post('sessions')
  log(@CurrentUser() user: AuthUser | undefined, @Body() body: Record<string, unknown>) {
    return this.nadeem.logSession(user?.id, body as NadeemSessionInput);
  }

  @Public()
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Post('sessions/:id/click')
  click(@Param('id', ParseUUIDPipe) id: string, @Body() body: Record<string, unknown>) {
    const propertyId = typeof body?.propertyId === 'string' ? body.propertyId : '';
    return this.nadeem.logClick(id, propertyId);
  }
}

/** لوحة التحكم — قسم نديم. */
@ApiTags('admin')
@ApiBearerAuth()
@Roles(UserRole.ADMIN, UserRole.STAFF)
@Controller('admin/nadeem')
export class AdminNadeemController {
  constructor(private readonly nadeem: NadeemService) {}

  @Get()
  get() {
    return this.nadeem.adminConfig();
  }

  @Put()
  @RequireStaffPermissions('nadeem.write')
  update(@CurrentUser() user: AuthUser, @Body() body: Record<string, unknown>) {
    return this.nadeem.update(user, body);
  }

  @Post('reset')
  @RequireStaffPermissions('nadeem.write')
  reset(@CurrentUser() user: AuthUser) {
    return this.nadeem.reset(user);
  }

  @Get('stats')
  stats(@Query('days') days?: string) {
    return this.nadeem.stats(Number(days) || 30);
  }

  @Get('sessions')
  sessions(@Query('page') page?: string, @Query('pageSize') pageSize?: string) {
    return this.nadeem.sessions(Number(page) || 1, Number(pageSize) || 30);
  }
}
