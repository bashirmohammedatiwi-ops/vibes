"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { IconSearch } from "@/components/nav-icons";
import { SkeletonList } from "@/components/ui/skeleton";
import { Alert } from "@/components/ui/alert";
import {
  BOOKING_STATUS_LABELS,
  KYC_STATUS_LABELS,
  PAYMENT_STATUS_LABELS,
  PROPERTY_STATUS_LABELS,
  PROPERTY_TYPE_LABELS,
} from "@/lib/constants";
import { api, buildQuery } from "@/lib/api";
import { formatShortDayAr } from "@/lib/dates";

const RECENT_KEY = "vibes-recent-searches";
const MAX_RECENT = 6;

type SearchResult = {
  properties: Array<{ id: string; name: string; slug: string; status: string; type: string }>;
  bookings: Array<{ id: string; status: string; startDate: string; property?: { name: string }; user?: { name?: string | null; phone: string } }>;
  users: Array<{ id: string; name?: string | null; phone: string; role: string }>;
  payments: Array<{ id: string; status: string; amount: number | string; booking?: { id: string; property?: { name: string }; user?: { name?: string | null; phone: string } } }>;
  providers: Array<{ id: string; businessName?: string | null; verified: boolean; kycStatus: string; user?: { name?: string | null; phone: string } }>;
};

type FlatResult = { href: string; label: string; section: string };

export function openGlobalSearch() {
  if (typeof window !== "undefined") {
    window.dispatchEvent(new Event("vibes-open-search"));
  }
}

export function SearchButton({ compact }: { compact?: boolean }) {
  if (compact) {
    return (
      <button
        type="button"
        onClick={openGlobalSearch}
        className="flex h-10 w-10 items-center justify-center rounded-xl border border-line bg-paper text-muted transition hover:border-accent/30 hover:bg-accent-soft hover:text-accent"
        aria-label="بحث"
      >
        <IconSearch className="h-4 w-4" />
      </button>
    );
  }

  return (
    <button type="button" onClick={openGlobalSearch} className="search-trigger">
      <IconSearch className="h-4 w-4 shrink-0 text-muted" />
      <span className="flex-1 text-right">ابحث عن مكان، حجز، هاتف...</span>
      <span className="hidden rounded-lg border border-line bg-surface px-2 py-0.5 text-[10px] font-bold text-muted sm:inline">
        Ctrl K
      </span>
    </button>
  );
}

function loadRecent(): string[] {
  if (typeof window === "undefined") return [];
  try {
    return JSON.parse(localStorage.getItem(RECENT_KEY) ?? "[]") as string[];
  } catch {
    return [];
  }
}

function saveRecent(term: string) {
  const trimmed = term.trim();
  if (trimmed.length < 2) return;
  const next = [trimmed, ...loadRecent().filter((t) => t !== trimmed)].slice(0, MAX_RECENT);
  localStorage.setItem(RECENT_KEY, JSON.stringify(next));
}

