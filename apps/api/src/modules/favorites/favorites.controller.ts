import { Body, Controller, Delete, Get, Param, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';

class FavoriteDto {
  @IsUUID()
  propertyId!: string;
}

@ApiTags('favorites')
@ApiBearerAuth()
@Controller('favorites')
export class FavoritesController {
  constructor(private readonly prisma: PrismaService) {}

  /** قائمة مفضلات المستخدم — بأماكن منشورة فقط */
  @Get()
  async list(@CurrentUser() user: AuthUser) {
    const rows = await this.prisma.favorite.findMany({
      where: { userId: user.id },
      include: {
        property: {
          include: {
            city: { include: { province: true } },
            media: { orderBy: { sortOrder: 'asc' as const }, take: 5 },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    // الوسائط المستقرة فقط + الأماكن المنشورة
    return rows
      .map((row) => row.property)
      .filter((property): property is NonNullable<typeof property> => !!property)
      .map((property) => ({
        ...property,
        media: (property.media as typeof property.media).filter(
          (m: { status: string }) => m.status === 'READY',
        ),
      }))
      .filter(
        (property: { status: string }) => property.status === 'APPROVED',
      );
  }

  @Post()
  async add(@CurrentUser() user: AuthUser, @Body() dto: FavoriteDto) {
    const property = await this.prisma.property.findUnique({
      where: { id: dto.propertyId },
    });
    if (!property) return { added: false };

    await this.prisma.favorite.upsert({
      where: {
        userId_propertyId: { userId: user.id, propertyId: dto.propertyId },
      },
      update: {},
      create: { userId: user.id, propertyId: dto.propertyId },
    });
    return { added: true };
  }

  @Delete(':propertyId')
  async remove(
    @CurrentUser() user: AuthUser,
    @Param('propertyId') propertyId: string,
  ) {
    await this.prisma.favorite.deleteMany({
      where: { userId: user.id, propertyId },
    });
    return { removed: true };
  }
}
