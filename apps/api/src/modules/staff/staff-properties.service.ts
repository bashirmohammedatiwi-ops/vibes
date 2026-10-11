import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { PropertyStatus, UserRole } from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';
import { AdminPropertiesService } from '../admin/admin-properties.service';
import { AdminCreatePropertyDto, AdminUpdatePropertyDto } from '../admin/dto/admin-property.dto';

/**
 * عمليات الأماكن لتطبيق الموظفين: تغلّف خدمات الإدارة نفسها (نفس المنطق والتحقق
 * وسجل النشاط وإبطال الـ cache) وتضيف حماية خاصة بالموظف:
 *  - الموظف بلا properties.moderate لا يستطيع النشر/الاعتماد (مسودة أو بانتظار فقط).
 *  - لا يُحذف مكان لديه حجوزات؛ يُعلَّق بدلاً من ذلك.
 */
@Injectable()
export class StaffPropertiesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly properties: AdminPropertiesService,
  ) {}

  /** بيانات تعبئة النموذج: المحافظات والمدن، كتالوج المزايا، والمزودون. */
  async formMeta() {
    const [provinces, amenities, providers] = await Promise.all([
      this.prisma.province.findMany({
        include: { cities: { orderBy: { nameAr: 'asc' } } },
        orderBy: { nameAr: 'asc' },
      }),
      this.prisma.amenity.findMany({
        where: { isActive: true },
        orderBy: [{ category: 'asc' }, { sortOrder: 'asc' }, { nameAr: 'asc' }],
      }),
      this.prisma.provider.findMany({
        select: {
          id: true,
          businessName: true,
          user: { select: { name: true, phone: true } },
        },
        orderBy: { businessName: 'asc' },
        take: 300,
      }),
    ]);
    return { provinces, amenities, providers };
  }

  getOne(id: string) {
    return this.properties.getOne(id);
  }

  async create(user: AuthUser, dto: AdminCreatePropertyDto) {
    await this.assertStatusAllowed(user, dto.status);
    return this.properties.create(user, dto);
  }

  async update(user: AuthUser, id: string, dto: AdminUpdatePropertyDto) {
    await this.assertStatusAllowed(user, dto.status);
    return this.properties.update(user, id, dto);
  }

  duplicate(user: AuthUser, id: string) {
    return this.properties.duplicate(user, id);
  }

  async remove(user: AuthUser, id: string) {
    const bookings = await this.prisma.booking.count({ where: { propertyId: id } });
    if (bookings > 0) {
      throw new BadRequestException('لا يمكن حذف مكان لديه حجوزات — علّقه بدلاً من الحذف');
    }
    return this.properties.remove(user, id);
  }

  private async assertStatusAllowed(user: AuthUser, status?: PropertyStatus) {
    if (!status || status === PropertyStatus.DRAFT || status === PropertyStatus.PENDING) return;
    if (user.role === UserRole.ADMIN) return;
    const profile = await this.prisma.staffProfile.findUnique({
      where: { userId: user.id },
      select: { permissions: true, isActive: true },
    });
    const ok = Boolean(profile?.isActive && profile.permissions.includes('properties.moderate'));
    if (!ok) {
      throw new ForbiddenException('تغيير حالة النشر يتطلب صلاحية اعتماد الأماكن');
    }
  }
}
