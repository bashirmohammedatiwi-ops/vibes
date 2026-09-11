import { Body, Controller, Delete, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, MinLength } from 'class-validator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';

class RegisterDeviceDto {
  @IsString()
  @MinLength(10)
  token!: string;

  @IsOptional()
  @IsIn(['android', 'ios', 'web'])
  platform?: string;
}

@ApiTags('devices')
@ApiBearerAuth()
@Controller('devices')
export class DevicesController {
  constructor(private readonly prisma: PrismaService) {}

  /** Registers (or refreshes) an FCM device token for push notifications. */
  @Post()
  async register(@CurrentUser() user: AuthUser, @Body() dto: RegisterDeviceDto) {
    const device = await this.prisma.deviceToken.upsert({
      where: { token: dto.token },
      update: { userId: user.id, platform: dto.platform ?? 'android' },
      create: { userId: user.id, token: dto.token, platform: dto.platform ?? 'android' },
    });
    return device;
  }

  @Delete()
  async unregister(@CurrentUser() user: AuthUser, @Query('token') token?: string) {
    if (!token) return { deleted: 0 };
    const result = await this.prisma.deviceToken.deleteMany({
      where: { token, userId: user.id },
    });
    return { deleted: result.count };
  }
}
