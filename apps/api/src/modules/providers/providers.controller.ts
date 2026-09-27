import { Body, Controller, Get, Param, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { IsArray, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { ProvidersService } from './providers.service';

class BecomeProviderDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(80)
  businessName?: string;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  placeTypes?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(400)
  note?: string;
}

class RejectProviderDto {
  @IsString()
  @MinLength(3)
  reason!: string;
}

@ApiTags('providers')
@ApiBearerAuth()
@Controller('providers')
export class ProvidersController {
  constructor(private readonly providers: ProvidersService) {}

  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.providers.me(user);
  }

  @Get()
  @Roles(UserRole.ADMIN, UserRole.STAFF)
  list() {
    return this.providers.list();
  }

  @Post('me')
  becomeProvider(@CurrentUser() user: AuthUser, @Body() dto: BecomeProviderDto) {
    return this.providers.becomeProvider(user, dto);
  }

  @Patch(':id/verify')
  @Roles(UserRole.ADMIN, UserRole.STAFF)
  verify(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.providers.verify(user, id);
  }

  @Patch(':id/reject')
  @Roles(UserRole.ADMIN, UserRole.STAFF)
  reject(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: RejectProviderDto) {
    return this.providers.reject(user, id, dto.reason);
  }

  @Patch(':id/revoke')
  @Roles(UserRole.ADMIN, UserRole.STAFF)
  revoke(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: { reason?: string }) {
    return this.providers.revoke(user, id, dto.reason);
  }
}
