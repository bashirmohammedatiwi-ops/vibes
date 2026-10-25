"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Bell, CalendarDays, ChevronLeft, Headphones, Heart, LogOut, MessageCircle, Phone, Sparkles, Tag } from "lucide-react";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import type { Settings } from "@/lib/types";
import { RequireAuth } from "@/components/require-auth";

export default function AccountPage() {
  return (
    <RequireAuth title="سجّل الدخول إلى حسابك">
      <Account />
    </RequireAuth>
  );
}

function Account() {
  const { user, logout, refreshUser } = useAuth();
  const router = useRouter();
  const [name, setName] = useState(user?.name ?? "");
  const [saved, setSaved] = useState(false);
  const [settings, setSettings] = useState<Settings | null>(null);

  useEffect(() => {
    api<Settings>("/api/settings", { auth: false }).then(setSettings).catch(() => undefined);
  }, []);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    await api("/api/users/me", { method: "PATCH", body: { name: name.trim() } });
    await refreshUser();
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  }

  const links = [
    { href: "/bookings", icon: CalendarDays, label: "حجوزاتي" },
    { href: "/favorites", icon: Heart, label: "المفضلة" },
    { href: "/messages", icon: MessageCircle, label: "الرسائل" },
    { href: "/notifications", icon: Bell, label: "الإشعارات" },
    { href: "/offers", icon: Tag, label: "العروض والكوبونات" },
    { href: "/nadeem", icon: Sparkles, label: "نديم — خطّط مناسبتك" },
  ];

  return (
    <div className="container-x max-w-3xl py-8">
      <div className="hero-grain flex items-center gap-4 rounded-[2rem] p-6 text-white">
        <span className="flex h-16 w-16 items-center justify-center rounded-2xl bg-white/10 text-2xl font-black text-brass-light">
          {(user?.name || "V").charAt(0)}
        </span>
        <div>
          <div className="text-xl font-black">{user?.name || "ضيف VIBES"}</div>
          <div className="num mt-0.5 text-sm text-white/70" dir="ltr">
            +{user?.phone}
          </div>
        </div>
      </div>

      <form onSubmit={save} className="card mt-4 flex flex-wrap items-end gap-3 p-5">
        <label className="min-w-0 flex-1">
          <span className="mb-1.5 block text-sm font-bold">الاسم</span>
          <input className="field" value={name} onChange={(e) => setName(e.target.value)} placeholder="اسمك" />
        </label>
        <button className="btn btn-primary h-12 px-6">{saved ? "تم الحفظ ✓" : "حفظ"}</button>
      </form>

      <div className="card mt-4 divide-y divide-line overflow-hidden">
        {links.map((l) => (
          <Link key={l.href} href={l.href} className="flex items-center gap-3 px-5 py-4 font-bold hover:bg-cream">
            <l.icon className="h-5 w-5 text-brass-deep" />
            <span className="flex-1">{l.label}</span>
            <ChevronLeft className="h-4 w-4 text-ink-3" />
          </Link>
        ))}
        <button
          onClick={async () => {
            const c = await api<{ id: string }>("/api/conversations/support", { method: "POST" });
            router.push(`/messages/${c.id}`);
          }}
          className="flex w-full items-center gap-3 px-5 py-4 text-right font-bold hover:bg-cream"
        >
          <Headphones className="h-5 w-5 text-brass-deep" />
          <span className="flex-1">الدعم والمساعدة</span>
          <ChevronLeft className="h-4 w-4 text-ink-3" />
        </button>
        {settings?.supportPhone && (
          <a href={`tel:+${settings.supportPhone.replace(/\D/g, "")}`} className="flex items-center gap-3 px-5 py-4 font-bold hover:bg-cream">
            <Phone className="h-5 w-5 text-brass-deep" />
            <span className="flex-1">اتصل بنا</span>
            <span className="num text-sm text-ink-3" dir="ltr">
              +{settings.supportPhone.replace(/\D/g, "")}
            </span>
          </a>
        )}
      </div>

      {settings?.cancellationPolicy && (
        <details className="card mt-4 p-5">
          <summary className="cursor-pointer font-black">سياسة الإلغاء</summary>
          <p className="mt-3 whitespace-pre-line text-sm leading-7 text-ink-2">{settings.cancellationPolicy}</p>
        </details>
      )}

      <button
        onClick={async () => {
          await logout();
          router.push("/");
        }}
        className="btn btn-ghost mt-4 h-12 w-full !text-danger"
      >
        <LogOut className="h-4 w-4" /> تسجيل الخروج
      </button>
      <div className="mt-6 flex justify-center gap-4 text-xs font-bold text-ink-3">
        <Link href="/privacy" className="hover:text-ink">سياسة الخصوصية</Link>
        <Link href="/terms" className="hover:text-ink">شروط الاستخدام</Link>
        <Link href="/delete-account" className="hover:text-danger">حذف الحساب</Link>
      </div>
    </div>
  );
}
