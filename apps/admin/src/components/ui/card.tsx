export function Card({
  children,
  className = "",
  padded = true,
  interactive = false,
}: {
  children: React.ReactNode;
  className?: string;
  padded?: boolean;
  interactive?: boolean;
}) {
  return (
    <div
      className={`card-premium ${interactive ? "card-interactive" : ""} ${padded ? "p-5" : ""} ${className}`}
    >
      {children}
    </div>
  );
}
