import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UploadedFile,
  UploadedFiles,
  UseInterceptors,
  Header,
  Res,
} from '@nestjs/common';
import { FileInterceptor, FilesInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiTags, PartialType } from '@nestjs/swagger';
import { Response } from 'express';
import { UserRole } from '@prisma/client';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { RequireStaffPermissions } from '../../common/decorators/staff-permissions.decorator';
import { AdminActivitiesService } from './admin-activities.service';
import { AdminAmenitiesService } from './admin-amenities.service';
import { AdminAvailabilityService } from './admin-availability.service';
import { AdminBannersService } from './admin-banners.service';
import { AdminSpotlightsService } from './admin-spotlights.service';
import { AdminCouponsService } from './admin-coupons.service';
import { AdminBookingNotesService } from './admin-booking-notes.service';
import { AdminCalendarService } from './admin-calendar.service';
import { AdminBookingsService } from './admin-bookings.service';
import { AdminDashboardService } from './admin-dashboard.service';
import { AdminLocationsService } from './admin-locations.service';
import { AdminMediaService, mediaStorageOptions, proofStorageOptions } from './admin-media.service';
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
import { AdminAmenityDto } from './dto/admin-amenity.dto';
import { AdminCouponDto, AdminValidateCouponDto } from './dto/admin-coupon.dto';
import {
  AdminBannerDto,
  AdminSpotlightDto,
  AdminBookingNoteDto,
  BulkPropertiesDto,
  AdminCityDto,
  AdminClearNotificationsDto,
  AdminDisputeDto,
  AdminEditBookingNoteDto,
  AdminPaymentStatusDto,
  AdminProviderReviewDto,
  AdminProvinceDto,
  AdminRefundPaymentDto,
  AdminRenameLocationDto,
  AdminResolveDisputeDto,
  AdminReviewVisibilityDto,
  AdminSettingsDto,
  AdminBookingQuoteDto,
  AdminBulkBookingsDto,
  AdminBulkPaymentsDto,
  AdminBulkReviewsDto,
  AdminCreateBookingDto,
  AdminCreateUserDto,
  AdminRescheduleBookingDto,
  AdminUpdateBookingStatusDto,
  AdminUpdateUserDto,
} from './dto/admin-common.dto';
import {
  AdminCreatePropertyDto,
  AdminUpdatePropertyDto,
  AdminPriceRuleDto,
  BulkAvailabilityDto,
  ClearAvailabilityDto,
  RejectPropertyDto,
  ReorderMediaDto,
  UpdateMediaDto,
} from './dto/admin-property.dto';
import { ProvidersService } from '../providers/providers.service';

// Validated partial bodies for PATCH (Partial<T> is erased at runtime, which
// skipped the global ValidationPipe whitelist).
class AdminCouponPatchDto extends PartialType(AdminCouponDto) {}
class AdminBannerPatchDto extends PartialType(AdminBannerDto) {}
class AdminSpotlightPatchDto extends PartialType(AdminSpotlightDto) {}
class AdminAmenityPatchDto extends PartialType(AdminAmenityDto) {}
class AdminPriceRulePatchDto extends PartialType(AdminPriceRuleDto) {}

@ApiTags('admin')
@ApiBearerAuth()
@Roles(UserRole.ADMIN, UserRole.STAFF)
@Controller('admin')
export class AdminController {
  constructor(
    private readonly properties: AdminPropertiesService,
    private readonly pricing: AdminPricingService,
    private readonly amenities: AdminAmenitiesService,
    private readonly media: AdminMediaService,
    private readonly dashboard: AdminDashboardService,
    private readonly availability: AdminAvailabilityService,
    private readonly bookings: AdminBookingsService,
    private readonly providers: AdminProvidersService,
    private readonly users: AdminUsersService,
    private readonly reviews: AdminReviewsService,
    private readonly payments: AdminPaymentsService,
    private readonly activities: AdminActivitiesService,
    private readonly banners: AdminBannersService,
    private readonly spotlights: AdminSpotlightsService,
    private readonly notifications: AdminNotificationsService,
    private readonly reports: AdminReportsService,
    private readonly locations: AdminLocationsService,
    private readonly bookingNotes: AdminBookingNotesService,
    private readonly calendar: AdminCalendarService,
    private readonly couponsAdmin: AdminCouponsService,
    private readonly search: AdminSearchService,
    private readonly settings: AdminSettingsService,
    private readonly providerLifecycle: ProvidersService,
  ) {}

