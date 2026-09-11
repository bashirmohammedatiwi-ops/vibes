import { Suspense } from "react";
import { LoadingBlock } from "@/components/page-header";
import PaymentsContent from "./payments-content";

export default function PaymentsPage() {
  return (
    <Suspense fallback={<LoadingBlock />}>
      <PaymentsContent />
    </Suspense>
  );
}
