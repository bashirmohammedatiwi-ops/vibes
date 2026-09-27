import { Module } from '@nestjs/common';
import { MediaPipelineService } from './media-pipeline.service';

@Module({
  providers: [MediaPipelineService],
  exports: [MediaPipelineService],
})
export class MediaPipelineModule {}