  @Get('search')
  globalSearch(@CurrentUser() user: AuthUser, @Query('q') q?: string) {
    // النتائج مفلترة حسب صلاحيات الموظف داخل الخدمة
    return this.search.search(q ?? '', user);
  }

  @Get('settings')
  platformSettings() {
    return this.settings.get();
  }

  @Patch('settings')
  @RequireStaffPermissions('settings.write')
  updateSettings(@CurrentUser() user: AuthUser, @Body() dto: AdminSettingsDto) {
    return this.settings.update(user, dto);
  }

  @Get('calendar')
  @RequireStaffPermissions('bookings.read')
  calendarMonth(
    @Query('month') month?: string,
    @Query('propertyId') propertyId?: string,
    @Query('propertyType') propertyType?: string,
  ) {
    return this.calendar.month(month, propertyId, propertyType);
  }

  @Get('dashboard/stats')
  @RequireStaffPermissions('reports.read')
  stats() {
    return this.dashboard.stats();
  }

  @Get('bookings/stats')
  @RequireStaffPermissions('bookings.read')
  bookingStats() {
    return this.bookings.stats();
  }

  @Post('bookings/quote')
  @RequireStaffPermissions('bookings.write')
  quoteBooking(@Body() dto: AdminBookingQuoteDto) {
    return this.bookings.quote(dto);
  }

  @Post('bookings/bulk')
  @RequireStaffPermissions('bookings.write')
  bulkBookings(@CurrentUser() user: AuthUser, @Body() dto: AdminBulkBookingsDto) {
    return this.bookings.bulkUpdateStatus(user, dto);
  }

  @Post('bookings')
  @RequireStaffPermissions('bookings.write')
  createBooking(@CurrentUser() user: AuthUser, @Body() dto: AdminCreateBookingDto) {
    return this.bookings.create(user, dto);
  }

  @Get('bookings')
  @RequireStaffPermissions('bookings.read')
  listBookings(@Query() query: Record<string, string>) {
    return this.bookings.list(query);
  }

  @Get('providers/claims')
  @RequireStaffPermissions('providers.read')
  listPlaceClaims(@Query('status') status?: string) {
    return this.providerLifecycle.listClaims(status);
  }

  @Patch('providers/claims/:id/approve')
  @RequireStaffPermissions('providers.link')
  approvePlaceClaim(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.providerLifecycle.approveClaim(user, id);
  }

  @Patch('providers/claims/:id/reject')
  @RequireStaffPermissions('providers.link')
  rejectPlaceClaim(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.providerLifecycle.rejectClaim(user, id);
  }

  @Post('providers/link')
  @RequireStaffPermissions('providers.link')
  linkProviderPlace(
    @CurrentUser() user: AuthUser,
    @Body() dto: { userId: string; propertyId: string; conversationId?: string },
  ) {
    return this.providerLifecycle.linkPlaceForUser(
      user,
      dto.userId,
      dto.propertyId,
      dto.conversationId,
    );
  }

  @Get('providers')
  @RequireStaffPermissions('providers.read')
  listProviders(@Query() query: Record<string, string>) {
    return this.providers.list(query);
  }

  @Get('providers/export')

  @RequireStaffPermissions('providers.read')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="providers.csv"')
  async exportProviders(@Res() res: Response, @Query() query: Record<string, string>) {
    const csv = await this.providers.exportCsv(query);
    res.send('\uFEFF' + csv);
  }

  @Get('providers/:id')
  @RequireStaffPermissions('providers.read')
  getProvider(@Param('id') id: string) {
    return this.providers.getOne(id);
  }

  @Patch('providers/:id/verify')
  @RequireStaffPermissions('providers.link')
  verifyProvider(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.providerLifecycle.verify(user, id);
  }

  @Patch('providers/:id/reject')
  @RequireStaffPermissions('providers.link')
  rejectProvider(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminProviderReviewDto,
  ) {
    return this.providerLifecycle.reject(user, id, dto.reason);
  }

