type Variant = "info" | "success" | "warning" | "danger";

const styles: Record<Variant, string> = {
  info: "alert-info",
  success: "alert-success",
  warning: "alert-warning",
  danger: "alert-danger",
};

export function Alert({
  children,
  variant = "info",
  className = "",
}: {
  children: React.ReactNode;
  variant?: Variant;
  className?: string;
}) {
  return (
    <div className={`alert ${styles[variant]} ${className}`}>
      {children}
    </div>
  );
}
