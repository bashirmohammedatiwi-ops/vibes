"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input, Select, Textarea } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { useToast } from "@/components/ui/toast";
import { EmptyState } from "@/components/empty-state";
import { FilterChips } from "@/components/filter-chips";
import { HelpTip } from "@/components/help-tip";
import { PhoneActions } from "@/components/phone-actions";
import { PaginationBar } from "@/components/pagination-bar";
import { PageHeader } from "@/components/page-header";
import { PageShell, ContentPanel, ContentToolbar, ContentFooter } from "@/components/page-shell";
import { DataTable } from "@/components/ui/data-table";
import { PageToolbar } from "@/components/ui/page-toolbar";
import { ListRow } from "@/components/ui/list-row";
import { SkeletonList } from "@/components/ui/skeleton";
import { Alert } from "@/components/ui/alert";
import { StatStrip } from "@/components/ui/stat-strip";
import { IconCalendar, IconChart, IconWallet } from "@/components/nav-icons";
import { useDebouncedValue } from "@/hooks/use-debounced-value";
import { BOOKING_STATUS_LABELS, FARM_SHIFTS, PAYMENT_METHOD_LABELS, PAYMENT_STATUS_LABELS, SHIFT_TYPE_LABELS } from "@/lib/constants";
import { api, buildQuery } from "@/lib/api";
import { useCsvExport } from "@/lib/use-csv-export";
import { formatMoney, formatShortDayAr } from "@/lib/dates";
import type { Booking, Paginated } from "@/lib/types";

const STATUS_VARIANT: Record<string, "default" | "success" | "warning" | "danger" | "muted"> = {
  PENDING: "warning",
  AWAITING_PAYMENT: "warning",
  CONFIRMED: "success",
  COMPLETED: "success",
  CANCELLED: "muted",
  DISPUTED: "danger",
};

const PAYMENT_VARIANT: Record<string, "default" | "success" | "warning" | "danger" | "muted"> = {
  PENDING: "warning",
  PAID: "success",
  FAILED: "danger",
  REFUNDED: "muted",
};

function formatRange(start: string, end: string) {
  return `${formatShortDayAr(start)} → ${formatShortDayAr(end)}`;
}

