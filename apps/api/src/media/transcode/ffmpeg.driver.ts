import { execFile } from 'child_process';
import { existsSync, mkdirSync, statSync } from 'fs';
import { dirname, join } from 'path';
import { promisify } from 'util';
import type { RenditionResult, RenditionSpec, TranscodeDriver, TranscodeResult, VideoProbe } from './transcode-driver';

const exec = promisify(execFile);

const KNOWN_RATIOS: Array<[number, string]> = [
  [16 / 9, '16:9'],
  [9 / 16, '9:16'],
  [1, '1:1'],
  [4 / 3, '4:3'],
  [3 / 4, '3:4'],
];

function gcd(a: number, b: number): number {
  return b === 0 ? a : gcd(b, a % b);
}

export function detectAspectRatio(width: number, height: number): string {
  if (!width || !height) return 'auto';
  const divisor = gcd(width, height);
  const rw = width / divisor;
  const rh = height / divisor;
  const value = width / height;
  for (const [target, label] of KNOWN_RATIOS) {
    if (Math.abs(value - target) / target < 0.035) return label;
  }
  return `${rw}:${rh}`;
}

function ratioNumber(ratio: string): number | null {
  const [w, h] = ratio.split(':').map(Number);
  if (!w || !h) return null;
  return w / h;
}

/** Center-crop filter chain to force a target ratio on the source. */
export function cropFilter(ratio: string): string | null {
  const value = ratioNumber(ratio);
  if (!value) return null;
  return value >= 1
    ? `crop='min(iw,ih*${value})':'min(ih,iw/${value})'`
    : `crop='min(iw/(${1 / value}),iw)':'min(ih,iw*${1 / value})'`;
}

function scaleFor(spec: RenditionSpec): string {
  // Width stays even for h264 chroma subsampling; height auto-preserves the ratio.
  return `scale=-2:'min(ih,${spec.maxHeight ?? 1080})':force_original_aspect_ratio=decrease`;
}

function run(args: string[]) {
  return exec('ffmpeg', args, { maxBuffer: 1024 * 1024 * 32, timeout: 15 * 60_000 });
}

/**
 * Local processing with ffmpeg/ffprobe: probe metadata, poster frame,
 * quality renditions and optional center-cropped ratio variants.
 */
export class FfmpegTranscodeDriver implements TranscodeDriver {
  readonly name = 'ffmpeg';
  private readonly postersDir: string;
  private readonly renditionsDir: string;

  constructor(
    mediaRoot = process.env.MEDIA_ROOT ?? './uploads',
    private readonly publicBase = (process.env.MEDIA_PUBLIC_URL ?? 'http://localhost/media').replace(/\/$/, ''),
  ) {
    this.postersDir = join(mediaRoot, 'posters');
    this.renditionsDir = join(mediaRoot, 'renditions');
  }

  async isAvailable() {
    try {
      await exec('ffmpeg', ['-version'], { timeout: 10_000 });
      return true;
    } catch {
      return false;
    }
  }

  async probe(inputPath: string): Promise<VideoProbe> {
    const { stdout } = await exec(
      'ffprobe',
      ['-v', 'error', '-selectStreams', 'v:0', '-showEntries', 'stream=width,height,duration', '-of', 'json', inputPath],
      { timeout: 60_000 },
    );
    const parsed = JSON.parse(stdout) as { streams?: Array<{ width?: number; height?: number; duration?: string }> };
    const stream = parsed.streams?.[0];
    if (!stream?.width || !stream?.height) {
      throw new Error('تعذر قراءة أبعاد الفيديو');
    }
    let durationSec = Number(stream.duration ?? 0);
    if (!durationSec) {
      // Some containers report duration on the format level instead of the stream.
      const format = await exec(
        'ffprobe',
        ['-v', 'error', '-showEntries', 'format=duration', '-of', 'json', inputPath],
        { timeout: 60_000 },
      );
      durationSec = Number((JSON.parse(format.stdout) as { format?: { duration?: string } }).format?.duration ?? 0);
    }
    return {
      width: stream.width,
      height: stream.height,
      durationSec: Math.round(durationSec),
      aspectRatio: detectAspectRatio(stream.width, stream.height),
    };
  }

  private async poster(inputPath: string, posterPath: string): Promise<string | null> {
    if (!existsSync(dirname(posterPath))) mkdirSync(dirname(posterPath), { recursive: true });
    try {
      await run([
        '-y', '-ss', '1', '-i', inputPath, '-frames:v', '1',
        '-vf', 'scale=-2:min(ih\\,720)', '-q:v', '4', posterPath,
      ]);
      return posterPath;
    } catch {
      try {
        await run(['-y', '-i', inputPath, '-frames:v', '1', posterPath]);
        return posterPath;
      } catch {
        return null;
      }
    }
  }

  private async rendition(inputPath: string, spec: RenditionSpec, outPath: string): Promise<RenditionResult> {
    if (!existsSync(dirname(outPath))) mkdirSync(dirname(outPath), { recursive: true });
    const filters = [spec.ratio ? cropFilter(spec.ratio) : null, scaleFor(spec)].filter(Boolean).join(',');
    await run([
      '-y', '-i', inputPath,
      '-vf', filters,
      '-c:v', 'libx264', '-preset', 'fast', '-crf', '23',
      '-c:a', 'aac', '-b:a', '128k',
      '-movflags', '+faststart',
      outPath,
    ]);
    const bytes = statSync(outPath).size;
    const probe = await this.probe(outPath);
    return {
      label: spec.label,
      url: `${this.publicBase}/renditions/${outPath.split('/').pop()}`,
      width: probe.width,
      height: probe.height,
      bytes,
    };
  }

  async process(inputPath: string, outputKey: (suffix: string) => string, specs: RenditionSpec[]): Promise<TranscodeResult> {
    const probe = await this.probe(inputPath);
    const posterPath = join(this.postersDir, outputKey('poster.jpg'));
    const poster = await this.poster(inputPath, posterPath);
    const renditions: RenditionResult[] = [];
    for (const spec of specs) {
      const outPath = join(this.renditionsDir, outputKey(`${spec.label.replace(/[^a-z0-9]/gi, '')}.mp4`));
      renditions.push(await this.rendition(inputPath, spec, outPath));
    }
    return {
      probe,
      posterUrl: poster ? `${this.publicBase}/posters/${posterPath.split('/').pop()}` : null,
      renditions,
    };
  }
}
