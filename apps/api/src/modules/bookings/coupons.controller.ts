import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { PropertyType } from '@prisma/client';
import { Public } from '../../common/decorators/public.decorator';
import { CouponService } from '../../common/services/coupon.service';

@ApiTags('coupons')
@Controller('coupons')
export class CouponsController {
  constructor(private readonly coupons: CouponService) {}

  @Public()
  @Get()
  list(@Query('type') type?: string) {
    const allowed = Object.values(PropertyType) as string[];
    const propertyType = type && allowed.includes(type) ? (type as PropertyType) : undefined;
    return this.coupons.listPublic(propertyType);
  }
}
