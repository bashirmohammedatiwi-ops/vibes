import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { ConversationsService } from './conversations.service';

describe('ConversationsService', () => {
  const user = { id: 'u1', phone: '9647700000000', role: UserRole.CUSTOMER } as AuthUser;
  let prisma: Record<string, any>;
  let service: ConversationsService;

  beforeEach(() => {
    prisma = {
      conversation: { findUnique: jest.fn(), findFirst: jest.fn(), create: jest.fn(), update: jest.fn() },
      conversationParticipant: { upsert: jest.fn(), findMany: jest.fn(), updateMany: jest.fn() },
      message: { create: jest.fn() },
      user: { findUnique: jest.fn() },
      $queryRaw: jest.fn(),
    };
    service = new ConversationsService(prisma as never, { notifyUser: jest.fn() } as never, {
      emit: jest.fn(),
    } as never);
  });

  it('يرفض رسالة بلا نص ولا صورة', async () => {
    prisma.conversation.findUnique.mockResolvedValue({
      id: 'c1',
      participants: [{ userId: 'u1', user: { id: 'u1' } }],
    });
    await expect(service.send(user, 'c1', {})).rejects.toBeInstanceOf(BadRequestException);
  });

  it('يرفض رسالة أطول من المسموح', async () => {
    prisma.conversation.findUnique.mockResolvedValue({
      id: 'c1',
      participants: [{ userId: 'u1', user: { id: 'u1' } }],
    });
    await expect(service.send(user, 'c1', { body: 'س'.repeat(4001) })).rejects.toBeInstanceOf(BadRequestException);
  });

  it('يمنع إرسال رسالة في محادثة لا تخص المستخدم', async () => {
    prisma.conversation.findUnique.mockResolvedValue({
      id: 'c1',
      participants: [{ userId: 'other', user: { id: 'other' } }],
    });
    await expect(service.send(user, 'c1', { body: 'مرحبا' })).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('يؤشر كل المحادثات مقروءة للمستخدم', async () => {
    prisma.conversationParticipant.updateMany.mockResolvedValue({ count: 2 });
    await expect(service.markAllRead(user)).resolves.toEqual({ ok: true });
    expect(prisma.conversationParticipant.updateMany).toHaveBeenCalledWith({
      where: { userId: 'u1' },
      data: { lastReadAt: expect.any(Date) },
    });
  });

  it('يرفض فتح دعم مع عميل من حساب غير إداري', async () => {
    await expect(service.openSupportForCustomer(user, 'u2')).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('يعيد استخدام محادثة الدعم الحالية ويضيف الموظف', async () => {
    const staff = { id: 'staff1', phone: '9647700000001', role: UserRole.ADMIN } as AuthUser;
    prisma.user.findUnique.mockResolvedValue({ id: 'u2' });
    prisma.conversation.findFirst.mockResolvedValue({ id: 'c-support' });
    prisma.conversationParticipant.upsert.mockResolvedValue({});
    prisma.conversation.findUnique.mockResolvedValue({
      id: 'c-support',
      kind: 'SUPPORT',
      participants: [{ userId: 'u2', user: { id: 'u2' } }],
    });
    prisma.conversationParticipant.updateMany.mockResolvedValue({ count: 1 });

    const result = await service.openSupportForCustomer(staff, 'u2');
    expect(result.id).toBe('c-support');
    expect(prisma.conversation.create).not.toHaveBeenCalled();
    expect(prisma.conversationParticipant.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { conversationId_userId: { conversationId: 'c-support', userId: 'staff1' } },
      }),
    );
  });
});
