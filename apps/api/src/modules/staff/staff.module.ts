import { Module } from '@nestjs/common';
import { AdminModule } from '../admin/admin.module';
import { MarketplaceModule } from '../marketplace/marketplace.module';
import { AdminStaffController } from './admin-staff.controller';
import { StaffController } from './staff.controller';
import { StaffPropertiesController } from './staff-properties.controller';
import { StaffPropertiesService } from './staff-properties.service';
import { StaffService } from './staff.service';

@Module({
  imports: [MarketplaceModule, AdminModule],
  // StaffPropertiesController يجب أن يسبق StaffController كي لا يلتهم
  // مسار properties/:id مساراتِ properties/form-meta وما يشبهها.
  controllers: [StaffPropertiesController, StaffController, AdminStaffController],
  providers: [StaffService, StaffPropertiesService],
})
export class StaffModule {}
