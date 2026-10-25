import Link from "next/link";

export default function NotFound() {
  return (
    <div className="container-x flex min-h-[60vh] flex-col items-center justify-center py-16 text-center">
      <div className="num text-7xl font-extrabold text-brass">404</div>
      <h1 className="mt-3 text-2xl font-black">الصفحة غير موجودة</h1>
      <p className="mt-2 text-ink-2">ربما نُقل المكان أو تغيّر الرابط.</p>
      <div className="mt-6 flex gap-2">
        <Link href="/" className="btn btn-primary h-11 px-6">
          الرئيسية
        </Link>
        <Link href="/search" className="btn btn-ghost h-11 px-6">
          تصفّح الأماكن
        </Link>
      </div>
    </div>
  );
}
