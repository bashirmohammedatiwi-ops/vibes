import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { IsBoolean, IsIn, IsOptional, IsString } from 'class-validator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { StaffService } from './staff.service';

class PresenceDto {
  @IsIn(['AVAILABLE', 'AWAY'])
  state!: 'AVAILABLE' | 'AWAY';

  @IsOptional()
  @IsString()
  deviceId?: string;
}

class HeartbeatDto {
  @IsOptional()
  @IsString()
  deviceId?: string;
}

class MessageDto {
  @IsString()
  body!: string;
}

class NoteDto {
  @IsString()
  staffNote!: string;

  @IsOptional()
  @IsBoolean()
  followUp?: boolean;
}

class ReasonDto {
  @IsOptional()
  @IsString()
  reason?: string;
}

class ReviewDto {
  @IsBoolean()
  approve!: boolean;

  @IsOptional()
  @IsString()
  note?: string;
}

class PropertyStatusDto {
  @IsIn(['APPROVED', 'REJECTED', 'SUSPENDED', 'PENDING'])
  status!: string;

  @IsOptional()
  @IsString()
  reason?: string;
}

class ProviderVerifyDto {
  @IsBoolean()
  verified!: boolean;

  @IsOptional()
  @IsString()
  reason?: string;
}

class ActiveDto {
  @IsBoolean()
  isActive!: boolean;
}

class ReviewVisibilityDto {
  @IsBoolean()
  isVisible!: boolean;

  @IsOptional()
  @IsString()
  adminNote?: string;
}

