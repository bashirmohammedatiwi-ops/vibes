import Link from "next/link";
import { Logo } from "./logo";

export function Footer() {
  return (
    <footer className="mt-16 bg-midnight text-white/80">
      <div className="container-x grid gap-10 py-12 md:grid-cols-4">
        <div className="md:col-span-2">
          <Logo light />
          <p className="mt-4 max-w-md text-sm leading-7 text-white/65">
            VIBES منصة عراقية لحجز المزارع وقاعات المناسبات وفرق التزيين — أسعار واضحة، أيام متاحة أمامك، وحجز صباحي أو
            مسائي أو يوم كامل بخطوات بسيطة.
          </p>
        </div>
        <div>
          <h3 className="mb-3 text-sm font-black text-brass-light">استكشف</h3>
          <ul className="space-y-2 text-sm">
            <li><Link className="hover:text-white" href="/search?type=FARM">المزارع</Link></li>
            <li><Link className="hover:text-white" href="/search?type=HALL">قاعات المناسبات</Link></li>
            <li><Link className="hover:text-white" href="/search?type=DECORATION">فرق التزيين</Link></li>
            <li><Link className="hover:text-white" href="/search?type=FARM&winter=true">مزارع شتوية</Link></li>
            <li><Link className="hover:text-white" href="/offers">العروض والكوبونات</Link></li>
          </ul>
        </div>
        <div>
          <h3 className="mb-3 text-sm font-black text-brass-light">حسابك</h3>
          <ul className="space-y-2 text-sm">
            <li><Link className="hover:text-white" href="/bookings">حجوزاتي</Link></li>
            <li><Link className="hover:text-white" href="/favorites">المفضلة</Link></li>
            <li><Link className="hover:text-white" href="/messages">الرسائل والدعم</Link></li>
            <li><Link className="hover:text-white" href="/nadeem">نديم — مخطّط المناسبات</Link></li>
          </ul>
        </div>
      </div>
      <div className="border-t border-white/10">
        <div className="container-x flex flex-wrap items-center justify-between gap-2 py-5 text-xs text-white/50">
          <span>© {new Date().getFullYear()} VIBES — جميع الحقوق محفوظة</span>
          <span className="flex gap-4">
            <Link href="/privacy" className="hover:text-white">سياسة الخصوصية</Link>
            <Link href="/terms" className="hover:text-white">شروط الاستخدام</Link>
            <Link href="/delete-account" className="hover:text-white">حذف الحساب</Link>
          </span>
        </div>
      </div>
    </footer>
  );
}