function flattenResults(results: SearchResult): FlatResult[] {
  const flat: FlatResult[] = [];
  for (const p of results.properties) {
    flat.push({
      href: `/properties/${p.id}/edit`,
      label: p.name,
      section: `${PROPERTY_TYPE_LABELS[p.type as keyof typeof PROPERTY_TYPE_LABELS] ?? p.type} · ${PROPERTY_STATUS_LABELS[p.status as keyof typeof PROPERTY_STATUS_LABELS] ?? p.status}`,
    });
  }
  for (const b of results.bookings) {
    flat.push({
      href: `/bookings/${b.id}`,
      label: b.property?.name ?? "حجز",
      section: `${b.user?.name ?? b.user?.phone} · ${formatShortDayAr(b.startDate)} · ${BOOKING_STATUS_LABELS[b.status as keyof typeof BOOKING_STATUS_LABELS] ?? b.status}`,
    });
  }
  for (const p of results.payments) {
    flat.push({
      href: p.booking?.id ? `/bookings/${p.booking.id}` : "/payments",
      label: p.booking?.property?.name ?? "دفعة",
      section: `${Number(p.amount).toLocaleString("ar-IQ")} د.ع · ${PAYMENT_STATUS_LABELS[p.status] ?? p.status}`,
    });
  }
  for (const u of results.users) {
    flat.push({
      href: `/users/${u.id}`,
      label: u.name ?? u.phone,
      section: u.name ? u.phone : "مستخدم",
    });
  }
  for (const pr of results.providers ?? []) {
    flat.push({
      href: `/providers/${pr.id}`,
      label: pr.businessName ?? pr.user?.name ?? pr.user?.phone ?? "مزود",
      section: `${pr.user?.phone ?? ""} · ${pr.verified ? "موثّق" : KYC_STATUS_LABELS[pr.kycStatus] ?? pr.kycStatus}`,
    });
  }
  return flat;
}

