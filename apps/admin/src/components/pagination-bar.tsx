"use client";

import { Button } from "@/components/ui/button";

type Props = {
  page: number;
  totalPages: number;
  total?: number;
  label?: string;
  onPage: (page: number) => void;
};

export function PaginationBar({ page, totalPages, total, label, onPage }: Props) {
  if (totalPages <= 1) return null;

  const pages = Array.from({ length: Math.min(totalPages, 5) }, (_, i) => {
    if (totalPages <= 5) return i + 1;
    if (page <= 3) return i + 1;
    if (page >= totalPages - 2) return totalPages - 4 + i;
    return page - 2 + i;
  });

  return (
    <div className="pagination-bar">
      <span className="pagination-meta">
        {total != null ? `${total}${label ? ` ${label}` : ""} — ` : ""}
        صفحة {page} من {totalPages}
      </span>
      <div className="flex items-center gap-1">
        <Button variant="ghost" size="sm" disabled={page <= 1} onClick={() => onPage(page - 1)}>
          السابق
        </Button>
        <div className="pagination-pages hidden sm:flex">
          {pages.map((p) => (
            <button
              key={p}
              type="button"
              onClick={() => onPage(p)}
              className={`pagination-page-btn ${p === page ? "pagination-page-btn-active" : ""}`}
            >
              {p}
            </button>
          ))}
        </div>
        <Button variant="ghost" size="sm" disabled={page >= totalPages} onClick={() => onPage(page + 1)}>
          التالي
        </Button>
      </div>
    </div>
  );
}
