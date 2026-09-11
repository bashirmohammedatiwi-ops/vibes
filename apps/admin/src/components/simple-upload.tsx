"use client";

import { useRef, useState } from "react";
import { Button } from "@/components/ui/button";

type Props = {
  onFiles: (files: FileList) => void;
  accept?: string;
  multiple?: boolean;
  uploading?: boolean;
  label?: string;
  hint?: string;
  previewUrl?: string | null;
};

export function SimpleUpload({
  onFiles,
  accept = "image/*",
  multiple = false,
  uploading = false,
  label = "اضغط لاختيار صورة",
  hint = "أو اسحب الملف هنا",
  previewUrl,
}: Props) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [dragging, setDragging] = useState(false);

  function pick(files: FileList | null) {
    if (!files?.length || uploading) return;
    onFiles(files);
  }

  return (
    <div
      className={`upload-zone ${dragging ? "upload-zone-active" : ""}`}
      onDragOver={(e) => {
        e.preventDefault();
        setDragging(true);
      }}
      onDragLeave={() => setDragging(false)}
      onDrop={(e) => {
        e.preventDefault();
        setDragging(false);
        pick(e.dataTransfer.files);
      }}
    >
      <input
        ref={inputRef}
        type="file"
        accept={accept}
        multiple={multiple}
        className="hidden"
        onChange={(e) => pick(e.target.files)}
      />
      {previewUrl ? (
        <div className="space-y-3">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={previewUrl} alt="" className="mx-auto max-h-40 rounded-lg object-contain" />
          <Button type="button" variant="ghost" disabled={uploading} onClick={() => inputRef.current?.click()}>
            {uploading ? "جاري الرفع..." : "تغيير الصورة"}
          </Button>
        </div>
      ) : (
        <>
          <p className="upload-zone-title">{uploading ? "جاري الرفع..." : label}</p>
          <p className="upload-zone-hint">{hint}</p>
          <Button type="button" className="mt-4" disabled={uploading} onClick={() => inputRef.current?.click()}>
            اختيار ملف
          </Button>
        </>
      )}
    </div>
  );
}
