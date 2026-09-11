import Link from "next/link";
import { Alert } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";

export function ErrorBanner({
  message,
  onRetry,
  backHref,
  backLabel,
}: {
  message: string;
  onRetry?: () => void;
  backHref?: string;
  backLabel?: string;
}) {
  return (
    <div className="space-y-4 py-8">
      <Alert variant="danger">{message}</Alert>
      <div className="flex flex-wrap gap-2">
        {onRetry && <Button onClick={onRetry}>إعادة المحاولة</Button>}
        {backHref && backLabel && (
          <Link href={backHref}>
            <Button variant="ghost">{backLabel}</Button>
          </Link>
        )}
      </div>
    </div>
  );
}
