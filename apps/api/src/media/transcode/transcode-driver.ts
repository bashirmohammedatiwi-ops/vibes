export type TargetRatio = 'auto' | '16:9' | '9:16' | '1:1' | '4:3';

export type RenditionSpec = {
  label: string;
  ratio?: string;
  maxHeight?: number;
};

export type RenditionResult = {
  label: string;
  url: string;
  width: number;
  height: number;
  bytes: number;
};

export type VideoProbe = {
  width: number;
  height: number;
  durationSec: number;
  aspectRatio: string;
};

export type TranscodeResult = {
  probe: VideoProbe;
  posterUrl: string | null;
  renditions: RenditionResult[];
};

export interface TranscodeDriver {
  readonly name: string;
  isAvailable(): Promise<boolean>;
  process(inputPath: string, outputKey: (suffix: string) => string, specs: RenditionSpec[]): Promise<TranscodeResult>;
}
