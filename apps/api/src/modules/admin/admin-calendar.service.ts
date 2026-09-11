import { Injectable } from '@nestjs/common';
import { BookingStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AdminCalendarService {
  constructor(private readonly prisma: PrismaService) {}

  async month(month?: string, propertyId?: string, propertyType?: string) {
    const start = month ? new Date(`${month}-01`) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
    const end = new Date(start);
    end.setMonth(end.getMonth() + 1);

    const bookingWhere = {
      status: { notIn: [BookingStatus.CANCELLED] as BookingStatus[] },
      startDate: { lt: end },
      endDate: { gt: start },
      ...(propertyId ? { propertyId } : {}),
      ...(propertyType ? { property: { type: propertyType as never } } : {}),
    };

    const slotWhere = {
      date: { gte: start, lt: end },
      isAvailable: false,
      ...(propertyId ? { propertyId } : {}),
      ...(propertyType ? { property: { type: propertyType as never } } : {}),
    };

    const [bookings, blockedSlots] = await Promise.all([
      this.prisma.booking.findMany({
        where: bookingWhere,
        include: {
          user: { select: { name: true, phone: true } },
          property: { select: { id: true, name: true, slug: true, type: true } },
        },
        orderBy: { startDate: 'asc' },
      }),
      this.prisma.availabilitySlot.findMany({
        where: slotWhere,
        include: { property: { select: { id: true, name: true, type: true } } },
        orderBy: [{ date: 'asc' }, { shift: 'asc' }],
      }),
    ]);

    return {
      month: `${start.getFullYear()}-${String(start.getMonth() + 1).padStart(2, '0')}`,
      bookings,
      blockedSlots,
    };
  }
}
