import Link from "next/link";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/empty-state";

export default function NotFound() {
  return (
    <div className="flex min-h-[50vh] flex-col items-center justify-center text-center">
      <div className="mb-4 flex h-16 w-16 items-center justify-center rounded-2xl bg-accent-soft text-2xl font-black text-accent/40">?</div>
      <h1 className="text-xl font-bold text-ink">الصفحة غير موجودة</h1>
      <p className="mt-2 max-w-sm text-sm leading-7 text-muted">ربما نُقل الرابط أو حُذف المحتوى.</p>
      <Link href="/" className="mt-6">
        <Button>العودة للرئيسية</Button>
      </Link>
    </div>
  );
}
