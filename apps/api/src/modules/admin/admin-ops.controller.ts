import { Body, Controller, Get, Header, Param, Patch, Post, Query, Res } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { IsBoolean, IsIn, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { Response } from 'express';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { RequireStaffPermissions } from '../../common/decorators/staff-permissions.decorator';
import { AdminOpsService } from './admin-ops.service';

class ReviewRequestDto {
  @IsBoolean()
  approve!: boolean;

  @IsOptional()
  @IsString()
  adminNote?: string;
}

class ModeratePostDto {
  @IsIn(['PUBLISHED', 'HIDDEN', 'REPORTED'])
  status!: 'PUBLISHED' | 'HIDDEN' | 'REPORTED';
}

class AdminMessageDto {
  @IsOptional()
  @IsString()
  @MaxLength(4000)
  body?: string;
}

class SupportUserDto {
  @IsUUID()
  userId!: string;
}

@ApiTags('admin-ops')
@ApiBearerAuth()
@Roles(UserRole.ADMIN, UserRole.STAFF)
@Controller('admin')
export class AdminOpsController {
  constructor(private readonly ops: AdminOpsService) {}

  @Get('conversations')
  @RequireStaffPermissions('inbox.read')
  conversations(@Query() query: Record<string, string | undefined>) {
    return this.ops.conversations(query);
  }

  @Get('conversations/export')
  @RequireStaffPermissions('inbox.read')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="conversations.csv"')
  async exportConversations(@Res() res: Response, @Query() query: Record<string, string | undefined>) {
    res.send('\uFEFF' + (await this.ops.exportConversationsCsv(query)));
  }

  @Post('conversations/support')
  @RequireStaffPermissions('inbox.reply')
  openSupport(@CurrentUser() user: AuthUser, @Body() dto: SupportUserDto) {
    return this.ops.openSupportForCustomer(user, dto.userId);
  }

  @Patch('conversations/:id/ops')
  @RequireStaffPermissions('inbox.assign')
  updateConversationOps(
    @Param('id') id: string,
    @Body() dto: { status?: string; priority?: string; assignedToId?: string | null; staffNote?: string },
  ) {
    return this.ops.updateConversationOps(id, dto);
  }

  @Get('conversations/:id/calls')
  @RequireStaffPermissions('inbox.read')
  conversationCalls(@Param('id') id: string) {
    return this.ops.conversationCalls(id);
  }

  @Get('conversations/staff')
  @RequireStaffPermissions('inbox.read')
  staffMembers() {
    return this.ops.staffMembers();
  }

  @Get('conversations/:id/messages')
  @RequireStaffPermissions('inbox.read')
  conversationMessages(
    @Param('id') id: string,
    @Query() query: Record<string, string | undefined>,
  ) {
    return this.ops.conversationMessages(id, query);
  }

  @Post('conversations/:id/messages')
  @RequireStaffPermissions('inbox.reply')
  reply(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminMessageDto,
  ) {
    return this.ops.replyToConversation(user, id, dto.body ?? '');
  }

  @Get('invoices')
  @RequireStaffPermissions('invoices.read')
  invoices(@Query() query: Record<string, string | undefined>) {
    return this.ops.invoices(query);
  }

  @Get('invoices/export')
  @RequireStaffPermissions('invoices.read')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="invoices.csv"')
  async exportInvoices(@Res() res: Response, @Query() query: Record<string, string | undefined>) {
    res.send('\uFEFF' + (await this.ops.exportInvoicesCsv(query)));
  }

  @Get('invoices/:id/print')
  @RequireStaffPermissions('invoices.read')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async printInvoice(@Param('id') id: string, @Res() res: Response) {
    res.send(await this.ops.invoicePrint(id));
  }

  @Get('invoices/:id')
  @RequireStaffPermissions('invoices.read')
  invoice(@Param('id') id: string) {
    return this.ops.invoiceById(id);
  }

  @Get('refunds')
  @RequireStaffPermissions('refunds.review')
  refunds(@Query() query: Record<string, string | undefined>) {
    return this.ops.refunds(query);
  }

  @Get('refunds/export')
  @RequireStaffPermissions('refunds.review')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="refunds.csv"')
  async exportRefunds(@Res() res: Response, @Query() query: Record<string, string | undefined>) {
    res.send('\uFEFF' + (await this.ops.exportRefundsCsv(query)));
  }

  @Patch('refunds/:id')
  @RequireStaffPermissions('refunds.review')
  reviewRefund(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ReviewRequestDto,
  ) {
    return this.ops.reviewRefund(user, id, dto);
  }

  @Patch('cancellations/:id')
  @RequireStaffPermissions('cancellations.review')
  reviewCancellation(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ReviewRequestDto,
  ) {
    return this.ops.reviewCancellation(user, id, dto);
  }

  @Get('collections')
  @RequireStaffPermissions('bookings.read')
  collections(@Query() query: Record<string, string | undefined>) {
    return this.ops.collections(query);
  }

  @Get('collections/export')
  @RequireStaffPermissions('bookings.read')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="collections.csv"')
  async exportCollections(@Res() res: Response, @Query() query: Record<string, string | undefined>) {
    res.send('\uFEFF' + (await this.ops.exportCollectionsCsv(query)));
  }

  @Get('collections/:id')
  @RequireStaffPermissions('bookings.read')
  collection(@Param('id') id: string) {
    return this.ops.collectionById(id);
  }

  @Get('social')
  @RequireStaffPermissions('reviews.moderate')
  social(@Query() query: Record<string, string | undefined>) {
    return this.ops.social(query);
  }

  @Get('social/export')
  @RequireStaffPermissions('reviews.moderate')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="social.csv"')
  async exportSocial(@Res() res: Response, @Query() query: Record<string, string | undefined>) {
    res.send('\uFEFF' + (await this.ops.exportSocialCsv(query)));
  }

  @Get('social/:id')
  @RequireStaffPermissions('reviews.moderate')
  socialPost(@Param('id') id: string) {
    return this.ops.socialById(id);
  }

  @Patch('social/:id')
  @RequireStaffPermissions('reviews.moderate')
  moderate(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ModeratePostDto,
  ) {
    return this.ops.moderatePost(user, id, dto.status as never);
  }

  @Get('offers')
  @RequireStaffPermissions('bookings.read')
  offers(@Query() query: Record<string, string | undefined>) {
    return this.ops.offers(query);
  }

  @Get('offers/export')
  @RequireStaffPermissions('bookings.read')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="offers.csv"')
  async exportOffers(@Res() res: Response, @Query() query: Record<string, string | undefined>) {
    res.send('\uFEFF' + (await this.ops.exportOffersCsv(query)));
  }
}
