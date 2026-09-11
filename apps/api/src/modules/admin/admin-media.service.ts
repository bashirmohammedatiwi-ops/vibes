import { Injectable, NotFoundException } from '@nestjs/common';
import { MediaStatus, MediaType } from '@prisma/client';
import { diskStorage } from 'multer';
import { existsSync, mkdirSync, unlinkSync } from 'fs';
import { basename, extname, join } from 'path';
import { v4 as uuid } from 'uuid';
import { ActivityLogService } from '../../common/services/activity-log.service';
import { CacheService } from '../../common/services/cache.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { JobsService } from '../../jobs/jobs.service';
import { buildSpecs } from '../../media/media-pipeline.service';
import type { TargetRatio } from '../../media/transcode/transcode-driver';
import { PrismaService } from '../../prisma/prisma.service';
import { UpdateMediaDto } from './dto/admin-property.dto';

@Injectable()
export class AdminMediaService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly activity: ActivityLogService,
    private readonly cache: CacheService,
    private readonly jobs: JobsService,
  ) {}

  private invalidatePublicCache() {
    return this.cache.invalidatePrefix('cache:properties:');
  }

  private mediaRoot() {
    return process.env.MEDIA_ROOT ?? './uploads';
  }

  /** Removes a media-derived file (original, poster or rendition) from local disk. */
  private unlinkMediaFile(url: string) {
    const filename = basename(url);
    // Posters and renditions live in subdirectories of the media root.
    const candidates = [join(this.mediaRoot(), filename), join(this.mediaRoot(), 'posters', filename), join(this.mediaRoot(), 'renditions', filename)];
    for (const filepath of candidates) {
      if (existsSync(filepath)) {
        try {
          unlinkSync(filepath);
        } catch {
          /* ignore file delete errors */
        }
        return;
      }
    }
  }

  private publicUrl(filename: string) {
    const base = (process.env.MEDIA_PUBLIC_URL ?? 'http://localhost:3000/media').replace(/\/$/, '');
    return `${base}/${filename}`;
  }

  async uploadForProperty(
    user: AuthUser,
    propertyId: string,
    file: Express.Multer.File,
    targetRatio?: string,
  ) {
    await this.ensureProperty(propertyId);

    const count = await this.prisma.media.count({ where: { propertyId } });
    const isPrimary = count === 0;
    const isVideo = file.mimetype.startsWith('video');

    const media = await this.prisma.media.create({
      data: {
        propertyId,
        uploadedById: user.id,
        type: isVideo ? MediaType.VIDEO : MediaType.IMAGE,
        url: this.publicUrl(file.filename),
        mimeType: file.mimetype,
        fileSizeBytes: BigInt(file.size),
        sortOrder: count,
        isPrimary,
        status: isVideo ? MediaStatus.PROCESSING : MediaStatus.READY,
        processingProgress: isVideo ? 0 : null,
        altText: basename(file.originalname, file.originalname.includes('.') ? `.${file.originalname.split('.').pop()}` : ''),
      },
    });

    if (isVideo) {
      await this.jobs.enqueue('process-video', {
        mediaId: media.id,
        specs: buildSpecs((targetRatio as TargetRatio | undefined) ?? 'auto'),
      });
    }

    await this.activity.log({
      userId: user.id,
      action: 'media.upload',
      entityType: 'property',
      entityId: propertyId,
      metadata: { mediaId: media.id, video: isVideo },
    });
    await this.invalidatePublicCache();

    return media;
  }

  /** Re-runs processing (e.g. to add a cropped ratio variant) for a video. */
  async reprocess(user: AuthUser, mediaId: string, targetRatio?: string) {
    const media = await this.prisma.media.findUnique({ where: { id: mediaId } });
    if (!media) throw new NotFoundException('الملف غير موجود');
    if (media.type !== MediaType.VIDEO && media.type !== MediaType.REEL) {
      throw new NotFoundException('إعادة المعالجة متاحة للفيديو فقط');
    }

    await this.prisma.media.update({
      where: { id: mediaId },
      data: { status: MediaStatus.PROCESSING, processingProgress: 0, processingError: null },
    });
    await this.jobs.enqueue('process-video', {
      mediaId,
      specs: buildSpecs((targetRatio as TargetRatio | undefined) ?? 'auto'),
    });
    await this.activity.log({
      userId: user.id,
      action: 'media.reprocess',
      entityType: 'media',
      entityId: mediaId,
      metadata: { targetRatio: targetRatio ?? 'auto' },
    });
    return { queued: true };
  }

  async reorder(user: AuthUser, propertyId: string, mediaIds: string[]) {
    await this.ensureProperty(propertyId);
    await Promise.all(
      mediaIds.map((id, index) =>
        this.prisma.media.updateMany({
          where: { id, propertyId },
          data: { sortOrder: index },
        }),
      ),
    );
    await this.activity.log({
      userId: user.id,
      action: 'media.reorder',
      entityType: 'property',
      entityId: propertyId,
    });
    await this.invalidatePublicCache();
    return this.listByProperty(propertyId);
  }

  async setPrimary(user: AuthUser, propertyId: string, mediaId: string) {
    await this.ensureProperty(propertyId);
    await this.prisma.media.updateMany({ where: { propertyId }, data: { isPrimary: false } });
    await this.prisma.media.update({ where: { id: mediaId }, data: { isPrimary: true } });
    await this.activity.log({
      userId: user.id,
      action: 'media.set_primary',
      entityType: 'property',
      entityId: propertyId,
      metadata: { mediaId },
    });
    await this.invalidatePublicCache();
    return this.listByProperty(propertyId);
  }

  async update(user: AuthUser, mediaId: string, dto: UpdateMediaDto) {
    const media = await this.prisma.media.findUnique({ where: { id: mediaId } });
    if (!media) throw new NotFoundException();
    const updated = await this.prisma.media.update({
      where: { id: mediaId },
      data: { caption: dto.caption, altText: dto.altText },
    });
    await this.invalidatePublicCache();
    return updated;
  }

  async remove(user: AuthUser, mediaId: string) {
    const media = await this.prisma.media.findUnique({ where: { id: mediaId } });
    if (!media) throw new NotFoundException();

    this.unlinkMediaFile(media.url);
    if (media.posterUrl) this.unlinkMediaFile(media.posterUrl);
    const renditions = Array.isArray(media.renditions)
      ? (media.renditions as Array<{ url?: string }>)
      : [];
    for (const rendition of renditions) {
      if (rendition?.url) this.unlinkMediaFile(rendition.url);
    }

    await this.prisma.media.delete({ where: { id: mediaId } });

    if (media.isPrimary && media.propertyId) {
      const next = await this.prisma.media.findFirst({
        where: { propertyId: media.propertyId },
        orderBy: { sortOrder: 'asc' },
      });
      if (next) {
        await this.prisma.media.update({ where: { id: next.id }, data: { isPrimary: true } });
      }
    }

    await this.activity.log({
      userId: user.id,
      action: 'media.delete',
      entityType: 'media',
      entityId: mediaId,
    });
    await this.invalidatePublicCache();

    return { deleted: true };
  }

  listByProperty(propertyId: string) {
    return this.prisma.media.findMany({
      where: { propertyId },
      orderBy: { sortOrder: 'asc' },
    });
  }

  private ensureProperty(propertyId: string) {
    return this.prisma.property.findUnique({ where: { id: propertyId } }).then((p) => {
      if (!p) throw new NotFoundException('المكان غير موجود');
      return p;
    });
  }

  saveUploadedFile(file: Express.Multer.File) {
    return this.publicUrl(file.filename);
  }
}

export function proofStorageOptions() {
  return diskStorage({
    destination: (_req: unknown, _file: unknown, cb: (e: Error | null, d: string) => void) => {
      const root = join(process.env.MEDIA_ROOT ?? './uploads', 'proofs');
      if (!existsSync(root)) mkdirSync(root, { recursive: true });
      cb(null, root);
    },
    filename: (_req: unknown, file: Express.Multer.File, cb: (e: Error | null, n: string) => void) => {
      cb(null, `${uuid()}${extname(file.originalname)}`);
    },
  });
}

export function mediaStorageOptions() {
  return diskStorage({
    destination: (_req: unknown, _file: unknown, cb: (e: Error | null, d: string) => void) => {
      const root = process.env.MEDIA_ROOT ?? './uploads';
      if (!existsSync(root)) mkdirSync(root, { recursive: true });
      cb(null, root);
    },
    filename: (_req: unknown, file: Express.Multer.File, cb: (e: Error | null, n: string) => void) => {
      cb(null, `${uuid()}${extname(file.originalname)}`);
    },
  });
}
