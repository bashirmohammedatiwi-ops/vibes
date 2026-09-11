import { Injectable, NotFoundException } from '@nestjs/common';
import { BookingStatus, KycStatus, Prisma } from '@prisma/client';
import { PaginationService } from '../../common/services/query-helpers';
import { PrismaService } from '../../prisma/prisma.service';

const providerInclude = {
  user: { select: { id: true, name: true, phone: true, role: true } },
  _count: { select: { properties: true } },
};

function csvCell(value?: string | null) {
  return `"${(value ?? '').replace(/"/g, '""')}"`;
}

@Injectable()
export class AdminProvidersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pagination: PaginationService,
  ) {}

  async list(query: Record<string, string | undefined>) {
    const { page, pageSize, skip, take } = this.pagination.parse(query.page, query.pageSize);
    const where: Prisma.ProviderWhereInput = {};

    if (query.kyc === 'verified') {
      where.verified = true;
    } else if (query.kyc === 'pending') {
      where.verified = false;
      where.kycStatus = KycStatus.PENDING;
    } else if (query.kyc === 'rejected') {
      where.kycStatus = KycStatus.REJECTED;
    }

    if (query.q) {
      where.OR = [
        { businessName: { contains: query.q, mode: 'insensitive' } },
        { user: { phone: { contains: query.q } } },
        { user: { name: { contains: query.q, mode: 'insensitive' } } },
      ];
    }

    const [items, total] = await Promise.all([
      this.prisma.provider.findMany({
        where,
        include: providerInclude,
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.provider.count({ where }),
    ]);

    return this.pagination.wrap(items, total, page, pageSize);
  }

  async getOne(id: string) {
    const provider = await this.prisma.provider.findUnique({
      where: { id },
      include: {
        user: {
          select: { id: true, name: true, phone: true, role: true, isActive: true, createdAt: true },
        },
        _count: { select: { properties: true } },
      },
    });
    if (!provider) throw new NotFoundException('المزود غير موجود');

    const [properties, revenueAgg, bookingCounts, recentBookings, recentActivities] = await Promise.all([
      this.prisma.property.findMany({
        where: { providerId: id },
        include: {
          city: { select: { nameAr: true } },
          media: { where: { isPrimary: true }, take: 1 },
          _count: { select: { bookings: true, reviews: true } },
        },
        orderBy: { updatedAt: 'desc' },
      }),
      this.prisma.booking.aggregate({
        where: {
          property: { providerId: id },
          status: { in: [BookingStatus.CONFIRMED, BookingStatus.COMPLETED] },
        },
        _sum: { totalPrice: true },
        _count: { id: true },
      }),
      this.prisma.booking.groupBy({
        by: ['status'],
        where: { property: { providerId: id } },
        _count: { id: true },
      }),
      this.prisma.booking.findMany({
        where: { property: { providerId: id } },
        take: 8,
        orderBy: { createdAt: 'desc' },
        include: {
          user: { select: { name: true, phone: true } },
          property: { select: { name: true } },
          payment: { select: { status: true } },
        },
      }),
      this.prisma.adminActivity.findMany({
        where: { entityType: 'provider', entityId: id },
        take: 10,
        orderBy: { createdAt: 'desc' },
        include: { user: { select: { name: true } } },
      }),
    ]);

    return {
      provider,
      properties,
      stats: {
        revenue: revenueAgg._sum.totalPrice ?? 0,
        confirmedBookings: revenueAgg._count.id,
        bookingsByStatus: bookingCounts.map((r) => ({ status: r.status, count: r._count.id })),
      },
      recentBookings,
      recentActivities,
    };
  }

  async exportCsv(query: Record<string, string | undefined> = {}) {
    const where: Prisma.ProviderWhereInput = {};
    if (query.kyc === 'verified') {
      where.verified = true;
    } else if (query.kyc === 'pending') {
      where.verified = false;
      where.kycStatus = KycStatus.PENDING;
    } else if (query.kyc === 'rejected') {
      where.kycStatus = KycStatus.REJECTED;
    }
    if (query.q) {
      where.OR = [
        { businessName: { contains: query.q, mode: 'insensitive' } },
        { user: { phone: { contains: query.q } } },
        { user: { name: { contains: query.q, mode: 'insensitive' } } },
      ];
    }

    const rows = await this.prisma.provider.findMany({
      where,
      include: providerInclude,
      orderBy: { createdAt: 'desc' },
      take: 5000,
    });

    const header = 'id,business_name,owner,phone,kyc_status,verified,properties,rejection_reason,created_at';
    const lines = rows.map((p) =>
      [
        p.id,
        csvCell(p.businessName),
        csvCell(p.user?.name),
        p.user?.phone ?? '',
        p.kycStatus,
        p.verified,
        p._count.properties,
        csvCell(p.rejectionReason),
        p.createdAt.toISOString(),
      ].join(','),
    );
    return [header, ...lines].join('\n');
  }

  geoProperties() {
    return this.prisma.property.findMany({
      select: {
        id: true,
        name: true,
        slug: true,
        type: true,
        status: true,
        latitude: true,
        longitude: true,
        city: { select: { nameAr: true } },
      },
      orderBy: { name: 'asc' },
    });
  }
}
