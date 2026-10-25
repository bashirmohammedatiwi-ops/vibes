import type { Metadata } from "next";
import { LegalPage } from "@/components/legal";
import { DeleteAccountBox } from "./delete-box";

export const metadata: Metadata = {
  title: "حذف الحساب",
  description: "كيف تحذف حسابك في VIBES وبياناتك الشخصية.",
};

export default function DeleteAccount() {
  return (
    <LegalPage title="حذف حسابك في VIBES" updated="25 تشرين الأول 2026">
      <section>
        <h2>من التطبيق</h2>
        <p>افتح تطبيق VIBES ← «ملفي» ← «حذف الحساب»، ثم أكّد الحذف.</p>
      </section>
      <section>
        <h2>من الموقع</h2>
        <p>سجّل الدخول برقم هاتفك ورمزك، ثم اضغط الزر أدناه.</p>
        <DeleteAccountBox />
      </section>
      <section>
        <h2>ما الذي يُحذف</h2>
        <ul>
          <li>رقم هاتفك واسمك ورمز الدخول — ويتحرر رقمك فيمكنك التسجيل به من جديد لاحقاً.</li>
          <li>المفضلة والقوائم والمتابعات والإشعارات وجلسات الدخول والأجهزة.</li>
          <li>منشوراتك وتعليقاتك وإعجاباتك.</li>
          <li>الحجوزات غير المدفوعة تُلغى تلقائياً.</li>
        </ul>
      </section>
      <section>
        <h2>ما الذي نحتفظ به</h2>
        <p>
          سجلات الحجوزات المؤكدة والفواتير تبقى دون اسمك أو رقمك، لأغراض محاسبية وقانونية ولحفظ حق صاحب المكان. الحذف فوري
          ونهائي ولا يمكن التراجع عنه.
        </p>
      </section>
    </LegalPage>
  );
}
