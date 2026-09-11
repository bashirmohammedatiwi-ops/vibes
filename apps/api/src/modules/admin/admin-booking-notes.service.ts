import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { BookingStatus, UserRole } from '@prisma/client';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { NotificationService } from '../../common/services/notification.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AdminBookingNotesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly activity: ActivityLogService,
    private readonly notifications: NotificationService,
  ) {}

  list(bookingId: string) {
    return this.prisma.bookingNote.findMany({
      where: { bookingId },
      include: { author: { select: { name: true, phone: true } } },
      orderBy: { createdAt: 'asc' },
    });
  }

  async add(user: AuthUser, bookingId: string, content: string, isInternal = true) {
    const note = await this.prisma.bookingNote.create({
      data: { bookingId, authorId: user.id, content, isInternal },
      include: { author: { select: { name: true, phone: true } } },
    });
    await this.activity.log({
      userId: user.id,
      action: 'booking.note',
      entityType: 'booking',
      entityId: bookingId,
    });
    return note;
  }

  /** Authors edit their own notes; admins may edit any note. */
  async edit(user: AuthUser, bookingId: string, noteId: string, content: string) {
    if (!content.trim()) throw new BadRequestException('الملاحظة فارغة');

    const note = await this.prisma.bookingNote.findUnique({ where: { id: noteId } });
    if (!note || note.bookingId !== bookingId) throw new NotFoundException('الملاحظة غير موجودة');
    if (note.authorId !== user.id && user.role !== UserRole.ADMIN) {
      throw new ForbiddenException('يمكن تعديل ملاحظاتك فقط');
    }

    const updated = await this.prisma.bookingNote.update({
      where: { id: noteId },
      data: { content: content.trim() },
      include: { author: { select: { name: true, phone: true } } },
    });
    await this.activity.log({
      userId: user.id,
      action: 'booking.note.edit',
      entityType: 'booking',
      entityId: bookingId,
      metadata: { noteId },
    });
    return updated;
  }

  async remove(user: AuthUser, bookingId: string, noteId: string) {
    const note = await this.prisma.bookingNote.findUnique({ where: { id: noteId } });
    if (!note || note.bookingId !== bookingId) throw new NotFoundException('الملاحظة غير موجودة');
    if (note.authorId !== user.id && user.role !== UserRole.ADMIN) {
      throw new ForbiddenException('يمكن حذف ملاحظاتك فقط');
    }

    await this.prisma.bookingNote.delete({ where: { id: noteId } });
    await this.activity.log({
      userId: user.id,
      action: 'booking.note.delete',
      entityType: 'booking',
      entityId: bookingId,
      metadata: { noteId },
    });
    return { deleted: true };
  }

  async openDispute(user: AuthUser, bookingId: string, reason: string, note?: string) {
    const booking = await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        status: BookingStatus.DISPUTED,
        disputeReason: reason,
        disputeNote: note,
      },
      include: { property: true, user: true },
    });
    await this.add(user, bookingId, `نزاع: ${reason}${note ? ` — ${note}` : ''}`);
    await this.notifications.disputeOpened(booking);
    await this.activity.log({
      userId: user.id,
      action: 'booking.dispute',
      entityType: 'booking',
      entityId: bookingId,
      metadata: { reason },
    });
    return booking;
  }

  async resolveDispute(user: AuthUser, bookingId: string, status: BookingStatus, note?: string) {
    if (status === BookingStatus.DISPUTED) {
      throw new BadRequestException('اختر حالة نهائية لحل النزاع');
    }

    const existing = await this.prisma.booking.findUnique({ where: { id: bookingId } });
    if (!existing) throw new BadRequestException('الحجز غير موجود');
    if (existing.status !== BookingStatus.DISPUTED) {
      throw new BadRequestException('الحجز ليس في حالة نزاع');
    }

    const booking = await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        status,
        disputeReason: null,
        disputeNote: note ?? null,
      },
      include: { property: true, user: true, payment: true },
    });

    await this.add(user, bookingId, `حل النزاع → ${status}${note ? `: ${note}` : ''}`);
    await this.activity.log({
      userId: user.id,
      action: 'booking.dispute.resolve',
      entityType: 'booking',
      entityId: bookingId,
      metadata: { status, note },
    });

    return booking;
  }
}