@ApiTags('staff')
@ApiBearerAuth()
@Roles(UserRole.STAFF, UserRole.ADMIN)
@Controller('staff')
export class StaffController {
  constructor(private readonly staff: StaffService) {}

  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.staff.me(user);
  }

  @Post('presence')
  presence(@CurrentUser() user: AuthUser, @Body() dto: PresenceDto) {
    return this.staff.setPresence(user, dto.state, dto.deviceId);
  }

  @Post('presence/heartbeat')
  heartbeat(@CurrentUser() user: AuthUser, @Body() dto: HeartbeatDto) {
    return this.staff.heartbeat(user, dto.deviceId);
  }

  @Get('calls/ringing')
  ringing(@CurrentUser() user: AuthUser) {
    return this.staff.ringing(user);
  }

  @Get('queue/summary')
  queue(@CurrentUser() user: AuthUser) {
    return this.staff.queueSummary(user);
  }

  @Get('queue/waiting')
  queueWaiting(@CurrentUser() user: AuthUser) {
    return this.staff.queueWaiting(user);
  }

  @Get('calls/recent')
  recentCalls(@CurrentUser() user: AuthUser) {
    return this.staff.recentCalls(user);
  }

  @Get('supervisor')
  supervisor(@CurrentUser() user: AuthUser) {
    return this.staff.supervisorForStaff(user);
  }

  @Get('dashboard')
  dashboard(@CurrentUser() user: AuthUser) {
    return this.staff.dashboard(user);
  }

  @Get('inbox')
  inbox(@CurrentUser() user: AuthUser) {
    return this.staff.inbox(user);
  }

  @Get('contacts')
  contacts(@CurrentUser() user: AuthUser) {
    return this.staff.chatContacts(user);
  }

  @Get('customers/:userId/thread')
  customerThread(@CurrentUser() user: AuthUser, @Param('userId') userId: string, @Query('after') after?: string) {
    return this.staff.customerThread(user, userId, after);
  }

  @Get('customers/:userId')
  customer(@CurrentUser() user: AuthUser, @Param('userId') userId: string) {
    return this.staff.customerProfile(user, userId);
  }

  @Post('customers/:userId/chat')
  openChat(@CurrentUser() user: AuthUser, @Param('userId') userId: string) {
    return this.staff.openCustomerChat(user, userId);
  }

  @Post('inbox/:id/messages')
  reply(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: MessageDto) {
    return this.staff.reply(user, id, dto.body);
  }

  @Post('inbox/:id/note')
  note(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: NoteDto) {
    return this.staff.note(user, id, dto.staffNote, dto.followUp);
  }

  @Get('ops/overview')
  opsOverview(@CurrentUser() user: AuthUser) {
    return this.staff.opsOverview(user);
  }

  @Get('bookings')
  bookings(
    @CurrentUser() user: AuthUser,
    @Query('status') status?: string,
    @Query('q') q?: string,
  ) {
    return this.staff.bookings(user, status, q);
  }

  @Get('bookings/:id')
  bookingDetail(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.staff.bookingDetail(user, id);
  }

  @Post('bookings/:id/notes')
  bookingNote(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: MessageDto,
  ) {
    return this.staff.addBookingNote(user, id, dto.body);
  }

  @Post('bookings/:id/confirm')
  confirm(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.staff.confirmBooking(user, id);
  }

  @Post('bookings/:id/cancel')
  cancel(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: ReasonDto) {
    return this.staff.cancelBooking(user, id, dto.reason ?? '');
  }

  @Get('payments')
  payments(@CurrentUser() user: AuthUser, @Query('status') status?: string) {
    return this.staff.listPayments(user, status);
  }

  @Get('payments/:id')
  paymentDetail(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.staff.paymentDetail(user, id);
  }

  @Post('payments/:id/verify')
  verify(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.staff.verifyPayment(user, id);
  }

  @Post('payments/:id/reject')
  rejectPayment(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ReasonDto,
  ) {
    return this.staff.rejectPayment(user, id, dto.reason);
  }

  @Get('properties')
  properties(
    @CurrentUser() user: AuthUser,
    @Query('status') status?: string,
    @Query('q') q?: string,
  ) {
    return this.staff.listProperties(user, status, q);
  }

  @Get('properties/:id')
  propertyDetail(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.staff.propertyDetail(user, id);
  }

  @Post('properties/:id/status')
  propertyStatus(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: PropertyStatusDto,
  ) {
    return this.staff.setPropertyStatus(user, id, dto.status, dto.reason);
  }

  @Get('providers')
  providers(@CurrentUser() user: AuthUser, @Query('q') q?: string) {
    return this.staff.listProviders(user, q);
  }

  @Post('providers/:id/verify')
  verifyProvider(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ProviderVerifyDto,
  ) {
    return this.staff.setProviderVerified(user, id, dto.verified, dto.reason);
  }

  @Get('users')
  users(@CurrentUser() user: AuthUser, @Query('q') q?: string) {
    return this.staff.searchUsers(user, q);
  }

  @Get('requests')
  requests(@CurrentUser() user: AuthUser) {
    return this.staff.requests(user);
  }

  @Post('requests/cancellations/:id')
  reviewCancellation(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: ReviewDto) {
    return this.staff.reviewCancellation(user, id, dto.approve, dto.note);
  }

  @Post('requests/refunds/:id')
  reviewRefund(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: ReviewDto) {
    return this.staff.reviewRefund(user, id, dto.approve, dto.note);
  }

  @Get('customers')
  customers(@CurrentUser() user: AuthUser, @Query('phone') phone = '') {
    return this.staff.findCustomer(user, phone);
  }

  @Get('banners')
  banners(@CurrentUser() user: AuthUser) {
    return this.staff.listBanners(user);
  }

  @Post('banners/:id/active')
  bannerActive(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ActiveDto,
  ) {
    return this.staff.setBannerActive(user, id, dto.isActive);
  }

  @Get('reviews')
  reviews(@CurrentUser() user: AuthUser, @Query('hidden') hidden?: string) {
    return this.staff.listReviews(user, hidden === '1' || hidden === 'true');
  }

  @Post('reviews/:id/visibility')
  reviewVisibility(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ReviewVisibilityDto,
  ) {
    return this.staff.setReviewVisible(user, id, dto.isVisible, dto.adminNote);
  }

  @Get('spotlights')
  spotlights(@CurrentUser() user: AuthUser) {
    return this.staff.listSpotlights(user);
  }

  @Post('spotlights/:id/active')
  spotlightActive(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ActiveDto,
  ) {
    return this.staff.setSpotlightActive(user, id, dto.isActive);
  }

  @Get('coupons')
  coupons(@CurrentUser() user: AuthUser) {
    return this.staff.listCoupons(user);
  }

  @Post('coupons/:id/active')
  couponActive(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ActiveDto,
  ) {
    return this.staff.setCouponActive(user, id, dto.isActive);
  }

  @Get('invoices')
  invoices(@CurrentUser() user: AuthUser, @Query('status') status?: string) {
    return this.staff.listInvoices(user, status);
  }

  @Get('notifications')
  notifications(@CurrentUser() user: AuthUser) {
    return this.staff.listNotifications(user);
  }

  @Post('notifications/:id/read')
  readNotification(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.staff.markNotificationRead(user, id);
  }
}
