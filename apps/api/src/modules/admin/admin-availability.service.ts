import { Injectable } from '@nestjs/common';
import { ShiftType } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { BulkAvailabilityDto } from './dto/admin-property.dto';

@Injectable()
export class AdminAvailabilityService {
  constructor(private readonly prisma: PrismaService) {}

  async bulkSet(propertyId: string, dto: BulkAvailabilityDto) {
    const shifts = dto.shifts?.length ? dto.shifts : dto.shift ? [dto.shift] : [ShiftType.FULL];

    const ops = dto.dates.flatMap((dateStr) =>
      shifts.map((shift) =>
        this.prisma.availabilitySlot.upsert({
          where: {
            propertyId_date_shift: {
              propertyId,
              date: new Date(dateStr),
              shift,
            },
          },
          update: {
            isAvailable: dto.isAvailable,
            priceOverride: dto.priceOverride,
          },
          create: {
            propertyId,
            date: new Date(dateStr),
            shift,
            isAvailable: dto.isAvailable,
            priceOverride: dto.priceOverride,
          },
        }),
      ),
    );
    await Promise.all(ops);
    return this.prisma.availabilitySlot.findMany({
      where: {
        propertyId,
        date: { in: dto.dates.map((d) => new Date(d)) },
        ...(dto.shifts?.length ? { shift: { in: dto.shifts } } : dto.shift ? { shift: dto.shift } : {}),
      },
      orderBy: [{ date: 'asc' }, { shift: 'asc' }],
    });
  }

  /** Removes explicit slots so the dates fall back to the property default. */
  async clear(propertyId: string, dates: string[], shifts?: ShiftType[]) {
    const { count } = await this.prisma.availabilitySlot.deleteMany({
      where: {
        propertyId,
        date: { in: dates.map((d) => new Date(d)) },
        ...(shifts?.length ? { shift: { in: shifts } } : {}),
      },
    });
    return { cleared: count };
  }

  list(propertyId: string, month?: string) {
    const start = month ? new Date(`${month}-01`) : new Date();
    const end = new Date(start);
    end.setMonth(end.getMonth() + 2);
    return this.prisma.availabilitySlot.findMany({
      where: { propertyId, date: { gte: start, lt: end } },
      orderBy: [{ date: 'asc' }, { shift: 'asc' }],
    });
  }
}
