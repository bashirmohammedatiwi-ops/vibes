import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { BookingStatus, PaymentStatus, ShiftType, UserRole } from '@prisma/client';
import { IsBoolean, IsEnum, IsInt, IsOptional, IsString, IsArray, IsUUID, Min, MinLength } from 'class-validator';

export class AdminCreateBookingDto {
  @ApiProperty()
  @IsUUID()
  propertyId!: string;

  @ApiProperty({ example: '2026-09-10' })
  @IsString()
  startDate!: string;

  @ApiProperty({ example: '2026-09-12' })
  @IsString()
  endDate!: string;

  @ApiPropertyOptional({ enum: ShiftType })
  @IsOptional()
  @IsEnum(ShiftType)
  shift?: ShiftType;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(1)
  guests?: number;

  @ApiPropertyOptional({ description: 'رمز خصم اختياري' })
  @IsOptional()
  @IsString()
  couponCode?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;

  @ApiProperty({ example: '9647XXXXXXXX' })
  @IsString()
  @MinLength(10)
  customerPhone!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  customerName?: string;

  @ApiPropertyOptional({ description: 'تأكيد الحجز والدفع فوراً (للطلبات الهاتفية)' })
  @IsOptional()
  @IsBoolean()
  confirmImmediately?: boolean;
}

export class AdminBookingQuoteDto {
  @ApiProperty()
  @IsUUID()
  propertyId!: string;

  @ApiProperty()
  @IsString()
  startDate!: string;

  @ApiProperty()
  @IsString()
  endDate!: string;

  @ApiPropertyOptional({ enum: ShiftType })
  @IsOptional()
  @IsEnum(ShiftType)
  shift?: ShiftType;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  excludeBookingId?: string;

  @ApiPropertyOptional({ description: 'رمز خصم لمعاينة الخصم' })
  @IsOptional()
  @IsString()
  couponCode?: string;
}

export class AdminRescheduleBookingDto {
  @ApiProperty()
  @IsString()
  startDate!: string;

  @ApiProperty()
  @IsString()
  endDate!: string;

  @ApiPropertyOptional({ enum: ShiftType })
  @IsOptional()
  @IsEnum(ShiftType)
  shift?: ShiftType;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  adminNote?: string;
}

export class AdminBulkBookingsDto {
  @ApiProperty({ type: [String] })
  @IsArray()
  @IsUUID('4', { each: true })
  ids!: string[];

  @ApiProperty({ enum: BookingStatus })
  @IsEnum(BookingStatus)
  status!: BookingStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  adminNote?: string;
}

export class AdminUpdateBookingStatusDto {
  @ApiProperty({ enum: BookingStatus })
  @IsEnum(BookingStatus)
  status!: BookingStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  adminNote?: string;
}

export class AdminCreateUserDto {
  @ApiProperty({ example: '9647XXXXXXXX' })
  @IsString()
  @MinLength(10)
  phone!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  name?: string;

  @ApiPropertyOptional({ enum: UserRole })
  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;
}

export class AdminBulkReviewsDto {
  @ApiProperty({ type: [String] })
  @IsArray()
  @IsUUID('4', { each: true })
  ids!: string[];

  @ApiProperty({ enum: ['show', 'hide', 'delete'] })
  @IsString()
  action!: 'show' | 'hide' | 'delete';
}

export class AdminBulkPaymentsDto {
  @ApiProperty({ type: [String] })
  @IsArray()
  @IsUUID('4', { each: true })
  ids!: string[];

  @ApiProperty({ enum: PaymentStatus })
  @IsEnum(PaymentStatus)
  status!: PaymentStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  adminNote?: string;
}

export class AdminProfileDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  name?: string;
}

export class AdminUpdateUserDto {
  @ApiPropertyOptional({ enum: UserRole })
  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  name?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

export class AdminReviewVisibilityDto {
  @ApiProperty()
  @IsBoolean()
  isVisible!: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  adminNote?: string;
}

export class AdminPaymentStatusDto {
  @ApiProperty({ enum: PaymentStatus })
  @IsEnum(PaymentStatus)
  status!: PaymentStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  adminNote?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  transactionRef?: string;
}

export class AdminBookingNoteDto {
  @ApiProperty()
  @IsString()
  content!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isInternal?: boolean;
}

export class AdminDisputeDto {
  @ApiProperty()
  @IsString()
  reason!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  note?: string;
}

export class AdminProvinceDto {
  @ApiProperty()
  @IsString()
  nameAr!: string;

  @ApiProperty()
  @IsString()
  nameEn!: string;

  @ApiProperty()
  @IsString()
  slug!: string;
}

export class AdminCityDto {
  @ApiProperty()
  @IsString()
  nameAr!: string;

  @ApiProperty()
  @IsString()
  nameEn!: string;

  @ApiProperty()
  @IsString()
  slug!: string;
}

export class AdminRenameLocationDto {
  @ApiProperty()
  @IsString()
  @MinLength(2)
  nameAr!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  nameEn?: string;
}

export class AdminSettingsDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  supportPhone?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  paymentInstructions?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  morningShiftStart?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  morningShiftEnd?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  eveningShiftStart?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  eveningShiftEnd?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  fullShiftStart?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  fullShiftEnd?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  commissionPercent?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  cancellationPolicy?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  minBookingNoticeDays?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  zainCashEnabled?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  qiCardEnabled?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  manualProofEnabled?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  maintenanceMode?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  maintenanceMessage?: string;

  @ApiPropertyOptional({ description: 'إشعار واتساب لملاك الأماكن عند أحداث الحجوزات' })
  @IsOptional()
  @IsBoolean()
  notifyWhatsappEnabled?: boolean;
}

export class AdminRefundPaymentDto {
  @ApiProperty({ description: 'سبب الاسترداد — مطلوب' })
  @IsString()
  @MinLength(3)
  adminNote!: string;
}

export class AdminProviderReviewDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  reason?: string;
}

export class AdminEditBookingNoteDto {
  @ApiProperty()
  @IsString()
  @MinLength(1)
  content!: string;
}

export class AdminClearNotificationsDto {
  @ApiPropertyOptional({ description: 'حذف المقروء الأقدم من هذا العدد من الأيام' })
  @IsOptional()
  @IsInt()
  @Min(0)
  olderThanDays?: number;
}

export enum BulkPropertyAction {
  publish = 'publish',
  suspend = 'suspend',
  feature = 'feature',
  unfeature = 'unfeature',
  delete = 'delete',
}

export class BulkPropertiesDto {
  @ApiProperty({ type: [String] })
  @IsArray()
  @IsUUID(undefined, { each: true })
  ids!: string[];

  @ApiProperty({ enum: BulkPropertyAction })
  @IsEnum(BulkPropertyAction)
  action!: BulkPropertyAction;
}

export class AdminResolveDisputeDto {
  @ApiProperty({ enum: BookingStatus })
  @IsEnum(BookingStatus)
  status!: BookingStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  note?: string;
}

export class AdminBannerDto {
  @ApiProperty()
  @IsString()
  title!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  subtitle?: string;

  @ApiProperty()
  @IsString()
  imageUrl!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  linkUrl?: string;

  @ApiPropertyOptional()
  @IsOptional()
  sortOrder?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
