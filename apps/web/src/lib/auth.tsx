"use client";

import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";
import { api, clearTokens, getTokens, setTokens } from "./api";
import type { User } from "./types";

type AuthState = {
  user: User | null;
  ready: boolean;
  login: (phone: string, pin: string) => Promise<User>;
  logout: () => Promise<void>;
  refreshUser: () => Promise<void>;
};

const Ctx = createContext<AuthState | null>(null);

export function normalizePhone(raw: string) {
  let phone = raw.trim().replace(/[\s-]/g, "").replace(/^\+/, "");
  // أرقام عربية-هندية → لاتينية
  phone = phone.replace(/[٠-٩]/g, (d) => String("٠١٢٣٤٥٦٧٨٩".indexOf(d)));
  if (phone.startsWith("07") && phone.length === 11) phone = `964${phone.slice(1)}`;
  if (phone.startsWith("7") && phone.length === 10) phone = `964${phone}`;
  return phone;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [ready, setReady] = useState(false);

  const refreshUser = useCallback(async () => {
    if (!getTokens().refresh) {
      setUser(null);
      setReady(true);
      return;
    }
    try {
      setUser(await api<User>("/api/users/me"));
    } catch (e) {
      if ((e as { status?: number }).status === 401) setUser(null);
    } finally {
      setReady(true);
    }
  }, []);

  useEffect(() => {
    refreshUser();
    const onAuth = () => {
      if (!getTokens().refresh) setUser(null);
    };
    window.addEventListener("vibes-auth", onAuth);
    return () => window.removeEventListener("vibes-auth", onAuth);
  }, [refreshUser]);

  const login = useCallback(async (phone: string, pin: string) => {
    const res = await api<{ accessToken: string; refreshToken: string; user: User }>("/api/auth/pin", {
      method: "POST",
      body: { phone, pin },
      auth: false,
    });
    setTokens(res.accessToken, res.refreshToken);
    setUser(res.user);
    api<User>("/api/users/me").then(setUser).catch(() => undefined);
    return res.user;
  }, []);

  const logout = useCallback(async () => {
    const { refresh } = getTokens();
    try {
      await api("/api/auth/logout", { method: "POST", body: { refreshToken: refresh ?? undefined } });
    } catch {}
    clearTokens();
    setUser(null);
  }, []);

  return <Ctx.Provider value={{ user, ready, login, logout, refreshUser }}>{children}</Ctx.Provider>;
}

export function useAuth() {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("useAuth outside AuthProvider");
  return ctx;
}
