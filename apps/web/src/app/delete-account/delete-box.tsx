"use client";

import Link from "next/link";
import { useState } from "react";
import { Loader2, Trash2 } from "lucide-react";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { clearTokens } from "@/lib/api";

export function DeleteAccountBox() {
  const { user, ready } = useAuth();
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  if (done) return <div className="mt-3 rounded-2xl bg-success-pale p-4 font-bold text-success">حُذف حسابك وبياناتك الشخصية.</div>;
  if (!ready) return null;
  if (!user)
    return (
      <Link href="/login?next=/delete-account" className="btn btn-primary mt-3 h-11 px-6">
        تسجيل الدخول
      </Link>
    );
  return (
    <div className="mt-3 rounded-2xl border border-danger/30 bg-danger-pale/40 p-4">
      <p className="text-sm">
        أنت مسجّل برقم{" "}
        <span className="num font-bold" dir="ltr">
          +{user.phone}
        </span>
      </p>
      {err && <p className="mt-2 text-sm font-semibold text-danger">{err}</p>}
      <button
        disabled={busy}
        onClick={async () => {
          if (!confirm("حذف الحساب نهائي ولا يمكن التراجع عنه. هل أنت متأكد؟")) return;
          setBusy(true);
          setErr(null);
          try {
            await api("/api/users/me", { method: "DELETE" });
            clearTokens();
            setDone(true);
          } catch (e) {
            setErr(e instanceof Error ? e.message : "تعذر حذف الحساب");
          } finally {
            setBusy(false);
          }
        }}
        className="btn mt-3 h-11 bg-danger px-6 text-white"
      >
        {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
        حذف حسابي نهائياً
      </button>
    </div>
  );
}
