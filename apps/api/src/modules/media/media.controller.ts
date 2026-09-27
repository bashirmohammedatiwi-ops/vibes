import {
  BadRequestException,
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { MediaStatus, MediaType } from '@prisma/client';
import { basename } from 'node:path';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { JobsService } from '../../jobs/jobs.service';
import { buildSpecs } from '../../media/media-pipeline.service';
import { mediaStorageOptions } from '../admin/admin-media.service';
import { PrismaService } from '../../prisma/prisma.service';

@ApiTags('media')
@ApiBearerAuth()
@Controller('media')
export class MediaController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jobs: JobsService,
  ) {}

  @Get(':id')
  async findOne(@Param('id') id: string) {
    const media = await this.prisma.media.findUnique({ where: { id } });
    if (!media) throw new NotFoundException('الملف غير موجود');
    return media;
  }

  @Post('upload')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: mediaStorageOptions(),
      limits: {
        fileSize:
          Math.max(Number(process.env.MAX_UPLOAD_MB ?? 20), Number(process.env.MEDIA_VIDEO_MAX_MB ?? 200)) *
          1024 *
          1024,
      },
    }),
  )
  async upload(
    @CurrentUser() user: AuthUser,
    @UploadedFile() file: Express.Multer.File,
    @Body('propertyId') propertyId?: string,
  ) {
    if (!file) throw new BadRequestException('الملف مطلوب');

    const isVideo = file.mimetype.startsWith('video');
    const base = (process.env.MEDIA_PUBLIC_URL ?? 'http://localhost:3000/media').replace(/\/$/, '');
    const media = await this.prisma.media.create({
      data: {
        propertyId: propertyId || null,
        uploadedById: user.id,
        type: isVideo ? MediaType.VIDEO : MediaType.IMAGE,
        url: `${base}/${file.filename}`,
        mimeType: file.mimetype,
        fileSizeBytes: BigInt(file.size),
        status: isVideo ? MediaStatus.PROCESSING : MediaStatus.READY,
        processingProgress: isVideo ? 0 : null,
        altText: basename(file.originalname, file.originalname.includes('.') ? `.${file.originalname.split('.').pop()}` : ''),
      },
    });

    if (isVideo) {
      await this.jobs.enqueue('process-video', { mediaId: media.id, specs: buildSpecs('auto') });
    }

    return media;
  }
}