  @Patch('providers/:id/revoke')
  @RequireStaffPermissions('providers.link')
  revokeProvider(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminProviderReviewDto,
  ) {
    return this.providerLifecycle.revoke(user, id, dto.reason);
  }

  @Get('properties/geo')
  @RequireStaffPermissions('properties.read')
  propertiesGeo() {
    return this.providers.geoProperties();
  }

  @Get('bookings/:id')
  @RequireStaffPermissions('bookings.read')
  getBooking(@Param('id') id: string) {
    return this.bookings.getOne(id);
  }

  @Patch('bookings/:id/status')
  @RequireStaffPermissions('bookings.write')
  updateBookingStatus(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminUpdateBookingStatusDto,
  ) {
    return this.bookings.updateStatus(user, id, dto.status, dto.adminNote);
  }

  @Patch('bookings/:id/dates')
  @RequireStaffPermissions('bookings.write')
  rescheduleBooking(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminRescheduleBookingDto,
  ) {
    return this.bookings.reschedule(user, id, dto);
  }

  @Get('users')
  @RequireStaffPermissions('users.read')
  listUsers(@Query() query: Record<string, string>) {
    return this.users.list(query);
  }

  @Post('users')
  @Roles(UserRole.ADMIN)
  createUser(@CurrentUser() user: AuthUser, @Body() dto: AdminCreateUserDto) {
    return this.users.create(user, dto);
  }

  @Get('users/:id')
  @RequireStaffPermissions('users.read')
  getUser(@Param('id') id: string) {
    return this.users.getOne(id);
  }

  @Patch('users/:id')
  @RequireStaffPermissions('users.write')
  updateUser(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: AdminUpdateUserDto) {
    return this.users.update(user, id, dto);
  }

  @Delete('users/:id')
  @Roles(UserRole.ADMIN)
  deleteUser(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.users.remove(user, id);
  }

  @Get('reviews')
  @RequireStaffPermissions('reviews.moderate')
  listReviews(@Query() query: Record<string, string>) {
    return this.reviews.list(query);
  }

  @Patch('reviews/:id/visibility')
  @RequireStaffPermissions('reviews.moderate')
  reviewVisibility(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminReviewVisibilityDto,
  ) {
    return this.reviews.setVisibility(user, id, dto.isVisible, dto.adminNote);
  }

  @Delete('reviews/:id')
  @RequireStaffPermissions('reviews.moderate')
  deleteReview(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.reviews.remove(user, id);
  }

  @Post('reviews/bulk')
  @RequireStaffPermissions('reviews.moderate')
  bulkReviews(@CurrentUser() user: AuthUser, @Body() dto: AdminBulkReviewsDto) {
    return this.reviews.bulk(user, dto.ids, dto.action);
  }

  @Get('reviews/export')

  @RequireStaffPermissions('reviews.moderate')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="reviews.csv"')
  async exportReviews(@Res() res: Response, @Query() query: Record<string, string>) {
    const csv = await this.reviews.exportCsv(query);
    res.send('\uFEFF' + csv);
  }

  @Get('properties/:id/bookings')
  @RequireStaffPermissions('bookings.read')
  propertyBookings(@Param('id') id: string, @Query() query: Record<string, string>) {
    return this.bookings.list({ ...query, propertyId: id });
  }

  @Get('payments')
  @RequireStaffPermissions('payments.read')
  listPayments(@Query() query: Record<string, string>) {
    return this.payments.list(query);
  }

  @Post('payments/bulk')
  @RequireStaffPermissions('payments.verify')
  bulkPayments(@CurrentUser() user: AuthUser, @Body() dto: AdminBulkPaymentsDto) {
    return this.payments.bulkReview(user, dto.ids, dto.status, dto.adminNote);
  }

  @Get('payments/:id')
  @RequireStaffPermissions('payments.read')
  getPayment(@Param('id') id: string) {
    return this.payments.getOne(id);
  }

  @Post('payments/:id/refund')
  @RequireStaffPermissions('payments.refund')
  refundPayment(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminRefundPaymentDto,
  ) {
    return this.payments.refund(user, id, dto.adminNote);
  }

  @Patch('payments/:id/review')
  @RequireStaffPermissions('payments.verify')
  reviewPayment(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminPaymentStatusDto,
  ) {
    return this.payments.review(user, id, dto);
  }

