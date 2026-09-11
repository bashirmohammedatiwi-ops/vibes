import { Module } from '@nestjs/common';
import { JobsModule } from '../../jobs/jobs.module';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { CouponService } from '../../common/services/coupon.service';
import { AmenitySyncService } from '../../common/services/amenity-sync.service';
import { NotificationService } from '../../common/services/notification.service';
import { SmsService } from '../../common/services/sms.service';
import { RatingService } from '../../common/services/rating.service';
import { PaginationService, PropertyQueryBuilder } from '../../common/services/query-helpers';
import { AdminActivitiesService } from './admin-activities.service';
import { AdminAmenitiesService } from './admin-amenities.service';
import { AdminAvailabilityService } from './admin-availability.service';
import { AdminBannersService } from './admin-banners.service';
import { AdminBookingNotesService } from './admin-booking-notes.service';
import { AdminBookingsService } from './admin-bookings.service';
import { AdminCouponsService } from './admin-coupons.service';
import { AdminCalendarService } from './admin-calendar.service';
import { AdminController } from './admin.controller';
import { AdminDashboardService } from './admin-dashboard.service';
import { AdminLocationsService } from './admin-locations.service';
import { AdminMediaService } from './admin-media.service';
import { AdminNotificationsService } from './admin-notifications.service';
import { AdminPaymentsService } from './admin-payments.service';
import { AdminPricingService } from './admin-pricing.service';
import { AdminProvidersService } from './admin-providers.service';
import { AdminPropertiesService } from './admin-properties.service';
import { AdminReportsService } from './admin-reports.service';
import { AdminReviewsService } from './admin-reviews.service';
import { AdminSearchService } from './admin-search.service';
import { AdminSettingsService } from './admin-settings.service';
import { AdminUsersService } from './admin-users.service';
import { ProvidersModule } from '../providers/providers.module';
import { PublicSettingsController } from './public-settings.controller';

@Module({
  imports: [ProvidersModule, JobsModule],
  controllers: [AdminController, PublicSettingsController],
  providers: [
    AdminPropertiesService,
    AdminPricingService,
    AdminAmenitiesService,
    AmenitySyncService,
    AdminMediaService,
    AdminDashboardService,
    AdminAvailabilityService,
    AdminBookingsService,
    AdminCouponsService,
    CouponService,
    AdminProvidersService,
    AdminUsersService,
    AdminReviewsService,
    AdminPaymentsService,
    AdminActivitiesService,
    AdminBannersService,
    AdminNotificationsService,
    AdminReportsService,
    AdminLocationsService,
    AdminBookingNotesService,
    AdminCalendarService,
    AdminSearchService,
    AdminSettingsService,
    ActivityLogService,
    NotificationService, SmsService,
    RatingService,
    PaginationService,
    PropertyQueryBuilder,
  ],
  exports: [AdminDashboardService, AdminBannersService, NotificationService, AmenitySyncService, AdminPricingService, AdminAvailabilityService],
})
export class AdminModule {}
