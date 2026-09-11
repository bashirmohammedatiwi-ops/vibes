"use client";

import { AnimatePresence, motion } from "framer-motion";
import { createContext, useCallback, useContext, useState } from "react";

type Toast = { id: number; message: string; type: "success" | "error" | "info" };

const ToastContext = createContext<{
  toast: (message: string, type?: Toast["type"]) => void;
} | null>(null);

const ICONS: Record<Toast["type"], string> = {
  success: "✓",
  error: "!",
  info: "i",
};

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [items, setItems] = useState<Toast[]>([]);

  const toast = useCallback((message: string, type: Toast["type"] = "success") => {
    const id = Date.now() + Math.random();
    setItems((prev) => [...prev, { id, message, type }]);
    setTimeout(() => setItems((prev) => prev.filter((t) => t.id !== id)), 4000);
  }, []);

  function dismiss(id: number) {
    setItems((prev) => prev.filter((t) => t.id !== id));
  }

  return (
    <ToastContext.Provider value={{ toast }}>
      {children}
      <div className="fixed bottom-24 left-4 z-[110] flex max-w-[min(100%-2rem,22rem)] flex-col gap-2 lg:bottom-6">
        <AnimatePresence initial={false}>
          {items.map((t) => (
            <motion.div
              key={t.id}
              layout
              initial={{ opacity: 0, y: 16, scale: 0.95 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, x: -24, scale: 0.95, transition: { duration: 0.15 } }}
              transition={{ duration: 0.25, ease: [0.19, 1, 0.22, 1] }}
              className={`toast-bloom flex items-start gap-3 text-sm font-medium ${
                t.type === "error" ? "toast-bloom-error" : t.type === "info" ? "toast-bloom-info" : "toast-bloom-success"
              }`}
              role="status"
            >
              <span className="toast-bloom-icon" aria-hidden>
                {ICONS[t.type]}
              </span>
              <span className="flex-1 leading-6">{t.message}</span>
              <button
                type="button"
                onClick={() => dismiss(t.id)}
                className="shrink-0 rounded-md px-1.5 py-0.5 text-muted transition hover:bg-surface hover:text-ink"
                aria-label="إغلاق"
              >
                ×
              </button>
            </motion.div>
          ))}
        </AnimatePresence>
      </div>
    </ToastContext.Provider>
  );
}

export function useToast() {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error("useToast outside provider");
  return ctx;
}
