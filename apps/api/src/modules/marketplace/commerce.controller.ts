import { Body, Controller, Get, Header, Param, Patch, Post, Res } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Response } from 'express';
import { ApiBearerAuth, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { ShiftType } from '@prisma/client';
import { Type } from 'class-transformer';
import { IsBoolean, IsDateString, IsEnum, IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { CommerceService } from './commerce.service';

class CancellationDto {
  @ApiProperty()
  @IsUUID()
  bookingId!: string;

  @IsOptional()
  @IsString()
  reason?: string;
}

class CreateOfferDto {
  @ApiProperty()
  @IsUUID()
  propertyId!: string;

  @ApiProperty({ example: '9647700000000' })
  @IsString()
  customerPhone!: string;

  @ApiProperty()
  @IsDateString()
  startDate!: string;

  @ApiProperty()
  @IsDateString()
  endDate!: string;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  amount!: number;

  @ApiPropertyOptional({ enum: ShiftType })
  @IsOptional()
  @IsEnum(ShiftType)
  shift?: ShiftType;

  @IsOptional()
  @IsString()
  message?: string;

  @IsOptional()
  @IsDateString()
  expiresAt?: string;
}

class OfferDecisionDto {
  @IsBoolean()
  accept!: boolean;
}

class ReviewOwnedRequestDto {
  @IsBoolean()
  approve!: boolean;

  @IsOptional()
  @IsString()
  note?: string;
}

@ApiTags('commerce')
@ApiBearerAuth()
@Controller()
export class CommerceController {
  constructor(private readonly commerce: CommerceService) {}

  @Get('invoices')
  invoices(@CurrentUser() user: AuthUser) {
    return this.commerce.myInvoices(user);
  }

  @Get('invoices/by-booking/:bookingId/print')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async invoicePrintByBooking(
    @CurrentUser() user: AuthUser,
    @Param('bookingId') bookingId: string,
    @Res() res: Response,
  ) {
    res.send(await this.commerce.invoicePrintByBooking(user, bookingId));
  }

  @Get('invoices/by-booking/:bookingId')
  invoiceByBooking(@CurrentUser() user: AuthUser, @Param('bookingId') bookingId: string) {
    return this.commerce.invoiceByBooking(user, bookingId);
  }

  @Get('invoices/:id/print')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async invoicePrint(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Res() res: Response,
  ) {
    res.send(await this.commerce.invoicePrint(user, id));
  }

  @Get('invoices/:id')
  invoice(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.commerce.invoiceById(user, id);
  }

  @Post('cancellations')
  cancelRequest(@CurrentUser() user: AuthUser, @Body() dto: CancellationDto) {
    return this.commerce.requestCancellation(user, dto.bookingId, dto.reason ?? '');
  }

  @Post('refunds')
  refund(@CurrentUser() user: AuthUser, @Body() dto: CancellationDto) {
    return this.commerce.requestRefund(user, dto.bookingId, dto.reason ?? '');
  }

  @Get('booking-requests')
  requests(@CurrentUser() user: AuthUser) {
    return this.commerce.myRequests(user);
  }

  @Patch('cancellations/:id')
  reviewCancellation(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ReviewOwnedRequestDto,
  ) {
    return this.commerce.reviewOwnedCancellation(user, id, dto);
  }

  @Get('offers')
  offers(@CurrentUser() user: AuthUser) {
    return this.commerce.myOffers(user);
  }

  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @Post('offers')
  createOffer(@CurrentUser() user: AuthUser, @Body() dto: CreateOfferDto) {
    return this.commerce.createOffer(user, dto);
  }

  @Post('offers/:id/respond')
  respond(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: OfferDecisionDto,
  ) {
    return this.commerce.respondOffer(user, id, dto.accept);
  }
}
