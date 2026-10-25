export function LegalPage({ title, updated, children }: { title: string; updated: string; children: React.ReactNode }) {
  return (
    <div className="container-x max-w-3xl py-10">
      <h1 className="text-3xl font-black">{title}</h1>
      <p className="mt-2 text-sm text-ink-3">آخر تحديث: {updated}</p>
      <div className="legal mt-8 space-y-6 leading-8 text-ink-2 [&_h2]:mb-2 [&_h2]:text-xl [&_h2]:font-black [&_h2]:text-ink [&_li]:mr-5 [&_li]:list-disc [&_strong]:text-ink">
        {children}
      </div>
    </div>
  );
}
