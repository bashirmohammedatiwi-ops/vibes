import { Body, Controller, Get, Header, Param, Patch, Post, Query, Res } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { IsBoolean, IsIn, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { Response } from 'express';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
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
  conversations(@Query() query: Record<string, string | undefined>) {
    return this.ops.conversations(query);
  }

  @Get('conversations/export')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="conversations.csv"')
  async exportConversations(@Res() res: Response, @Query() query: Record<string, string | undefined>) {
    res.send('\uFEFF' + (await this.ops.exportConversationsCsv(query)));
  }

  @Post('conversations/support')
  openSupport(@CurrentUser() user: AuthUser, @Body() dto: SupportUserDto) {
    return this.ops.openSupportForCustomer(user, dto.userId);
  }

  @Get('conversations/:id/messages')
  conversationMessages(
    @Param('id') id: string,
    @Query() query: Record<string, string | undefined>,
  ) {
    return this.ops.conversationMessages(id, query);
  }

  @Post('conversations/:id/messages')
  reply(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminMessageDto,
  ) {
    return this.ops.replyToConversation(user, id, dto.body ?? '');
  }

  @Get('invoices')
  invoices(@Query() query: Record<string, string | undefined>) {
    return this.ops.invoices(query);
  }

  @Get('invoices/export')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="invoices.csv"')
  async exportInvoices(@Res() res: Response, @Query() query: Record<string, string | undefined>) {
    res.send('\uFEFF' + (await this.ops.exportInvoicesCsv(query)));
  }

  @Get('invoices/:id/print')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async printInvoice(@Param('id') id: string, @Res() res: Response) {
    res.send(await this.ops.invoicePrint(id));
  }

  @Get('invoices/:id')
  invoice(@Param('id') id: string) {
    return this.ops.invoiceById(id);
  }

  @Get('refunds')
  refunds(@Query() query: Record<string, string | undefined>) {
    return this.ops.refunds(query);
  }

  @Get('refunds/export')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="refunds.csv"')
  async exportRefunds(@Res() res: Response, @Query() query: Record<string, string | undefined>) {
    res.send('\uFEFF' + (await this.ops.exportRefundsCsv(query)));
  }

  @Patch('refunds/:id')
  reviewRefund(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ReviewRequestDto,
  ) {
    return this.ops.reviewRefund(user, id, dto);
  }

  @Patch('cancellations/:id')
  reviewCancellation(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ReviewRequestDto,
  ) {
    return this.ops.reviewCancellation(user, id, dto);
  }

  @Get('collections')
  collections(@Query() query: Record<string, string | undefined>) {
    return this.ops.collections(query);
  }

  @Get('collections/export')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="collections.csv"')
  async exportCollections(@Res() res: Response, @Query() query: Record<string, string | undefined>) {
    res.send('\uFEFF' + (await this.ops.exportCollectionsCsv(query)));
  }

  @Get('collections/:id')
  collection(@Param('id') id: string) {
    return this.ops.collectionById(id);
  }

  @Get('social')
  social(@Query() query: Record<string, string | undefined>) {
    return this.ops.social(query);
  }

  @Get('social/export')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="social.csv"')
  async exportSocial(@Res() res: Response, @Query() query: Record<string, string | undefined>) {
    res.send('\uFEFF' + (await this.ops.exportSocialCsv(query)));
  }

  @Get('social/:id')
  socialPost(@Param('id') id: string) {
    return this.ops.socialById(id);
  }

  @Patch('social/:id')
  moderate(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ModeratePostDto,
  ) {
    return this.ops.moderatePost(user, id, dto.status as never);
  }

  @Get('offers')
  offers(@Query() query: Record<string, string | undefined>) {
    return this.ops.offers(query);
  }

  @Get('offers/export')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="offers.csv"')
  async exportOffers(@Res() res: Response, @Query() query: Record<string, string | undefined>) {
    res.send('\uFEFF' + (await this.ops.exportOffersCsv(query)));
  }
}
