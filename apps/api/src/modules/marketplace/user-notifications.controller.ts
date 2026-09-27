import { Controller, Get, Param, Patch, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserNotificationsService } from './user-notifications.service';

@ApiTags('notifications')
@ApiBearerAuth()
@Controller('notifications')
export class UserNotificationsController {
  constructor(private readonly notifications: UserNotificationsService) {}

  @Get()
  list(@CurrentUser() user: AuthUser, @Query() query: { page?: string; pageSize?: string }) {
    return this.notifications.list(user, query);
  }

  @Get('unread')
  unread(@CurrentUser() user: AuthUser) {
    return this.notifications.unreadCount(user);
  }

  @Patch('read')
  readAll(@CurrentUser() user: AuthUser) {
    return this.notifications.markRead(user);
  }

  @Patch(':id/read')
  readOne(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.notifications.markRead(user, id);
  }
}
