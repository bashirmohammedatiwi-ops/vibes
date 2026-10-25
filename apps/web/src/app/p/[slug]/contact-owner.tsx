"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { MessageCircle } from "lucide-react";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";

export function ContactOwner({ propertyId, className = "" }: { propertyId: string; className?: string }) {
  const { user } = useAuth();
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  return (
    <button
      disabled={busy}
      onClick={async () => {
        if (!user) {
          router.push(`/login?next=${encodeURIComponent(location.pathname)}`);
          return;
        }
        setBusy(true);
        try {
          const c = await api<{ id: string }>("/api/conversations/property", { method: "POST", body: { propertyId } });
          router.push(`/messages/${c.id}`);
        } catch (e) {
          alert(e instanceof Error ? e.message : "تعذر فتح المحادثة");
          setBusy(false);
        }
      }}
      className={`btn btn-primary h-10 px-4 text-sm ${className}`}
    >
      <MessageCircle className="h-4 w-4" />
      {busy ? "لحظة…" : "اسأل عن المكان"}
    </button>
  );
}
