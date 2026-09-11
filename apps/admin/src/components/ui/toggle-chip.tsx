export function ToggleChip({
  active,
  onClick,
  children,
  className = "",
}: {
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`rounded-full px-3 py-1.5 text-sm font-semibold transition ${
        active
          ? "bg-accent text-white"
          : "border border-line bg-paper text-muted hover:bg-accent-soft hover:text-accent"
      } ${className}`}
    >
      {children}
    </button>
  );
}
