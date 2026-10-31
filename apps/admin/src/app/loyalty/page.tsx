"use client";

import { useEffect, useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { SkeletonList } from "@/components/ui/skeleton";
import { useToast } from "@/components/ui/toast";
import { Grid, NumberField, Section, Switch } from "@/components/nadeem/fields";
import { api } from "@/lib/api";

type WorldType = "FARM" | "HALL" | "DECORATION";
type Program = { enabled: boolean; required: number; percent: number; maxDiscount: number };
type Config = { enabled: boolean; programs: Record<WorldType, Program> };
type Stat = { type: WorldType; members: number; earned: number; used: number; totalDiscount: number };
type Payload = { config: Config; stats: Stat[]; updatedAt: string | null };

const WORLDS: { type: WorldType; label: string }[] = [
  { type: "FARM", label: "المزارع" },
  { type: "HALL", label: "القاعات" },
  { type: "DECORATION", label: "التزيين" },
];

export default function LoyaltyPage() {
  const { toast } = useToast();
  const [payload, setPayload] = useState<Payload | null>(null);
  const [draft, setDraft] = useState<Config | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    api<Payload>("/api/admin/loyalty")
      .then((p) => {
        setPayload(p);
        setDraft(structuredClone(p.config));
      })
      .catch((e) => toast(e instanceof Error ? e.message : "تعذر التحميل", "error"));
  }, []);

  const dirty = useMemo(
    () => !!payload && !!draft && JSON.stringify(payload.config) !== JSON.stringify(draft),
    [payload, draft],
  );

  async function save() {
    if (!draft) return;
    setSaving(true);
    try {
      const p = await api<Payload>("/api/admin/loyalty", { method: "PUT", body: JSON.stringify(draft) });
      setPayload(p);
      setDraft(structuredClone(p.config));
      toast("حُفظ برنامج الولاء — يطبَّق خلال دقيقة");
    } catch (e) {
      toast(e instanceof Error ? e.message : "تعذر الحفظ", "error");
    } finally {
      setSaving(false);
    }
  }

  const description = "كل بطاقة مستقلة: حجوزات المزارع لا تُحسب في القاعات أو التزيين";

  if (!payload || !draft) {
    return (
      <PageShell>
        <PageHeader title="برنامج الولاء" description={description} />
        <SkeletonList count={3} />
      </PageShell>
    );
  }

  const setProgram = (type: WorldType, patch: Partial<Program>) =>
    setDraft((d) => {
      const next = structuredClone(d!);
      next.programs[type] = { ...next.programs[type], ...patch };
      return next;
    });

  return (
    <PageShell>
      <PageHeader title="برنامج الولاء" description={description} />
      <div className="space-y-5">
        <Section title="تشغيل البرنامج" description="عند الإيقاف لا تظهر البطاقات ولا يُمنح أي خصم جديد">
          <Switch
            checked={draft.enabled}
            onChange={(enabled) => setDraft((d) => ({ ...d!, enabled }))}
            label={draft.enabled ? "مفعّل" : "متوقف"}
          />
        </Section>

        {WORLDS.map(({ type, label }) => {
          const program = draft.programs[type];
          const stat = payload.stats.find((s) => s.type === type);
          return (
            <Section
              key={type}
              title={label}
              description={`بعد ${program.required} حجوزات مكتملة يحصل الزبون على خصم ${program.percent}% على حجزه التالي`}
            >
              <div className="space-y-4">
                <Switch
                  checked={program.enabled}
                  onChange={(enabled) => setProgram(type, { enabled })}
                  label={program.enabled ? "مفعّلة" : "متوقفة"}
                />
                <Grid cols={3}>
                  <NumberField
                    label="الحجوزات المطلوبة"
                    value={program.required}
                    onChange={(required) => setProgram(type, { required })}
                  />
                  <NumberField
                    label="نسبة الخصم %"
                    value={program.percent}
                    onChange={(percent) => setProgram(type, { percent })}
                  />
                  <NumberField
                    label="أقصى خصم بالدينار (0 = بلا سقف)"
                    value={program.maxDiscount}
                    onChange={(maxDiscount) => setProgram(type, { maxDiscount })}
                  />
                </Grid>
                {stat && (
                  <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
                    <Metric label="زبائن لديهم حجوزات مكتملة" value={stat.members} />
                    <Metric label="خصومات مكتسبة" value={stat.earned} />
                    <Metric label="خصومات مستخدمة" value={stat.used} />
                    <Metric label="إجمالي الخصم (د.ع)" value={stat.totalDiscount} />
                  </div>
                )}
              </div>
            </Section>
          );
        })}

        <div className="flex justify-end">
          <Button disabled={!dirty || saving} onClick={save}>
            {saving ? "جارٍ الحفظ…" : "حفظ"}
          </Button>
        </div>
      </div>
    </PageShell>
  );
}

function Metric({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-2xl border border-line bg-paper p-3">
      <div className="text-lg font-bold text-ink">{value.toLocaleString("en-US")}</div>
      <div className="text-xs text-muted">{label}</div>
    </div>
  );
}
