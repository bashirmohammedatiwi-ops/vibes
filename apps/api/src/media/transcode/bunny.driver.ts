import { createReadStream, statSync } from 'node:fs';
import { basename } from 'node:path';
import type { RenditionResult, RenditionSpec, TranscodeDriver, TranscodeResult, VideoProbe } from './transcode-driver';

/**
 * Bunny Stream driver — نفس عقد ffmpeg لكن المعالجة تحدث في سحابة Bunny:
 *   1. إنشاء فيديو (CreateVideo) داخل مكتبة Stream.
 *   2. رفع الملف الأصلي (TUS-like upload عبر PUT …/videos/{id}/source).
 *   3. استطلاع الحالة حتى "Finished processing" (بحد أقصى دقيقتين لكل مقطع 8-60 ثانية).
 *   4. جلب أبعاد/مدة الفيديو وربط روابط HLS/MP4 + الصورة المصغرة.
 *
 * التفعيل: MEDIA_TRANSCODE_DRIVER=bunny + المفاتيح في .env
 *   BUNNY_STREAM_LIBRARY_ID / BUNNY_STREAM_API_KEY / BUNNY_STREAM_CDN_HOSTNAME
 * لا حاجة لأي مكتبة HTTP — fetch الأصلية في Node 20.
 */

const BUNNY_API = 'https://video.bunnycdn.com';
const POLL_INTERVAL_MS = 3_000;
const POLL_TIMEOUT_MS = 10 * 60_000; // فيديو ريلز قصير يكفيه دقيقتان؛ حد أقصى عام 10 د

interface BunnyVideo {
  guid: string;
  title: string;
  status: number; // 0=Created, 1=Uploaded, 2=Processing, 3=Transcoding, 4=Finished, 5=Error, 6=UploadFailed
  length: number; // seconds
  width: number;
  height: number;
  availableResolutions: string;
  previewOffset: number;
}

export class BunnyStreamTranscodeDriver implements TranscodeDriver {
  readonly name = 'bunny';

