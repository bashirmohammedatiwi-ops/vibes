import { Body, Controller, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { ModerationService, REPORT_TARGETS, ReportTarget } from './moderation.service';

class ReportDto {
  @IsIn(REPORT_TARGETS as unknown as string[])
  targetType!: ReportTarget;

  @IsString()
  @MaxLength(80)
  targetId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  reportedUserId?: string;

  @IsOptional()
  @IsBoolean()
  block?: boolean;
}

@ApiTags('moderation')
@ApiBearerAuth()
@Controller('reports')
export class ModerationController {
  constructor(private readonly moderation: ModerationService) {}

  @Post()
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  report(@CurrentUser() user: AuthUser, @Body() dto: ReportDto) {
    return this.moderation.report(user, dto);
  }
}
