const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3000";
const TOKEN_KEY = "vibes_admin_token";
const REFRESH_KEY = "vibes_admin_refresh";
const ROLE_KEY = "vibes_admin_role";
const COOKIE_MAX_AGE = 60 * 60 * 24 * 30;

function setAuthCookie(name: string, value: string) {
  if (typeof document === "undefined") return;
  document.cookie = `${name}=${encodeURIComponent(value)}; path=/; max-age=${COOKIE_MAX_AGE}; SameSite=Lax`;
}

function clearAuthCookie(name: string) {
  if (typeof document === "undefined") return;
  document.cookie = `${name}=; path=/; max-age=0; SameSite=Lax`;
}

export function getToken() {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(TOKEN_KEY);
}

/** يزامن localStorage مع cookies لـ middleware (للجلسات القديمة) */
export function syncAuthCookies() {
  if (typeof window === "undefined") return;
  const token = localStorage.getItem(TOKEN_KEY);
  const role = localStorage.getItem(ROLE_KEY);
  if (token) setAuthCookie(TOKEN_KEY, token);
  if (role) setAuthCookie(ROLE_KEY, role);
}

export function getRefreshToken() {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(REFRESH_KEY);
}

export function getUserRole() {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(ROLE_KEY);
}

export function isAdmin() {
  return getUserRole() === "ADMIN";
}

export function setSession(accessToken: string, refreshToken: string, role: string) {
  localStorage.setItem(TOKEN_KEY, accessToken);
  localStorage.setItem(REFRESH_KEY, refreshToken);
  localStorage.setItem(ROLE_KEY, role);
  setAuthCookie(TOKEN_KEY, accessToken);
  setAuthCookie(ROLE_KEY, role);
}

export function buildQuery(params: Record<string, string | number | boolean | undefined | null>) {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null && value !== "") {
      search.set(key, String(value));
    }
  }
  const qs = search.toString();
  return qs ? `?${qs}` : "";
}

let refreshPromise: Promise<string | null> | null = null;

async function refreshAccessToken(): Promise<string | null> {
  const refresh = getRefreshToken();
  if (!refresh) return null;

  if (!refreshPromise) {
    refreshPromise = fetch(`${API_URL}/api/auth/refresh`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refreshToken: refresh }),
    })
      .then(async (res) => {
        if (!res.ok) return null;
        const data = (await res.json()) as { accessToken: string; refreshToken?: string };
        localStorage.setItem(TOKEN_KEY, data.accessToken);
        if (data.refreshToken) localStorage.setItem(REFRESH_KEY, data.refreshToken);
        return data.accessToken;
      })
      .catch(() => null)
      .finally(() => {
        refreshPromise = null;
      });
  }

  return refreshPromise;
}

export async function api<T>(path: string, init: RequestInit = {}, retried = false): Promise<T> {
  const token = getToken();
  const headers = new Headers(init.headers);
  const isFormData = init.body instanceof FormData;
  if (!isFormData) headers.set("Content-Type", "application/json");
  if (token) headers.set("Authorization", `Bearer ${token}`);

  const response = await fetch(`${API_URL}${path}`, { ...init, headers });

  if (response.status === 401 && !retried && getRefreshToken()) {
    const newToken = await refreshAccessToken();
    if (newToken) return api<T>(path, init, true);
  }

  if (response.status === 401 && typeof window !== "undefined" && !path.includes("/auth/")) {
    clearToken();
    window.location.replace("/login");
  }

  if (!response.ok) {
    let message = response.statusText;
    try {
      const body = await response.json();
      message = body.message ?? (Array.isArray(body.message) ? body.message.join(", ") : message);
    } catch {
      const text = await response.text();
      if (text) message = text;
    }
    throw new Error(message);
  }
  if (response.status === 204) return undefined as T;
  return response.json() as Promise<T>;
}

export async function uploadFiles<T>(path: string, fieldName: string, files: File[]): Promise<T> {
  const token = getToken();
  const form = new FormData();
  for (const file of files) form.append(fieldName, file);

  const headers = new Headers();
  if (token) headers.set("Authorization", `Bearer ${token}`);

  const response = await fetch(`${API_URL}${path}`, { method: "POST", headers, body: form });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(text || response.statusText);
  }
  return response.json() as Promise<T>;
}

/**
 * XHR-based multipart upload with per-batch progress (fetch cannot report
 * upload progress). Extra fields are appended before the files.
 */
export function uploadFilesWithProgress<T>(
  path: string,
  fieldName: string,
  files: File[],
  options: {
    fields?: Record<string, string | undefined>;
    onProgress?: (percent: number) => void;
  } = {},
): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const token = getToken();
    const form = new FormData();
    for (const [key, value] of Object.entries(options.fields ?? {})) {
      if (value !== undefined && value !== "") form.append(key, value);
    }
    for (const file of files) form.append(fieldName, file);

    const xhr = new XMLHttpRequest();
    xhr.open("POST", `${API_URL}${path}`);
    if (token) xhr.setRequestHeader("Authorization", `Bearer ${token}`);
    xhr.upload.onprogress = (event) => {
      if (event.lengthComputable && options.onProgress) {
        options.onProgress(Math.round((event.loaded / event.total) * 100));
      }
    };
    xhr.onerror = () => reject(new Error("فشل الاتصال أثناء الرفع"));
    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        try {
          resolve(JSON.parse(xhr.responseText) as T);
        } catch {
          resolve(undefined as T);
        }
      } else {
        let message = xhr.statusText;
        try {
          const body = JSON.parse(xhr.responseText) as { message?: string | string[] };
          if (body.message) message = Array.isArray(body.message) ? body.message.join(", ") : body.message;
        } catch {
          /* keep statusText */
        }
        reject(new Error(message || "فشل الرفع"));
      }
    };
    xhr.send(form);
  });
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(REFRESH_KEY);
  localStorage.removeItem(ROLE_KEY);
  clearAuthCookie(TOKEN_KEY);
  clearAuthCookie(ROLE_KEY);
}

/** Rejects on failure so callers can surface a toast instead of failing silently. */
export async function downloadCsv(path: string, filename = "export.csv") {
  const token = getToken();
  const headers = new Headers();
  if (token) headers.set("Authorization", `Bearer ${token}`);

  const response = await fetch(`${API_URL}${path}`, { headers });
  if (!response.ok) {
    throw new Error(response.status === 403 ? "لا تملك صلاحية التصدير" : "فشل التصدير");
  }

  const blob = await response.blob();
  if (!blob.size) throw new Error("لا توجد بيانات للتصدير");

  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}

export async function openPrintHtml(path: string) {
  const token = getToken();
  const headers = new Headers();
  if (token) headers.set("Authorization", `Bearer ${token}`);

  const response = await fetch(`${API_URL}${path}`, { headers });
  if (!response.ok) throw new Error("تعذر فتح الفاتورة للطباعة");
  const html = await response.text();
  const popup = window.open("", "_blank");
  if (!popup) throw new Error("اسمح بالنوافذ المنبثقة لطباعة الفاتورة");
  popup.document.write(html);
  popup.document.close();
  popup.focus();
  popup.print();
}
