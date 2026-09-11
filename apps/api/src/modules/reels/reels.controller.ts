import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * تغذية الريلز — فيديوهات عمودية (9:16) للأماكن المنشورة.
 * تجميع الوسائط الجاهزة مع سياق مكانها في استجابة واحدة.
 */
@ApiTags('reels')
@Public()
@Controller('reels')
export class ReelsController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async feed(@Query('take') takeParam?: string, @Query('cursor') cursor?: string) {
    const take = Math.min(Math.max(Number(takeParam) || 12, 1), 30);

    const mediaRows = await this.prisma.media.findMany({
      where: {
        status: 'READY',
        type: { in: ['VIDEO', 'REEL'] },
        property: { status: 'APPROVED' },
        propertyId: { not: null },
      },
      include: {
        property: {
          include: {
            city: { include: { province: true } },
            media: {
              where: { status: 'READY', type: 'IMAGE' },
              orderBy: { sortOrder: 'asc' as const },
              take: 3,
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: take + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });

    const hasMore = mediaRows.length > take;
    const rows = hasMore ? mediaRows.slice(0, take) : mediaRows;

    return {
      items: rows.map((media) => ({ media, property: media.property })),
      nextCursor: hasMore ? rows[rows.length - 1].id : null,
    };
  }
}
