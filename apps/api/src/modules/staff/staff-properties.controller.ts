import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireStaffPermissions } from '../../common/decorators/staff-permissions.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AdminAvailabilityService } from '../admin/admin-availability.service';
import { AdminMediaService, mediaStorageOptions } from '../admin/admin-media.service';
import { AdminPricingService } from '../admin/admin-pricing.service';
import {
  AdminCreatePropertyDto,
  AdminPriceRuleDto,
  AdminUpdatePropertyDto,
  BulkAvailabilityDto,
  ClearAvailabilityDto,
  ReorderMediaDto,
  UpdateMediaDto,
} from '../admin/dto/admin-property.dto';
import { StaffPropertiesService } from './staff-properties.service';

const MAX_UPLOAD_BYTES =
  Math.max(Number(process.env.MAX_UPLOAD_MB ?? 20), Number(process.env.MEDIA_VIDEO_MAX_MB ?? 200)) *
  1024 *
  1024;

/**
 * إدارة الأماكن والوسائط من تطبيق الموظفين.
 * يُسجَّل قبل StaffController (انظر staff.module.ts) حتى لا يلتقط مسار
 * `properties/:id` الخاص به المسارَ الثابت `properties/form-meta`.
 */
@ApiTags('staff-properties')
@ApiBearerAuth()
@Roles(UserRole.STAFF, UserRole.ADMIN)
@Controller('staff')
export class StaffPropertiesController {
  constructor(
    private readonly props: StaffPropertiesService,
    private readonly media: AdminMediaService,
    private readonly pricing: AdminPricingService,
    private readonly availability: AdminAvailabilityService,
  ) {}

  // ───────── بيانات النموذج ─────────

  @Get('properties/form-meta')
  @RequireStaffPermissions('properties.write')
  formMeta() {
    return this.props.formMeta();
  }

  // ───────── الأماكن ─────────

  @Get('properties/:id/full')
  @RequireStaffPermissions('properties.read')
  full(@Param('id') id: string) {
    return this.props.getOne(id);
  }

  @Post('properties')
  @RequireStaffPermissions('properties.write')
  create(@CurrentUser() user: AuthUser, @Body() dto: AdminCreatePropertyDto) {
    return this.props.create(user, dto);
  }

  @Patch('properties/:id')
  @RequireStaffPermissions('properties.write')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminUpdatePropertyDto,
  ) {
    return this.props.update(user, id, dto);
  }

  @Post('properties/:id/duplicate')
  @RequireStaffPermissions('properties.write')
  duplicate(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.props.duplicate(user, id);
  }

  @Delete('properties/:id')
  @RequireStaffPermissions('properties.write')
  remove(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.props.remove(user, id);
  }

  // ───────── الوسائط (صور / فيديو / ريلز / 360°) ─────────

  @Get('properties/:id/media')
  @RequireStaffPermissions('properties.read')
  listMedia(@Param('id') id: string) {
    return this.media.listByProperty(id);
  }

  /**
   * kind: media (افتراضي) | reel (فيديو عمودي لتبويب الاستكشاف) | panorama (صورة 360°).
   * targetRatio: auto | 16:9 | 9:16 | 1:1 | 4:3 — لمعالجة الفيديو.
   */
  @Post('properties/:id/media')
  @RequireStaffPermissions('properties.write')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: mediaStorageOptions(),
      limits: { fileSize: MAX_UPLOAD_BYTES },
    }),
  )
  uploadMedia(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @UploadedFile() file: Express.Multer.File,
    @Body('targetRatio') targetRatio?: string,
    @Body('kind') kind?: string,
  ) {
    return this.media.uploadForProperty(user, id, file, targetRatio, kind);
  }

  @Patch('properties/:id/media/reorder')
  @RequireStaffPermissions('properties.write')
  reorderMedia(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ReorderMediaDto,
  ) {
    return this.media.reorder(user, id, dto.mediaIds);
  }

  @Patch('properties/:id/media/:mediaId/primary')
  @RequireStaffPermissions('properties.write')
  setPrimary(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('mediaId') mediaId: string,
  ) {
    return this.media.setPrimary(user, id, mediaId);
  }

  @Patch('media/:mediaId')
  @RequireStaffPermissions('properties.write')
  updateMedia(
    @CurrentUser() user: AuthUser,
    @Param('mediaId') mediaId: string,
    @Body() dto: UpdateMediaDto,
  ) {
    return this.media.update(user, mediaId, dto);
  }

  @Post('media/:mediaId/reprocess')
  @RequireStaffPermissions('properties.write')
  reprocess(
    @CurrentUser() user: AuthUser,
    @Param('mediaId') mediaId: string,
    @Body('targetRatio') targetRatio?: string,
  ) {
    return this.media.reprocess(user, mediaId, targetRatio);
  }

  @Delete('media/:mediaId')
  @RequireStaffPermissions('properties.write')
  deleteMedia(@CurrentUser() user: AuthUser, @Param('mediaId') mediaId: string) {
    return this.media.remove(user, mediaId);
  }

  // ───────── التسعير ─────────

  @Get('properties/:id/pricing-rules')
  @RequireStaffPermissions('properties.read')
  listRules(@Param('id') id: string) {
    return this.pricing.listRules(id);
  }

  @Post('properties/:id/pricing-rules')
  @RequireStaffPermissions('properties.write')
  createRule(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AdminPriceRuleDto,
  ) {
    return this.pricing.createRule(user, id, dto);
  }

  @Patch('properties/:id/pricing-rules/:ruleId')
  @RequireStaffPermissions('properties.write')
  updateRule(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('ruleId') ruleId: string,
    @Body() dto: Partial<AdminPriceRuleDto>,
  ) {
    return this.pricing.updateRule(user, id, ruleId, dto);
  }

  @Delete('properties/:id/pricing-rules/:ruleId')
  @RequireStaffPermissions('properties.write')
  deleteRule(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('ruleId') ruleId: string,
  ) {
    return this.pricing.deleteRule(user, id, ruleId);
  }

  // ───────── التوفر ─────────

  @Get('properties/:id/availability')
  @RequireStaffPermissions('properties.read')
  listAvailability(@Param('id') id: string, @Query('month') month?: string) {
    return this.availability.list(id, month);
  }

  @Post('properties/:id/availability/bulk')
  @RequireStaffPermissions('properties.write')
  bulkAvailability(@Param('id') id: string, @Body() dto: BulkAvailabilityDto) {
    return this.availability.bulkSet(id, dto);
  }

  @Post('properties/:id/availability/clear')
  @RequireStaffPermissions('properties.write')
  clearAvailability(@Param('id') id: string, @Body() dto: ClearAvailabilityDto) {
    return this.availability.clear(id, dto.dates, dto.shifts);
  }
}
