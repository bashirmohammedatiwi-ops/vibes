"use client";

import { Button } from "@/components/ui/button";

export default function ErrorPage({ error, reset }: { error: Error; reset: () => void }) {
  return (
    <div className="flex min-h-[50vh] flex-col items-center justify-center text-center">
      <div className="mb-4 flex h-16 w-16 items-center justify-center rounded-2xl bg-danger-soft text-2xl font-black text-danger">!</div>
      <h1 className="text-xl font-bold text-ink">حدث خطأ</h1>
      <p className="mt-2 max-w-sm text-sm leading-7 text-muted">{error.message || "تعذر عرض هذه الصفحة"}</p>
      <Button className="mt-6" onClick={reset}>إعادة المحاولة</Button>
    </div>
  );
}
