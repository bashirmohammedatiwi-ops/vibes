import { Module } from '@nestjs/common';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { AdminNadeemController, NadeemController } from './nadeem.controller';
import { NadeemService } from './nadeem.service';

@Module({
  controllers: [NadeemController, AdminNadeemController],
  providers: [NadeemService, ActivityLogService],
})
export class NadeemModule {}
