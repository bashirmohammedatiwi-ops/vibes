"use client";

import { apiBase } from "./config";

const ACCESS = "vibes_access";
const REFRESH = "vibes_refresh";

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
  ) {
    super(message);
  }
}

function read(key: string) {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

export function getTokens() {
  return { access: read(ACCESS), refresh: read(REFRESH) };
}

export function setTokens(access: string, refresh: string) {
  try {
    localStorage.setItem(ACCESS, access);
    localStorage.setItem(REFRESH, refresh);
  } catch {}
  window.dispatchEvent(new Event("vibes-auth"));
}

export function clearTokens() {
  try {
    localStorage.removeItem(ACCESS);
    localStorage.removeItem(REFRESH);
  } catch {}
  window.dispatchEvent(new Event("vibes-auth"));
}

/** ثوانٍ متبقية على انتهاء توكن الدخول. */
function secondsLeft(token: string) {
  try {
    const payload = JSON.parse(atob(token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
    return payload.exp - Date.now() / 1000;
  } catch {
    return 0;
  }
}

let refreshing: Promise<string | null> | null = null;

async function refreshAccess(): Promise<string | null> {
  const { refresh } = getTokens();
  if (!refresh) return null;
  refreshing ??= (async () => {
    try {
      const res = await fetch(`${apiBase()}/api/auth/refresh`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refreshToken: refresh }),
      });
      if (res.status === 401 || res.status === 403) {
        clearTokens();
        return null;
      }
      if (!res.ok) return getTokens().access;
      const data = await res.json();
      setTokens(data.accessToken, data.refreshToken);
      return data.accessToken as string;
    } catch {
      return getTokens().access;
    } finally {
      setTimeout(() => (refreshing = null), 0);
    }
  })();
  return refreshing;
}

async function token(): Promise<string | null> {
  const { access } = getTokens();
  if (!access) return null;
  if (secondsLeft(access) < 45) return refreshAccess();
  return access;
}

function messageOf(data: unknown, fallback: string) {
  if (data && typeof data === "object" && "message" in data) {
    const m = (data as { message: unknown }).message;
    if (Array.isArray(m)) return m.join("، ");
    if (typeof m === "string") return m;
  }
  return fallback;
}

type Init = Omit<RequestInit, "body"> & { body?: unknown; auth?: boolean };

/** طلب للـ API من المتصفح — يرفق التوكن ويجدده تلقائياً. */
export async function api<T = unknown>(path: string, init: Init = {}): Promise<T> {
  const { body, auth = true, ...rest } = init;
  const isForm = typeof FormData !== "undefined" && body instanceof FormData;
  const run = async (tk: string | null) => {
    const headers = new Headers(rest.headers);
    if (!isForm && body !== undefined) headers.set("Content-Type", "application/json");
    if (auth && tk) headers.set("Authorization", `Bearer ${tk}`);
    return fetch(`${apiBase()}${path}`, {
      ...rest,
      headers,
      body: body === undefined ? undefined : isForm ? (body as FormData) : JSON.stringify(body),
    });
  };
  let res = await run(auth ? await token() : null);
  if (res.status === 401 && auth && getTokens().refresh) {
    const fresh = await refreshAccess();
    if (fresh) res = await run(fresh);
  }
  const text = await res.text();
  let data: unknown = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  if (!res.ok) {
    throw new ApiError(
      messageOf(data, res.status === 401 ? "يجب تسجيل الدخول" : res.status >= 500 ? "خطأ في الخادم — حاول لاحقاً" : "تعذر الطلب"),
      res.status,
    );
  }
  return data as T;
}

export function isLoggedIn() {
  return !!getTokens().refresh;
}
