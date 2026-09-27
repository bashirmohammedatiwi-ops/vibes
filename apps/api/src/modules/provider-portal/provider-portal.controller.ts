import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { ShiftType, UserRole } from '@prisma/client';
import { Type } from 'class-transformer';
import { IsEnum, IsInt, IsNumber, IsOptional, IsString, IsUUID, MaxLength, Min } from 'class-validator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AdminAvailabilityService } from '../admin/admin-availability.service';
import { AdminPricingService } from '../admin/admin-pricing.service';
import { AdminPriceRuleDto } from '../admin/dto/admin-property.dto';
import { ClearAvailabilityDto, BulkAvailabilityDto } from '../admin/dto/admin-property.dto';
import { ProviderPortalService } from './provider-portal.service';

class CreateExternalBookingDto {
  @ApiProperty()
  @IsUUID()
  propertyId!: string;

  @ApiProperty({ example: '2026-09-20' })
  @IsString()
  startDate!: string;

  @ApiPropertyOptional({ example: '2026-09-21' })
  @IsOptional()
  @IsString()
  endDate?: string;

  @ApiPropertyOptional({ enum: ShiftType })
  @IsOptional()
  @IsEnum(ShiftType)
  shift?: ShiftType;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(80)
  guestName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(20)
  guestPhone?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  guests?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  totalPrice?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(400)
  notes?: string;
}

@ApiTags('provider-portal')
@ApiBearerAuth()
@Roles(UserRole.PROVIDER)
@Controller('provider')
export class ProviderPortalController {
  constructor(
    private readonly portal: ProviderPortalService,
    private readonly pricing: AdminPricingService,
    private readonly availability: AdminAvailabilityService,
  ) {}

  @Get('overview')
  overview(@CurrentUser() user: AuthUser) {
    return this.portal.overview(user);
  }

  @Get('revenue')
  revenue(@CurrentUser() user: AuthUser, @Query('months') months?: string) {
    return this.portal.revenue(user, Math.min(Math.max(Number(months) || 6, 1), 12));
  }

  @Get('properties')
  properties(@CurrentUser() user: AuthUser) {
    return this.portal.properties(user);
  }

  @Get('bookings')
  bookings(@CurrentUser() user: AuthUser, @Query() query: Record<string, string>) {
    return this.portal.bookings(user, query);
  }

  @Get('bookings/:id')
  bookingDetail(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.portal.bookingDetail(user, id);
  }

  @Post('external-bookings')
  createExternal(@CurrentUser() user: AuthUser, @Body() dto: CreateExternalBookingDto) {
    return this.portal.createExternal(user, dto);
  }

  @Patch('bookings/:id/cancel')
  cancelExternal(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.portal.cancelExternal(user, id);
  }

  @Get('properties/:id/pricing-rules')
  async listRules(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    await this.portal.assertOwnedProperty(user, id);
    return this.pricing.listRules(id);
  }

  @Post('properties/:id/pricing-rules')
  async createRule(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminPriceRuleDto,
  ) {
    await this.portal.assertOwnedProperty(user, id);
    return this.pricing.createRule(user, id, dto);
  }

  @Patch('properties/:id/pricing-rules/:ruleId')
  async updateRule(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('ruleId') ruleId: string,
    @Body() dto: Partial<AdminPriceRuleDto>,
  ) {
    await this.portal.assertOwnedProperty(user, id);
    return this.pricing.updateRule(user, id, ruleId, dto);
  }

  @Delete('properties/:id/pricing-rules/:ruleId')
  async deleteRule(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('ruleId') ruleId: string,
  ) {
    await this.portal.assertOwnedProperty(user, id);
    return this.pricing.deleteRule(user, id, ruleId);
  }

  @Get('properties/:id/pricing-preview')
  async pricingPreview(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    await this.portal.assertOwnedProperty(user, id);
    return this.pricing.preview(id, from, to);
  }

  @Get('properties/:id/availability')
  async listAvailability(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query('month') month?: string,
  ) {
    await this.portal.assertOwnedProperty(user, id);
    return this.availability.list(id, month);
  }

  @Post('properties/:id/availability/bulk')
  async bulkAvailability(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: BulkAvailabilityDto,
  ) {
    await this.portal.assertOwnedProperty(user, id);
    return this.availability.bulkSet(id, dto);
  }

  @Post('properties/:id/availability/clear')
  async clearAvailability(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ClearAvailabilityDto,
  ) {
    await this.portal.assertOwnedProperty(user, id);
    return this.availability.clear(id, dto.dates, dto.shifts);
  }
}
