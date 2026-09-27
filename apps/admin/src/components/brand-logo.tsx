import Image from "next/image";

export function BrandLogo({
  size = "md",
  showWordmark = true,
  className = "",
  variant = "light",
}: {
  size?: "sm" | "md" | "lg";
  showWordmark?: boolean;
  className?: string;
  variant?: "light" | "dark";
}) {
  const sizes = {
    sm: { icon: 32, word: "text-base" },
    md: { icon: 40, word: "text-lg" },
    lg: { icon: 64, word: "text-3xl" },
  }[size];

  return (
    <div className={`brand brand--${variant} flex items-center gap-3 ${className}`}>
      <div
        className="brand-logo-mark relative shrink-0 overflow-hidden bg-paper"
        style={{ width: sizes.icon, height: sizes.icon }}
      >
        <Image src="/vibees-mark.png" alt="VIBEES" fill className="object-contain p-0.5" priority />
      </div>
      {showWordmark && (
        <div className="min-w-0">
          <div className={`brand-wordmark ${sizes.word}`}>VIBEES</div>
          <p className="brand-tagline text-[11px] font-medium">لوحة التشغيل</p>
        </div>
      )}
    </div>
  );
}
