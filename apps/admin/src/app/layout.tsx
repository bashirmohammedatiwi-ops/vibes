import type { Metadata } from "next";
import { Cairo } from "next/font/google";
import { AdminShell } from "@/components/admin-shell";
import { ToastProvider } from "@/components/ui/toast";
import "./globals.css";
import "./vibes-bloom.css";
import "./theme.css";
import "./vibes-nova.css";

const cairo = Cairo({
  subsets: ["arabic", "latin"],
  variable: "--font-cairo",
});

export const metadata: Metadata = {
  title: "VIBES Admin",
  description: "لوحة إدارة منصة VIBES",
};

// Runs before paint so the saved theme applies with zero flash-of-wrong-theme.
const NO_FLASH_SCRIPT = `
try {
  var t = localStorage.getItem("vibes-admin-theme");
  if (t === "dark") {
    document.documentElement.dataset.theme = "dark";
    document.documentElement.style.colorScheme = "dark";
  }
} catch (e) {}
`;

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ar" dir="rtl">
      <head>
        <script dangerouslySetInnerHTML={{ __html: NO_FLASH_SCRIPT }} />
      </head>
      <body className={`${cairo.variable} antialiased text-ink`} style={{ fontFamily: "var(--font-cairo), system-ui, sans-serif" }}>
        <ToastProvider>
          <AdminShell>{children}</AdminShell>
        </ToastProvider>
      </body>
    </html>
  );
}
