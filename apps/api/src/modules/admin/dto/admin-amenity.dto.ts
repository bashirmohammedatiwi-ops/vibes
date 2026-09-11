import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { PropertyType } from '@prisma/client';
import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class AdminAmenityDto {
  @ApiProperty()
  @IsString()
  nameAr!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  nameEn?: string;

  @ApiPropertyOptional({ description: 'فريد — يُولّد تلقائياً من الاسم إن تُرك فارغاً' })
  @IsOptional()
  @IsString()
  slug?: string;

  @ApiPropertyOptional({ description: 'أيقونة (رمز تعبيري أو اسم أيقونة)' })
  @IsOptional()
  @IsString()
  icon?: string;

  @ApiPropertyOptional({ description: 'فئة التجميع مثل: عام، تقنيات، خدمات' })
  @IsOptional()
  @IsString()
  category?: string;

  @ApiPropertyOptional({ enum: PropertyType, isArray: true, description: 'أنواع العقارات التي تظهر لها' })
  @IsOptional()
  @IsArray()
  @IsEnum(PropertyType, { each: true })
  appliesTo?: PropertyType[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
