import { Controller, Get } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { AdminSettingsService } from './admin-settings.service';

@ApiTags('settings')
@Controller('settings')
export class PublicSettingsController {
  constructor(private readonly settings: AdminSettingsService) {}

  @Public()
  @Get()
  get() {
    return this.settings.public();
  }
}
