import { Module } from '@nestjs/common';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { AdminHomeLayoutController, HomeLayoutController } from './home-layout.controller';
import { HomeLayoutService } from './home-layout.service';

@Module({
  controllers: [HomeLayoutController, AdminHomeLayoutController],
  providers: [HomeLayoutService, ActivityLogService],
})
export class HomeLayoutModule {}
