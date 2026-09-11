import { Module } from '@nestjs/common';
import { AdminModule } from '../admin/admin.module';
import { PaginationService } from '../../common/services/query-helpers';
import { ProviderPortalController } from './provider-portal.controller';
import { ProviderPortalService } from './provider-portal.service';

@Module({
  imports: [AdminModule],
  controllers: [ProviderPortalController],
  providers: [ProviderPortalService, PaginationService],
})
export class ProviderPortalModule {}
