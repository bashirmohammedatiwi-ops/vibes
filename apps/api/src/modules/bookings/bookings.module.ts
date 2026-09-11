import { Module } from '@nestjs/common';
import { CouponService } from '../../common/services/coupon.service';
import { NotificationService } from '../../common/services/notification.service';
import { SmsService } from '../../common/services/sms.service';
import { BookingsController } from './bookings.controller';
import { BookingsService } from './bookings.service';

@Module({
  controllers: [BookingsController],
  providers: [BookingsService, NotificationService, SmsService, CouponService],
})
export class BookingsModule {}
