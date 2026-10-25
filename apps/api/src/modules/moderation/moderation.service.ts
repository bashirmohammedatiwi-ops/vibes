import { Injectable, NotFoundException } from '@nestjs/common';
import { SocialPostStatus } from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';
import { ConversationsService } from '../marketplace/conversations.service';

export const REPORT_TARGETS = ['POST', 'COMMENT', 'REVIEW', 'MESSAGE', 'CONVERSATION', 'USER', 'COLLECTION', 'PROPERTY'] as const;
export type ReportTarget = (typeof REPORT_TARGETS)[number];

const TARGET_LABEL: Record<ReportTarget, string> = {
  POST: 'منشور تجربة',
  COMMENT: 'تعليق',
  REVIEW: 'تقييم',
  MESSAGE: 'رسالة',
  CONVERSATION: 'محادثة',
  USER: 'مستخدم',
  COLLECTION: 'قائمة عامة',
  PROPERTY: 'مكان',
};

@Injectable()
export class ModerationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly conversations: ConversationsService,
  ) {}

  /**
   * بلاغ عن محتوى أو مستخدم (+ حظر اختياري). يُحفظ ويصل للدعم كرسالة فوراً
   * ليُراجع خلال 24 ساعة. منشورات التجارب تُخفى تلقائياً بعد 3 بلاغات.
   */
  async report(
    user: AuthUser,
    input: { targetType: ReportTarget; targetId: string; reason?: string; reportedUserId?: string; block?: boolean },
  ) {
    const reason = (input.reason ?? '').trim().slice(0, 500);
    let reportedUserId = input.reportedUserId ?? null;

    if (input.targetType === 'POST') {
      const post = await this.prisma.socialPost.findUnique({ where: { id: input.targetId } });
      if (!post) throw new NotFoundException('المنشور غير موجود');
      reportedUserId ??= post.userId;
      await this.prisma.socialPostReport.upsert({
        where: { postId_userId: { postId: post.id, userId: user.id } },
        update: { reason },
        create: { postId: post.id, userId: user.id, reason },
      });
      const count = await this.prisma.socialPostReport.count({ where: { postId: post.id } });
      if (count >= 3 && post.status === SocialPostStatus.PUBLISHED) {
        await this.prisma.socialPost.update({ where: { id: post.id }, data: { status: SocialPostStatus.REPORTED } });
      }
    } else if (input.targetType === 'COMMENT') {
      const c = await this.prisma.socialPostComment.findUnique({ where: { id: input.targetId } });
      reportedUserId ??= c?.userId ?? null;
    } else if (input.targetType === 'REVIEW') {
      const r = await this.prisma.review.findUnique({ where: { id: input.targetId } });
      reportedUserId ??= r?.userId ?? null;
    } else if (input.targetType === 'MESSAGE') {
      const m = await this.prisma.message.findUnique({ where: { id: input.targetId } });
      reportedUserId ??= m?.senderId ?? null;
    }

    const row = await this.prisma.contentReport.create({
      data: {
        reporterId: user.id,
        targetType: input.targetType,
        targetId: input.targetId,
        reportedUserId,
        reason,
        blocked: input.block === true,
      },
    });

    // يصل لفريق الدعم في صندوق المحادثات فوراً
    try {
      const conv = await this.conversations.openSupport(user);
      const lines = [
        `🚩 ${input.block ? 'بلاغ + حظر' : 'بلاغ'} عن ${TARGET_LABEL[input.targetType]}`,
        reason ? `السبب: ${reason}` : null,
        `المعرّف: ${input.targetId}`,
        reportedUserId ? `المستخدم المُبلَّغ عنه: ${reportedUserId}` : null,
        `رقم البلاغ: ${row.id.slice(0, 8)}`,
      ].filter(Boolean);
      await this.conversations.send(user, conv.id, { body: lines.join('\n') });
    } catch {
      // البلاغ محفوظ حتى لو تعذّر إرسال الرسالة
    }
    return { reported: true, id: row.id };
  }
}
