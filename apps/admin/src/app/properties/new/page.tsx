"use client";

import { useRouter } from "next/navigation";
import { PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { PropertyForm } from "@/components/property-form";
import type { Property } from "@/lib/types";

export default function NewPropertyPage() {
  const router = useRouter();

  function onSaved(property: Property) {
    router.push(`/properties/${property.id}/edit?tab=photos`);
  }

  return (
    <PageShell className="page-shell-medium">
      <PageHeader
        title="إضافة مكان جديد"
        description="املأ المعلومات الأساسية — بعد الحفظ ستفتح صفحة رفع الصور مباشرة"
        eyebrow="VIBES Admin"
        back={{ href: "/properties", label: "العودة للأماكن" }}
      />
      <PropertyForm submitLabel="إنشاء المكان" onSaved={onSaved} />
    </PageShell>
  );
}
