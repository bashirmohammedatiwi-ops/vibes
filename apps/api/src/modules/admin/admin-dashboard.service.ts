import { Injectable } from '@nestjs/common';
import { BookingStatus, ConversationKind, KycStatus, PaymentStatus, PropertyStatus, RequestStatus, OfferStatus, SocialPostStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AdminDashboardService {
  constructor(private readonly prisma: PrismaService) {}

  async stats() {
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    const [
      users,
      properties,
      bookings,
      pendingProperties,
      draftProperties,
      featuredProperties,
      confirmedBookings,
      monthlyBookings,
      recentBookings,
      recentActivities,
      revenueAgg,
      byType,
      byProvince,
      monthlyRevenue,
      unreadNotifications,
      pendingPaymentProofs,
      disputedBookings,
      todayCheckIns,
      pendingProviders,
      pendingProviderProperties,
      pendingRefunds,
      pendingCancellations,
      pendingOffers,
      pendingSocialReports,
      pendingSupport,
    ] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.property.count(),
      this.prisma.booking.count({ where: { status: { not: BookingStatus.CANCELLED } } }),
      this.prisma.property.count({ where: { status: PropertyStatus.PENDING } }),
      this.prisma.property.count({ where: { status: PropertyStatus.DRAFT } }),
      this.prisma.property.count({ where: { featured: true, status: PropertyStatus.APPROVED } }),
      this.prisma.booking.count({ where: { status: BookingStatus.CONFIRMED } }),
      this.prisma.booking.count({ where: { createdAt: { gte: monthStart } } }),
      this.prisma.booking.findMany({
        take: 8,
        orderBy: { createdAt: 'desc' },
        include: {
          user: { select: { name: true, phone: true } },
          property: { select: { name: true, type: true } },
        },
      }),
      this.prisma.adminActivity.findMany({
        take: 12,
        orderBy: { createdAt: 'desc' },
        include: { user: { select: { name: true, phone: true } } },
      }),
      this.prisma.booking.aggregate({
        where: { status: { in: [BookingStatus.CONFIRMED, BookingStatus.COMPLETED] } },
        _sum: { totalPrice: true },
      }),
      this.prisma.property.groupBy({ by: ['type'], _count: { id: true } }),
      this.prisma.property.findMany({
        select: { city: { select: { province: { select: { nameAr: true, slug: true } } } } },
      }),
      this.monthlyRevenueSeries(6),
      this.prisma.teamNotification.count({ where: { isRead: false } }),
      this.prisma.payment.count({ where: { status: PaymentStatus.PENDING, proofUrl: { not: null } } }),
      this.prisma.booking.count({ where: { status: BookingStatus.DISPUTED } }),
      this.prisma.booking.count({
        where: {
          startDate: { lte: new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1) },
          endDate: { gt: new Date(now.getFullYear(), now.getMonth(), now.getDate()) },
          status: { in: [BookingStatus.CONFIRMED, BookingStatus.PENDING, BookingStatus.AWAITING_PAYMENT] },
        },
      }),
      this.prisma.provider.count({ where: { kycStatus: KycStatus.PENDING } }),
      this.prisma.property.count({
        where: { status: PropertyStatus.PENDING, providerId: { not: null } },
      }),
      this.prisma.refundRequest.count({ where: { status: RequestStatus.PENDING } }),
      this.prisma.cancellationRequest.count({ where: { status: RequestStatus.PENDING } }),
      this.prisma.priceOffer.count({ where: { status: OfferStatus.PENDING } }),
      this.prisma.socialPost.count({ where: { status: SocialPostStatus.REPORTED } }),
      this.prisma.conversation.count({
        where: {
          kind: ConversationKind.SUPPORT,
          updatedAt: { gte: new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000) },
        },
      }),
    ]);

    const provinceMap = new Map<string, number>();
    for (const row of byProvince) {
      const key = row.city.province.nameAr;
      provinceMap.set(key, (provinceMap.get(key) ?? 0) + 1);
    }

    return {
      users,
      properties,
      bookings,
      pendingProperties,
      draftProperties,
      featuredProperties,
      confirmedBookings,
      monthlyBookings,
      totalRevenue: revenueAgg._sum.totalPrice ?? 0,
      propertiesByType: byType.map((r) => ({ type: r.type, count: r._count.id })),
      propertiesByProvince: [...provinceMap.entries()].map(([name, count]) => ({ name, count })),
      monthlyRevenue,
      unreadNotifications,
      pendingPaymentProofs,
      disputedBookings,
      todayCheckIns,
      pendingProviders,
      pendingProviderProperties,
      pendingRefunds,
      pendingCancellations,
      pendingOffers,
      pendingSocialReports,
      pendingSupport,
      recentBookings,
      recentActivities,
    };
  }

  private async monthlyRevenueSeries(months: number) {
    const series: { month: string; revenue: number; bookings: number }[] = [];
    const now = new Date();

    for (let i = months - 1; i >= 0; i--) {
      const start = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const end = new Date(now.getFullYear(), now.getMonth() - i + 1, 1);
      const key = `${start.getFullYear()}-${String(start.getMonth() + 1).padStart(2, '0')}`;

      const [agg, count] = await Promise.all([
        this.prisma.booking.aggregate({
          where: {
            createdAt: { gte: start, lt: end },
            status: { in: [BookingStatus.CONFIRMED, BookingStatus.COMPLETED] },
          },
          _sum: { totalPrice: true },
        }),
        this.prisma.booking.count({ where: { createdAt: { gte: start, lt: end } } }),
      ]);

      series.push({
        month: key,
        revenue: Number(agg._sum.totalPrice ?? 0),
        bookings: count,
      });
    }

    return series;
  }
}
