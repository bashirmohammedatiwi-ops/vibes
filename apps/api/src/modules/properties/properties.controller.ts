import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { PropertyStatus, UserRole } from '@prisma/client';
import { IsEnum } from 'class-validator';
import { Public } from '../../common/decorators/public.decorator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AttachMediaDto, CreatePropertyDto, UpdatePropertyDto } from './dto/create-property.dto';
import { PropertiesService } from './properties.service';

class UpdateStatusDto {
  @IsEnum(PropertyStatus)
  status!: PropertyStatus;
}

@ApiTags('properties')
@Controller('properties')
export class PropertiesController {
  constructor(private readonly properties: PropertiesService) {}

  @Public()
  @Get()
  list(
    @Query('type') type?: string,
    @Query('status') status?: string,
    @Query('cityId') cityId?: string,
    @Query('featured') featured?: string,
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
    @Query('q') q?: string,
  ) {
    return this.properties.list({ type, status, cityId, featured, page, pageSize, q });
  }

  @ApiBearerAuth()
  @Get('mine')
  @Roles(UserRole.PROVIDER)
  listMine(@CurrentUser() user: AuthUser) {
    return this.properties.listMine(user);
  }

  @Public()
  @Get('slug/:slug/meta')
  metaBySlug(@Param('slug') slug: string) {
    return this.properties.metaBySlug(slug);
  }

  @Public()
  @Get('slug/:slug')
  findBySlug(@Param('slug') slug: string) {
    return this.properties.findBySlug(slug);
  }

  @Public()
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.properties.findOne(id);
  }

  @Public()
  @Get(':id/availability')
  availability(@Param('id') id: string, @Query('month') month?: string) {
    return this.properties.availability(id, month);
  }

  @ApiBearerAuth()
  @Post()
  @Roles(UserRole.PROVIDER)
  create(@CurrentUser() user: AuthUser, @Body() dto: CreatePropertyDto) {
    return this.properties.create(user, dto);
  }

  @ApiBearerAuth()
  @Patch(':id')
  @Roles(UserRole.PROVIDER, UserRole.ADMIN, UserRole.STAFF)
  update(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: UpdatePropertyDto) {
    return this.properties.update(user, id, dto);
  }

  @ApiBearerAuth()
  @Post(':id/media')
  @Roles(UserRole.PROVIDER, UserRole.ADMIN, UserRole.STAFF)
  attachMedia(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AttachMediaDto,
  ) {
    return this.properties.attachMedia(user, id, dto.mediaId);
  }

  @ApiBearerAuth()
  @Delete(':id')
  @Roles(UserRole.ADMIN, UserRole.STAFF)
  remove(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.properties.remove(user, id);
  }

  @ApiBearerAuth()
  @Patch(':id/status')
  @Roles(UserRole.ADMIN, UserRole.STAFF)
  setStatus(@Param('id') id: string, @Body() dto: UpdateStatusDto) {
    return this.properties.setStatus(id, dto.status);
  }
}
