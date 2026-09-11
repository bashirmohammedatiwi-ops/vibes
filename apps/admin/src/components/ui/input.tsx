import { forwardRef, type InputHTMLAttributes, type TextareaHTMLAttributes } from "react";

const base =
  "input-field w-full rounded-xl border border-line bg-paper px-3.5 py-2.5 text-sm text-ink outline-none transition-all placeholder:text-muted-light";

export const Input = forwardRef<HTMLInputElement, InputHTMLAttributes<HTMLInputElement>>(function Input(
  { className = "", ...props },
  ref,
) {
  return <input ref={ref} className={`${base} ${className}`} {...props} />;
});

export function Textarea({ className = "", ...props }: TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return <textarea className={`${base} min-h-[104px] resize-y ${className}`} {...props} />;
}

export function Select({ className = "", children, ...props }: InputHTMLAttributes<HTMLSelectElement>) {
  return (
    <select className={`${base} ${className}`} {...props}>
      {children}
    </select>
  );
}

export function Label({ children, htmlFor }: { children: React.ReactNode; htmlFor?: string }) {
  return (
    <label htmlFor={htmlFor} className="mb-1.5 block text-sm font-semibold text-ink/85">
      {children}
    </label>
  );
}