  @Patch('payments/:id/status')
  @RequireStaffPermissions('payments.verify')
  updatePaymentStatus(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminPaymentStatusDto,
  ) {
    return this.payments.review(user, id, dto);
  }

  @Post('bookings/:bookingId/payment/proof')
  @RequireStaffPermissions('payments.verify')
  @UseInterceptors(FileInterceptor('file', { storage: proofStorageOptions() }))
  @ApiConsumes('multipart/form-data')
  uploadPaymentProof(
    @CurrentUser() user: AuthUser,
    @Param('bookingId') bookingId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.payments.uploadProof(user, bookingId, file);
  }

  @Get('notifications')
  @RequireStaffPermissions('activity.read')
  listNotifications(@Query() query: Record<string, string>) {
    return this.notifications.list(query);
  }

  @Get('notifications/export')

  @RequireStaffPermissions('activity.read')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="notifications.csv"')
  async exportNotifications(@Res() res: Response, @Query() query: Record<string, string>) {
    const csv = await this.notifications.exportCsv(query);
    res.send('\uFEFF' + csv);
  }

  @Patch('notifications/:id/read')
  @RequireStaffPermissions('activity.read')
  readNotification(@Param('id') id: string) {
    return this.notifications.markRead(id);
  }

  @Post('notifications/read-all')
  @RequireStaffPermissions('activity.read')
  readAllNotifications() {
    return this.notifications.markAllRead();
  }

  @Post('notifications/clear-read')
  @RequireStaffPermissions('activity.read')
  clearReadNotifications(@Body() dto: AdminClearNotificationsDto) {
    return this.notifications.clearRead(dto.olderThanDays ?? 30);
  }

  @Delete('notifications/:id')
  @RequireStaffPermissions('activity.read')
  deleteNotification(@Param('id') id: string) {
    return this.notifications.remove(id);
  }

  @Get('reports/analytics')
  @RequireStaffPermissions('reports.read')
  analytics(@Query('from') from?: string, @Query('to') to?: string, @Query('days') days?: string) {
    if (!from && days) {
      const parsedDays = Math.min(Math.max(Number(days) || 30, 1), 365);
      const start = new Date();
      start.setDate(start.getDate() - parsedDays + 1);
      return this.reports.analytics(start.toISOString().slice(0, 10), undefined);
    }
    return this.reports.analytics(from, to);
  }

  @Get('reports/summary')
  @RequireStaffPermissions('reports.read')
  reportSummary(@Query('from') from?: string, @Query('to') to?: string) {
    return this.reports.summary(from, to);
  }

  @Get('reports/bookings/export')

  @RequireStaffPermissions('reports.read')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="bookings.csv"')
  async exportBookings(@Res() res: Response, @Query() query: Record<string, string>) {
    const csv = await this.reports.exportBookingsCsv(query);
    res.send('\uFEFF' + csv);
  }

  @Get('reports/payments/export')

  @RequireStaffPermissions('reports.read')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="payments.csv"')
  async exportPayments(@Res() res: Response, @Query() query: Record<string, string>) {
    const csv = await this.reports.exportPaymentsCsv(query);
    res.send('\uFEFF' + csv);
  }

  @Get('reports/properties/export')

  @RequireStaffPermissions('reports.read')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="properties.csv"')
  async exportProperties(@Res() res: Response) {
    const csv = await this.reports.exportPropertiesCsv();
    res.send('\uFEFF' + csv);
  }

  @Get('reports/users/export')

  @RequireStaffPermissions('reports.read', 'users.read')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="users.csv"')
  async exportUsers(@Res() res: Response, @Query() query: Record<string, string>) {
    const csv = await this.reports.exportUsersCsv(query);
    res.send('\uFEFF' + csv);
  }

  @Get('locations/provinces')
  listProvinces() {
    return this.locations.provinces();
  }

  @Post('locations/provinces')
  @RequireStaffPermissions('locations.write')
  createProvince(@CurrentUser() user: AuthUser, @Body() dto: AdminProvinceDto) {
    return this.locations.createProvince(user, dto);
  }

  @Patch('locations/provinces/:id')
  @RequireStaffPermissions('locations.write')
  updateProvince(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminRenameLocationDto,
  ) {
    return this.locations.updateProvince(user, id, dto);
  }

