import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { BookingMode, PriceRuleType, PropertyStatus, PropertyType, ShiftType } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  Min,
  MinLength,
} from 'class-validator';

const TIME_FORMAT = /^([01]\d|2[0-3]):[0-5]\d$/;
const TIME_MESSAGE = 'صيغة الوقت يجب أن تكون HH:mm (مثال 08:30)';

export class AdminCreatePropertyDto {
  @ApiProperty({ enum: PropertyType })
  @IsEnum(PropertyType)
  type!: PropertyType;

  @ApiProperty()
  @IsString()
  name!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  slug?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty()
  @IsUUID()
  cityId!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  address?: string;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  latitude!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  longitude!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  capacity?: number;

  @ApiPropertyOptional({ enum: BookingMode, description: 'وضع الحجز — افتراضياً مشتق من النوع' })
  @IsOptional()
  @IsEnum(BookingMode)
  bookingMode?: BookingMode;

  @ApiPropertyOptional({ description: 'بداية الشفت الصباحي HH:mm' })
  @IsOptional()
  @IsString()
  @Matches(TIME_FORMAT, { message: TIME_MESSAGE })
  morningStart?: string;

  @ApiPropertyOptional({ description: 'نهاية الشفت الصباحي HH:mm' })
  @IsOptional()
  @IsString()
  @Matches(TIME_FORMAT, { message: TIME_MESSAGE })
  morningEnd?: string;

  @ApiPropertyOptional({ description: 'بداية الشفت المسائي HH:mm' })
  @IsOptional()
  @IsString()
  @Matches(TIME_FORMAT, { message: TIME_MESSAGE })
  eveningStart?: string;

  @ApiPropertyOptional({ description: 'نهاية الشفت المسائي HH:mm' })
  @IsOptional()
  @IsString()
  @Matches(TIME_FORMAT, { message: TIME_MESSAGE })
  eveningEnd?: string;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  pricePerDay!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  weekendPrice?: number;

  @ApiPropertyOptional({ description: 'سعر الشفت الصباحي للمزارع' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  priceMorningShift?: number;

  @ApiPropertyOptional({ description: 'سعر الشفت المسائي للمزارع' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  priceEveningShift?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  phone?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  whatsapp?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  featured?: boolean;

  @ApiPropertyOptional({ description: 'يظهر المكان ضمن المزارع أو القاعات الجديدة' })
  @IsOptional()
  @IsBoolean()
  isNew?: boolean;

  @ApiPropertyOptional({ enum: PropertyStatus })
  @IsOptional()
  @IsEnum(PropertyStatus)
  status?: PropertyStatus;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  amenities?: string[];

  @ApiPropertyOptional({
    type: [String],
    description: 'معرفات المزايا من الكتالوج — البديل المنظم عن amenities النصية',
  })
  @IsOptional()
  @IsArray()
  @IsUUID(undefined, { each: true })
  amenityIds?: string[];

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  tags?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  rules?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  internalNotes?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  nameEn?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  descriptionEn?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  metaTitle?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  metaDescription?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  providerId?: string;
}

export class RejectPropertyDto {
  @ApiProperty()
  @IsString()
  @MinLength(3)
  reason!: string;
}

export class AdminUpdatePropertyDto extends PartialType(AdminCreatePropertyDto) {}

export class ReorderMediaDto {
  @ApiProperty({ type: [String] })
  @IsArray()
  @IsUUID(undefined, { each: true })
  mediaIds!: string[];
}

export class UpdateMediaDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  caption?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  altText?: string;
}

export class BulkAvailabilityDto {
  @ApiProperty({ type: [String], description: 'ISO dates YYYY-MM-DD' })
  @IsArray()
  @IsString({ each: true })
  dates!: string[];

  @ApiProperty()
  @IsBoolean()
  isAvailable!: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  priceOverride?: number;

  @ApiPropertyOptional({ enum: ShiftType })
  @IsOptional()
  @IsEnum(ShiftType)
  shift?: ShiftType;

  @ApiPropertyOptional({ enum: ShiftType, isArray: true })
  @IsOptional()
  @IsArray()
  @IsEnum(ShiftType, { each: true })
  shifts?: ShiftType[];
}

export class ClearAvailabilityDto {
  @ApiProperty({ type: [String], description: 'ISO dates YYYY-MM-DD' })
  @IsArray()
  @IsString({ each: true })
  dates!: string[];

  @ApiPropertyOptional({ enum: ShiftType, isArray: true })
  @IsOptional()
  @IsArray()
  @IsEnum(ShiftType, { each: true })
  shifts?: ShiftType[];
}

export class AdminPriceRuleDto {
  @ApiPropertyOptional({ description: 'اسم وصفي للقاعدة مثل: أسعار نهاية الأسبوع' })
  @IsOptional()
  @IsString()
  name?: string;

  @ApiProperty({ enum: PriceRuleType })
  @IsEnum(PriceRuleType)
  ruleType!: PriceRuleType;

  @ApiPropertyOptional({
    type: [Number],
    description: 'أيام الأسبوع 0=الأحد .. 6=السبت (للقاعدة الأسبوعية)',
  })
  @IsOptional()
  @IsArray()
  @IsInt({ each: true })
  @Min(0, { each: true })
  @Max(6, { each: true })
  daysOfWeek?: number[];

  @ApiPropertyOptional({ description: 'بداية الفترة YYYY-MM-DD (للقاعدة الموسمية)' })
  @IsOptional()
  @IsDateString()
  startDate?: string;

  @ApiPropertyOptional({ description: 'نهاية الفترة YYYY-MM-DD (شاملة)' })
  @IsOptional()
  @IsDateString()
  endDate?: string;

  @ApiPropertyOptional({ description: 'سعر اليوم الكامل — الفارغ يرث الافتراضي' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  fullDayPrice?: number;

  @ApiPropertyOptional({ description: 'سعر الشفت الصباحي — الفارغ يرث الافتراضي' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  morningPrice?: number;

  @ApiPropertyOptional({ description: 'سعر الشفت المسائي — الفارغ يرث الافتراضي' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  eveningPrice?: number;

  @ApiPropertyOptional({ description: 'بداية الشفت الصباحي البديلة HH:mm (مثال رمضان)' })
  @IsOptional()
  @IsString()
  @Matches(TIME_FORMAT, { message: TIME_MESSAGE })
  morningStart?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Matches(TIME_FORMAT, { message: TIME_MESSAGE })
  morningEnd?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Matches(TIME_FORMAT, { message: TIME_MESSAGE })
  eveningStart?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Matches(TIME_FORMAT, { message: TIME_MESSAGE })
  eveningEnd?: string;

  @ApiPropertyOptional({ description: 'الأعلى أولاً — فترات التواريخ تتفوق على الأسبوعية عند التساوي' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  priority?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
