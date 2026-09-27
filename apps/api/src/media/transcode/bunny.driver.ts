import type { RenditionSpec, TranscodeDriver, TranscodeResult } from './transcode-driver';

/**
 * Placeholder Bunny Stream driver implementing the same contract as ffmpeg.
 * Activated by setting MEDIA_TRANSCODE_DRIVER=bunny plus the credentials below;
 * until wired it fails loudly instead of silently producing no output.
 *
 * Bunny Stream push flow (to implement when keys are provisioned):
 *  1. POST the original file to the Bunny Stream library "upload" endpoint.
 *  2. Poll the video until it reaches "Finished processing".
 *  3. Fetch the HLS/MP4 rendition URLs and map them to RenditionResult.
 *  4. Store the bunny video id so reprocessing and deletion can be synced.
 */
export class BunnyStreamTranscodeDriver implements TranscodeDriver {
  readonly name = 'bunny';

  constructor(
    private readonly config = {
      libraryId: process.env.BUNNY_STREAM_LIBRARY_ID,
      apiKey: process.env.BUNNY_STREAM_API_KEY,
      cdnHostname: process.env.BUNNY_STREAM_CDN_HOSTNAME,
    },
  ) {}

  async isAvailable() {
    return Boolean(this.config.libraryId && this.config.apiKey && this.config.cdnHostname);
  }

  async process(): Promise<TranscodeResult> {
    throw new Error(
      'Bunny Stream غير مهيأ — أضف BUNNY_STREAM_LIBRARY_ID و BUNNY_STREAM_API_KEY و BUNNY_STREAM_CDN_HOSTNAME أو استخدم MEDIA_TRANSCODE_DRIVER=ffmpeg',
    );
  }
}
