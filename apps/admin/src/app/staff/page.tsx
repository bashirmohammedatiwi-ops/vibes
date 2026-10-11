"use client";

import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";

type Permission = string;

type StaffRow = {
  id: string;
  displayName: string;
  isActive: boolean;
  permissions: string[];
  lastSeenAt: string | null;
  user: { phone: string; name: string | null };
  presence: { state: string } | null;
};

const TEMPLATES: Record<string, string[]> = {
  line: ["calls.answer", "inbox.read", "inbox.reply", "bookings.read", "users.read"],
  bookings: [
    "calls.answer",
    "inbox.read",
    "inbox.reply",
    "bookings.read",
    "users.read",
    "bookings.confirm",
    "bookings.cancel",
    "payments.verify",
  ],
  supervisor: [
    "calls.answer",
    "calls.outbound",
    "calls.monitor",
    "inbox.read",
    "inbox.reply",
    "inbox.assign",
    "inbox.note",
    "bookings.read",
    "bookings.confirm",
    "bookings.cancel",
    "payments.verify",
    "refunds.review",
    "cancellations.review",
    "providers.link",
    "users.read",
  ],
};

export default function StaffPage() {
  const [rows, setRows] = useState<StaffRow[]>([]);
  const [live, setLive] = useState<{ waiting: number; answeredToday: number; missedToday: number; avgPacketLoss: number | null } | null>(null);
  const [permissions, setPermissions] = useState<Permission[]>([]);
  const [phone, setPhone] = useState("");
  const [name, setName] = useState("");
  const [pin, setPin] = useState("");
  const [error, setError] = useState("");

  async function load() {
    const [list, board] = await Promise.all([
      api<StaffRow[]>("/api/admin/staff"),
      api<typeof live>("/api/admin/staff/live"),
    ]);
    setRows(list);
    setLive(board);
  }

  useEffect(() => {
    load().catch((e) => setError(String(e)));
    const timer = setInterval(() => {
      api<typeof live>("/api/admin/staff/live").then(setLive).catch(() => undefined);
    }, 5000);
    return () => clearInterval(timer);
  }, []);

  async function createStaff() {
    setError("");
    try {
      await api("/api/admin/staff", {
        method: "POST",
        body: JSON.stringify({ phone, name, pin, permissions, isActive: true }),
      });
      setPhone("");
      setName("");
      setPin("");
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "تعذّر الإنشاء");
    }
  }

  function toggle(code: string) {
    setPermissions((current) =>
      current.includes(code) ? current.filter((item) => item !== code) : [...current, code],
    );
  }

  return (
    <div className="space-y-6 p-6">
      <h1 className="text-2xl font-black">الموظفون</h1>
      {live && (
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Stat label="في الانتظار" value={String(live.waiting)} />
          <Stat label="مُجابة اليوم" value={String(live.answeredToday)} />
          <Stat label="فائتة اليوم" value={String(live.missedToday)} />
          <Stat label="فقدان الحزم" value={live.avgPacketLoss == null ? "—" : `${live.avgPacketLoss.toFixed(1)}%`} />
        </div>
      )}
      <section className="rounded-2xl border p-4">
        <h2 className="mb-3 font-bold">حساب جديد</h2>
        <div className="mb-3 flex flex-wrap gap-2">
          <Button type="button" variant="ghost" onClick={() => setPermissions(TEMPLATES.line)}>موظف خط</Button>
          <Button type="button" variant="ghost" onClick={() => setPermissions(TEMPLATES.bookings)}>حجوزات</Button>
          <Button type="button" variant="ghost" onClick={() => setPermissions(TEMPLATES.supervisor)}>مشرف</Button>
        </div>
        <div className="grid gap-2 md:grid-cols-3">
          <input className="rounded-lg border px-3 py-2" placeholder="الهاتف" value={phone} onChange={(e) => setPhone(e.target.value)} />
          <input className="rounded-lg border px-3 py-2" placeholder="الاسم" value={name} onChange={(e) => setName(e.target.value)} />
          <input className="rounded-lg border px-3 py-2" placeholder="PIN من 4–6" value={pin} onChange={(e) => setPin(e.target.value)} />
        </div>
        <div className="mt-3 flex flex-wrap gap-2">
          {Object.values(TEMPLATES).flat().filter((code, index, all) => all.indexOf(code) === index).concat(["properties.read", "properties.moderate"]).map((code) => (
            <label key={code} className="flex items-center gap-1 text-xs">
              <input type="checkbox" checked={permissions.includes(code)} onChange={() => toggle(code)} />
              {code}
            </label>
          ))}
        </div>
        <Button className="mt-3" onClick={createStaff}>إنشاء الموظف</Button>
        {error && <p className="mt-2 text-sm text-red-600">{error}</p>}
      </section>
      <section className="space-y-2">
        {rows.map((row) => (
          <div key={row.id} className="flex flex-wrap items-center justify-between gap-2 rounded-xl border px-4 py-3">
            <div>
              <div className="font-bold">{row.displayName}</div>
              <div className="text-xs text-neutral-500">{row.user.phone} · {row.presence?.state ?? "OFFLINE"} · {row.lastSeenAt ? new Date(row.lastSeenAt).toLocaleString("ar") : "لم يظهر"}</div>
            </div>
            <div className="flex gap-2">
              <Button
                variant="ghost"
                onClick={async () => {
                  const next = prompt("PIN جديد");
                  if (!next) return;
                  await api(`/api/admin/staff/${row.id}`, { method: "PATCH", body: JSON.stringify({ pin: next }) });
                }}
              >
                PIN جديد
              </Button>
              <Button
                variant="ghost"
                onClick={async () => {
                  await api(`/api/admin/staff/${row.id}`, {
                    method: "PATCH",
                    body: JSON.stringify({ isActive: !row.isActive }),
                  });
                  await load();
                }}
              >
                {row.isActive ? "تعطيل" : "تفعيل"}
              </Button>
            </div>
          </div>
        ))}
      </section>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border p-3">
      <div className="text-xs text-neutral-500">{label}</div>
      <div className="text-xl font-black">{value}</div>
    </div>
  );
}
