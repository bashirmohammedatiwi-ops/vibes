import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { BookingStatus, Prisma, PropertyType } from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { CacheService } from '../../common/services/cache.service';
import { PrismaService } from '../../prisma/prisma.service';
import {
  LOYALTY_TYPES,
  LoyaltyConfig,
  loyaltyDiscount,
  loyaltyProgress,
  normalizeLoyaltyConfig,
} from './loyalty.config';

const KEY = 'loyalty_config';
const CACHE_KEY = 'cache:loyalty:config';
const IN_PROGRESS: BookingStatus[] = [
  BookingStatus.PENDING,
  BookingStatus.AWAITING_PAYMENT,
  BookingStatus.CONFIRMED,
];

const WORLD_LABEL: Record<PropertyType, string> = {
  [PropertyType.FARM]: 'المزارع',
  [PropertyType.HALL]: 'القاعات',
  [PropertyType.DECORATION]: 'التزيين',
};

type Db = Prisma.TransactionClient | PrismaService;

@Injectable()
export class LoyaltyService {
  private readonly logger = new Logger(LoyaltyService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly cache: CacheService,
    private readonly activity: ActivityLogService,
  ) {}

  config(): Promise<LoyaltyConfig> {
    return this.cache.getOrSet(CACHE_KEY, 60, () => this.readConfig());
  }

  private async readConfig(): Promise<LoyaltyConfig> {
    const row = await this.prisma.platformSetting.findUnique({ where: { key: KEY } });
    if (!row) return normalizeLoyaltyConfig(null);
    try {
      return normalizeLoyaltyConfig(JSON.parse(row.value));
    } catch {
      return normalizeLoyaltyConfig(null);
    }
  }

  private async counts(db: Db, userId: string, type: PropertyType) {
    const [paidCompleted, activeRewards] = await Promise.all([
      db.booking.count({
        where: {
          userId,
          status: BookingStatus.COMPLETED,
          loyaltyDiscount: 0,
          property: { type },
        },
      }),
      db.booking.count({
        where: {
          userId,
          status: { not: BookingStatus.CANCELLED },
          loyaltyDiscount: { gt: 0 },
          property: { type },
        },
      }),
    ]);
    return { paidCompleted, activeRewards };
  }

  /** حالة بطاقات الولاء الثلاث لهذا الزبون. */
  async status(user: AuthUser) {
    const config = await this.config();
    const programs = await Promise.all(
      LOYALTY_TYPES.map(async (type) => {
        const program = config.programs[type];
        const { paidCompleted, activeRewards } = await this.counts(this.prisma, user.id, type);
        const progress = loyaltyProgress(paidCompleted, activeRewards, program.required);
        const [inProgress, saved, cycle, rewards] = await Promise.all([
          this.prisma.booking.count({
            where: {
              userId: user.id,
              status: { in: IN_PROGRESS },
              loyaltyDiscount: 0,
              property: { type },
            },
          }),
          this.prisma.booking.aggregate({
            where: {
              userId: user.id,
              status: { not: BookingStatus.CANCELLED },
              loyaltyDiscount: { gt: 0 },
              property: { type },
            },
            _sum: { loyaltyDiscount: true },
          }),
          progress.stamps === 0
            ? Promise.resolve([])
            : this.prisma.booking.findMany({
                where: {
                  userId: user.id,
                  status: BookingStatus.COMPLETED,
                  loyaltyDiscount: 0,
                  property: { type },
                },
                orderBy: { endDate: 'desc' },
                take: progress.stamps,
                select: {
                  id: true,
                  startDate: true,
                  property: { select: { name: true } },
                },
              }),
          this.prisma.booking.findMany({
            where: {
              userId: user.id,
              status: { not: BookingStatus.CANCELLED },
              loyaltyDiscount: { gt: 0 },
              property: { type },
            },
            orderBy: { startDate: 'desc' },
            take: 10,
            select: {
              id: true,
              startDate: true,
              loyaltyDiscount: true,
              property: { select: { name: true } },
            },
          }),
        ]);
        return {
          type,
          enabled: config.enabled && program.enabled,
          required: program.required,
          percent: program.percent,
          maxDiscount: program.maxDiscount,
          ...progress,
          rewardReady: progress.rewardsAvailable > 0,
          inProgress,
          lifetimeRewards: activeRewards,
          lifetimeSaved: Number(saved._sum.loyaltyDiscount ?? 0),
          stampHistory: [...cycle].reverse().map((b) => ({
            bookingId: b.id,
            placeName: b.property.name,
            date: b.startDate,
          })),
          rewardHistory: rewards.map((b) => ({
            bookingId: b.id,
            placeName: b.property.name,
            date: b.startDate,
            discount: Number(b.loyaltyDiscount),
          })),
        };
      }),
    );
    return { enabled: config.enabled, programs };
  }

