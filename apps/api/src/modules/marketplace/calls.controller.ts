import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { CallsService } from './calls.service';

class StartCallDto {
  @IsOptional()
  @IsString()
  propertyId?: string;

  @IsOptional()
  @IsString()
  conversationId?: string;

  @IsOptional()
  @IsString()
  bookingId?: string;
}

@ApiTags('calls')
@ApiBearerAuth()
@Controller('calls')
export class CallsController {
  constructor(private readonly calls: CallsService) {}

  @Post()
  start(@CurrentUser() user: AuthUser, @Body() dto: StartCallDto) {
    return this.calls.start(user, dto);
  }

  /// هل ترنّ مكالمة لي الآن؟ — تستطلعها طبقة الرنين كل بضع ثوانٍ
  @Get('incoming')
  incoming(@CurrentUser() user: AuthUser) {
    return this.calls.incomingRinging(user);
  }

  @Get(':id')
  snapshot(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.calls.snapshot(user, id);
  }

  @Post(':id/quality')
  quality(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() body: { rttMs?: number; packetLossPct?: number; reconnects?: number },
  ) {
    return this.calls.reportQuality(user, id, body);
  }

  @Post(':id/join')
  join(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.calls.join(user, id);
  }

  @Post(':id/decline')
  decline(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.calls.decline(user, id);
  }

  @Post(':id/end')
  end(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.calls.end(user, id);
  }

  /// سجل مكالمات محادثة
  @Get()
  history(
    @CurrentUser() user: AuthUser,
    @Query() query: { conversationId?: string },
  ) {
    if (!query.conversationId) return [];
    return this.calls.history(user, query.conversationId);
  }
}
