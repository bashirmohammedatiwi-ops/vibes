import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AdminSearchService {
  constructor(private readonly prisma: PrismaService) {}

  async search(q: string) {
    const term = q.trim();
    if (term.length < 2) {
      return { properties: [], bookings: [], users: [], payments: [], providers: [] };
    }

    const [properties, bookings, users, payments, providers] = await Promise.all([
      this.prisma.property.findMany({
        where: {
          OR: [
            { name: { contains: term, mode: 'insensitive' } },
            { slug: { contains: term, mode: 'insensitive' } },
          ],
        },
        take: 6,
        orderBy: { updatedAt: 'desc' },
        select: { id: true, name: true, slug: true, status: true, type: true },
      }),
      this.prisma.booking.findMany({
        where: {
          OR: [
            { user: { phone: { contains: term } } },
            { user: { name: { contains: term, mode: 'insensitive' } } },
            { property: { name: { contains: term, mode: 'insensitive' } } },
          ],
        },
        take: 6,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          status: true,
          startDate: true,
          property: { select: { id: true, name: true } },
          user: { select: { name: true, phone: true } },
        },
      }),
      this.prisma.user.findMany({
        where: {
          OR: [
            { phone: { contains: term } },
            { name: { contains: term, mode: 'insensitive' } },
          ],
        },
        take: 6,
        orderBy: { createdAt: 'desc' },
        select: { id: true, name: true, phone: true, role: true },
      }),
      this.prisma.payment.findMany({
        where: {
          OR: [
            { transactionRef: { contains: term, mode: 'insensitive' } },
            { booking: { user: { phone: { contains: term } } } },
            { booking: { property: { name: { contains: term, mode: 'insensitive' } } } },
          ],
        },
        take: 6,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          status: true,
          amount: true,
          booking: {
            select: {
              id: true,
              property: { select: { name: true } },
              user: { select: { name: true, phone: true } },
            },
          },
        },
      }),
      this.prisma.provider.findMany({
        where: {
          OR: [
            { businessName: { contains: term, mode: 'insensitive' } },
            { user: { phone: { contains: term } } },
            { user: { name: { contains: term, mode: 'insensitive' } } },
          ],
        },
        take: 6,
        orderBy: { updatedAt: 'desc' },
        select: {
          id: true,
          businessName: true,
          verified: true,
          kycStatus: true,
          user: { select: { name: true, phone: true } },
        },
      }),
    ]);

    return { properties, bookings, users, payments, providers };
  }
}
