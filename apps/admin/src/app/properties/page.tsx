import { Suspense } from "react";
import { LoadingBlock } from "@/components/page-header";
import PropertiesPageContent from "./properties-page";

export default function PropertiesPage() {
  return (
    <Suspense fallback={<LoadingBlock />}>
      <PropertiesPageContent />
    </Suspense>
  );
}
