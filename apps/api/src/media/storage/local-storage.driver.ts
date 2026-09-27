import { existsSync, mkdirSync, unlinkSync } from 'fs';
import { basename, join } from 'path';
import type { StorageDriver, StoredObject } from './storage-driver';

/**
 * Default driver: same local disk layout the platform has always used —
 * files land in MEDIA_ROOT and are served under MEDIA_PUBLIC_URL (nginx /media).
 */
export class LocalStorageDriver implements StorageDriver {
  readonly name = 'local';
  private readonly root: string;
  private readonly publicBase: string;

  constructor(root = process.env.MEDIA_ROOT ?? './uploads', publicBase = process.env.MEDIA_PUBLIC_URL ?? 'http://localhost/media') {
    this.root = root;
    this.publicBase = publicBase.replace(/\/$/, '');
    if (!existsSync(this.root)) mkdirSync(this.root, { recursive: true });
  }

  localPath(key: string) {
    return join(this.root, key);
  }

  publicUrl(key: string) {
    return `${this.publicBase}/${basename(key)}`;
  }

  save(key: string): StoredObject {
    return { key, url: this.publicUrl(key) };
  }

  delete(key: string) {
    const path = this.localPath(key);
    if (existsSync(path)) {
      try {
        unlinkSync(path);
      } catch {
        /* best-effort */
      }
    }
  }
}
