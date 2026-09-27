import { BadRequestException, Body, Controller, Get, NotFoundException, Param, Patch, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { BookingStatus, ShiftType, UserRole } from '@prisma/client';
import { IsDateString, IsEnum, IsInt, IsOptional, IsString, IsUUID, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { CouponService } from '../../common/services/coupon.service';
import { PrismaService } from '../../prisma/prisma.service';
import { proofStorageOptions } from '../admin/admin-media.service';
import { BookingsService } from './bookings.service';

class CreateBookingBody {
  @ApiProperty()
  @IsUUID()
  propertyId!: string;

  @ApiProperty()
  @IsDateString()
  startDate!: string;

  @ApiProperty()
  @IsDateString()
  endDate!: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  guests?: number;

  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsString()
  proofUrl?: string;

  @ApiPropertyOptional({ enum: ShiftType })
  @IsOptional()
  @IsEnum(ShiftType)
  shift?: ShiftType;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  couponCode?: string;
}

class QuoteBookingBody {
  @ApiProperty()
  @IsUUID()
  propertyId!: string;

  @ApiProperty()
  @IsDateString()
  startDate!: string;

  @ApiProperty()
  @IsDateString()
  endDate!: string;

  @ApiPropertyOptional({ enum: ShiftType })
  @IsOptional()
  @IsEnum(ShiftType)
  shift?: ShiftType;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  couponCode?: string;
}

class UpdateBookingStatusDto {
  @IsEnum(BookingStatus)
  status!: BookingStatus;
}

class ValidateCouponDto {
  @ApiProperty()
  @IsString()
  code!: string;

  @ApiProperty()
  @IsUUID()
  propertyId!: string;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  total!: number;
}

@ApiTags('bookings')
@ApiBearerAuth()
@Controller('bookings')
export class BookingsController {
  constructor(
    private readonly bookings: BookingsService,
    private readonly coupons: CouponService,
    private readonly prisma: PrismaService,
  ) {}

  /** تفاصيل حجز واحد — لصاحبه أو فريق المنصة */
  @Get(':id')
  async getOne(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    const booking = await this.bookings.getOne(id);
    const isStaff = user.role === 'ADMIN' || user.role === 'STAFF';
    const isOwner = booking.userId === user.id;
    const isPropertyOwner = booking.property?.provider?.userId === user.id;
    if (!isStaff && !isOwner && !isPropertyOwner) {
      throw new NotFoundException('الحجز غير موجود');
    }
    return booking;
  }

  @Public()
  @Post('quote')
  quote(@CurrentUser() user: AuthUser | undefined, @Body() dto: QuoteBookingBody) {
    return this.bookings.quote(user ?? null, dto);
  }

  /** تحقق فوري من كوبون للعرض الحي أثناء الحجز */
  @Post('quote-coupon')
  async validateCoupon(@CurrentUser() user: AuthUser, @Body() dto: ValidateCouponDto) {
    try {
      const property = await this.prisma.property.findUnique({
        where: { id: dto.propertyId },
      });
      if (!property) throw new BadRequestException('المكان غير موجود');
      const validation = await this.coupons.validate(
        dto.code,
        property,
        dto.total,
        user.id,
      );
      return {
        valid: true,
        code: validation.coupon.code,
        discount: validation.discount,
        totalAfterDiscount: validation.totalAfterDiscount,
      };
    } catch (error) {
      return {
        valid: false,
        reason: error instanceof Error ? error.message : 'رمز غير صالح',
      };
    }
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateBookingBody) {
    return this.bookings.create(user, dto);
  }

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.bookings.list(user);
  }

  @Post(':id/cancel')
  cancel(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.bookings.cancelByCustomer(user, id);
  }

  @Post(':id/payment-proof')
  @UseInterceptors(FileInterceptor('file', { storage: proofStorageOptions() }))
  attachProof(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @UploadedFile() file?: Express.Multer.File,
    @Body() body?: { proofUrl?: string },
  ) {
    const base = (process.env.MEDIA_PUBLIC_URL ?? 'http://localhost:3000/media').replace(/\/$/, '');
    const proofUrl = file ? `${base}/proofs/${file.filename}` : body?.proofUrl;
    if (!proofUrl) throw new BadRequestException('ارفع صورة الإيصال');
    return this.bookings.attachPaymentProof(user, id, proofUrl);
  }

  @Patch(':id/status')
  @Roles(UserRole.ADMIN, UserRole.STAFF, UserRole.PROVIDER)
  updateStatus(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateBookingStatusDto,
  ) {
    return this.bookings.updateStatus(user, id, dto.status);
  }
}
