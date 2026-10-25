import { Body, Controller, Delete, Get, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { IsOptional, IsString } from 'class-validator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { PrismaService } from '../../prisma/prisma.service';
import { AccountDeletionService } from './account-deletion.service';

class UpdateProfileDto {
  @IsOptional()
  @IsString()
  name?: string;
}

@ApiTags('users')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly deletion: AccountDeletionService,
  ) {}

  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.prisma.user.findUnique({
      where: { id: user.id },
      include: { provider: true },
      omit: { pinHash: true },
    });
  }

  @Patch('me')
  updateMe(@CurrentUser() user: AuthUser, @Body() dto: UpdateProfileDto) {
    return this.prisma.user.update({
      where: { id: user.id },
      data: { name: dto.name?.trim() || null },
      include: { provider: true },
      omit: { pinHash: true },
    });
  }

  /** حذف الحساب نهائياً (متطلب المتاجر). */
  @Delete('me')
  deleteMe(@CurrentUser() user: AuthUser) {
    return this.deletion.deleteAccount(user);
  }

  @Get()
  @Roles(UserRole.ADMIN)
  list() {
    return this.prisma.user.findMany({
      orderBy: { createdAt: 'desc' },
      include: { provider: true },
      omit: { pinHash: true },
    });
  }
}
