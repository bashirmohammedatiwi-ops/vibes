import { Module } from '@nestjs/common';
import { AccountDeletionService } from './account-deletion.service';
import { DevicesController } from './devices.controller';
import { UsersController } from './users.controller';

@Module({
  controllers: [UsersController, DevicesController],
  providers: [AccountDeletionService],
})
export class UsersModule {}
