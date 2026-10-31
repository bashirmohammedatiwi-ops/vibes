import { Module } from '@nestjs/common';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { AdminLoyaltyController, LoyaltyController } from './loyalty.controller';
import { LoyaltyService } from './loyalty.service';

@Module({
  controllers: [LoyaltyController, AdminLoyaltyController],
  providers: [LoyaltyService, ActivityLogService],
  exports: [LoyaltyService],
})
export class LoyaltyModule {}
