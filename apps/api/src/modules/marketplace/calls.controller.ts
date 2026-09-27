import { Body, Controller, Param, Post } from '@nestjs/common';
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

  @Post(':id/join')
  join(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.calls.join(user, id);
  }

  @Post(':id/end')
  end(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.calls.end(user, id);
  }
}
