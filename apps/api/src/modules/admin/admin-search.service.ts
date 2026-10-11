import { Injectable } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';
import { expandStaffPermissions } from '../staff/staff.permissions';

@Injectable()
export class AdminSearchService {
  constructor(private readonly prisma: PrismaService) {}

  /** Sections a staff member may see — admins see everything. */
  private async allowed(user?: AuthUser) {
    if (!user || user.role === UserRole.ADMIN) {
      return { properties: true, bookings: true, users: true, payments: true, providers: true };
    }
    const profile = await this.prisma.staffProfile.findUnique({
      where: { userId: user.id },
      select: { permissions: true, isActive: true },
    });
    const granted = profile?.isActive ? expandStaffPermissions(profile.permissions) : [];
    const has = (code: string) => granted.includes(code);
    return {
      properties: has('properties.read'),
      bookings: has('bookings.read'),
      users: has('users.read'),
      payments: has('payments.read'),
      providers: has('providers.read'),
    };
  }

  async search(q: string, user?: AuthUser) {
    const term = q.trim();
    if (term.length < 2) {
      return { properties: [], bookings: [], users: [], payments: [], providers: [] };
    }
    const can = await this.allowed(user);
    const none = Promise.resolve([]);

    const [properties, bookings, users, payments, providers] = await Promise.all([
      can.properties
        ? this.prisma.property.findMany({
            where: {
              OR: [
                { name: { contains: term, mode: 'insensitive' } },
                { slug: { contains: term, mode: 'insensitive' } },
              ],
            },
            take: 6,
            orderBy: { updatedAt: 'desc' },
            select: { id: true, name: true, slug: true, status: true, type: true },
          })
        : none,
      can.bookings
        ? this.prisma.booking.findMany({
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
          })
        : none,
      can.users
        ? this.prisma.user.findMany({
            where: {
              OR: [
                { phone: { contains: term } },
                { name: { contains: term, mode: 'insensitive' } },
              ],
            },
            take: 6,
            orderBy: { createdAt: 'desc' },
            select: { id: true, name: true, phone: true, role: true },
          })
        : none,
      can.payments
        ? this.prisma.payment.findMany({
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
          })
        : none,
      can.providers
        ? this.prisma.provider.findMany({
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
          })
        : none,
    ]);

    return { properties, bookings, users, payments, providers };
  }
}