export function BookingsContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { toast } = useToast();
  const { exportCsv, exporting } = useCsvExport();
  const [data, setData] = useState<Paginated<Booking> | null>(null);
  const [stats, setStats] = useState<{ pending: number; confirmed: number; revenue: number | string } | null>(null);
  const [q, setQ] = useState(() => searchParams.get("q") ?? "");
  const qDebounced = useDebouncedValue(q);
  const [status, setStatus] = useState(() => searchParams.get("status") ?? "");
  const [propertyId, setPropertyId] = useState(() => searchParams.get("propertyId") ?? "");
  const [properties, setProperties] = useState<Array<{ id: string; name: string }>>([]);
  const [from, setFrom] = useState(() => searchParams.get("from") ?? "");
  const [to, setTo] = useState(() => searchParams.get("to") ?? "");
  const [shift, setShift] = useState(() => searchParams.get("shift") ?? "");
  const [paymentStatus, setPaymentStatus] = useState(() => searchParams.get("paymentStatus") ?? "");
  const [paymentMethod, setPaymentMethod] = useState(() => searchParams.get("paymentMethod") ?? "");
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [statusChange, setStatusChange] = useState<{ id: string; name: string; status: string } | null>(null);
  const [adminNote, setAdminNote] = useState("");
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [bulkStatus, setBulkStatus] = useState<string | null>(null);
  const [bulkNote, setBulkNote] = useState("");
  const [bulkLoading, setBulkLoading] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [list, bookingStats] = await Promise.all([
        api<Paginated<Booking>>(`/api/admin/bookings${buildQuery({ q: qDebounced, status, propertyId, from, to, shift, paymentStatus, paymentMethod, page, pageSize: 15 })}`),
        api<{ pending: number; confirmed: number; revenue: number | string }>("/api/admin/bookings/stats"),
      ]);
      setData(list);
      setStats(bookingStats);
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر التحميل");
    } finally {
      setLoading(false);
    }
  }, [qDebounced, status, propertyId, from, to, shift, paymentStatus, paymentMethod, page]);

  useEffect(() => {
    api<Paginated<{ id: string; name: string }>>("/api/admin/properties?pageSize=200")
      .then((res) => setProperties(res.items.map((p) => ({ id: p.id, name: p.name }))))
      .catch(() => undefined);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    const params = new URLSearchParams();
    if (status) params.set("status", status);
    if (propertyId) params.set("propertyId", propertyId);
    if (from) params.set("from", from);
    if (to) params.set("to", to);
    if (shift) params.set("shift", shift);
    if (paymentStatus) params.set("paymentStatus", paymentStatus);
    if (paymentMethod) params.set("paymentMethod", paymentMethod);
    if (qDebounced) params.set("q", qDebounced);
    const qs = params.toString();
    router.replace(qs ? `/bookings?${qs}` : "/bookings", { scroll: false });
  }, [status, propertyId, from, to, shift, paymentStatus, paymentMethod, qDebounced, router]);

  useEffect(() => {
    setSelected(new Set());
  }, [qDebounced, status, propertyId, from, to, shift, paymentStatus, paymentMethod, page]);

  async function applyStatusChange(id: string, next: string, note?: string) {
    try {
      await api(`/api/admin/bookings/${id}/status`, {
        method: "PATCH",
        body: JSON.stringify({ status: next, adminNote: note?.trim() || undefined }),
      });
      toast(`تم تحديث الحالة إلى ${BOOKING_STATUS_LABELS[next] ?? next}`);
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث", "error");
    }
  }

  function chipValue() {
    if (status === "PENDING") return "pending";
    if (status === "DISPUTED") return "disputed";
    if (status === "CONFIRMED") return "confirmed";
    if (status === "AWAITING_PAYMENT") return "awaiting";
    if (status === "COMPLETED") return "completed";
    if (status === "CANCELLED") return "cancelled";
    return "all";
  }

  function applyChip(id: string) {
    setPage(1);
    if (id === "all") setStatus("");
    if (id === "pending") setStatus("PENDING");
    if (id === "awaiting") setStatus("AWAITING_PAYMENT");
    if (id === "disputed") setStatus("DISPUTED");
    if (id === "confirmed") setStatus("CONFIRMED");
    if (id === "completed") setStatus("COMPLETED");
    if (id === "cancelled") setStatus("CANCELLED");
  }

  function toggleSelect(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function toggleSelectAll() {
    const ids = data?.items.map((b) => b.id) ?? [];
    if (ids.every((id) => selected.has(id))) {
      setSelected(new Set());
    } else {
      setSelected(new Set(ids));
    }
  }

  async function applyBulkStatus(next: string) {
    if (!selected.size) return;
    setBulkLoading(true);
    try {
      const res = await api<{ updated: number; failed: number }>("/api/admin/bookings/bulk", {
        method: "POST",
        body: JSON.stringify({ ids: [...selected], status: next, adminNote: bulkNote.trim() || undefined }),
      });
      toast(`تم تحديث ${res.updated} حجز${res.failed ? ` — فشل ${res.failed}` : ""}`);
      setBulkStatus(null);
      setBulkNote("");
      setSelected(new Set());
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث الجماعي", "error");
    } finally {
      setBulkLoading(false);
    }
  }

  function PaymentCell({ item }: { item: Booking }) {
    if (!item.payment) {
      return <span className="text-xs text-muted">—</span>;
    }
    return (
      <div className="space-y-1">
        <Badge variant={PAYMENT_VARIANT[item.payment.status] ?? "default"}>
          {PAYMENT_STATUS_LABELS[item.payment.status] ?? item.payment.status}
        </Badge>
        <div className="text-xs text-muted">{PAYMENT_METHOD_LABELS[item.payment.method] ?? item.payment.method}</div>
        {item.status === "AWAITING_PAYMENT" && item.payment.proofUrl && (
          <Link href={`/bookings/${item.id}`} className="block text-xs text-accent hover:underline">
            مراجعة الإثبات
          </Link>
        )}
      </div>
    );
  }

  function BookingActions({ item }: { item: Booking }) {
    return (
      <div className="flex flex-wrap gap-1" onClick={(e) => e.stopPropagation()}>
        <Link href={`/bookings/${item.id}`}>
          <Button variant="ghost" className="px-2 py-1 text-xs">تفاصيل</Button>
        </Link>
        {item.status === "PENDING" && (
          <>
            <Button className="px-2 py-1 text-xs" onClick={() => applyStatusChange(item.id, "CONFIRMED")}>تأكيد</Button>
            <Button
              variant="danger"
              className="px-2 py-1 text-xs"
              onClick={() => {
                setStatusChange({ id: item.id, name: item.property?.name ?? "الحجز", status: "CANCELLED" });
                setAdminNote("");
              }}
            >
              إلغاء
            </Button>
          </>
        )}
        {item.status === "AWAITING_PAYMENT" && (
          <Link href={`/bookings/${item.id}`}>
            <Button variant="accent" className="px-2 py-1 text-xs">مراجعة الدفع</Button>
          </Link>
        )}
        {item.status === "CONFIRMED" && (
          <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => applyStatusChange(item.id, "COMPLETED")}>تمت الزيارة</Button>
        )}
        {item.status === "DISPUTED" && (
          <Link href={`/disputes`}>
            <Button variant="ghost" className="px-2 py-1 text-xs">حل النزاع</Button>
          </Link>
        )}
      </div>
    );
  }

  return (
    <PageShell>
      <PageHeader
        title="الحجوزات"
        description="تابع طلبات العملاء — أكّد أو ألغِ من هنا"
        eyebrow="VIBES Admin"
        onRefresh={load}
        refreshing={loading}
        action={
          <>
            <Link href="/bookings/new">
              <Button size="sm">+ حجز يدوي</Button>
            </Link>
            <Button variant="ghost" disabled={exporting} onClick={() => exportCsv(`/api/admin/reports/bookings/export${buildQuery({ status, propertyId, from, to, shift, paymentStatus, paymentMethod, q: qDebounced })}`, "bookings.csv")}>
              تصدير CSV
            </Button>
          </>
        }
      />

      <HelpTip>اضغط على أي حجز لفتح التفاصيل. للتواصل مع العميل استخدم اتصال أو واتساب.</HelpTip>

      {stats && (
        <StatStrip
          stats={[
            { label: "قيد الانتظار", value: stats.pending, icon: <IconCalendar className="h-5 w-5" /> },
            { label: "مؤكدة", value: stats.confirmed, accent: true, icon: <IconChart className="h-5 w-5" /> },
            { label: "إجمالي الإيرادات", value: formatMoney(stats.revenue), icon: <IconWallet className="h-5 w-5" /> },
          ]}
        />
      )}

      <ContentPanel>
        <ContentToolbar>
          <FilterChips
            value={chipValue()}
            onChange={applyChip}
            options={[
              { id: "all", label: "الكل" },
              { id: "pending", label: "بانتظار التأكيد" },
              { id: "awaiting", label: "بانتظار الدفع" },
              { id: "disputed", label: "نزاعات" },
              { id: "confirmed", label: "مؤكدة" },
              { id: "completed", label: "مكتملة" },
              { id: "cancelled", label: "ملغاة" },
            ]}
          />
          <PageToolbar className="mb-0 mt-4">
            <Input className="max-w-sm flex-1" placeholder="بحث بالاسم أو الهاتف..." value={q} onChange={(e) => { setPage(1); setQ(e.target.value); }} />
            <Select value={propertyId} onChange={(e) => { setPage(1); setPropertyId(e.target.value); }} className="max-w-[200px]">
              <option value="">كل الأماكن</option>
              {properties.map((p) => (
                <option key={p.id} value={p.id}>{p.name}</option>
              ))}
            </Select>
            <Input type="date" value={from} onChange={(e) => { setPage(1); setFrom(e.target.value); }} title="من تاريخ" className="max-w-[160px]" />
            <Input type="date" value={to} onChange={(e) => { setPage(1); setTo(e.target.value); }} title="إلى تاريخ" className="max-w-[160px]" />
            <Select value={shift} onChange={(e) => { setPage(1); setShift(e.target.value); }} className="max-w-[140px]">
              <option value="">كل الشفتات</option>
              {FARM_SHIFTS.map((s) => (
                <option key={s} value={s}>{SHIFT_TYPE_LABELS[s]}</option>
              ))}
            </Select>
            <Select value={paymentStatus} onChange={(e) => { setPage(1); setPaymentStatus(e.target.value); }} className="max-w-[140px]">
              <option value="">حالة الدفع</option>
              {Object.entries(PAYMENT_STATUS_LABELS).map(([k, v]) => (
                <option key={k} value={k}>{v}</option>
              ))}
            </Select>
            <Select value={paymentMethod} onChange={(e) => { setPage(1); setPaymentMethod(e.target.value); }} className="max-w-[140px]">
              <option value="">طريقة الدفع</option>
              {Object.entries(PAYMENT_METHOD_LABELS).map(([k, v]) => (
                <option key={k} value={k}>{v}</option>
              ))}
            </Select>
          </PageToolbar>
          {selected.size > 0 && (
            <div className="mt-4 flex flex-wrap items-center gap-2 rounded-xl border border-accent/30 bg-accent-soft/40 px-4 py-3">
              <span className="text-sm font-semibold">{selected.size} محدد</span>
              <Button size="sm" onClick={() => setBulkStatus("CONFIRMED")}>تأكيد</Button>
              <Button size="sm" variant="ghost" onClick={() => setBulkStatus("COMPLETED")}>إكمال</Button>
              <Button size="sm" variant="danger" onClick={() => setBulkStatus("CANCELLED")}>إلغاء</Button>
              <Button size="sm" variant="ghost" onClick={() => setSelected(new Set())}>إلغاء التحديد</Button>
            </div>
          )}
        </ContentToolbar>

        {error && <div className="content-alert"><Alert variant="danger">{error}</Alert></div>}
        {loading && <div className="p-5"><SkeletonList count={5} /></div>}

        <div className="list-rows p-4 md:hidden">
          {(data?.items ?? []).map((item) => (
            <ListRow
              key={item.id}
              onClick={() => router.push(`/bookings/${item.id}`)}
              title={item.property?.name}
              subtitle={`${item.user?.name ?? item.user?.phone} · ${item.guests} ضيف · ${formatRange(item.startDate, item.endDate)}${item.shift && item.shift !== "FULL" ? ` · ${SHIFT_TYPE_LABELS[item.shift]}` : ""}`}
              badge={<Badge variant={STATUS_VARIANT[item.status] ?? "default"}>{BOOKING_STATUS_LABELS[item.status] ?? item.status}</Badge>}
              meta={
                <>
                  <span className="text-sm font-bold text-ink">{formatMoney(item.totalPrice)}</span>
                  {item.payment && (
                    <Badge variant={PAYMENT_VARIANT[item.payment.status] ?? "default"}>
                      {PAYMENT_STATUS_LABELS[item.payment.status] ?? item.payment.status}
                    </Badge>
                  )}
                  <PhoneActions phone={item.user?.phone} compact />
                </>
              }
              footer={<BookingActions item={item} />}
            />
          ))}
        </div>

        {!loading && (
          <DataTable
            columns={[
              {
                key: "select",
                header: (
                  <input
                    type="checkbox"
                    checked={(data?.items.length ?? 0) > 0 && (data?.items.every((b) => selected.has(b.id)) ?? false)}
                    onChange={toggleSelectAll}
                    aria-label="تحديد الكل"
                  />
                ),
                cell: (item) => (
                  <input
                    type="checkbox"
                    checked={selected.has(item.id)}
                    onChange={() => toggleSelect(item.id)}
                    onClick={(e) => e.stopPropagation()}
                    aria-label="تحديد"
                  />
                ),
              },
              {
                key: "property",
                header: "المكان",
                cell: (item) => (
                  <>
                    <div className="font-semibold">{item.property?.name}</div>
                    <div className="text-xs text-muted">{item.guests} ضيف</div>
                  </>
                ),
              },
              {
                key: "user",
                header: "العميل",
                cell: (item) => (
                  <>
                    <div>{item.user?.name ?? item.user?.phone}</div>
                    <PhoneActions phone={item.user?.phone} compact />
                  </>
                ),
              },
              {
                key: "dates",
                header: "التواريخ",
                cell: (item) =>
                  `${formatRange(item.startDate, item.endDate)}${item.shift && item.shift !== "FULL" ? ` · ${SHIFT_TYPE_LABELS[item.shift]}` : ""}`,
              },
              { key: "price", header: "المبلغ", cell: (item) => <span className="font-semibold">{formatMoney(item.totalPrice)}</span> },
              {
                key: "payment",
                header: "الدفع",
                cell: (item) => <PaymentCell item={item} />,
              },
              {
                key: "status",
                header: "الحالة",
                cell: (item) => <Badge variant={STATUS_VARIANT[item.status] ?? "default"}>{BOOKING_STATUS_LABELS[item.status] ?? item.status}</Badge>,
              },
              { key: "actions", header: "إجراءات", cell: (item) => <BookingActions item={item} /> },
            ]}
            rows={data?.items ?? []}
            rowKey={(item) => item.id}
            onRowClick={(item) => router.push(`/bookings/${item.id}`)}
            empty={!data?.items.length ? <EmptyState title="لا توجد حجوزات" description="جرّب تغيير الفلاتر أو انتظر طلبات جديدة" /> : undefined}
          />
        )}

        {data && (
          <ContentFooter>
            <PaginationBar page={page} totalPages={data.totalPages} total={data.total} label="حجز" onPage={setPage} />
          </ContentFooter>
        )}
      </ContentPanel>

      <Modal
        open={!!bulkStatus}
        title={`تحديث ${selected.size} حجز`}
        onClose={() => setBulkStatus(null)}
      >
        <p className="mb-3 text-sm text-muted">
          الحالة الجديدة: {BOOKING_STATUS_LABELS[bulkStatus ?? ""] ?? bulkStatus}
        </p>
        <Textarea
          value={bulkNote}
          onChange={(e) => setBulkNote(e.target.value)}
          placeholder="ملاحظة داخلية (اختياري)..."
          rows={3}
        />
        <div className="mt-4 flex gap-2">
          <Button
            variant={bulkStatus === "CANCELLED" ? "danger" : "primary"}
            disabled={bulkLoading}
            onClick={() => bulkStatus && applyBulkStatus(bulkStatus)}
          >
            تأكيد
          </Button>
          <Button variant="ghost" onClick={() => setBulkStatus(null)}>إلغاء</Button>
        </div>
      </Modal>

      <Modal
        open={!!statusChange}
        title={statusChange?.status === "CANCELLED" ? "إلغاء الحجز" : "تغيير حالة الحجز"}
        onClose={() => setStatusChange(null)}
      >
        <p className="mb-3 text-sm text-muted">
          {statusChange?.name} — {BOOKING_STATUS_LABELS[statusChange?.status ?? ""] ?? statusChange?.status}
        </p>
        <Textarea
          value={adminNote}
          onChange={(e) => setAdminNote(e.target.value)}
          placeholder="ملاحظة داخلية (اختياري)..."
          rows={3}
        />
        <div className="mt-4 flex gap-2">
          <Button
            variant={statusChange?.status === "CANCELLED" ? "danger" : "primary"}
            onClick={async () => {
              if (!statusChange) return;
              await applyStatusChange(statusChange.id, statusChange.status, adminNote);
              setStatusChange(null);
            }}
          >
            تأكيد
          </Button>
          <Button variant="ghost" onClick={() => setStatusChange(null)}>إلغاء</Button>
        </div>
      </Modal>
    </PageShell>
  );
}
