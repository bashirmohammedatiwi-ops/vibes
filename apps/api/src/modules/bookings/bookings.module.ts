import { Module } from '@nestjs/common';
import { CouponService } from '../../common/services/coupon.service';
import { NotificationService } from '../../common/services/notification.service';
import { SmsService } from '../../common/services/sms.service';
import { LoyaltyModule } from '../loyalty/loyalty.module';
import { MarketplaceModule } from '../marketplace/marketplace.module';
import { BookingsController } from './bookings.controller';
import { BookingsService } from './bookings.service';
import { CouponsController } from './coupons.controller';

@Module({
  imports: [MarketplaceModule, LoyaltyModule],
  controllers: [BookingsController, CouponsController],
  providers: [BookingsService, NotificationService, SmsService, CouponService],
})
export class BookingsModule {}
