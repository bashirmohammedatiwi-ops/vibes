export function StepIndicator({ steps, current }: { steps: string[]; current: number }) {
  return (
    <div className="step-indicator" aria-label={`الخطوة ${current + 1} من ${steps.length}`}>
      {steps.map((step, i) => (
        <div key={step} className="flex items-center gap-2">
          <span
            className={`step-dot ${i === current ? "step-dot-active" : i < current ? "step-dot-done" : ""}`}
            title={step}
          />
          {i < steps.length - 1 && <span className="h-px w-4 bg-line" aria-hidden />}
        </div>
      ))}
    </div>
  );
}
