import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { DiscountType, PropertyType } from '@prisma/client';
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
  Min,
  MinLength,
} from 'class-validator';

export class AdminCouponDto {
  @ApiProperty({ description: 'رمز الخصم — يُحوَّل لحروف كبيرة تلقائياً' })
  @IsString()
  @MinLength(3)
  code!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ enum: DiscountType })
  @IsOptional()
  @IsEnum(DiscountType)
  discountType?: DiscountType;

  @ApiProperty({ description: 'نسبة (0-100) أو مبلغ ثابت حسب النوع' })
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  discountValue!: number;

  @ApiPropertyOptional({ description: 'الحد الأدنى لإجمالي الحجز' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  minBookingTotal?: number;

  @ApiPropertyOptional({ description: 'حد الاستخدام الكلي — فارغ = غير محدود' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  maxUses?: number;

  @ApiPropertyOptional({ description: 'حد الاستخدام لكل مستخدم' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  maxUsesPerUser?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  startsAt?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  expiresAt?: string;

  @ApiPropertyOptional({ enum: PropertyType, isArray: true, description: 'فارغ = كل الأنواع' })
  @IsOptional()
  @IsArray()
  @IsEnum(PropertyType, { each: true })
  appliesToTypes?: PropertyType[];

  @ApiPropertyOptional({ description: 'حصر الكوبون بمكان محدد' })
  @IsOptional()
  @IsUUID()
  propertyId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

export class AdminValidateCouponDto {
  @ApiProperty()
  @IsString()
  code!: string;

  @ApiProperty()
  @IsUUID()
  propertyId!: string;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  total!: number;
}
