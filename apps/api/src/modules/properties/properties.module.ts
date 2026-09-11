import { Module } from '@nestjs/common';
import { AmenitySyncService } from '../../common/services/amenity-sync.service';
import { NotificationService } from '../../common/services/notification.service';
import { SmsService } from '../../common/services/sms.service';
import { PaginationService, PropertyQueryBuilder } from '../../common/services/query-helpers';
import { PropertiesController } from './properties.controller';
import { PropertiesService } from './properties.service';

@Module({
  controllers: [PropertiesController],
  providers: [
    PropertiesService,
    PaginationService,
    PropertyQueryBuilder,
    NotificationService, SmsService,
    AmenitySyncService,
  ],
  exports: [PropertiesService],
})
export class PropertiesModule {}
