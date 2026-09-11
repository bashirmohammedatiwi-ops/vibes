import { InjectQueue } from '@nestjs/bullmq';
import { Injectable } from '@nestjs/common';
import { JobsOptions, Queue } from 'bullmq';

export const DEFAULT_QUEUE = 'default';

export type JobName = 'send-otp-sms' | 'process-video';

const DEFAULT_OPTS: JobsOptions = {
  attempts: 3,
  backoff: { type: 'exponential', delay: 2000 },
  removeOnComplete: 200,
  removeOnFail: 500,
};

/** Producer side of the BullMQ-backed background queue (Redis persisted, retried on failure). */
@Injectable()
export class JobsService {
  constructor(@InjectQueue(DEFAULT_QUEUE) private readonly queue: Queue) {}

  enqueue(name: JobName, data: Record<string, unknown> = {}, opts?: JobsOptions) {
    return this.queue.add(name, data, { ...DEFAULT_OPTS, ...opts });
  }

  async activeCount() {
    return this.queue.getActiveCount();
  }
}
