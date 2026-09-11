import { redirect } from "next/navigation";

/** `/properties/:id` has no read-only view — the edit hub is the canonical page. */
export default async function PropertyPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  redirect(`/properties/${id}/edit`);
}
