import { Controller, Get, Header } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { PropertyStatus } from '@prisma/client';
import { Public } from '../../common/decorators/public.decorator';
import { PrismaService } from '../../prisma/prisma.service';

@ApiTags('seo')
@Controller()
export class SeoController {
  constructor(private readonly prisma: PrismaService) {}

  @Public()
  @Get('sitemap.xml')
  @Header('Content-Type', 'application/xml')
  async sitemap() {
    const base = process.env.PUBLIC_WEB_URL ?? 'https://vibes.iq';
    const properties = await this.prisma.property.findMany({
      where: { status: PropertyStatus.APPROVED },
      select: { slug: true, updatedAt: true },
      orderBy: { updatedAt: 'desc' },
    });

    const urls = [
      { loc: base, priority: '1.0' },
      ...properties.map((p) => ({
        loc: `${base}/places/${p.slug}`,
        lastmod: p.updatedAt.toISOString().slice(0, 10),
        priority: '0.8',
      })),
    ];

    const body = urls
      .map(
        (u) =>
          `  <url><loc>${u.loc}</loc>${'lastmod' in u ? `<lastmod>${u.lastmod}</lastmod>` : ''}<priority>${u.priority}</priority></url>`,
      )
      .join('\n');

    return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${body}\n</urlset>`;
  }

  @Public()
  @Get('robots.txt')
  @Header('Content-Type', 'text/plain')
  robots() {
    const base = process.env.PUBLIC_WEB_URL ?? 'https://vibes.iq';
    return `User-agent: *\nAllow: /\nSitemap: ${base}/api/sitemap.xml\n`;
  }
}
