import { notFound, redirect } from "next/navigation";
import { serverGet } from "@/lib/server";
import type { PropertyDetail } from "@/lib/types";

/** /go/<id> → /p/<slug> (روابط البانرات والإشعارات تحمل المعرّف). */
export default async function Go({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const p = await serverGet<PropertyDetail>(`/api/properties/${id}`, 300);
  if (!p) notFound();
  redirect(`/p/${p.slug}`);
}
