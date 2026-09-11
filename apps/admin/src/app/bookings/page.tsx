import { Suspense } from "react";
import { LoadingBlock } from "@/components/page-header";
import { BookingsContent } from "./bookings-content";

export default function BookingsPage() {
  return (
    <Suspense fallback={<LoadingBlock />}>
      <BookingsContent />
    </Suspense>
  );
}
