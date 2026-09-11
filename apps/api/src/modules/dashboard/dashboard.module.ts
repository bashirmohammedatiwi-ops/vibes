import { Module } from '@nestjs/common';
import { AdminModule } from '../admin/admin.module';
import { DashboardController } from './dashboard.controller';

@Module({
  imports: [AdminModule],
  controllers: [DashboardController],
})
export class DashboardModule {}
