"use client";

import { useEffect, useState } from "react";
import { isAdmin } from "@/lib/api";
import { LoadingBlock, PageHeader } from "@/components/page-header";

export function AdminOnly({ children }: { children: React.ReactNode }) {
  const [allowed, setAllowed] = useState<boolean | null>(null);

  useEffect(() => {
    setAllowed(isAdmin());
  }, []);

  if (allowed === null) return <LoadingBlock />;
  if (!allowed) {
    return (
      <PageHeader
        title="ليست لديك صلاحية"
        description="هذه الصفحة للمدير فقط. اطلب من مدير النظام إن كنت بحاجة للوصول."
      />
    );
  }

  return <>{children}</>;
}
