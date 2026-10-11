"use client";

import { Suspense } from "react";
import { LoadingBlock } from "@/components/page-header";
import PropertiesPageContent from "../properties/properties-page";

export default function التزيينWorldPage() {
  return (
    <Suspense fallback={<LoadingBlock />}>
      <PropertiesPageContent
        world={{
          type: "DECORATION",
          title: "✿ التزيين",
          description: "إدارة عالم التزيين والديكور",
          eyebrow: "عالم التزيين",
        }}
      />
    </Suspense>
  );
}
