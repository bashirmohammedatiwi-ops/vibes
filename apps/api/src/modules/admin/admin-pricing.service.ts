import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, PriceRuleType } from '@prisma/client';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import {
  resolveDayPricing,
  type PriceRuleLike,
  type PropertyPricing,
} from '../../common/utils/pricing.util';
import { dateKey, eachDay, resolveBookingMode, resolveShiftTimes, shiftsRequiredForBooking } from '../../common/utils/shift.util';
import { PrismaService } from '../../prisma/prisma.service';
import { AdminPriceRuleDto } from './dto/admin-property.dto';

const MAX_PREVIEW_DAYS = 62;

/** Maximum number of days a single rule preview may span. */
@Injectable()
export class AdminPricingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly activity: ActivityLogService,
  ) {}

  private async requireProperty(propertyId: string) {
    const property = await this.prisma.property.findUnique({ where: { id: propertyId } });
    if (!property) throw new NotFoundException('المكان غير موجود');
    return property;
  }

  private validateRule(dto: AdminPriceRuleDto) {
    if (dto.ruleType === PriceRuleType.WEEKDAY) {
      const days = dto.daysOfWeek ?? [];
      if (!days.length) {
        throw new BadRequestException('اختر يوم الأسبوع واحداً على الأقل للقاعدة الأسبوعية');
      }
      if (new Set(days).size !== days.length) {
        throw new BadRequestException('لا يمكن تكرار نفس اليوم في القاعدة');
      }
    }
    if (dto.ruleType === PriceRuleType.DATE_RANGE) {
      if (!dto.startDate || !dto.endDate) {
        throw new BadRequestException('حدد تاريخ البداية والنهاية للقاعدة الموسمية');
      }
      if (new Date(dto.startDate) > new Date(dto.endDate)) {
        throw new BadRequestException('تاريخ البداية يجب أن يكون قبل النهاية');
      }
    }
  }

  private ruleData(dto: AdminPriceRuleDto) {
    return {
      name: dto.name?.trim() ?? '',
      ruleType: dto.ruleType,
      daysOfWeek:
        dto.ruleType === PriceRuleType.WEEKDAY ? Array.from(new Set(dto.daysOfWeek ?? [])) : [],
      startDate: dto.ruleType === PriceRuleType.DATE_RANGE && dto.startDate ? new Date(dto.startDate) : null,
      endDate: dto.ruleType === PriceRuleType.DATE_RANGE && dto.endDate ? new Date(dto.endDate) : null,
      fullDayPrice: dto.fullDayPrice,
      morningPrice: dto.morningPrice,
      eveningPrice: dto.eveningPrice,
      morningStart: dto.morningStart ?? null,
      morningEnd: dto.morningEnd ?? null,
      eveningStart: dto.eveningStart ?? null,
      eveningEnd: dto.eveningEnd ?? null,
      priority: dto.priority ?? 0,
      isActive: dto.isActive ?? true,
    };
  }

  listRules(propertyId: string) {
    return this.prisma.priceRule.findMany({
      where: { propertyId },
      orderBy: [{ priority: 'desc' }, { createdAt: 'desc' }],
    });
  }

  async createRule(user: AuthUser, propertyId: string, dto: AdminPriceRuleDto) {
    await this.requireProperty(propertyId);
    this.validateRule(dto);
    const rule = await this.prisma.priceRule.create({
      data: { propertyId, ...this.ruleData(dto) },
    });
    await this.activity.log({
      userId: user.id,
      action: 'pricing.rule.create',
      entityType: 'property',
      entityId: propertyId,
      metadata: { ruleId: rule.id, ruleType: rule.ruleType, name: rule.name },
    });
    return rule;
  }

  async updateRule(user: AuthUser, propertyId: string, ruleId: string, dto: Partial<AdminPriceRuleDto>) {
    await this.requireProperty(propertyId);
    const existing = await this.prisma.priceRule.findFirst({ where: { id: ruleId, propertyId } });
    if (!existing) throw new NotFoundException('القاعدة غير موجودة');

    const merged: AdminPriceRuleDto = {
      ...existing,
      ...dto,
      ruleType: dto.ruleType ?? existing.ruleType,
    } as AdminPriceRuleDto;
    this.validateRule(merged);

    const data: Prisma.PriceRuleUpdateInput = {};
    if (dto.name !== undefined) data.name = dto.name.trim();
    if (dto.ruleType !== undefined) data.ruleType = dto.ruleType;
    if (dto.daysOfWeek !== undefined) data.daysOfWeek = Array.from(new Set(dto.daysOfWeek));
    if (dto.startDate !== undefined) {
      data.startDate = dto.startDate ? new Date(dto.startDate) : null;
    }
    if (dto.endDate !== undefined) data.endDate = dto.endDate ? new Date(dto.endDate) : null;
    for (const key of ['fullDayPrice', 'morningPrice', 'eveningPrice'] as const) {
      if (dto[key] !== undefined) data[key] = dto[key];
    }
    for (const key of ['morningStart', 'morningEnd', 'eveningStart', 'eveningEnd'] as const) {
      if (dto[key] !== undefined) data[key] = dto[key] || null;
    }
    if (dto.priority !== undefined) data.priority = dto.priority;
    if (dto.isActive !== undefined) data.isActive = dto.isActive;

    const rule = await this.prisma.priceRule.update({ where: { id: ruleId }, data });
    await this.activity.log({
      userId: user.id,
      action: 'pricing.rule.update',
      entityType: 'property',
      entityId: propertyId,
      metadata: { ruleId, changes: dto },
    });
    return rule;
  }

  async deleteRule(user: AuthUser, propertyId: string, ruleId: string) {
    await this.requireProperty(propertyId);
    const existing = await this.prisma.priceRule.findFirst({ where: { id: ruleId, propertyId } });
    if (!existing) throw new NotFoundException('القاعدة غير موجودة');
    await this.prisma.priceRule.delete({ where: { id: ruleId } });
    await this.activity.log({
      userId: user.id,
      action: 'pricing.rule.delete',
      entityType: 'property',
      entityId: propertyId,
      metadata: { ruleId, name: existing.name },
    });
    return { deleted: true };
  }

  /**
   * Per-day price preview across a date range — powers the live pricing
   * calendar in the dashboard. Includes booking/blocking state per day.
   */
  async preview(propertyId: string, from?: string, to?: string) {
    const property = await this.requireProperty(propertyId);

    const start = from ? new Date(`${from}T00:00:00.000Z`) : new Date();
    const end = to ? new Date(`${to}T00:00:00.000Z`) : new Date(start);
    if (!to) end.setDate(end.getDate() + 30);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end <= start) {
      throw new BadRequestException('نطاق التواريخ غير صالح');
    }
    const dayCount = Math.ceil((end.getTime() - start.getTime()) / 86_400_000);
    if (dayCount > MAX_PREVIEW_DAYS) {
      throw new BadRequestException(`النطاق الأقصى للمعاينة ${MAX_PREVIEW_DAYS} يوماً`);
    }

    const [rules, slots, bookings] = await Promise.all([
      this.prisma.priceRule.findMany({ where: { propertyId, isActive: true } }),
      this.prisma.availabilitySlot.findMany({
        where: { propertyId, date: { gte: start, lt: end } },
      }),
      this.prisma.booking.findMany({
        where: {
          propertyId,
          status: { in: ['PENDING', 'AWAITING_PAYMENT', 'CONFIRMED'] },
          startDate: { lt: end },
          endDate: { gt: start },
        },
        select: { startDate: true, endDate: true, shift: true },
      }),
    ]);

    const slotMap = new Map(slots.map((slot) => [`${dateKey(slot.date)}:${slot.shift}`, slot]));
    const bookingDays = new Map<string, Set<string>>();
    for (const booking of bookings) {
      for (const day of eachDay(new Date(booking.startDate), new Date(booking.endDate))) {
        const key = dateKey(day);
        if (!bookingDays.has(key)) bookingDays.set(key, new Set());
        bookingDays.get(key)!.add(booking.shift);
      }
    }

    const propertyPricing: PropertyPricing = property;
    const mode = resolveBookingMode(property.type, property.bookingMode);

    const days = eachDay(start, end).map((date) => {
      const key = dateKey(date);
      const dayPricing = resolveDayPricing(propertyPricing, rules as PriceRuleLike[], date);
      const bookedShifts = bookingDays.get(key) ?? new Set<string>();
      const blockedShifts = shiftsRequiredForBooking('FULL').filter((shift) => {
        const slot = slotMap.get(`${key}:${shift}`);
        return slot && !slot.isAvailable;
      });

      return {
        date: key,
        dayOfWeek: date.getUTCDay(),
        prices: {
          full: dayPricing.full,
          morning: dayPricing.morning,
          evening: dayPricing.evening,
        },
        times: dayPricing.times,
        ruleId: dayPricing.rule?.id ?? null,
        ruleName: dayPricing.rule?.name ?? null,
        bookedShifts: Array.from(bookedShifts),
        blockedShifts,
        mode,
      };
    });

    return {
      propertyId,
      bookingMode: mode,
      shiftTimes: resolveShiftTimes(property),
      days,
    };
  }
}
