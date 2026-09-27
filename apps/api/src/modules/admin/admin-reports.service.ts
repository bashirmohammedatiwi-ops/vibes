import { Injectable } from '@nestjs/common';
import { BookingStatus, PaymentStatus, Prisma, ShiftType } from '@prisma/client';
import { dateKey } from '../../common/utils/shift.util';
import { PrismaService } from '../../prisma/prisma.service';

const REVENUE_STATUSES: BookingStatus[] = [BookingStatus.CONFIRMED, BookingStatus.COMPLETED];

@Injectable()
export class AdminReportsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Deep analytics for the dashboard: revenue trend with period comparison,
   * occupancy approximation, cancellation rate, average booking value,
   * booking lead time and top providers.
   */
  async analytics(from?: string, to?: string) {
    const end = to ? new Date(`${to}T23:59:59.999Z`) : new Date();
    const start = from ? new Date(from) : new Date(end.getTime() - 29 * 86_400_000);
    const spanDays = Math.max(1, Math.ceil((end.getTime() - start.getTime()) / 86_400_000));
    const spanMs = end.getTime() - start.getTime();
    const prevStart = new Date(start.getTime() - spanMs);
    const prevEnd = new Date(start.getTime() - 1);

    const revenueWhere = {
      status: { in: REVENUE_STATUSES },
      createdAt: { gte: start, lte: end },
    };
    const prevRevenueWhere = {
      status: { in: REVENUE_STATUSES },
      createdAt: { gte: prevStart, lte: prevEnd },
    };

    const [
      rangeBookings,
      prevBookings,
      statusCounts,
      approvedProperties,
      topProviderRows,
      totalCustomers,
      newCustomers,
    ] = await Promise.all([
      this.prisma.booking.findMany({
        where: revenueWhere,
        select: {
          totalPrice: true,
          discountAmount: true,
          createdAt: true,
          startDate: true,
          status: true,
          shift: true,
          endDate: true,
          property: { select: { providerId: true, provider: { select: { businessName: true, user: { select: { name: true } } } } } },
        },
      }),
      this.prisma.booking.findMany({
        where: prevRevenueWhere,
        select: { totalPrice: true, createdAt: true },
      }),
      this.prisma.booking.groupBy({
        by: ['status'],
        _count: { id: true },
        where: { createdAt: { gte: start, lte: end } },
      }),
      this.prisma.property.count({ where: { status: 'APPROVED' } }),
      this.prisma.booking.groupBy({
        by: ['propertyId'],
        where: revenueWhere,
        _count: { id: true },
        _sum: { totalPrice: true },
        orderBy: { _sum: { totalPrice: 'desc' } },
        take: 40,
      }),
      this.prisma.user.count({ where: { role: 'CUSTOMER' } }),
      this.prisma.user.count({ where: { role: 'CUSTOMER', createdAt: { gte: start, lte: end } } }),
    ]);

    // Revenue bucketed per day for the trend chart.
    const dayBuckets = new Map<string, number>();
    for (let i = 0; i < spanDays; i++) {
      const day = new Date(start.getTime() + i * 86_400_000);
      dayBuckets.set(dateKey(day), 0);
    }
    let revenue = 0;
    let discounts = 0;
    let leadTimeSum = 0;
    let bookedDayUnits = 0;
    for (const booking of rangeBookings) {
      const amount = Number(booking.totalPrice);
      revenue += amount;
      discounts += Number(booking.discountAmount ?? 0);
      const key = dateKey(new Date(booking.createdAt));
      if (dayBuckets.has(key)) dayBuckets.set(key, (dayBuckets.get(key) ?? 0) + amount);

      leadTimeSum += Math.max(0, (booking.startDate.getTime() - booking.createdAt.getTime()) / 86_400_000);

      // Occupancy approximation: FULL day = 1 unit, half-day shifts = 0.5.
      const overlapStart = Math.max(booking.startDate.getTime(), start.getTime());
      const overlapEnd = Math.min(booking.endDate.getTime(), end.getTime() + 1);
      const overlapDays = Math.max(0, Math.ceil((overlapEnd - overlapStart) / 86_400_000));
      const unit = booking.shift === ShiftType.FULL ? 1 : 0.5;
      bookedDayUnits += overlapDays * unit;
    }

    const prevRevenue = prevBookings.reduce((sum, b) => sum + Number(b.totalPrice), 0);
    const revenueTrend = Array.from(dayBuckets.entries()).map(([date, value]) => ({ date, value }));

    const statusMap = new Map(statusCounts.map((row) => [row.status, row._count.id]));
    const totalInRange = statusCounts.reduce((sum, row) => sum + row._count.id, 0);
    const cancelled = statusMap.get(BookingStatus.CANCELLED) ?? 0;

    // Top providers from the top-property rows.
    const propertyIds = topProviderRows.map((row) => row.propertyId);
    const properties = propertyIds.length
      ? await this.prisma.property.findMany({
          where: { id: { in: propertyIds } },
          select: { id: true, name: true, provider: { select: { businessName: true, user: { select: { name: true } } } } },
        })
      : [];
    const propertyById = new Map(properties.map((p) => [p.id, p]));
    const providerMap = new Map<string, { name: string; revenue: number; bookings: number }>();
    for (const row of topProviderRows) {
      const property = propertyById.get(row.propertyId);
      const name =
        property?.provider?.businessName ??
        property?.provider?.user?.name ??
        'بدون مزود';
      const entry = providerMap.get(name) ?? { name, revenue: 0, bookings: 0 };
      entry.revenue += Number(row._sum.totalPrice ?? 0);
      entry.bookings += row._count.id;
      providerMap.set(name, entry);
    }

    const capacityUnits = Math.max(1, approvedProperties * spanDays);
    const percentChange = (current: number, previous: number) =>
      previous > 0 ? Math.round(((current - previous) / previous) * 100) : null;

    return {
      range: { from: dateKey(start), to: dateKey(end), days: spanDays },
      revenue,
      discounts,
      prevRevenue,
      revenueChangePct: percentChange(revenue, prevRevenue),
      revenueTrend,
      bookings: totalInRange,
      avgBookingValue: rangeBookings.length ? Math.round(revenue / rangeBookings.length) : 0,
      cancellationRatePct: totalInRange ? Math.round((cancelled / totalInRange) * 100) : 0,
      avgLeadTimeDays: rangeBookings.length ? Math.round((leadTimeSum / rangeBookings.length) * 10) / 10 : 0,
      occupancyPct: Math.min(100, Math.round((bookedDayUnits / capacityUnits) * 100)),
      approvedProperties,
      totalCustomers,
      newCustomers,
      bookingsByStatus: statusCounts.map((row) => ({ status: row.status, count: row._count.id })),
      topProviders: Array.from(providerMap.values())
        .sort((a, b) => b.revenue - a.revenue)
        .slice(0, 5),
    };
  }

  async summary(from?: string, to?: string) {
    const dateFilter =
      from || to
        ? {
            createdAt: {
              ...(from ? { gte: new Date(from) } : {}),
              ...(to ? { lte: new Date(`${to}T23:59:59.999Z`) } : {}),
            },
          }
        : {};

    const bookingWhere = dateFilter;
    const revenueWhere = {
      ...dateFilter,
      status: { in: [BookingStatus.CONFIRMED, BookingStatus.COMPLETED] },
    };

    const [bookings, revenue, byType, byProvince, byStatus, byPropertyType, bookingsForType] = await Promise.all([
      this.prisma.booking.count({ where: bookingWhere }),
      this.prisma.booking.aggregate({ where: revenueWhere, _sum: { totalPrice: true } }),
      this.prisma.property.groupBy({ by: ['type'], _count: { id: true } }),
      this.prisma.booking.findMany({
        where: bookingWhere,
        select: {
          property: { select: { city: { select: { province: { select: { nameAr: true } } } } } },
        },
      }),
      this.prisma.booking.groupBy({ by: ['status'], _count: { id: true }, where: bookingWhere }),
      this.prisma.booking.groupBy({
        by: ['propertyId'],
        where: revenueWhere,
        _count: { id: true },
        _sum: { totalPrice: true },
        orderBy: { _sum: { totalPrice: 'desc' } },
        take: 10,
      }),
      this.prisma.booking.findMany({
        where: bookingWhere,
        select: { property: { select: { type: true } } },
      }),
    ]);

    const propertyTypeMap = new Map<string, number>();
    for (const row of bookingsForType) {
      const type = row.property?.type ?? 'UNKNOWN';
      propertyTypeMap.set(type, (propertyTypeMap.get(type) ?? 0) + 1);
    }

    const provinceMap = new Map<string, number>();
    for (const row of byProvince) {
      const name = row.property?.city?.province?.nameAr ?? 'غير محدد';
      provinceMap.set(name, (provinceMap.get(name) ?? 0) + 1);
    }

    const propertyIds = byPropertyType.map((r) => r.propertyId);
    const propertyNames = propertyIds.length
      ? await this.prisma.property.findMany({
          where: { id: { in: propertyIds } },
          select: { id: true, name: true, type: true },
        })
      : [];
    const nameById = new Map(propertyNames.map((p) => [p.id, p]));

    return {
      bookings,
      revenue: revenue._sum.totalPrice ?? 0,
      propertiesByType: byType.map((r) => ({ type: r.type, count: r._count.id })),
      bookingsByType: [...propertyTypeMap.entries()].map(([type, count]) => ({ type, count })),
      bookingsByProvince: [...provinceMap.entries()].map(([name, count]) => ({ name, count })),
      bookingsByStatus: byStatus.map((r) => ({ status: r.status, count: r._count.id })),
      topProperties: byPropertyType.map((r) => ({
        id: r.propertyId,
        name: nameById.get(r.propertyId)?.name ?? '—',
        type: nameById.get(r.propertyId)?.type ?? 'UNKNOWN',
        bookings: r._count.id,
        revenue: r._sum.totalPrice ?? 0,
      })),
    };
  }

  async exportPropertiesCsv() {
    const rows = await this.prisma.property.findMany({
      include: {
        city: { include: { province: true } },
        _count: { select: { bookings: true, reviews: true } },
      },
      orderBy: { updatedAt: 'desc' },
      take: 5000,
    });

    const header = 'id,name,type,status,city,province,price_per_day,bookings,reviews,featured,created_at';
    const lines = rows.map((p) =>
      [
        p.id,
        `"${p.name.replace(/"/g, '""')}"`,
        p.type,
        p.status,
        `"${p.city.nameAr.replace(/"/g, '""')}"`,
        `"${p.city.province.nameAr.replace(/"/g, '""')}"`,
        Number(p.pricePerDay),
        p._count.bookings,
        p._count.reviews,
        p.featured,
        p.createdAt.toISOString(),
      ].join(','),
    );
    return [header, ...lines].join('\n');
  }

  async exportUsersCsv(query: Record<string, string | undefined> = {}) {
    const where: Prisma.UserWhereInput = {};
    if (query.role) where.role = query.role as never;
    if (query.q) {
      where.OR = [
        { phone: { contains: query.q } },
        { name: { contains: query.q, mode: 'insensitive' } },
      ];
    }

    const rows = await this.prisma.user.findMany({
      where,
      include: { _count: { select: { bookings: true, reviews: true } } },
      orderBy: { createdAt: 'desc' },
      take: 5000,
    });

    const header = 'id,name,phone,role,is_active,bookings,reviews,created_at';
    const lines = rows.map((u) =>
      [
        u.id,
        `"${(u.name ?? '').replace(/"/g, '""')}"`,
        u.phone,
        u.role,
        u.isActive,
        u._count.bookings,
        u._count.reviews,
        u.createdAt.toISOString(),
      ].join(','),
    );
    return [header, ...lines].join('\n');
  }

  private bookingExportWhere(query: Record<string, string | undefined>): Prisma.BookingWhereInput {
    const where: Prisma.BookingWhereInput = {};
    if (query.status) where.status = query.status as BookingStatus;
    if (query.propertyId) where.propertyId = query.propertyId;
    if (query.from || query.to) {
      where.createdAt = {};
      if (query.from) where.createdAt.gte = new Date(query.from);
      if (query.to) where.createdAt.lte = new Date(`${query.to}T23:59:59.999Z`);
    }
    if (query.q) {
      where.OR = [
        { user: { phone: { contains: query.q } } },
        { user: { name: { contains: query.q, mode: 'insensitive' } } },
        { property: { name: { contains: query.q, mode: 'insensitive' } } },
      ];
    }
    if (query.shift) where.shift = query.shift as never;
    if (query.paymentStatus || query.paymentMethod) {
      where.payment = {
        ...(query.paymentStatus ? { status: query.paymentStatus as never } : {}),
        ...(query.paymentMethod ? { method: query.paymentMethod as never } : {}),
      };
    }
    return where;
  }

  async exportBookingsCsv(query: Record<string, string | undefined> = {}) {
    const where = this.bookingExportWhere(query);

    const rows = await this.prisma.booking.findMany({
      where,
      include: {
        user: { select: { name: true, phone: true } },
        property: { select: { name: true, type: true } },
        payment: { select: { status: true, method: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 5000,
    });

    const header = 'id,property,customer,phone,start,end,guests,status,amount,payment_status,payment_method,created_at';
    const lines = rows.map((b) =>
      [
        b.id,
        `"${b.property.name.replace(/"/g, '""')}"`,
        `"${(b.user?.name ?? b.guestName ?? '').replace(/"/g, '""')}"`,
        b.user?.phone ?? b.guestPhone ?? '',
        b.startDate.toISOString().slice(0, 10),
        b.endDate.toISOString().slice(0, 10),
        b.guests,
        b.status,
        Number(b.totalPrice),
        b.payment?.status ?? '',
        b.payment?.method ?? '',
        b.createdAt.toISOString(),
      ].join(','),
    );

    return [header, ...lines].join('\n');
  }

  async exportPaymentsCsv(query: Record<string, string | undefined> = {}) {
    const where: Prisma.PaymentWhereInput = {};
    if (query.status) where.status = query.status as PaymentStatus;
    if (query.method) where.method = query.method as never;
    if (query.hasProof === 'true') where.proofUrl = { not: null };
    if (query.from || query.to) {
      where.createdAt = {};
      if (query.from) where.createdAt.gte = new Date(query.from);
      if (query.to) where.createdAt.lte = new Date(`${query.to}T23:59:59.999Z`);
    }
    if (query.q) {
      where.OR = [
        { transactionRef: { contains: query.q, mode: 'insensitive' } },
        { booking: { user: { phone: { contains: query.q } } } },
        { booking: { property: { name: { contains: query.q, mode: 'insensitive' } } } },
      ];
    }

    const rows = await this.prisma.payment.findMany({
      where,
      include: {
        booking: {
          include: {
            user: { select: { name: true, phone: true } },
            property: { select: { name: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 5000,
    });

    const header = 'id,property,customer,phone,amount,method,status,transaction_ref,created_at';
    const lines = rows.map((p) =>
      [
        p.id,
        `"${(p.booking?.property?.name ?? '').replace(/"/g, '""')}"`,
        `"${(p.booking?.user?.name ?? '').replace(/"/g, '""')}"`,
        p.booking?.user?.phone ?? '',
        Number(p.amount),
        p.method,
        p.status,
        p.transactionRef ?? '',
        p.createdAt.toISOString(),
      ].join(','),
    );

    return [header, ...lines].join('\n');
  }
}
