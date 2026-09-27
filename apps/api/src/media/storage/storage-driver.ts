/**
 * Storage abstraction — media bytes can live on local disk (default) or on a
 * cloud provider later without touching the pipeline code.
 */
export type StoredObject = {
  /** Server-side relative path/key used by transcoders and cleanup. */
  key: string;
  /** Public URL served to clients. */
  url: string;
};

export interface StorageDriver {
  readonly name: string;
  /** Absolute local path for the stored object (transcoders run on local disk). */
  localPath(key: string): string;
  publicUrl(key: string): string;
  delete(key: string): void;
}
