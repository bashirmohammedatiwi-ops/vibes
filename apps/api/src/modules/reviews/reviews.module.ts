import { Module } from '@nestjs/common';
import { NotificationService } from '../../common/services/notification.service';
import { SmsService } from '../../common/services/sms.service';
import { RatingService } from '../../common/services/rating.service';
import { ReviewsController } from './reviews.controller';
import { ReviewsService } from './reviews.service';

@Module({
  controllers: [ReviewsController],
  providers: [ReviewsService, RatingService, NotificationService, SmsService],
})
export class ReviewsModule {}
