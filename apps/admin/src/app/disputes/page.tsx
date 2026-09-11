"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input, Select, Textarea } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { Alert } from "@/components/ui/alert";
import { EmptyState } from "@/components/empty-state";
import { HelpTip } from "@/components/help-tip";
import { PageHeader } from "@/components/page-header";
import { PageShell, ContentPanel, ContentToolbar, ContentFooter } from "@/components/page-shell";
import { PageToolbar } from "@/components/ui/page-toolbar";
import { PaginationBar } from "@/components/pagination-bar";
import { PhoneActions } from "@/components/phone-actions";
import { DataTable } from "@/components/ui/data-table";
import { ListRow } from "@/components/ui/list-row";
import { SkeletonList } from "@/components/ui/skeleton";
import { useToast } from "@/components/ui/toast";
import { BOOKING_STATUS_LABELS } from "@/lib/constants";
import { api, buildQuery } from "@/lib/api";
import { useDebouncedValue } from "@/hooks/use-debounced-value";
import { useCsvExport } from "@/lib/use-csv-export";
import { formatMoney, formatShortDayAr, relativeTimeAr } from "@/lib/dates";
import type { Booking, Paginated } from "@/lib/types";

const PAGE_SIZE = 15;

export default function DisputesPage() {
  const router = useRouter();
  const { toast } = useToast();
  const { exportCsv, exporting } = useCsvExport();
  const [data, setData] = useState<Paginated<Booking> | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [q, setQ] = useState("");
  const qDebounced = useDebouncedValue(q);
  const [propertyId, setPropertyId] = useState("");
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [page, setPage] = useState(1);
  const [properties, setProperties] = useState<Array<{ id: string; name: string }>>([]);
  const [resolveId, setResolveId] = useState<string | null>(null);
  const [resolveNote, setResolveNote] = useState("");
  const [resolving, setResolving] = useState(false);

  const filters = useMemo(
    () => ({ status: "DISPUTED", q: qDebounced, propertyId, from, to }),
    [qDebounced, propertyId, from, to],
  );

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setData(
        await api<Paginated<Booking>>(
          `/api/admin/bookings${buildQuery({ ...filters, page, pageSize: PAGE_SIZE })}`,
        ),
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تحميل النزاعات");
    } finally {
      setLoading(false);
    }
  }, [filters, page]);

  useEffect(() => {
    load().catch(() => undefined);
  }, [load]);

  useEffect(() => {
    api<Paginated<{ id: string; name: string }>>(`/api/admin/properties${buildQuery({ pageSize: 200 })}`)
      .then((res) => setProperties(res.items))
      .catch(() => undefined);
  }, []);

  useEffect(() => {
    setPage(1);
  }, [qDebounced, propertyId, from, to]);

  async function resolve(status: "CONFIRMED" | "CANCELLED") {
    if (!resolveId) return;
    setResolving(true);
    try {
      await api(`/api/admin/bookings/${resolveId}/dispute/resolve`, {
        method: "POST",
        body: JSON.stringify({ status, note: resolveNote.trim() || undefined }),
      });
      toast(`تم حل النزاع — ${BOOKING_STATUS_LABELS[status]}`);
      setResolveId(null);
      setResolveNote("");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحل", "error");
    } finally {
      setResolving(false);
    }
  }

  function resetFilters() {
    setQ("");
    setPropertyId("");
    setFrom("");
    setTo("");
  }

  const hasFilters = !!(q || propertyId || from || to);

  return (
    <PageShell>
      <PageHeader
        title="النزاعات"
        description={
          data
            ? `${data.total} نزاع مفتوح — تأكيد أو إلغاء بعد المراجعة`
            : "حجوزات تحتاج قراراً — تأكيد أو إلغاء بعد المراجعة"
        }
        eyebrow="العمليات"
        onRefresh={load}
        refreshing={loading}
        action={
          <>
            <Button
              variant="ghost"
              disabled={exporting}
              onClick={() => exportCsv(`/api/admin/reports/bookings/export${buildQuery(filters)}`, "disputes.csv")}
            >
              تصدير CSV
            </Button>
            <Link href="/bookings?status=DISPUTED">
              <Button variant="ghost">عرض في الحجوزات</Button>
            </Link>
          </>
        }
      />

      <HelpTip>راجع ملاحظات الحجز وإثبات الدفع قبل القرار — التأكيد يُثبّت الحجز والإلغاء يحرّر التاريخ.</HelpTip>

      <ContentPanel flush>
        <ContentToolbar>
          <PageToolbar className="mb-0">
            <Input
              className="max-w-sm flex-1"
              placeholder="بحث بالعميل أو المكان..."
              value={q}
              onChange={(e) => setQ(e.target.value)}
            />
            <Select value={propertyId} onChange={(e) => setPropertyId(e.target.value)} className="max-w-[200px]">
              <option value="">كل الأماكن</option>
              {properties.map((p) => (
                <option key={p.id} value={p.id}>{p.name}</option>
              ))}
            </Select>
            <Input type="date" value={from} onChange={(e) => setFrom(e.target.value)} title="من" className="max-w-[160px]" />
            <Input type="date" value={to} onChange={(e) => setTo(e.target.value)} title="إلى" className="max-w-[160px]" />
            {hasFilters && (
              <Button variant="ghost" size="sm" onClick={resetFilters}>مسح الفلاتر</Button>
            )}
          </PageToolbar>
        </ContentToolbar>

        {error && (
          <div className="content-alert">
            <Alert variant="danger">{error}</Alert>
          </div>
        )}

        {loading && <div className="p-5"><SkeletonList count={4} /></div>}

        {!loading && !error && (data?.items.length ?? 0) > 0 && (
          <div className="list-rows p-4 md:hidden">
            {(data?.items ?? []).map((b) => (
              <ListRow
                key={b.id}
                title={b.property?.name ?? "—"}
                subtitle={
                  <>
                    {b.user?.name ?? b.user?.phone} · {formatMoney(b.totalPrice)}
                    <span className="mx-2 text-line">·</span>
                    {formatShortDayAr(b.startDate)} → {formatShortDayAr(b.endDate)}
                  </>
                }
                badge={<Badge variant="danger">نزاع</Badge>}
                meta={<PhoneActions phone={b.user?.phone} compact />}
                footer={
                  <>
                    {b.disputeReason && <p className="text-xs text-muted">{b.disputeReason}</p>}
                    <div className="flex flex-wrap gap-2">
                      <Button className="px-2 py-1 text-xs" onClick={() => setResolveId(b.id)}>حل النزاع</Button>
                      <Link href={`/bookings/${b.id}`}>
                        <Button variant="ghost" className="px-2 py-1 text-xs">تفاصيل</Button>
                      </Link>
                    </div>
                  </>
                }
              />
            ))}
          </div>
        )}

        {!loading && !error && (
          <DataTable
            columns={[
              {
                key: "property",
                header: "المكان",
                cell: (b) => (
                  <button type="button" className="font-semibold hover:text-accent" onClick={() => router.push(`/bookings/${b.id}`)}>
                    {b.property?.name ?? "—"}
                  </button>
                ),
              },
              {
                key: "customer",
                header: "العميل",
                cell: (b) => (
                  <div className="flex items-center gap-2">
                    <span>{b.user?.name ?? b.user?.phone ?? "—"}</span>
                    <PhoneActions phone={b.user?.phone} compact />
                  </div>
                ),
              },
              {
                key: "dates",
                header: "التواريخ",
                cell: (b) => `${formatShortDayAr(b.startDate)} → ${formatShortDayAr(b.endDate)}`,
              },
              { key: "amount", header: "المبلغ", cell: (b) => formatMoney(b.totalPrice) },
              {
                key: "reason",
                header: "السبب",
                cell: (b) =>
                  b.disputeReason ? (
                    <span className="line-clamp-2 text-xs text-muted">{b.disputeReason}</span>
                  ) : (
                    <Badge variant="muted">غير محدد</Badge>
                  ),
              },
              { key: "age", header: "منذ", cell: (b) => relativeTimeAr(b.createdAt) },
              {
                key: "actions",
                header: "إجراء",
                cell: (b) => (
                  <div className="flex flex-wrap gap-1">
                    <Button className="px-2 py-1 text-xs" onClick={() => setResolveId(b.id)}>حل النزاع</Button>
                    <Link href={`/bookings/${b.id}`}>
                      <Button variant="ghost" className="px-2 py-1 text-xs">تفاصيل</Button>
                    </Link>
                  </div>
                ),
              },
            ]}
            rows={data?.items ?? []}
            rowKey={(b) => b.id}
            empty={
              <EmptyState
                title={hasFilters ? "لا نتائج لهذه الفلاتر" : "لا نزاعات مفتوحة — ممتاز!"}
                description={hasFilters ? "جرّب مسح الفلاتر" : "سيظهر هنا أي حجز يُفتح له نزاع"}
              />
            }
          />
        )}

        {data && data.totalPages > 1 && (
          <ContentFooter>
            <PaginationBar page={page} totalPages={data.totalPages} total={data.total} label="نزاع" onPage={setPage} />
          </ContentFooter>
        )}
      </ContentPanel>

      <Modal
        open={!!resolveId}
        onClose={() => { setResolveId(null); setResolveNote(""); }}
        title="حل النزاع"
      >
        <Textarea
          placeholder="ملاحظة حل النزاع (اختياري)..."
          value={resolveNote}
          onChange={(e) => setResolveNote(e.target.value)}
        />
        <div className="mt-4 flex flex-wrap gap-2">
          <Button disabled={resolving} onClick={() => resolve("CONFIRMED")}>تأكيد الحجز</Button>
          <Button variant="danger" disabled={resolving} onClick={() => resolve("CANCELLED")}>إلغاء الحجز</Button>
          <Button variant="ghost" onClick={() => { setResolveId(null); setResolveNote(""); }}>إلغاء</Button>
        </div>
      </Modal>
    </PageShell>
  );
}
