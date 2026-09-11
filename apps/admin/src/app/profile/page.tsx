"use client";

import { useEffect, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { DetailCard } from "@/components/ui/detail-card";
import { Input, Label } from "@/components/ui/input";
import { LoadingBlock, PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { useToast } from "@/components/ui/toast";
import { USER_ROLE_LABELS } from "@/lib/constants";
import { api, clearToken, getUserRole } from "@/lib/api";
import { useRouter } from "next/navigation";

type Profile = {
  id: string;
  phone: string;
  name?: string | null;
  role: string;
  isActive: boolean;
  createdAt: string;
};

export default function ProfilePage() {
  const router = useRouter();
  const { toast } = useToast();
  const [profile, setProfile] = useState<Profile | null>(null);
  const [name, setName] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    api<Profile>("/api/users/me")
      .then((data) => {
        setProfile(data);
        setName(data.name ?? "");
      })
      .catch(() => undefined)
      .finally(() => setLoading(false));
  }, []);

  async function save() {
    setSaving(true);
    try {
      const updated = await api<Profile>("/api/users/me", {
        method: "PATCH",
        body: JSON.stringify({ name: name.trim() || undefined }),
      });
      setProfile(updated);
      toast("تم حفظ الملف");
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحفظ", "error");
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <LoadingBlock />;

  return (
    <PageShell>
      <PageHeader
        title="ملفي"
        description="إعدادات حسابك في لوحة التحكم"
        eyebrow="VIBES Admin"
      />

      <DetailCard title="معلومات الحساب">
        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <Label>الاسم المعروض</Label>
            <div className="mt-1 flex gap-2">
              <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="اسمك في اللوحة" />
              <Button onClick={save} disabled={saving}>{saving ? "..." : "حفظ"}</Button>
            </div>
          </div>
          <div>
            <Label>الهاتف</Label>
            <Input dir="ltr" value={profile?.phone ?? ""} readOnly className="mt-1 bg-surface" />
          </div>
          <div>
            <Label>الدور</Label>
            <div className="mt-2">
              <Badge>{USER_ROLE_LABELS[getUserRole() ?? profile?.role ?? ""] ?? profile?.role}</Badge>
            </div>
          </div>
          <div>
            <Label>تاريخ الانضمام</Label>
            <div className="mt-2 text-sm text-muted">
              {profile?.createdAt ? new Date(profile.createdAt).toLocaleDateString("ar-IQ") : "—"}
            </div>
          </div>
        </div>
      </DetailCard>

      <DetailCard title="الجلسة">
        <p className="mb-4 text-sm text-muted">تسجيل الخروج ينهي جلسة لوحة التحكم على هذا الجهاز.</p>
        <Button
          variant="danger"
          onClick={() => {
            clearToken();
            router.replace("/login");
          }}
        >
          تسجيل الخروج
        </Button>
      </DetailCard>
    </PageShell>
  );
}
