"use client";

import { Heart } from "lucide-react";
import { useFavorites } from "@/lib/favorites";

export function FavButton({ id, className = "" }: { id: string; className?: string }) {
  const { ids, toggle } = useFavorites();
  const on = ids.has(id);
  return (
    <button
      type="button"
      aria-label={on ? "إزالة من المفضلة" : "أضف للمفضلة"}
      onClick={(e) => {
        e.preventDefault();
        e.stopPropagation();
        toggle(id);
      }}
      className={`flex h-9 w-9 items-center justify-center rounded-full bg-white/95 shadow-sm transition hover:scale-105 ${className}`}
    >
      <Heart className={`h-[18px] w-[18px] ${on ? "fill-rose text-rose" : "text-ink"}`} />
    </button>
  );
}