export function GlobalSearch() {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");
  const [results, setResults] = useState<SearchResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [searchError, setSearchError] = useState<string | null>(null);
  const [activeIndex, setActiveIndex] = useState(-1);
  const [recent, setRecent] = useState<string[]>([]);
  const inputRef = useRef<HTMLInputElement>(null);
  const listRef = useRef<HTMLDivElement>(null);

  const flatResults = useMemo(() => (results ? flattenResults(results) : []), [results]);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") {
        e.preventDefault();
        setOpen((v) => !v);
      }
      if (e.key === "Escape") setOpen(false);
    }
    function onOpen() {
      setOpen(true);
    }
    window.addEventListener("keydown", onKey);
    window.addEventListener("vibes-open-search", onOpen);
    return () => {
      window.removeEventListener("keydown", onKey);
      window.removeEventListener("vibes-open-search", onOpen);
    };
  }, []);

  useEffect(() => {
    if (open) {
      document.body.style.overflow = "hidden";
      setRecent(loadRecent());
      setTimeout(() => inputRef.current?.focus(), 50);
    } else {
      document.body.style.overflow = "";
      setQ("");
      setResults(null);
      setSearchError(null);
      setActiveIndex(-1);
    }
    return () => {
      document.body.style.overflow = "";
    };
  }, [open]);

  const search = useCallback(async (term: string) => {
    if (term.trim().length < 2) {
      setResults(null);
      return;
    }
    setLoading(true);
    setSearchError(null);
    try {
      const data = await api<SearchResult>(`/api/admin/search${buildQuery({ q: term })}`);
      setResults(data);
      setActiveIndex(-1);
      saveRecent(term);
      setRecent(loadRecent());
    } catch {
      setSearchError("تعذر البحث — حاول مرة أخرى");
      setResults({ properties: [], bookings: [], users: [], payments: [], providers: [] });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    const id = setTimeout(() => search(q), 250);
    return () => clearTimeout(id);
  }, [q, search]);

  useEffect(() => {
    if (activeIndex < 0 || !listRef.current) return;
    const el = listRef.current.querySelector(`[data-search-idx="${activeIndex}"]`);
    el?.scrollIntoView({ block: "nearest" });
  }, [activeIndex]);

  function handleInputKeyDown(e: React.KeyboardEvent) {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setActiveIndex((i) => Math.min(i + 1, flatResults.length - 1));
    }
    if (e.key === "ArrowUp") {
      e.preventDefault();
      setActiveIndex((i) => Math.max(i - 1, 0));
    }
    if (e.key === "Enter" && activeIndex >= 0 && flatResults[activeIndex]) {
      e.preventDefault();
      close();
      router.push(flatResults[activeIndex].href);
    }
  }

  const empty = results && !results.properties.length && !results.bookings.length && !results.users.length && !results.payments.length && !(results.providers?.length);

  if (!open) return null;

  const close = () => setOpen(false);

  let flatIdx = -1;

  const resultsBody = (
    <>
      {loading && <SkeletonList count={4} />}
      {!loading && q.length < 2 && recent.length > 0 && (
        <section className="mb-2">
          <div className="section-label px-3 py-2">عمليات بحث سابقة</div>
          {recent.map((term) => (
            <button
              key={term}
              type="button"
              className="block w-full rounded-xl px-3 py-2.5 text-right text-sm transition hover:bg-accent-soft"
              onClick={() => setQ(term)}
            >
              {term}
            </button>
          ))}
        </section>
      )}
      {!loading && q.length < 2 && recent.length === 0 && (
        <p className="px-3 py-8 text-center text-sm text-muted">اكتب حرفين على الأقل للبحث</p>
      )}
      {!loading && searchError && (
        <div className="p-2"><Alert variant="danger">{searchError}</Alert></div>
      )}
      {!loading && empty && !searchError && <p className="px-3 py-8 text-center text-sm text-muted">لا نتائج مطابقة</p>}

      {!!results?.properties.length && (
        <section className="mb-2">
          <div className="section-label px-3 py-2">الأماكن</div>
          {results.properties.map((p) => {
            flatIdx += 1;
            const idx = flatIdx;
            return (
              <Link
                key={p.id}
                href={`/properties/${p.id}/edit`}
                data-search-idx={idx}
                onClick={close}
                className={`block rounded-xl px-3 py-3 text-sm transition hover:bg-accent-soft ${activeIndex === idx ? "bg-accent-soft ring-1 ring-accent/30" : ""}`}
              >
                <span className="font-semibold">{p.name}</span>
                <span className="mx-2 text-line">·</span>
                <span className="text-muted">
                  {PROPERTY_TYPE_LABELS[p.type as keyof typeof PROPERTY_TYPE_LABELS] ?? p.type}
                </span>
                <span className="mx-2 text-line">·</span>
                <span className="text-muted">
                  {PROPERTY_STATUS_LABELS[p.status as keyof typeof PROPERTY_STATUS_LABELS] ?? p.status}
                </span>
              </Link>
            );
          })}
        </section>
      )}

      {!!results?.bookings.length && (
        <section className="mb-2">
          <div className="section-label px-3 py-2">الحجوزات</div>
          {results.bookings.map((b) => {
            flatIdx += 1;
            const idx = flatIdx;
            return (
              <Link
                key={b.id}
                href={`/bookings/${b.id}`}
                data-search-idx={idx}
                onClick={close}
                className={`block rounded-xl px-3 py-3 text-sm transition hover:bg-accent-soft ${activeIndex === idx ? "bg-accent-soft ring-1 ring-accent/30" : ""}`}
              >
                <span className="font-semibold">{b.property?.name ?? "—"}</span>
                <span className="mx-2 text-line">·</span>
                <span className="text-muted">{b.user?.name ?? b.user?.phone}</span>
                <span className="mx-2 text-line">·</span>
                <span className="text-muted">{formatShortDayAr(b.startDate)}</span>
                <span className="mx-2 text-line">·</span>
                <span className="text-muted">
                  {BOOKING_STATUS_LABELS[b.status as keyof typeof BOOKING_STATUS_LABELS] ?? b.status}
                </span>
              </Link>
            );
          })}
        </section>
      )}

      {!!results?.payments.length && (
        <section className="mb-2">
          <div className="section-label px-3 py-2">المدفوعات</div>
          {results.payments.map((p) => {
            flatIdx += 1;
            const idx = flatIdx;
            return (
              <Link
                key={p.id}
                href={p.booking?.id ? `/bookings/${p.booking.id}` : "/payments"}
                data-search-idx={idx}
                onClick={close}
                className={`block rounded-xl px-3 py-3 text-sm transition hover:bg-accent-soft ${activeIndex === idx ? "bg-accent-soft ring-1 ring-accent/30" : ""}`}
              >
                <span className="font-semibold">{p.booking?.property?.name ?? "—"}</span>
                <span className="mx-2 text-line">·</span>
                <span className="text-muted">{Number(p.amount).toLocaleString("ar-IQ")} د.ع</span>
                <span className="mx-2 text-line">·</span>
                <span className="text-muted">{PAYMENT_STATUS_LABELS[p.status] ?? p.status}</span>
              </Link>
            );
          })}
        </section>
      )}

      {!!results?.providers?.length && (
        <section className="mb-2">
          <div className="section-label px-3 py-2">المزودون</div>
          {results.providers.map((pr) => {
            flatIdx += 1;
            const idx = flatIdx;
            return (
              <Link
                key={pr.id}
                href={`/providers/${pr.id}`}
                data-search-idx={idx}
                onClick={close}
                className={`block rounded-xl px-3 py-3 text-sm transition hover:bg-accent-soft ${activeIndex === idx ? "bg-accent-soft ring-1 ring-accent/30" : ""}`}
              >
                <span className="font-semibold">{pr.businessName ?? pr.user?.name ?? pr.user?.phone}</span>
                <span className="mx-2 text-line">·</span>
                <span className="text-muted">{pr.verified ? "موثّق" : KYC_STATUS_LABELS[pr.kycStatus] ?? pr.kycStatus}</span>
              </Link>
            );
          })}
        </section>
      )}

      {!!results?.users.length && (
        <section>
          <div className="section-label px-3 py-2">المستخدمون</div>
          {results.users.map((u) => {
            flatIdx += 1;
            const idx = flatIdx;
            return (
              <Link
                key={u.id}
                href={`/users/${u.id}`}
                data-search-idx={idx}
                onClick={close}
                className={`block rounded-xl px-3 py-3 text-sm transition hover:bg-accent-soft ${activeIndex === idx ? "bg-accent-soft ring-1 ring-accent/30" : ""}`}
              >
                <span className="font-semibold">{u.name ?? u.phone}</span>
                {u.name && (
                  <span className="mx-2 text-muted" dir="ltr">
                    {u.phone}
                  </span>
                )}
              </Link>
            );
          })}
        </section>
      )}
    </>
  );

  return (
    <div
      className="modal-overlay fixed inset-0 z-[100] sm:flex sm:items-start sm:justify-center sm:p-3 sm:pt-[8vh]"
      onClick={close}
    >
      <div
        className="search-sheet h-full sm:h-auto sm:max-h-none sm:w-full sm:max-w-xl sm:overflow-hidden sm:rounded-2xl sm:shadow-float sm:animate-fade-up"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center gap-3 border-b border-line px-4 py-3 sm:py-0">
          <IconSearch className="h-5 w-5 shrink-0 text-muted" />
          <input
            ref={inputRef}
            className="min-w-0 flex-1 bg-transparent py-2 text-base outline-none placeholder:text-muted-light sm:py-4 sm:text-sm"
            placeholder="ابحث عن مكان، حجز، دفعة، أو مستخدم..."
            value={q}
            onChange={(e) => setQ(e.target.value)}
            onKeyDown={handleInputKeyDown}
          />
          <button
            type="button"
            onClick={close}
            className="shrink-0 rounded-lg px-2 py-1 text-sm font-semibold text-accent sm:hidden"
          >
            إلغاء
          </button>
          <kbd className="hidden rounded-lg border border-line bg-surface px-2 py-0.5 text-[10px] font-bold text-muted sm:inline">
            Esc
          </kbd>
        </div>

        <div ref={listRef} className="search-sheet-body soft-scroll sm:max-h-96">{resultsBody}</div>
        {flatResults.length > 0 && (
          <div className="hidden border-t border-line px-4 py-2 text-[10px] text-muted sm:block">
            ↑↓ للتنقل · Enter للفتح
          </div>
        )}
      </div>
    </div>
  );
}
