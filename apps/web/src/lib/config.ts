/** عنوان الـ API — في المتصفح: نفس الموقع (الـ API تحت /api). على السيرفر
 *  (SSR داخل docker): API_INTERNAL_URL مثل http://api:3000. */
export function apiBase(): string {
  if (typeof window !== "undefined") {
    const { hostname, origin } = window.location;
    if (hostname === "localhost" || hostname === "127.0.0.1") {
      return process.env.NEXT_PUBLIC_API_URL || "https://vibesiraq.com";
    }
    return origin;
  }
  return process.env.API_INTERNAL_URL || process.env.NEXT_PUBLIC_API_URL || "https://vibesiraq.com";
}

export const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL || "https://vibesiraq.com";
