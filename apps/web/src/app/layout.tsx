import type { Metadata, Viewport } from "next";
import { Cairo, Montserrat } from "next/font/google";
import { AuthProvider } from "@/lib/auth";
import { FavoritesProvider } from "@/lib/favorites";
import { SITE_URL } from "@/lib/config";
import { Header } from "@/components/header";
import { Footer } from "@/components/footer";
import { BottomNav } from "@/components/bottom-nav";
import "./globals.css";

const cairo = Cairo({ subsets: ["arabic", "latin"], variable: "--font-cairo", display: "swap" });
const montserrat = Montserrat({ subsets: ["latin"], variable: "--font-montserrat", display: "swap", weight: ["600", "700", "800"] });

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: { default: "VIBES — احجز مزرعتك وقاعتك في العراق", template: "%s | VIBES" },
  description:
    "VIBES — منصة حجز المزارع وقاعات المناسبات وفرق التزيين في العراق. أسعار واضحة، أيام متاحة، وحجز صباحي أو مسائي أو يوم كامل.",
  applicationName: "VIBES",
  openGraph: { type: "website", locale: "ar_IQ", siteName: "VIBES" },
  icons: { icon: "/logo-mark-gold.png", apple: "/logo-mark-gold.png" },
};

export const viewport: Viewport = {
  themeColor: "#0f2138",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ar" dir="rtl" className={`${cairo.variable} ${montserrat.variable}`}>
      <body className="min-h-screen bg-canvas">
        <AuthProvider>
          <FavoritesProvider>
            <Header />
            <main className="min-h-[60vh] pb-24 md:pb-0">{children}</main>
            <Footer />
            <BottomNav />
          </FavoritesProvider>
        </AuthProvider>
      </body>
    </html>
  );
}
