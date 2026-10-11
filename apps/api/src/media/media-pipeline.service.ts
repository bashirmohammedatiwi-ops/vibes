import { Injectable, Logger } from '@nestjs/common';
import { MediaStatus } from '@prisma/client';
import { existsSync } from 'node:fs';
import { basename } from 'node:path';
import { PrismaService } from '../prisma/prisma.service';
import { LocalStorageDriver } from './storage/local-storage.driver';
import { BunnyStreamTranscodeDriver } from './transcode/bunny.driver';
import { FfmpegTranscodeDriver } from './transcode/ffmpeg.driver';
import type { RenditionResult, RenditionSpec, TargetRatio, TranscodeDriver } from './transcode/transcode-driver';

export type { RenditionSpec, TargetRatio };

export function buildSpecs(ratio: TargetRatio = 'auto'): RenditionSpec[] {
  const crop = ratio === 'auto' ? undefined : ratio;
  return [
    { label: '1080p', maxHeight: 1080, ratio: crop },
    { label: '720p', maxHeight: 720, ratio: crop },
  ];
}

function transcodeDriver(): TranscodeDriver {
  if (process.env.MEDIA_TRANSCODE_DRIVER === 'bunny') return new BunnyStreamTranscodeDriver();
  return new FfmpegTranscodeDriver();
}

@Injectable()
export class MediaPipelineService {
  private readonly logger = new Logger(MediaPipelineService.name);

  constructor(private readonly prisma: PrismaService) {}

  async processVideo(mediaId: string, specs: RenditionSpec[]) {
    const media = await this.prisma.media.findUnique({ where: { id: mediaId } });
    if (!media) return null;

    const storage = new LocalStorageDriver();
    const input = storage.localPath(basename(media.url.split('?')[0] ?? media.url));
    if (!existsSync(input)) {
      await this.fail(mediaId, 'الملف الأصلي غير موجود');
      return null;
    }

    const engine = transcodeDriver();
    if (!(await engine.isAvailable())) {
      await this.fail(mediaId, 'معالج الفيديو غير متاح على الخادم');
      return null;
    }

    try {
      await this.prisma.media.update({
        where: { id: mediaId },
        data: { status: MediaStatus.PROCESSING, processingProgress: 15, processingError: null },
      });
      const result = await engine.process(
        input,
        (suffix) => `${mediaId}-${suffix}`,
        specs.length ? specs : buildSpecs('auto'),
      );

      // مع Bunny: روابط التشغيل تخدم من CDN — لا ملفات محلية renditions
      // نخزن GUID داخل renditions (label=bunny_guid) للحذف المتزامن لاحقاً.
      const isBunny = engine.name === 'bunny';
      const renditions: RenditionResult[] = isBunny
        ? [
            ...result.renditions,
            { label: 'bunny_guid', url: `bunny:${extractBunnyGuid(result.renditions[0]?.url)}`, width: 0, height: 0, bytes: 0 },
          ]
        : result.renditions;

      const hls = result.renditions.find((r) => r.label === 'hls');
      const primary = hls ?? result.renditions[0];

      // النوع يبقى كما اختاره الفريق عند الرفع: خانة «الريلز» → REEL
      // (يظهر في «استكشف»)، والفيديو العادي → VIDEO (صفحة المكان فقط).
      const w = result.probe.width || 0;
      const h = result.probe.height || 0;

      await this.prisma.media.update({
        where: { id: mediaId },
        data: {
          status: MediaStatus.READY,
          processingProgress: 100,
          processingError: null,
          width: w || null,
          height: h || null,
          durationSec: result.probe.durationSec || null,
          aspectRatio: result.probe.aspectRatio,
          posterUrl: result.posterUrl,
          thumbnailUrl: result.posterUrl,
          hlsUrl: primary?.url ?? null,
          renditions,
        },
      });
      return { mediaId, renditions: result.renditions };
    } catch (error) {
      const message = error instanceof Error ? error.message : 'تعذر معالجة الفيديو';
      this.logger.error(`process-video ${mediaId}: ${message}`);
      await this.fail(mediaId, message);
      throw error;
    }
  }

  private fail(mediaId: string, message: string) {
    return this.prisma.media.update({
      where: { id: mediaId },
      data: {
        status: MediaStatus.FAILED,
        processingError: message.slice(0, 500),
        processingProgress: 0,
      },
    });
  }
}

/** يستخرج GUID من رابط CDN بصيغة https://host/{guid}/playlist.m3u8 */
function extractBunnyGuid(url?: string): string {
  if (!url) return '';
  const m = url.match(/https?:\/\/[^/]+\/([0-9a-f-]{36})\//);
  return m?.[1] ?? '';
}
