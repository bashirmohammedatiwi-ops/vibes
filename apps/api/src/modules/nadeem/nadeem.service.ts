import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { CacheService } from '../../common/services/cache.service';
import { PrismaService } from '../../prisma/prisma.service';
import { DEFAULT_NADEEM_CONFIG, NADEEM_ICONS, NadeemConfig, normalizeNadeemConfig } from './nadeem.config';

const CONFIG_KEY = 'nadeem_config';
const CACHE_KEY = 'cache:nadeem:config';
const CACHE_TTL = 60;

export type NadeemSessionInput = {
  occasion?: string;
  propertyType?: string | null;
  autoType?: boolean;
  province?: string | null;
  guests?: number | null;
  shift?: string | null;
  maxBudget?: number | null;
  budgetOpen?: boolean;
  resultIds?: string[];
  precise?: boolean;
  platform?: string;
};

const clip = (v: unknown, max = 60) => (typeof v === 'string' && v.trim() ? v.trim().slice(0, max) : null);
const int = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? Math.round(Math.min(v, 2_000_000_000)) : null);

@Injectable()
export class NadeemService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cache: CacheService,
    private readonly activity: ActivityLogService,
  ) {}

  // ── الإعدادات ──

  async config(): Promise<NadeemConfig> {
    return this.cache.getOrSet(CACHE_KEY, CACHE_TTL, () => this.readConfig());
  }

  private async readConfig(): Promise<NadeemConfig> {
    const row = await this.prisma.platformSetting.findUnique({ where: { key: CONFIG_KEY } });
    if (!row) return DEFAULT_NADEEM_CONFIG;
    try {
      return normalizeNadeemConfig(JSON.parse(row.value));
    } catch {
      return DEFAULT_NADEEM_CONFIG;
    }
  }

  async adminConfig() {
    const [config, row] = await Promise.all([
      this.readConfig(),
      this.prisma.platformSetting.findUnique({ where: { key: CONFIG_KEY } }),
    ]);
    return {
      config,
      defaults: DEFAULT_NADEEM_CONFIG,
      icons: NADEEM_ICONS,
      customized: !!row,
      updatedAt: row?.updatedAt ?? null,
    };
  }

  async update(user: AuthUser, raw: unknown) {
    const config = normalizeNadeemConfig(raw);
    const value = JSON.stringify(config);
    await this.prisma.platformSetting.upsert({
      where: { key: CONFIG_KEY },
      update: { value },
      create: { key: CONFIG_KEY, value },
    });
    await this.cache.del(CACHE_KEY);
    await this.activity.log({
      userId: user.id,
      action: 'nadeem.update',
      entityType: 'settings',
      entityId: 'nadeem',
    });
    return this.adminConfig();
  }

  async reset(user: AuthUser) {
    await this.prisma.platformSetting.deleteMany({ where: { key: CONFIG_KEY } });
    await this.cache.del(CACHE_KEY);
    await this.activity.log({
      userId: user.id,
      action: 'nadeem.reset',
      entityType: 'settings',
      entityId: 'nadeem',
    });
    return this.adminConfig();
  }

  // ── الجلسات ──

  async logSession(userId: string | undefined, body: NadeemSessionInput) {
    const ids = Array.isArray(body.resultIds)
      ? body.resultIds.filter((x): x is string => typeof x === 'string').slice(0, 30)
      : [];
    const row = await this.prisma.nadeemSession.create({
      data: {
        userId: userId ?? null,
        occasion: clip(body.occasion, 40),
        propertyType: clip(body.propertyType, 20),
        autoType: body.autoType === true,
        province: clip(body.province, 80),
        guests: int(body.guests),
        shift: clip(body.shift, 20),
        maxBudget: int(body.maxBudget),
        budgetOpen: body.budgetOpen === true,
        resultIds: ids,
        resultCount: ids.length,
        precise: body.precise === true,
        platform: clip(body.platform, 20),
      },
      select: { id: true },
    });
    return row;
  }

  async logClick(id: string, propertyId: string) {
    const session = await this.prisma.nadeemSession.findUnique({ where: { id }, select: { id: true, clickedAt: true } });
    if (!session) throw new NotFoundException();
    if (!session.clickedAt) {
      await this.prisma.nadeemSession.update({
        where: { id },
        data: { clickedPropertyId: propertyId.slice(0, 64), clickedAt: new Date() },
      });
    }
    return { ok: true };
  }

  // ── الإحصاءات ──

  async stats(days = 30) {
    const span = Math.min(365, Math.max(1, days));
    const since = new Date(Date.now() - span * 86_400_000);
    const where: Prisma.NadeemSessionWhereInput = { createdAt: { gte: since } };

    const [total, clicked, empty, precise, byOccasion, byType, byProvince, byShift, guestsAgg, budgetAgg, allTime] =
      await Promise.all([
        this.prisma.nadeemSession.count({ where }),
        this.prisma.nadeemSession.count({ where: { ...where, clickedAt: { not: null } } }),
        this.prisma.nadeemSession.count({ where: { ...where, resultCount: 0 } }),
        this.prisma.nadeemSession.count({ where: { ...where, precise: true } }),
        this.prisma.nadeemSession.groupBy({ by: ['occasion'], where, _count: { _all: true } }),
        this.prisma.nadeemSession.groupBy({ by: ['propertyType'], where, _count: { _all: true } }),
        this.prisma.nadeemSession.groupBy({ by: ['province'], where, _count: { _all: true } }),
        this.prisma.nadeemSession.groupBy({ by: ['shift'], where, _count: { _all: true } }),
        this.prisma.nadeemSession.aggregate({ where: { ...where, guests: { not: null } }, _avg: { guests: true } }),
        this.prisma.nadeemSession.aggregate({
          where: { ...where, budgetOpen: false, maxBudget: { not: null } },
          _avg: { maxBudget: true },
        }),
        this.prisma.nadeemSession.count(),
      ]);

    // سلسلة يومية
    const rows = await this.prisma.$queryRaw<{ day: Date; n: bigint; c: bigint }[]>`
      SELECT date_trunc('day', created_at) AS day,
             COUNT(*) AS n,
             COUNT(clicked_at) AS c
      FROM nadeem_sessions
      WHERE created_at >= ${since}
      GROUP BY 1 ORDER BY 1`;
    const byDay = new Map(rows.map((r) => [r.day.toISOString().slice(0, 10), { n: Number(r.n), c: Number(r.c) }]));
    const daily: { date: string; sessions: number; clicks: number }[] = [];
    const chartDays = Math.min(span, 60);
    for (let i = chartDays - 1; i >= 0; i--) {
      const d = new Date(Date.now() - i * 86_400_000).toISOString().slice(0, 10);
      const hit = byDay.get(d);
      daily.push({ date: d, sessions: hit?.n ?? 0, clicks: hit?.c ?? 0 });
    }

    // الأماكن الأكثر اقتراحاً ونقراً
    const recRows = await this.prisma.$queryRaw<{ id: string; n: bigint }[]>`
      SELECT unnest(result_ids[1:3]) AS id, COUNT(*) AS n
      FROM nadeem_sessions
      WHERE created_at >= ${since}
      GROUP BY 1 ORDER BY 2 DESC LIMIT 10`;
    const clickRows = await this.prisma.nadeemSession.groupBy({
      by: ['clickedPropertyId'],
      where: { ...where, clickedPropertyId: { not: null } },
      _count: { _all: true },
      orderBy: { _count: { clickedPropertyId: 'desc' } },
      take: 10,
    });
    const propIds = [
      ...new Set([...recRows.map((r) => r.id), ...clickRows.map((r) => r.clickedPropertyId!).filter(Boolean)]),
    ];
    const props = propIds.length
      ? await this.prisma.property.findMany({
          where: { id: { in: propIds } },
          select: { id: true, name: true, type: true },
        })
      : [];
    const propName = new Map(props.map((p) => [p.id, p]));

    const count = <T extends { _count: { _all: number } }>(list: T[], key: (r: T) => string | null) =>
      list
        .map((r) => ({ key: key(r) ?? '—', count: r._count._all }))
        .sort((a, b) => b.count - a.count);

    return {
      days: span,
      total,
      allTime,
      clicked,
      clickRate: total ? Math.round((clicked / total) * 100) : 0,
      emptyResults: empty,
      preciseRate: total ? Math.round((precise / total) * 100) : 0,
      avgGuests: guestsAgg._avg.guests ? Math.round(guestsAgg._avg.guests) : null,
      avgBudget: budgetAgg._avg.maxBudget ? Math.round(budgetAgg._avg.maxBudget) : null,
      byOccasion: count(byOccasion, (r) => r.occasion),
      byType: count(byType, (r) => r.propertyType ?? 'AUTO'),
      byProvince: count(byProvince, (r) => r.province ?? 'كل العراق').slice(0, 12),
      byShift: count(byShift, (r) => r.shift),
      daily,
      topRecommended: recRows.map((r) => ({
        id: r.id,
        name: propName.get(r.id)?.name ?? 'مكان محذوف',
        type: propName.get(r.id)?.type ?? null,
        count: Number(r.n),
      })),
      topClicked: clickRows.map((r) => ({
        id: r.clickedPropertyId!,
        name: propName.get(r.clickedPropertyId!)?.name ?? 'مكان محذوف',
        type: propName.get(r.clickedPropertyId!)?.type ?? null,
        count: r._count._all,
      })),
    };
  }

  async sessions(page = 1, pageSize = 30) {
    const take = Math.min(100, Math.max(1, pageSize));
    const skip = (Math.max(1, page) - 1) * take;
    const [total, items] = await Promise.all([
      this.prisma.nadeemSession.count(),
      this.prisma.nadeemSession.findMany({ orderBy: { createdAt: 'desc' }, skip, take }),
    ]);
    const userIds = [...new Set(items.map((i) => i.userId).filter((x): x is string => !!x))];
    const propIds = [
      ...new Set(items.flatMap((i) => [...i.resultIds.slice(0, 3), ...(i.clickedPropertyId ? [i.clickedPropertyId] : [])])),
    ];
    const [users, props] = await Promise.all([
      userIds.length
        ? this.prisma.user.findMany({ where: { id: { in: userIds } }, select: { id: true, name: true, phone: true } })
        : [],
      propIds.length
        ? this.prisma.property.findMany({ where: { id: { in: propIds } }, select: { id: true, name: true } })
        : [],
    ]);
    const userMap = new Map(users.map((u) => [u.id, u]));
    const propMap = new Map(props.map((p) => [p.id, p.name]));
    return {
      total,
      page: Math.max(1, page),
      pageSize: take,
      items: items.map((i) => ({
        ...i,
        user: i.userId ? userMap.get(i.userId) ?? null : null,
        topResults: i.resultIds.slice(0, 3).map((id) => ({ id, name: propMap.get(id) ?? '—' })),
        clickedName: i.clickedPropertyId ? propMap.get(i.clickedPropertyId) ?? '—' : null,
      })),
    };
  }
}
