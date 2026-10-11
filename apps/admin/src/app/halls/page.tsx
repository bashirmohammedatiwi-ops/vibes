"use client";

import { Suspense } from "react";
import { LoadingBlock } from "@/components/page-header";
import PropertiesPageContent from "../properties/properties-page";

export default function القاعاتWorldPage() {
  return (
    <Suspense fallback={<LoadingBlock />}>
      <PropertiesPageContent
        world={{
          type: "HALL",
          title: "🏛 القاعات",
          description: "إدارة عالم القاعات والأعراس",
          eyebrow: "عالم القاعات",
        }}
      />
    </Suspense>
  );
}
