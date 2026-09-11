type Props = {
  children: React.ReactNode;
  variant?: "info" | "success" | "warning";
};

export function HelpTip({ children, variant = "info" }: Props) {
  return (
    <div className={`help-tip help-tip-${variant}`} role="note">
      {children}
    </div>
  );
}
