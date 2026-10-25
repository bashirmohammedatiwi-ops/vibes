"use client";

import { useState } from "react";
import { Check, Share2 } from "lucide-react";

export function ShareButton({ title }: { title: string }) {
  const [done, setDone] = useState(false);
  return (
    <button
      aria-label="مشاركة"
      onClick={async () => {
        const url = location.href;
        try {
          if (navigator.share) await navigator.share({ title, url });
          else {
            await navigator.clipboard.writeText(url);
            setDone(true);
            setTimeout(() => setDone(false), 1800);
          }
        } catch {}
      }}
      className="flex h-10 items-center gap-1.5 rounded-full border border-line bg-white px-3.5 text-sm font-bold transition hover:bg-cream"
    >
      {done ? <Check className="h-4 w-4 text-success" /> : <Share2 className="h-4 w-4" />}
      {done ? "نُسخ الرابط" : "مشاركة"}
    </button>
  );
}
