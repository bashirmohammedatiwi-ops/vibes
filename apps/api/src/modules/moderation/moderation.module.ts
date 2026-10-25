import { Module } from '@nestjs/common';
import { MarketplaceModule } from '../marketplace/marketplace.module';
import { ModerationController } from './moderation.controller';
import { ModerationService } from './moderation.service';

@Module({
  imports: [MarketplaceModule],
  controllers: [ModerationController],
  providers: [ModerationService],
})
export class ModerationModule {}
