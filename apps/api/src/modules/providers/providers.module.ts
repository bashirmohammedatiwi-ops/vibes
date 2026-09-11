import { Module } from '@nestjs/common';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { NotificationService } from '../../common/services/notification.service';
import { SmsService } from '../../common/services/sms.service';
import { ProvidersController } from './providers.controller';
import { ProvidersService } from './providers.service';

@Module({
  controllers: [ProvidersController],
  providers: [ProvidersService, NotificationService, SmsService, ActivityLogService],
  exports: [ProvidersService],
})
export class ProvidersModule {}