  @Post('locations/provinces/:provinceId/cities')
  @RequireStaffPermissions('locations.write')
  createCity(
    @CurrentUser() user: AuthUser,
    @Param('provinceId') provinceId: string,
    @Body() dto: AdminCityDto,
  ) {
    return this.locations.createCity(user, provinceId, dto);
  }

  @Patch('locations/cities/:id')
  @RequireStaffPermissions('locations.write')
  updateCity(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminRenameLocationDto,
  ) {
    return this.locations.updateCity(user, id, dto);
  }

  @Delete('locations/cities/:id')
  @RequireStaffPermissions('locations.write')
  deleteCity(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.locations.deleteCity(user, id);
  }

  @Delete('locations/provinces/:id')
  @RequireStaffPermissions('locations.write')
  deleteProvince(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.locations.deleteProvince(user, id);
  }

  @Get('bookings/:id/notes')
  @RequireStaffPermissions('bookings.read')
  listBookingNotes(@Param('id') id: string) {
    return this.bookingNotes.list(id);
  }

  @Post('bookings/:id/notes')
  @RequireStaffPermissions('bookings.read')
  addBookingNote(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminBookingNoteDto,
  ) {
    return this.bookingNotes.add(user, id, dto.content, dto.isInternal ?? true);
  }

  @Patch('bookings/:id/notes/:noteId')
  @RequireStaffPermissions('bookings.read')
  editBookingNote(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('noteId') noteId: string,
    @Body() dto: AdminEditBookingNoteDto,
  ) {
    return this.bookingNotes.edit(user, id, noteId, dto.content);
  }

  @Delete('bookings/:id/notes/:noteId')
  @RequireStaffPermissions('bookings.write')
  deleteBookingNote(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('noteId') noteId: string,
  ) {
    return this.bookingNotes.remove(user, id, noteId);
  }

  @Post('bookings/:id/dispute')
  @RequireStaffPermissions('disputes.review')
  openDispute(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminDisputeDto,
  ) {
    return this.bookingNotes.openDispute(user, id, dto.reason, dto.note);
  }

  @Post('bookings/:id/dispute/resolve')
  @RequireStaffPermissions('disputes.review')
  resolveDispute(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminResolveDisputeDto,
  ) {
    return this.bookingNotes.resolveDispute(user, id, dto.status, dto.note);
  }

  @Get('activities/export')

  @RequireStaffPermissions('activity.read')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="activity.csv"')
  async exportActivities(@Res() res: Response, @Query() query: Record<string, string>) {
    const csv = await this.activities.exportCsv(query);
    res.send('\uFEFF' + csv);
  }

  @Get('activities')
  @RequireStaffPermissions('activity.read')
  listActivities(@Query() query: Record<string, string>) {
    return this.activities.list(query);
  }

  @Get('coupons')
  @RequireStaffPermissions('coupons.read')
  listCoupons(@Query() query: Record<string, string>) {
    return this.couponsAdmin.list(query);
  }

  @Post('coupons')
  @RequireStaffPermissions('coupons.write')
  createCoupon(@CurrentUser() user: AuthUser, @Body() dto: AdminCouponDto) {
    return this.couponsAdmin.create(user, dto);
  }

  @Post('coupons/validate')
  @RequireStaffPermissions('coupons.read')
  validateCoupon(@CurrentUser() user: AuthUser, @Body() dto: AdminValidateCouponDto) {
    return this.couponsAdmin.validate(user, dto);
  }

  @Patch('coupons/:id')
  @RequireStaffPermissions('coupons.write')
  updateCoupon(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminCouponPatchDto,
  ) {
    return this.couponsAdmin.update(user, id, dto);
  }

  @Delete('coupons/:id')
  @RequireStaffPermissions('coupons.write')
  deleteCoupon(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.couponsAdmin.remove(user, id);
  }

  @Get('banners')
  listBanners() {
    return this.banners.list();
  }

  @Post('banners')
  @RequireStaffPermissions('content.write')
  createBanner(@CurrentUser() user: AuthUser, @Body() dto: AdminBannerDto) {
    return this.banners.create(user, dto);
  }

  @Patch('banners/:id')
  @RequireStaffPermissions('content.write')
  updateBanner(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminBannerPatchDto,
  ) {
    return this.banners.update(user, id, dto);
  }

