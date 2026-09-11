import { Module } from '@nestjs/common';
import { ReelsController } from './reels.controller';

@Module({
  controllers: [ReelsController],
})
export class ReelsModule {}