  /** عرض الخصم لهذا الحجز (بلا حجزه فعلياً). */
  async offer(userId: string | undefined, type: PropertyType, total: number) {
    if (!userId) return null;
    const config = await this.config();
    const program = config.programs[type];
    if (!config.enabled || !program.enabled) return null;
    const { paidCompleted, activeRewards } = await this.counts(this.prisma, userId, type);
    const progress = loyaltyProgress(paidCompleted, activeRewards, program.required);
    const discount = progress.rewardsAvailable > 0 ? loyaltyDiscount(total, program) : 0;
    return {
      eligible: discount > 0,
      percent: program.percent,
      discount,
      totalAfterDiscount: total - discount,
      required: program.required,
      stamps: progress.stamps,
      remaining: progress.remaining,
    };
  }

  /**
   * يستهلك خصماً داخل معاملة إنشاء الحجز. القفل يمنع استخدام الخصم نفسه
   * في حجزين متزامنين.
   */
  async claim(tx: Prisma.TransactionClient, userId: string, type: PropertyType, total: number) {
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${`loyalty:${userId}:${type}`}))`;
    const config = await this.config();
    const program = config.programs[type];
    const { paidCompleted, activeRewards } = await this.counts(tx, userId, type);
    const { rewardsAvailable } = loyaltyProgress(paidCompleted, activeRewards, program.required);
    const discount = loyaltyDiscount(total, program);
    if (!config.enabled || !program.enabled || rewardsAvailable <= 0 || discount <= 0) {
      throw new BadRequestException('لا يوجد خصم ولاء متاح لهذا الحجز');
    }
    return discount;
  }

  /**
   * يبلّغ من اكتملت بطاقته. فحص دوري لأن الحجوزات تكتمل من عدة مسارات
   * (مهمة ساعية، الموظفون، المالك)؛ ومعرّف الإشعار يمنع تكراره.
   */
  @Cron(CronExpression.EVERY_30_MINUTES)
  async announceRewards() {
    const config = await this.config();
    if (!config.enabled) return;
    const since = new Date(Date.now() - 3 * 60 * 60_000);
    const recent = await this.prisma.booking.findMany({
      where: {
        status: BookingStatus.COMPLETED,
        updatedAt: { gte: since },
        loyaltyDiscount: 0,
        userId: { not: null },
      },
      select: { userId: true, property: { select: { type: true } } },
      distinct: ['userId', 'propertyId'],
      take: 500,
    });
    const seen = new Set<string>();
    for (const { userId, property } of recent) {
      const signature = `${userId}:${property.type}`;
      if (!userId || seen.has(signature)) continue;
      seen.add(signature);
      await this.announceFor(config, userId, property.type).catch((err: Error) =>
        this.logger.warn(`loyalty notice failed: ${err.message}`),
      );
    }
  }

  private async announceFor(config: LoyaltyConfig, userId: string, type: PropertyType) {
    const program = config.programs[type];
    if (!program.enabled) return;
    const { paidCompleted, activeRewards } = await this.counts(this.prisma, userId, type);
    const { earned, rewardsAvailable } = loyaltyProgress(paidCompleted, activeRewards, program.required);
    if (rewardsAvailable <= 0) return;
    const entityId = `${type}:${earned}`;
    const sent = await this.prisma.userNotification.findFirst({
      where: { userId, entityType: 'loyalty', entityId },
      select: { id: true },
    });
    if (sent) return;
    await this.prisma.userNotification.create({
      data: {
        userId,
        type: 'SYSTEM',
        title: `خصم ${program.percent}% بانتظارك في ${WORLD_LABEL[type]}`,
        body: `أكملت ${program.required} حجوزات. خصمك جاهز لحجزك القادم في ${WORLD_LABEL[type]}.`,
        linkUrl: '/loyalty',
        entityType: 'loyalty',
        entityId,
      },
    });
  }

  async admin() {
    const [config, row] = await Promise.all([
      this.readConfig(),
      this.prisma.platformSetting.findUnique({ where: { key: KEY } }),
    ]);
    const stats = await Promise.all(
      LOYALTY_TYPES.map(async (type) => {
        const required = config.programs[type].required;
        const [members, used] = await Promise.all([
          this.prisma.booking.groupBy({
            by: ['userId'],
            where: {
              status: BookingStatus.COMPLETED,
              loyaltyDiscount: 0,
              userId: { not: null },
              property: { type },
            },
            _count: { _all: true },
          }),
          this.prisma.booking.aggregate({
            where: {
              status: { not: BookingStatus.CANCELLED },
              loyaltyDiscount: { gt: 0 },
              property: { type },
            },
            _count: { _all: true },
            _sum: { loyaltyDiscount: true },
          }),
        ]);
        return {
          type,
          members: members.length,
          earned: members.reduce((sum, m) => sum + Math.floor(m._count._all / required), 0),
          used: used._count._all,
          totalDiscount: Number(used._sum.loyaltyDiscount ?? 0),
        };
      }),
    );
    return { config, stats, updatedAt: row?.updatedAt ?? null };
  }

  async update(user: AuthUser, body: unknown) {
    const config = normalizeLoyaltyConfig(body);
    const value = JSON.stringify(config);
    await this.prisma.platformSetting.upsert({
      where: { key: KEY },
      create: { key: KEY, value },
      update: { value },
    });
    await this.cache.del(CACHE_KEY);
    await this.activity.log({
      userId: user.id,
      action: 'loyalty.update',
      entityType: 'setting',
      entityId: KEY,
    });
    return this.admin();
  }
}
