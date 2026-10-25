"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { SkeletonList } from "@/components/ui/skeleton";
import { useToast } from "@/components/ui/toast";
import { Section, Switch } from "@/components/nadeem/fields";
import { api } from "@/lib/api";

type Item = { key: string; enabled: boolean };
type Layout = { header: Item[]; body: Item[]; quickLinks: Record<string, boolean> };
type CatalogEntry = { key: string; label: string; hint?: string };
type Payload = {
  layout: Layout;
  catalog: { header: CatalogEntry[]; body: CatalogEntry[]; quickLinks: CatalogEntry[] };
  updatedAt: string | null;
};

export default function HomeLayoutPage() {
  const { toast } = useToast();
  const [payload, setPayload] = useState<Payload | null>(null);
  const [draft, setDraft] = useState<Layout | null>(null);
  const [saving, setSaving] = useState(false);
  const [confirmReset, setConfirmReset] = useState(false);

  useEffect(() => {
    api<Payload>("/api/admin/home-layout")
      .then((p) => {
        setPayload(p);
        setDraft(structuredClone(p.layout));
      })
      .catch((e) => toast(e instanceof Error ? e.message : "تعذر التحميل", "error"));
  }, []);

  const dirty = useMemo(() => !!payload && !!draft && JSON.stringify(payload.layout) !== JSON.stringify(draft), [payload, draft]);

  async function save() {
    if (!draft) return;
    setSaving(true);
    try {
      const p = await api<Payload>("/api/admin/home-layout", { method: "PUT", body: JSON.stringify(draft) });
      setPayload(p);
      setDraft(structuredClone(p.layout));
      toast("حُفظت الصفحة الرئيسية — تظهر في التطبيق والموقع خلال دقيقة");
    } catch (e) {
      toast(e instanceof Error ? e.message : "تعذر الحفظ", "error");
    } finally {
      setSaving(false);
    }
  }

  async function reset() {
    try {
      const p = await api<Payload>("/api/admin/home-layout/reset", { method: "POST" });
      setPayload(p);
      setDraft(structuredClone(p.layout));
      toast("أُعيد الترتيب الأصلي");
    } finally {
      setConfirmReset(false);
    }
  }

  if (!payload || !draft) {
    return (
      <PageShell>
        <PageHeader title="الصفحة الرئيسية" description="أقسام الصفحة الرئيسية في التطبيق والموقع" />
        <SkeletonList count={5} />
      </PageShell>
    );
  }

  const label = (group: "header" | "body", key: string) => payload.catalog[group].find((c) => c.key === key);

  function list(group: "header" | "body") {
    const items = draft![group];
    return (
      <div className="space-y-2">
        {items.map((it, i) => {
          const meta = label(group, it.key);
          return (
            <div
              key={it.key}
              className={`flex items-center gap-3 rounded-2xl border border-line p-3 transition ${it.enabled ? "bg-surface" : "bg-paper opacity-60"}`}
            >
              <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-xl bg-accent-soft text-xs font-bold text-accent">{i + 1}</span>
              <div className="min-w-0 flex-1">
                <div className="font-bold text-ink">{meta?.label ?? it.key}</div>
                {meta?.hint && <div className="truncate text-xs text-muted">{meta.hint}</div>}
              </div>
              <Button
                size="sm"
                variant="ghost"
                disabled={i === 0}
                aria-label="للأعلى"
                onClick={() =>
                  setDraft((d) => {
                    const n = structuredClone(d!);
                    [n[group][i - 1], n[group][i]] = [n[group][i], n[group][i - 1]];
                    return n;
                  })
                }
              >
                ↑
              </Button>
              <Button
                size="sm"
                variant="ghost"
                disabled={i === items.length - 1}
                aria-label="للأسفل"
                onClick={() =>
                  setDraft((d) => {
                    const n = structuredClone(d!);
                    [n[group][i + 1], n[group][i]] = [n[group][i], n[group][i + 1]];
                    return n;
                  })
                }
              >
                ↓
              </Button>
              <Switch
                checked={it.enabled}
                onChange={(v) =>
                  setDraft((d) => {
                    const n = structuredClone(d!);
                    n[group][i].enabled = v;
                    return n;
                  })
                }
              />
            </div>
          );
        })}
      </div>
    );
  }

  const shown = draft.header.filter((x) => x.enabled).length + draft.body.filter((x) => x.enabled).length;

  return (
    <PageShell>
      <PageHeader
        eyebrow="تطبيق الزبون والموقع"
        title="الصفحة الرئيسية"
        description="شغّل أو أوقف أي قسم في الصفحة الرئيسية ورتّبه كما تريد — يُطبَّق على التطبيق والموقع معاً"
        action={
          <div className="flex items-center gap-2">
            <Badge>{shown} قسم ظاهر</Badge>
            <Button variant="ghost" size="sm" onClick={() => setConfirmReset(true)}>
              الترتيب الأصلي
            </Button>
          </div>
        }
      />

      <div className="grid grid-cols-1 gap-5 pb-24 xl:grid-cols-2">
        <Section title="رأس الصفحة" description="ما يظهر أسفل البحث مباشرة">
          {list("header")}
          {draft.header.find((h) => h.key === "quickLinks")?.enabled && (
            <div className="rounded-2xl bg-paper p-4">
              <div className="mb-3 text-sm font-bold text-ink">أزرار الاختصارات</div>
              <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
                {payload.catalog.quickLinks.map((q) => (
                  <label key={q.key} className="flex items-center justify-between gap-2 rounded-xl border border-line bg-surface px-3 py-2 text-sm font-semibold">
                    {q.label}
                    <Switch
                      checked={draft.quickLinks[q.key] !== false}
                      onChange={(v) => setDraft((d) => ({ ...d!, quickLinks: { ...d!.quickLinks, [q.key]: v } }))}
                    />
                  </label>
                ))}
              </div>
              <p className="mt-3 text-xs text-muted">
                زر نديم يُدار من{" "}
                <Link href="/nadeem" className="font-bold text-accent">
                  قسم نديم
                </Link>{" "}
                (خيار «اختصار نديم في الصفحة الرئيسية»).
              </p>
            </div>
          )}
        </Section>

        <Section title="أقسام المحتوى" description="بالترتيب من الأعلى للأسفل — استخدم الأسهم لتغيير الترتيب">
          {list("body")}
          <p className="text-xs text-muted">
            محتوى بعض الأقسام يُدار من أقسامه: البانرات، أماكن مميزة، الكوبونات، والأماكن المؤشّر عليها «مميز».
          </p>
        </Section>
      </div>

      <div className="fixed inset-x-0 bottom-0 z-30 border-t border-line bg-surface/95 px-4 py-3 backdrop-blur lg:pr-[280px]">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-3">
          <span className="text-sm text-muted">{dirty ? "لديك تعديلات غير محفوظة" : "كل التعديلات محفوظة"}</span>
          <div className="flex gap-2">
            <Button variant="ghost" disabled={!dirty || saving} onClick={() => setDraft(structuredClone(payload.layout))}>
              تراجع
            </Button>
            <Button disabled={!dirty || saving} onClick={save}>
              {saving ? "جاري الحفظ…" : "حفظ ونشر"}
            </Button>
          </div>
        </div>
      </div>

      <ConfirmDialog
        open={confirmReset}
        title="إعادة الترتيب الأصلي؟"
        message="ستظهر كل الأقسام بترتيبها الأصلي."
        confirmLabel="إعادة"
        onConfirm={reset}
        onClose={() => setConfirmReset(false)}
      />
    </PageShell>
  );
}