  @Delete('banners/:id')
  @RequireStaffPermissions('content.write')
  deleteBanner(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.banners.remove(user, id);
  }

  @Get('spotlights')
  listSpotlights() {
    return this.spotlights.list();
  }

  @Post('spotlights')
  @RequireStaffPermissions('content.write')
  createSpotlight(@CurrentUser() user: AuthUser, @Body() dto: AdminSpotlightDto) {
    return this.spotlights.create(user, dto);
  }

  @Patch('spotlights/:id')
  @RequireStaffPermissions('content.write')
  updateSpotlight(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminSpotlightPatchDto,
  ) {
    return this.spotlights.update(user, id, dto);
  }

  @Delete('spotlights/:id')
  @RequireStaffPermissions('content.write')
  deleteSpotlight(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.spotlights.remove(user, id);
  }

  @Post('properties/bulk')
  @RequireStaffPermissions('properties.write')
  bulkProperties(@CurrentUser() user: AuthUser, @Body() dto: BulkPropertiesDto) {
    return this.properties.bulk(user, dto.action, dto.ids);
  }

  @Post('properties/:id/duplicate')
  @RequireStaffPermissions('properties.write')
  duplicateProperty(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.properties.duplicate(user, id);
  }

  @Get('properties')
  @RequireStaffPermissions('properties.read')
  listProperties(@Query() query: Record<string, string>) {
    return this.properties.list(query);
  }

  @Get('properties/:id')
  @RequireStaffPermissions('properties.read')
  getProperty(@Param('id') id: string) {
    return this.properties.getOne(id);
  }

  @Post('properties')
  @RequireStaffPermissions('properties.write')
  createProperty(@CurrentUser() user: AuthUser, @Body() dto: AdminCreatePropertyDto) {
    return this.properties.create(user, dto);
  }

  @Patch('properties/:id')
  @RequireStaffPermissions('properties.write')
  updateProperty(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminUpdatePropertyDto,
  ) {
    return this.properties.update(user, id, dto);
  }

  @Delete('properties/:id')
  @RequireStaffPermissions('properties.write')
  deleteProperty(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.properties.remove(user, id);
  }

  @Post('properties/:id/publish')
  @RequireStaffPermissions('properties.moderate')
  publishProperty(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.properties.publish(user, id);
  }

  @Post('properties/:id/suspend')
  @RequireStaffPermissions('properties.moderate')
  suspendProperty(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.properties.suspend(user, id);
  }

  @Post('properties/:id/reject')
  @RequireStaffPermissions('properties.moderate')
  rejectProperty(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: RejectPropertyDto,
  ) {
    return this.properties.reject(user, id, dto.reason);
  }

  @Get('amenities')
  listAmenities(@Query() query: Record<string, string>) {
    return this.amenities.list(query);
  }

  @Post('amenities')
  @RequireStaffPermissions('amenities.write')
  createAmenity(@CurrentUser() user: AuthUser, @Body() dto: AdminAmenityDto) {
    return this.amenities.create(user, dto);
  }

  @Patch('amenities/:id')
  @RequireStaffPermissions('amenities.write')
  updateAmenity(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminAmenityPatchDto,
  ) {
    return this.amenities.update(user, id, dto);
  }

  @Delete('amenities/:id')
  @RequireStaffPermissions('amenities.write')
  deleteAmenity(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.amenities.remove(user, id);
  }

  @Get('properties/:id/pricing-preview')
  @RequireStaffPermissions('properties.read')
  pricingPreview(
    @Param('id') id: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.pricing.preview(id, from, to);
  }

  @Get('properties/:id/pricing-rules')
  @RequireStaffPermissions('properties.read')
  listPricingRules(@Param('id') id: string) {
    return this.pricing.listRules(id);
  }

  @Post('properties/:id/pricing-rules')
  @RequireStaffPermissions('properties.write')
  createPricingRule(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminPriceRuleDto,
  ) {
    return this.pricing.createRule(user, id, dto);
  }

  @Patch('properties/:id/pricing-rules/:ruleId')
  @RequireStaffPermissions('properties.write')
  updatePricingRule(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('ruleId') ruleId: string,
    @Body() dto: AdminPriceRulePatchDto,
  ) {
    return this.pricing.updateRule(user, id, ruleId, dto);
  }

