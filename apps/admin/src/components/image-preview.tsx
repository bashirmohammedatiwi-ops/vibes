"use client";

import { Modal } from "@/components/ui/modal";

type Props = {
  url: string | null;
  title?: string;
  onClose: () => void;
};

export function ImagePreview({ url, title, onClose }: Props) {
  if (!url) return null;

  const isPdf = url.toLowerCase().includes('.pdf');

  return (
    <Modal open title={title ?? "معاينة"} onClose={onClose}>
      <div className="max-h-[70vh] overflow-auto">
        {isPdf ? (
          <iframe src={url} className="h-[60vh] w-full rounded-lg border" title="PDF" />
        ) : (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={url} alt="" className="mx-auto max-h-[65vh] rounded-lg object-contain" />
        )}
        <a href={url} target="_blank" rel="noreferrer" className="mt-3 block text-center text-sm text-accent underline">
          فتح في تبويب جديد
        </a>
      </div>
    </Modal>
  );
}
