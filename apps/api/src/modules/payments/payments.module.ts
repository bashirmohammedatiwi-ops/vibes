import { Module } from '@nestjs/common';
import { NotificationService } from '../../common/services/notification.service';
import { SmsService } from '../../common/services/sms.service';
import { MarketplaceModule } from '../marketplace/marketplace.module';
import { PaymentCallbackController } from './payment-callback.controller';
import { PaymentGatewayService } from './payment-gateway.service';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';

@Module({
  imports: [MarketplaceModule],
  controllers: [PaymentsController, PaymentCallbackController],
  providers: [PaymentsService, PaymentGatewayService, NotificationService, SmsService],
  exports: [PaymentGatewayService, PaymentsService],
})
export class PaymentsModule {}