  @Delete('properties/:id/pricing-rules/:ruleId')
  @RequireStaffPermissions('properties.write')
  deletePricingRule(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('ruleId') ruleId: string,
  ) {
    return this.pricing.deleteRule(user, id, ruleId);
  }

  @Get('properties/:id/media')
  @RequireStaffPermissions('properties.read')
  listMedia(@Param('id') id: string) {
    return this.media.listByProperty(id);
  }

  @Post('properties/:id/media')
  @RequireStaffPermissions('properties.write')
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: { type: 'string', format: 'binary' },
        targetRatio: { type: 'string', enum: ['auto', '16:9', '9:16', '1:1', '4:3'] },
        kind: { type: 'string', enum: ['media', 'panorama'], description: 'panorama لرفع صورة 360°' },
      },
    },
  })
  @UseInterceptors(
    FileInterceptor('file', {
      storage: mediaStorageOptions(),
      limits: { fileSize: Math.max(Number(process.env.MAX_UPLOAD_MB ?? 20), Number(process.env.MEDIA_VIDEO_MAX_MB ?? 200)) * 1024 * 1024 },
    }),
  )
  uploadMedia(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @UploadedFile() file: Express.Multer.File,
    @Body('targetRatio') targetRatio?: string,
    @Body('kind') kind?: string,
  ) {
    return this.media.uploadForProperty(user, id, file, targetRatio, kind);
  }

  @Post('properties/:id/media/bulk')

  @RequireStaffPermissions('properties.write')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FilesInterceptor('files', 20, {
      storage: mediaStorageOptions(),
      limits: { fileSize: Math.max(Number(process.env.MAX_UPLOAD_MB ?? 20), Number(process.env.MEDIA_VIDEO_MAX_MB ?? 200)) * 1024 * 1024 },
    }),
  )
  async uploadBulkMedia(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @UploadedFiles() files: Express.Multer.File[],
    @Body('targetRatio') targetRatio?: string,
    @Body('kind') kind?: string,
  ) {
    const results = [];
    for (const file of files ?? []) {
      results.push(await this.media.uploadForProperty(user, id, file, targetRatio, kind));
    }
    return results;
  }

  @Post('media/:mediaId/reprocess')
  @RequireStaffPermissions('properties.write')
  reprocessMedia(
    @CurrentUser() user: AuthUser,
    @Param('mediaId') mediaId: string,
    @Body('targetRatio') targetRatio?: string,
  ) {
    return this.media.reprocess(user, mediaId, targetRatio);
  }

  @Patch('properties/:id/media/reorder')
  @RequireStaffPermissions('properties.write')
  reorderMedia(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ReorderMediaDto,
  ) {
    return this.media.reorder(user, id, dto.mediaIds);
  }

  @Patch('properties/:id/media/:mediaId/primary')
  @RequireStaffPermissions('properties.write')
  setPrimaryMedia(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('mediaId') mediaId: string,
  ) {
    return this.media.setPrimary(user, id, mediaId);
  }

  @Patch('media/:mediaId')
  @RequireStaffPermissions('properties.write')
  updateMedia(
    @CurrentUser() user: AuthUser,
    @Param('mediaId') mediaId: string,
    @Body() dto: UpdateMediaDto,
  ) {
    return this.media.update(user, mediaId, dto);
  }

  @Delete('media/:mediaId')
  @RequireStaffPermissions('properties.write')
  deleteMedia(@CurrentUser() user: AuthUser, @Param('mediaId') mediaId: string) {
    return this.media.remove(user, mediaId);
  }

  @Get('properties/:id/availability')
  @RequireStaffPermissions('properties.read')
  listAvailability(@Param('id') id: string, @Query('month') month?: string) {
    return this.availability.list(id, month);
  }

  @Post('properties/:id/availability/bulk')
  @RequireStaffPermissions('properties.write')
  bulkAvailability(@Param('id') id: string, @Body() dto: BulkAvailabilityDto) {
    return this.availability.bulkSet(id, dto);
  }

  @Post('properties/:id/availability/clear')
  @RequireStaffPermissions('properties.write')
  clearAvailability(@Param('id') id: string, @Body() dto: ClearAvailabilityDto) {
    return this.availability.clear(id, dto.dates, dto.shifts);
  }
}
