import type { ButtonHTMLAttributes } from "react";

type Props = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "primary" | "ghost" | "danger" | "accent";
  size?: "sm" | "md";
};

export function Button({ variant = "primary", size = "md", className = "", ...props }: Props) {
  const styles = {
    primary: "btn-primary",
    accent: "btn-accent",
    ghost: "btn-ghost",
    danger: "btn-danger",
  }[variant];

  const sizes = {
    sm: "min-h-8 rounded-lg px-3 py-1.5 text-xs",
    md: "min-h-10 rounded-xl px-4 py-2 text-sm",
  }[size];

  return (
    <button
      className={`btn-base inline-flex items-center justify-center gap-1.5 font-semibold transition-all active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-45 disabled:active:scale-100 ${sizes} ${styles} ${className}`}
      {...props}
    />
  );
}
