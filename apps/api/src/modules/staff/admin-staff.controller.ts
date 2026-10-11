import { Body, Controller, Get, Param, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { IsArray, IsBoolean, IsOptional, IsString } from 'class-validator';
import { Roles } from '../../common/decorators/roles.decorator';
import { StaffService } from './staff.service';

class CreateStaffDto {
  @IsString()
  phone!: string;

  @IsString()
  name!: string;

  @IsString()
  pin!: string;

  @IsArray()
  permissions!: string[];

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

class UpdateStaffDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsArray()
  permissions?: string[];

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsString()
  pin?: string;
}

@ApiTags('admin-staff')
@ApiBearerAuth()
@Roles(UserRole.ADMIN)
@Controller('admin/staff')
export class AdminStaffController {
  constructor(private readonly staff: StaffService) {}

  @Get('meta')
  meta() {
    return this.staff.templates();
  }

  @Get()
  list() {
    return this.staff.listForAdmin();
  }

  @Get('live')
  live() {
    return this.staff.supervisorBoard();
  }

  @Post()
  create(@Body() dto: CreateStaffDto) {
    return this.staff.createStaff(dto);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateStaffDto) {
    return this.staff.updateStaff(id, dto);
  }
}
