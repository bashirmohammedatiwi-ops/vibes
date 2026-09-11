import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { NotificationService } from '../common/services/notification.service';
import { SmsService } from '../common/services/sms.service';
import { MediaPipelineModule } from '../media/media-pipeline.module';
import { BookingLifecycleService } from './booking-lifecycle.service';
import { DefaultQueueProcessor } from './jobs.processor';
import { DEFAULT_QUEUE, JobsService } from './jobs.service';

@Module({
  imports: [
    BullModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        connection: { url: config.get<string>('REDIS_URL', 'redis://localhost:6379') },
      }),
    }),
    BullModule.registerQueue({ name: DEFAULT_QUEUE }),
    MediaPipelineModule,
  ],
  providers: [JobsService, DefaultQueueProcessor, SmsService, BookingLifecycleService, NotificationService],
  exports: [JobsService],
})
export class JobsModule {}
