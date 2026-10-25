import Link from "next/link";

export function Logo({ light = false }: { light?: boolean }) {
  return (
    <Link href="/" className="flex items-center gap-2.5" aria-label="VIBES — الرئيسية">
      <img src={light ? "/logo-mark-white.png" : "/logo-mark-gold.png"} alt="" className="h-9 w-9 object-contain" />
      <span className={`text-xl font-black tracking-[0.18em] ${light ? "text-white" : "text-midnight"}`} style={{ fontFamily: "var(--font-num)" }}>
        VIBES
      </span>
    </Link>
  );
}
