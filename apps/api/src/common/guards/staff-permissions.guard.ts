import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { UserRole } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { STAFF_PERMISSIONS_KEY } from '../decorators/staff-permissions.decorator';
import { expandStaffPermissions } from '../../modules/staff/staff.permissions';

@Injectable()
export class StaffPermissionsGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext) {
    const required = this.reflector.getAllAndOverride<string[]>(STAFF_PERMISSIONS_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!required?.length) return true;

    const user = context.switchToHttp().getRequest().user as { id?: string; role?: UserRole } | undefined;
    if (!user?.id) throw new ForbiddenException('ليست لديك صلاحية هذا الإجراء');
    if (user.role === UserRole.ADMIN) return true;
    if (user.role !== UserRole.STAFF) throw new ForbiddenException('هذا التطبيق للموظفين');

    const profile = await this.prisma.staffProfile.findUnique({
      where: { userId: user.id },
      select: { permissions: true, isActive: true },
    });
    if (!profile?.isActive) throw new ForbiddenException('الحساب موقوف');
    const granted = expandStaffPermissions(profile.permissions);
    const has = required.every((code) => granted.includes(code));
    if (!has) throw new ForbiddenException('ليست لديك صلاحية هذا الإجراء');
    return true;
  }
}
