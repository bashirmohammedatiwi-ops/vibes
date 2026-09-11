type Variant = "default" | "success" | "warning" | "danger" | "muted";

const styles: Record<Variant, string> = {
  default: "badge-default",
  success: "badge-success",
  warning: "badge-warning",
  danger: "badge-danger",
  muted: "badge-muted",
};

export function Badge({ children, variant = "default" }: { children: React.ReactNode; variant?: Variant }) {
  return (
    <span className={`badge ${styles[variant]}`}>
      {children}
    </span>
  );
}
