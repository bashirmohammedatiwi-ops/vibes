"use client";

import { useCallback, useState } from "react";
import { useToast } from "@/components/ui/toast";
import { downloadCsv } from "@/lib/api";

/** Wraps downloadCsv with a busy flag and success/error toasts. */
export function useCsvExport() {
  const { toast } = useToast();
  const [exporting, setExporting] = useState(false);

  const exportCsv = useCallback(
    async (path: string, filename = "export.csv") => {
      setExporting(true);
      try {
        await downloadCsv(path, filename);
        toast("تم تنزيل الملف");
      } catch (err) {
        toast(err instanceof Error ? err.message : "فشل التصدير", "error");
      } finally {
        setExporting(false);
      }
    },
    [toast],
  );

  return { exportCsv, exporting };
}
