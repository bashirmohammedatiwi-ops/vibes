import { Module } from '@nestjs/common';
import { DevicesController } from './devices.controller';
import { UsersController } from './users.controller';

@Module({
  controllers: [UsersController, DevicesController],
})
export class UsersModule {}
