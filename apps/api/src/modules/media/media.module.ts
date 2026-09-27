import { Module } from '@nestjs/common';
import { JobsModule } from '../../jobs/jobs.module';
import { MediaController } from './media.controller';

@Module({
  imports: [JobsModule],
  controllers: [MediaController],
})
export class MediaModule {}
