"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";

export function FollowButton({ providerId }: { providerId: string }) {
  const { user } = useAuth();
  const router = useRouter();
  const [following, setFollowing] = useState(false);
  useEffect(() => {
    api<{ following: boolean }>(`/api/follows/${providerId}`).then((r) => setFollowing(r.following)).catch(() => undefined);
  }, [providerId, user]);
  return (
    <button
      onClick={async () => {
        if (!user) {
          router.push(`/login?next=${encodeURIComponent(location.pathname)}`);
          return;
        }
        const next = !following;
        setFollowing(next);
        try {
          await api(`/api/follows/${providerId}`, { method: next ? "POST" : "DELETE" });
        } catch {
          setFollowing(!next);
        }
      }}
      className={`btn h-11 px-6 ${following ? "border border-white/30 bg-white/10 text-white" : "btn-gold"}`}
    >
      {following ? "تتابعه ✓" : "متابعة"}
    </button>
  );
}
