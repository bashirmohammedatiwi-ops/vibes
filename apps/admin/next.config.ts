import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  // الإنتاج يُقدَّم خلف nginx على مسار /admin — القيمة تُمرر وقت البناء
  // (NEXT_PUBLIC_BASE_PATH في Dockerfile) حتى يعمل التطبيق محلياً بدونها.
  basePath: process.env.NEXT_PUBLIC_BASE_PATH?.trim() ? process.env.NEXT_PUBLIC_BASE_PATH : undefined,
  poweredByHeader: false,
  compiler: {
    // أزل console.log من حزمة الإنتاج — أسرع وأصغر
    removeConsole: process.env.NODE_ENV === "production" ? { exclude: ["error", "warn"] } : false,
  },
  experimental: {
    // تقسيم أفضل لحزم UI الثقيلة
    optimizePackageImports: ["lucide-react", "recharts", "date-fns"],
  },
};

export default nextConfig;
