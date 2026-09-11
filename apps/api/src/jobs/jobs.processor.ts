import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';
import { SmsService } from '../common/services/sms.service';
import { MediaPipelineModule } from '../media/media-pipeline.module';
import { MediaPipelineService, type RenditionSpec } from '../media/media-pipeline.service';
import { DEFAULT_QUEUE } from './jobs.service';

type VideoJobData = { mediaId: string; specs: RenditionSpec[] };

@Processor(DEFAULT_QUEUE)
export class DefaultQueueProcessor extends WorkerHost {
  private readonly logger = new Logger(DefaultQueueProcessor.name);

  constructor(
    private readonly sms: SmsService,
    private readonly mediaPipeline: MediaPipelineService,
  ) {
    super();
  }

  async process(job: Job): Promise<unknown> {
    switch (job.name) {
      case 'send-otp-sms':
        return this.sms.sendOtp(job.data.phone as string, job.data.code as string);
      case 'process-video': {
        const data = job.data as unknown as VideoJobData;
        return this.mediaPipeline.processVideo(data.mediaId, data.specs ?? []);
      }
      default:
        this.logger.warn(`No handler registered for job "${job.name}"`);
        return null;
    }
  }
}

// Re-exported so the module import stays declarative in one place.
export { MediaPipelineModule };
