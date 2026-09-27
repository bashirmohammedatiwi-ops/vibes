"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { BackLink, DetailCard, InfoRow } from "@/components/ui/detail-card";
import { ErrorBanner } from "@/components/ui/error-banner";
import { EmptyState } from "@/components/empty-state";
import { HelpTip } from "@/components/help-tip";
import { LoadingBlock, PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { PhoneActions } from "@/components/phone-actions";
import { api } from "@/lib/api";
import { PROPERTY_TYPE_LABELS } from "@/lib/constants";
import { relativeTimeAr } from "@/lib/dates";
import type { PropertyType } from "@/lib/types";

type CollectionDetail = {
  id: string;
  name: string;
  description?: string | null;
  visibility: string;
  isDefault: boolean;
  coverUrl?: string | null;
  updatedAt: string;
  user?: { id: string; name?: string | null; phone: string };
  items: Array<{
    id: string;
    note?: string;
    createdAt: string;
    property: {
      id: string;
      name: string;
      type: PropertyType;
      city?: { nameAr: string } | null;
    };
  }>;
};

export default function CollectionDetailPage() {
  const params = useParams<{ id: string }>();
  const [data, setData] = useState<CollectionDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setData(await api<CollectionDetail>(`/api/admin/collections/${params.id}`));
  }, [params.id]);

  useEffect(() => {
    load()
      .catch((err: Error) => setError(err.message))
      .finally(() => setLoading(false));
  }, [load]);

  if (loading) return <LoadingBlock />;
  if (error) {
    return (
      <PageShell>
        <ErrorBanner message={error} />
      </PageShell>
    );
  }
  if (!data) return null;

  return (
    <PageShell>
      <BackLink href="/collections">كل القوائم</BackLink>
      <PageHeader
        title={data.name}
        description={data.description || "قائمة حفظ أنشأها عميل"}
        eyebrow="اكتشاف"
      />
      <HelpTip>اضغط اسم المكان لفتح بطاقة العقار في الإدارة.</HelpTip>
      <div className="grid gap-4 lg:grid-cols-[1.1fr_0.9fr]">
        <DetailCard title="بيانات القائمة">
          <InfoRow label="الظهور">
            <Badge variant={data.visibility === "PUBLIC" ? "success" : "muted"}>
              {data.visibility === "PUBLIC" ? "عامة" : "خاصة"}
            </Badge>
          </InfoRow>
          <InfoRow label="النوع" value={data.isDefault ? "افتراضية" : "مخصصة"} />
          <InfoRow label="العناصر" value={data.items.length} />
          <InfoRow label="آخر تحديث" value={relativeTimeAr(data.updatedAt)} />
        </DetailCard>
        <DetailCard title="المالك">
          <InfoRow label="الاسم" value={data.user?.name || "—"} />
          <InfoRow label="الهاتف">
            {data.user?.phone ? <PhoneActions phone={data.user.phone} /> : "—"}
          </InfoRow>
        </DetailCard>
      </div>
      {data.coverUrl ? (
        <Card className="overflow-hidden p-0">
          <img src={data.coverUrl} alt="" className="h-48 w-full object-cover" />
        </Card>
      ) : null}
      <Card padded={false} className="overflow-hidden">
        <div className="border-b border-line px-4 py-3 font-bold">الأماكن المحفوظة</div>
        {!data.items.length ? (
          <EmptyState title="القائمة فارغة" description="لم يُضف العميل أماكن بعد" />
        ) : (
          <div className="divide-y divide-line">
            {data.items.map((item) => (
              <Link
                key={item.id}
                href={`/properties/${item.property.id}/edit`}
                className="flex items-start justify-between gap-3 px-4 py-3 transition hover:bg-accent-soft"
              >
                <div>
                  <div className="font-semibold">{item.property.name}</div>
                  <div className="text-xs text-muted">
                    {PROPERTY_TYPE_LABELS[item.property.type] ?? item.property.type}
                    {item.property.city?.nameAr ? ` · ${item.property.city.nameAr}` : ""}
                  </div>
                  {item.note ? <div className="mt-1 text-sm text-ink">{item.note}</div> : null}
                </div>
                <span className="text-xs text-muted">{relativeTimeAr(item.createdAt)}</span>
              </Link>
            ))}
          </div>
        )}
      </Card>
    </PageShell>
  );
}