  constructor(
    private readonly config = {
      libraryId: process.env.BUNNY_STREAM_LIBRARY_ID,
      apiKey: process.env.BUNNY_STREAM_API_KEY,
      cdnHostname: (process.env.BUNNY_STREAM_CDN_HOSTNAME ?? process.env.BUNNY_CDN_HOSTNAME ?? '').replace(/^https?:\/\//, '').replace(/\/$/, ''),
    },
  ) {}

  async isAvailable() {
    return Boolean(this.config.libraryId && this.config.apiKey && this.config.cdnHostname);
  }

  private headers(json = true): Record<string, string> {
    const h: Record<string, string> = { AccessKey: this.config.apiKey! };
    if (json) h['Content-Type'] = 'application/json';
    return h;
  }

  private base() {
    return `${BUNNY_API}/library/${this.config.libraryId}`;
  }

  private cdnUrl(guid: string, path = '') {
    return `https://${this.config.cdnHostname}/${guid}/${path}`;
  }

  async process(
    inputPath: string,
    outputKey: (suffix: string) => string,
    _specs: RenditionSpec[],
  ): Promise<TranscodeResult> {
    // 1) إنشاء كائن فيديو فارغ في المكتبة
    const title = outputKey('reel');
    const createRes = await fetch(`${this.base()}/videos`, {
      method: 'POST',
      headers: this.headers(),
      body: JSON.stringify({ title }),
    });
    if (!createRes.ok) {
      throw new Error(`Bunny CreateVideo فشل (${createRes.status}): ${await safeText(createRes)}`);
    }
    const { guid } = (await createRes.json()) as { guid: string };

    // 2) رفع الملف الأصلي — نقطة النهاية الموثقة:
    //    PUT /library/{lib}/videos/{guid} بجسم ثنائي octet-stream.
    //    (المسار القديم /videos/{guid}/source يرجع 404 على هذه المكتبة.)
    //    البث من الملف مباشرة (duplex) — لا تحميل الفيديو كاملاً في الذاكرة،
    //    فيديو 200MB يمر بثابت ذاكرة بغض النظر عن حجمه.
    const { createReadStream } = await import('node:fs');
    const size = statSync(inputPath).size;
    // duplex: 'half' مطلوب لبث الجسم في Node fetch — أنواع @types/node
    // القديمة لا تعرفه، لذا نمرره كامتداد.
    const init = {
      method: 'PUT',
      headers: {
        ...this.headers(false),
        'Content-Type': 'application/octet-stream',
        Accept: 'application/json',
        'Content-Length': String(size),
      },
      body: createReadStream(inputPath),
      duplex: 'half',
    } as unknown as RequestInit;
    const uploadRes = await fetch(`${this.base()}/videos/${guid}`, init);
    if (!uploadRes.ok) {
      // نظّف الفيديو الفارغ حتى لا تتراكم كائنات ميتة في المكتبة
      await this.deleteVideo(guid).catch(() => {});
      throw new Error(`Bunny Upload فشل (${uploadRes.status}): ${await safeText(uploadRes)}`);
    }

    // 3) استطلاع حتى اكتمال المعالجة
    const video = await this.pollUntilFinished(guid);

    // 4) بناء النتيجة بنفس عقد ffmpeg
    const probe: VideoProbe = {
      width: video.width || 0,
      height: video.height || 0,
      durationSec: video.length || 0,
      aspectRatio: ratioLabel(video.width, video.height),
    };

    // Bunny يولّد تلقائياً: HLS متعدد الجودات + MP4 720p/360p + صورة مصغرة
    const renditions: RenditionResult[] = [
      { label: 'hls', url: `${this.cdnUrl(guid, 'playlist.m3u8')}`, width: 0, height: 0, bytes: 0 },
      { label: 'mp4_0_720', url: `${this.cdnUrl(guid, 'play_720p.mp4')}`, width: 0, height: 720, bytes: 0 },
      { label: 'mp4_0_360', url: `${this.cdnUrl(guid, 'play_360p.mp4')}`, width: 0, height: 360, bytes: 0 },
    ];
    const posterUrl = `${this.cdnUrl(guid, `preview.webp`)}`;

    return { probe, posterUrl, renditions };
  }

  /** حذف فيديو من Bunny — تُستدعى عند حذف الوسائط من التطبيق. */
  async deleteVideo(guid: string) {
    const res = await fetch(`${this.base()}/videos/${guid}`, {
      method: 'DELETE',
      headers: this.headers(false),
    });
    if (!res.ok && res.status !== 404) {
      throw new Error(`Bunny Delete فشل (${res.status})`);
    }
    return true;
  }

  private async pollUntilFinished(guid: string): Promise<BunnyVideo> {
    const deadline = Date.now() + POLL_TIMEOUT_MS;
    while (Date.now() < deadline) {
      const res = await fetch(`${this.base()}/videos/${guid}`, {
        headers: this.headers(false),
      });
      if (!res.ok) throw new Error(`Bunny GetVideo فشل (${res.status})`);
      const v = (await res.json()) as BunnyVideo;
      if (v.status === 4) return v; // Finished
      if (v.status === 5 || v.status === 6) {
        throw new Error(`Bunny معالجة الفيديو فشلت (status=${v.status})`);
      }
      await sleep(POLL_INTERVAL_MS);
    }
    throw new Error('Bunny انتهت مهلة انتظار المعالجة');
  }
}

function ratioLabel(w: number, h: number): string {
  if (!w || !h) return 'auto';
  const value = w / h;
  const known: Array<[number, string]> = [
    [16 / 9, '16:9'],
    [9 / 16, '9:16'],
    [1, '1:1'],
    [4 / 3, '4:3'],
    [3 / 4, '3:4'],
  ];
  for (const [target, label] of known) {
    if (Math.abs(value - target) / target < 0.035) return label;
  }
  return 'auto';
}

async function safeText(res: Response): Promise<string> {
  try {
    return (await res.text()).slice(0, 200);
  } catch {
    return '<no body>';
  }
}

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}
