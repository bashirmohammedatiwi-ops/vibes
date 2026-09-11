import { Suspense } from "react";
import { LoadingBlock } from "@/components/page-header";
import { UsersContent } from "./users-content";

export default function UsersPage() {
  return (
    <Suspense fallback={<LoadingBlock />}>
      <UsersContent />
    </Suspense>
  );
}
