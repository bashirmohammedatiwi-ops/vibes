"use client";

import Link from "next/link";
import { Button } from "@/components/ui/button";

type Props = {
  greeting: string;
  dateLabel: string;
  urgentTotal: number;
  loading: boolean;
  onRefresh: () => void;
  subtitle: string;
};

export function DashboardHero({ greeting, dateLabel, urgentTotal, loading, onRefresh, subtitle }: Props) {
  return (
    <header className="dash-welcome-card dash-hero-modern animate-fade-up">
      <div className="dash-hero-modern-grid">
        <div className="min-w-0 space-y-3">
          <span className="dash-hero-eyebrow">{dateLabel}</span>
          <h1 className="dash-hero-modern-title">{greeting}</h1>
          <p className="dash-hero-modern-sub">{subtitle}</p>
          {urgentTotal > 0 ? (
            <div className="dash-status-chip dash-status-chip--urgent">
              <span className="dash-status-dot" />
              {urgentTotal} مهمة تحتاج قراراً
            </div>
          ) : (
            <div className="dash-status-chip dash-status-chip--calm">
              كل شيء تحت السيطرة
            </div>
          )}
        </div>

        <div className="dash-hero-actions">
          <Button variant="ghost" size="sm" onClick={onRefresh} disabled={loading}>
            {loading ? "..." : "↻ تحديث"}
          </Button>
          <Link href="/calendar">
            <Button variant="ghost" size="sm">التقويم</Button>
          </Link>
          <Link href="/properties/new">
            <Button size="sm">+ مكان جديد</Button>
          </Link>
        </div>
      </div>
    </header>
  );
}
