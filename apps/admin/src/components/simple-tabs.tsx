"use client";

type Tab = { id: string; label: string; count?: number };

type Props = {
  tabs: Tab[];
  active: string;
  onChange: (id: string) => void;
};

export function SimpleTabs({ tabs, active, onChange }: Props) {
  return (
    <div className="simple-tabs">
      {tabs.map((tab) => (
        <button
          key={tab.id}
          type="button"
          onClick={() => onChange(tab.id)}
          className={`simple-tab ${active === tab.id ? "simple-tab-active" : ""}`}
        >
          {tab.label}
          {tab.count != null && tab.count > 0 && (
            <span className="rounded-full bg-accent px-1.5 py-0.5 text-[10px] font-bold text-white">
              {tab.count}
            </span>
          )}
        </button>
      ))}
    </div>
  );
}
