import { Module } from '@nestjs/common';
import { MarketplaceModule } from '../marketplace/marketplace.module';
import { AccountDeletionService } from './account-deletion.service';
import { DevicesController } from './devices.controller';
import { UsersController } from './users.controller';

@Module({
  imports: [MarketplaceModule],
  controllers: [UsersController, DevicesController],
  providers: [AccountDeletionService],
})
export class UsersModule {}
