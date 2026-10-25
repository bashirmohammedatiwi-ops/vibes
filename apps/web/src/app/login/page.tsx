import type { Metadata } from "next";
import { Suspense } from "react";
import { LoginForm } from "./login-form";

export const metadata: Metadata = { title: "تسجيل الدخول", robots: { index: false } };

export default function LoginPage() {
  return (
    <div className="container-x flex min-h-[70vh] items-center justify-center py-10">
      <Suspense>
        <LoginForm />
      </Suspense>
    </div>
  );
}
