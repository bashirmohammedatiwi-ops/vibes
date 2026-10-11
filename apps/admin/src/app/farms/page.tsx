"use client";

import { Suspense } from "react";
import { LoadingBlock } from "@/components/page-header";
import PropertiesPageContent from "../properties/properties-page";

export default function المزارعWorldPage() {
  return (
    <Suspense fallback={<LoadingBlock />}>
      <PropertiesPageContent
        world={{
          type: "FARM",
          title: "🌾 المزارع",
          description: "إدارة عالم المزارع: أضف، راجع، انشر",
          eyebrow: "عالم المزارع",
        }}
      />
    </Suspense>
  );
}
