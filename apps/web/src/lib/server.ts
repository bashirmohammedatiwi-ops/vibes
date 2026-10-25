import "server-only";
import { apiBase } from "./config";

/** جلب من الـ API على السيرفر (SSR) مع تخزين مؤقت قصير. */
export async function serverGet<T>(path: string, revalidate = 60): Promise<T | null> {
  try {
    const res = await fetch(`${apiBase()}${path}`, { next: { revalidate } });
    if (!res.ok) return null;
    return (await res.json()) as T;
  } catch {
    return null;
  }
}
