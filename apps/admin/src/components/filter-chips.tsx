type Chip = { id: string; label: string };

type Props = {
  options: Chip[];
  value: string;
  onChange: (id: string) => void;
};

export function FilterChips({ options, value, onChange }: Props) {
  return (
    <div className="filter-chips" role="tablist">
      {options.map((chip) => (
        <button
          key={chip.id}
          type="button"
          role="tab"
          aria-selected={value === chip.id}
          onClick={() => onChange(chip.id)}
          className={`filter-chip ${value === chip.id ? "filter-chip-active" : ""}`}
        >
          {chip.label}
        </button>
      ))}
    </div>
  );
}
