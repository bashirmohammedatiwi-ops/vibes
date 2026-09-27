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
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { Response } from 'express';
import { UserRole } from '@prisma/client';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
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
  globalSearch(@Query('q') q?: string) {
    return this.search.search(q ?? '');
  }

  @Get('settings')
  platformSettings() {
    return this.settings.get();
  }

  @Patch('settings')
  @Roles(UserRole.ADMIN)
  updateSettings(@CurrentUser() user: AuthUser, @Body() dto: AdminSettingsDto) {
    return this.settings.update(user, dto);
  }

  @Get('calendar')
  calendarMonth(
    @Query('month') month?: string,
    @Query('propertyId') propertyId?: string,
    @Query('propertyType') propertyType?: string,
  ) {
    return this.calendar.month(month, propertyId, propertyType);
  }

  @Get('dashboard/stats')
  stats() {
    return this.dashboard.stats();
  }

  @Get('bookings/stats')
  bookingStats() {
    return this.bookings.stats();
  }

  @Post('bookings/quote')
  quoteBooking(@Body() dto: AdminBookingQuoteDto) {
    return this.bookings.quote(dto);
  }

  @Post('bookings/bulk')
  bulkBookings(@CurrentUser() user: AuthUser, @Body() dto: AdminBulkBookingsDto) {
    return this.bookings.bulkUpdateStatus(user, dto);
  }

  @Post('bookings')
  createBooking(@CurrentUser() user: AuthUser, @Body() dto: AdminCreateBookingDto) {
    return this.bookings.create(user, dto);
  }

  @Get('bookings')
  listBookings(@Query() query: Record<string, string>) {
    return this.bookings.list(query);
  }

  @Get('providers')
  listProviders(@Query() query: Record<string, string>) {
    return this.providers.list(query);
  }

  @Get('providers/export')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="providers.csv"')
  async exportProviders(@Res() res: Response, @Query() query: Record<string, string>) {
    const csv = await this.providers.exportCsv(query);
    res.send('\uFEFF' + csv);
  }

  @Get('providers/:id')
  getProvider(@Param('id') id: string) {
    return this.providers.getOne(id);
  }

  @Patch('providers/:id/verify')
  verifyProvider(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.providerLifecycle.verify(user, id);
  }

  @Patch('providers/:id/reject')
  rejectProvider(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminProviderReviewDto,
  ) {
    return this.providerLifecycle.reject(user, id, dto.reason);
  }

  @Patch('providers/:id/revoke')
  revokeProvider(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminProviderReviewDto,
  ) {
    return this.providerLifecycle.revoke(user, id, dto.reason);
  }

  @Get('properties/geo')
  propertiesGeo() {
    return this.providers.geoProperties();
  }

  @Get('bookings/:id')
  getBooking(@Param('id') id: string) {
    return this.bookings.getOne(id);
  }

  @Patch('bookings/:id/status')
  updateBookingStatus(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminUpdateBookingStatusDto,
  ) {
    return this.bookings.updateStatus(user, id, dto.status, dto.adminNote);
  }

  @Patch('bookings/:id/dates')
  rescheduleBooking(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminRescheduleBookingDto,
  ) {
    return this.bookings.reschedule(user, id, dto);
  }

  @Get('users')
  listUsers(@Query() query: Record<string, string>) {
    return this.users.list(query);
  }

  @Post('users')
  @Roles(UserRole.ADMIN)
  createUser(@CurrentUser() user: AuthUser, @Body() dto: AdminCreateUserDto) {
    return this.users.create(user, dto);
  }

  @Get('users/:id')
  getUser(@Param('id') id: string) {
    return this.users.getOne(id);
  }

  @Patch('users/:id')
  @Roles(UserRole.ADMIN)
  updateUser(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: AdminUpdateUserDto) {
    return this.users.update(user, id, dto);
  }

  @Delete('users/:id')
  @Roles(UserRole.ADMIN)
  deleteUser(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.users.remove(user, id);
  }

  @Get('reviews')
  listReviews(@Query() query: Record<string, string>) {
    return this.reviews.list(query);
  }

  @Patch('reviews/:id/visibility')
  reviewVisibility(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminReviewVisibilityDto,
  ) {
    return this.reviews.setVisibility(user, id, dto.isVisible, dto.adminNote);
  }

  @Delete('reviews/:id')
  deleteReview(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.reviews.remove(user, id);
  }

  @Post('reviews/bulk')
  bulkReviews(@CurrentUser() user: AuthUser, @Body() dto: AdminBulkReviewsDto) {
    return this.reviews.bulk(user, dto.ids, dto.action);
  }

  @Get('reviews/export')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="reviews.csv"')
  async exportReviews(@Res() res: Response, @Query() query: Record<string, string>) {
    const csv = await this.reviews.exportCsv(query);
    res.send('\uFEFF' + csv);
  }

  @Get('properties/:id/bookings')
  propertyBookings(@Param('id') id: string, @Query() query: Record<string, string>) {
    return this.bookings.list({ ...query, propertyId: id });
  }

  @Get('payments')
  listPayments(@Query() query: Record<string, string>) {
    return this.payments.list(query);
  }

  @Post('payments/bulk')
  bulkPayments(@CurrentUser() user: AuthUser, @Body() dto: AdminBulkPaymentsDto) {
    return this.payments.bulkReview(user, dto.ids, dto.status, dto.adminNote);
  }

  @Get('payments/:id')
  getPayment(@Param('id') id: string) {
    return this.payments.getOne(id);
  }

  @Post('payments/:id/refund')
  @Roles(UserRole.ADMIN)
  refundPayment(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminRefundPaymentDto,
  ) {
    return this.payments.refund(user, id, dto.adminNote);
  }

  @Patch('payments/:id/review')
  reviewPayment(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminPaymentStatusDto,
  ) {
    return this.payments.review(user, id, dto);
  }

  @Patch('payments/:id/status')
  updatePaymentStatus(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminPaymentStatusDto,
  ) {
    return this.payments.review(user, id, dto);
  }

  @Post('bookings/:bookingId/payment/proof')
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
  listNotifications(@Query() query: Record<string, string>) {
    return this.notifications.list(query);
  }

  @Get('notifications/export')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="notifications.csv"')
  async exportNotifications(@Res() res: Response, @Query() query: Record<string, string>) {
    const csv = await this.notifications.exportCsv(query);
    res.send('\uFEFF' + csv);
  }

  @Patch('notifications/:id/read')
  readNotification(@Param('id') id: string) {
    return this.notifications.markRead(id);
  }

  @Post('notifications/read-all')
  readAllNotifications() {
    return this.notifications.markAllRead();
  }

  @Post('notifications/clear-read')
  clearReadNotifications(@Body() dto: AdminClearNotificationsDto) {
    return this.notifications.clearRead(dto.olderThanDays ?? 30);
  }

  @Delete('notifications/:id')
  deleteNotification(@Param('id') id: string) {
    return this.notifications.remove(id);
  }

  @Get('reports/analytics')
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
  reportSummary(@Query('from') from?: string, @Query('to') to?: string) {
    return this.reports.summary(from, to);
  }

  @Get('reports/bookings/export')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="bookings.csv"')
  async exportBookings(@Res() res: Response, @Query() query: Record<string, string>) {
    const csv = await this.reports.exportBookingsCsv(query);
    res.send('\uFEFF' + csv);
  }

  @Get('reports/payments/export')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="payments.csv"')
  async exportPayments(@Res() res: Response, @Query() query: Record<string, string>) {
    const csv = await this.reports.exportPaymentsCsv(query);
    res.send('\uFEFF' + csv);
  }

  @Get('reports/properties/export')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="properties.csv"')
  async exportProperties(@Res() res: Response) {
    const csv = await this.reports.exportPropertiesCsv();
    res.send('\uFEFF' + csv);
  }

  @Get('reports/users/export')
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
  @Roles(UserRole.ADMIN)
  createProvince(@CurrentUser() user: AuthUser, @Body() dto: AdminProvinceDto) {
    return this.locations.createProvince(user, dto);
  }

  @Patch('locations/provinces/:id')
  @Roles(UserRole.ADMIN)
  updateProvince(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminRenameLocationDto,
  ) {
    return this.locations.updateProvince(user, id, dto);
  }

  @Post('locations/provinces/:provinceId/cities')
  @Roles(UserRole.ADMIN)
  createCity(
    @CurrentUser() user: AuthUser,
    @Param('provinceId') provinceId: string,
    @Body() dto: AdminCityDto,
  ) {
    return this.locations.createCity(user, provinceId, dto);
  }

  @Patch('locations/cities/:id')
  @Roles(UserRole.ADMIN)
  updateCity(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminRenameLocationDto,
  ) {
    return this.locations.updateCity(user, id, dto);
  }

  @Delete('locations/cities/:id')
  @Roles(UserRole.ADMIN)
  deleteCity(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.locations.deleteCity(user, id);
  }

  @Delete('locations/provinces/:id')
  @Roles(UserRole.ADMIN)
  deleteProvince(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.locations.deleteProvince(user, id);
  }

  @Get('bookings/:id/notes')
  listBookingNotes(@Param('id') id: string) {
    return this.bookingNotes.list(id);
  }

  @Post('bookings/:id/notes')
  addBookingNote(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminBookingNoteDto,
  ) {
    return this.bookingNotes.add(user, id, dto.content, dto.isInternal ?? true);
  }

  @Patch('bookings/:id/notes/:noteId')
  editBookingNote(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('noteId') noteId: string,
    @Body() dto: AdminEditBookingNoteDto,
  ) {
    return this.bookingNotes.edit(user, id, noteId, dto.content);
  }

  @Delete('bookings/:id/notes/:noteId')
  deleteBookingNote(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('noteId') noteId: string,
  ) {
    return this.bookingNotes.remove(user, id, noteId);
  }

  @Post('bookings/:id/dispute')
  openDispute(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminDisputeDto,
  ) {
    return this.bookingNotes.openDispute(user, id, dto.reason, dto.note);
  }

  @Post('bookings/:id/dispute/resolve')
  resolveDispute(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminResolveDisputeDto,
  ) {
    return this.bookingNotes.resolveDispute(user, id, dto.status, dto.note);
  }

  @Get('activities/export')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="activity.csv"')
  async exportActivities(@Res() res: Response, @Query() query: Record<string, string>) {
    const csv = await this.activities.exportCsv(query);
    res.send('\uFEFF' + csv);
  }

  @Get('activities')
  listActivities(@Query() query: Record<string, string>) {
    return this.activities.list(query);
  }

  @Get('coupons')
  listCoupons(@Query() query: Record<string, string>) {
    return this.couponsAdmin.list(query);
  }

  @Post('coupons')
  @Roles(UserRole.ADMIN)
  createCoupon(@CurrentUser() user: AuthUser, @Body() dto: AdminCouponDto) {
    return this.couponsAdmin.create(user, dto);
  }

  @Post('coupons/validate')
  validateCoupon(@CurrentUser() user: AuthUser, @Body() dto: AdminValidateCouponDto) {
    return this.couponsAdmin.validate(user, dto);
  }

  @Patch('coupons/:id')
  @Roles(UserRole.ADMIN)
  updateCoupon(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: Partial<AdminCouponDto>,
  ) {
    return this.couponsAdmin.update(user, id, dto);
  }

  @Delete('coupons/:id')
  @Roles(UserRole.ADMIN)
  deleteCoupon(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.couponsAdmin.remove(user, id);
  }

  @Get('banners')
  listBanners() {
    return this.banners.list();
  }

  @Post('banners')
  createBanner(@CurrentUser() user: AuthUser, @Body() dto: AdminBannerDto) {
    return this.banners.create(user, dto);
  }

  @Patch('banners/:id')
  updateBanner(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: Partial<AdminBannerDto>,
  ) {
    return this.banners.update(user, id, dto);
  }

  @Delete('banners/:id')
  deleteBanner(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.banners.remove(user, id);
  }

  @Get('spotlights')
  listSpotlights() {
    return this.spotlights.list();
  }

  @Post('spotlights')
  createSpotlight(@CurrentUser() user: AuthUser, @Body() dto: AdminSpotlightDto) {
    return this.spotlights.create(user, dto);
  }

  @Patch('spotlights/:id')
  updateSpotlight(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: Partial<AdminSpotlightDto>,
  ) {
    return this.spotlights.update(user, id, dto);
  }

  @Delete('spotlights/:id')
  deleteSpotlight(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.spotlights.remove(user, id);
  }

  @Post('properties/bulk')
  bulkProperties(@CurrentUser() user: AuthUser, @Body() dto: BulkPropertiesDto) {
    return this.properties.bulk(user, dto.action, dto.ids);
  }

  @Post('properties/:id/duplicate')
  duplicateProperty(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.properties.duplicate(user, id);
  }

  @Get('properties')
  listProperties(@Query() query: Record<string, string>) {
    return this.properties.list(query);
  }

  @Get('properties/:id')
  getProperty(@Param('id') id: string) {
    return this.properties.getOne(id);
  }

  @Post('properties')
  createProperty(@CurrentUser() user: AuthUser, @Body() dto: AdminCreatePropertyDto) {
    return this.properties.create(user, dto);
  }

  @Patch('properties/:id')
  updateProperty(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminUpdatePropertyDto,
  ) {
    return this.properties.update(user, id, dto);
  }

  @Delete('properties/:id')
  deleteProperty(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.properties.remove(user, id);
  }

  @Post('properties/:id/publish')
  publishProperty(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.properties.publish(user, id);
  }

  @Post('properties/:id/suspend')
  suspendProperty(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.properties.suspend(user, id);
  }

  @Post('properties/:id/reject')
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
  @Roles(UserRole.ADMIN)
  createAmenity(@CurrentUser() user: AuthUser, @Body() dto: AdminAmenityDto) {
    return this.amenities.create(user, dto);
  }

  @Patch('amenities/:id')
  @Roles(UserRole.ADMIN)
  updateAmenity(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: Partial<AdminAmenityDto>,
  ) {
    return this.amenities.update(user, id, dto);
  }

  @Delete('amenities/:id')
  @Roles(UserRole.ADMIN)
  deleteAmenity(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.amenities.remove(user, id);
  }

  @Get('properties/:id/pricing-preview')
  pricingPreview(
    @Param('id') id: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.pricing.preview(id, from, to);
  }

  @Get('properties/:id/pricing-rules')
  listPricingRules(@Param('id') id: string) {
    return this.pricing.listRules(id);
  }

  @Post('properties/:id/pricing-rules')
  createPricingRule(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminPriceRuleDto,
  ) {
    return this.pricing.createRule(user, id, dto);
  }

  @Patch('properties/:id/pricing-rules/:ruleId')
  updatePricingRule(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('ruleId') ruleId: string,
    @Body() dto: Partial<AdminPriceRuleDto>,
  ) {
    return this.pricing.updateRule(user, id, ruleId, dto);
  }

  @Delete('properties/:id/pricing-rules/:ruleId')
  deletePricingRule(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('ruleId') ruleId: string,
  ) {
    return this.pricing.deleteRule(user, id, ruleId);
  }

  @Get('properties/:id/media')
  listMedia(@Param('id') id: string) {
    return this.media.listByProperty(id);
  }

  @Post('properties/:id/media')
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: { type: 'string', format: 'binary' },
        targetRatio: { type: 'string', enum: ['auto', '16:9', '9:16', '1:1', '4:3'] },
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
  ) {
    return this.media.uploadForProperty(user, id, file, targetRatio);
  }

  @Post('properties/:id/media/bulk')
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
  ) {
    const results = [];
    for (const file of files ?? []) {
      results.push(await this.media.uploadForProperty(user, id, file, targetRatio));
    }
    return results;
  }

  @Post('media/:mediaId/reprocess')
  reprocessMedia(
    @CurrentUser() user: AuthUser,
    @Param('mediaId') mediaId: string,
    @Body('targetRatio') targetRatio?: string,
  ) {
    return this.media.reprocess(user, mediaId, targetRatio);
  }

  @Patch('properties/:id/media/reorder')
  reorderMedia(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ReorderMediaDto,
  ) {
    return this.media.reorder(user, id, dto.mediaIds);
  }

  @Patch('properties/:id/media/:mediaId/primary')
  setPrimaryMedia(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('mediaId') mediaId: string,
  ) {
    return this.media.setPrimary(user, id, mediaId);
  }

  @Patch('media/:mediaId')
  updateMedia(
    @CurrentUser() user: AuthUser,
    @Param('mediaId') mediaId: string,
    @Body() dto: UpdateMediaDto,
  ) {
    return this.media.update(user, mediaId, dto);
  }

  @Delete('media/:mediaId')
  deleteMedia(@CurrentUser() user: AuthUser, @Param('mediaId') mediaId: string) {
    return this.media.remove(user, mediaId);
  }

  @Get('properties/:id/availability')
  listAvailability(@Param('id') id: string, @Query('month') month?: string) {
    return this.availability.list(id, month);
  }

  @Post('properties/:id/availability/bulk')
  bulkAvailability(@Param('id') id: string, @Body() dto: BulkAvailabilityDto) {
    return this.availability.bulkSet(id, dto);
  }

  @Post('properties/:id/availability/clear')
  clearAvailability(@Param('id') id: string, @Body() dto: ClearAvailabilityDto) {
    return this.availability.clear(id, dto.dates, dto.shifts);
  }
}
