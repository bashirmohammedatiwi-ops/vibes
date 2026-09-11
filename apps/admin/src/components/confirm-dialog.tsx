"use client";

import { Button } from "@/components/ui/button";
import { Modal } from "@/components/ui/modal";

type Props = {
  open: boolean;
  title: string;
  message: string;
  confirmLabel?: string;
  danger?: boolean;
  confirmDisabled?: boolean;
  children?: React.ReactNode;
  onConfirm: () => void;
  onClose: () => void;
};

export function ConfirmDialog({
  open,
  title,
  message,
  confirmLabel = "تأكيد",
  danger,
  confirmDisabled,
  children,
  onConfirm,
  onClose,
}: Props) {
  return (
    <Modal open={open} title={title} onClose={onClose}>
      <p className="mb-4 text-sm leading-6 text-muted">{message}</p>
      {children}
      <div className="mt-4 flex gap-2">
        <Button variant={danger ? "danger" : "primary"} disabled={confirmDisabled} onClick={onConfirm}>{confirmLabel}</Button>
        <Button variant="ghost" onClick={onClose}>إلغاء</Button>
      </div>
    </Modal>
  );
}
