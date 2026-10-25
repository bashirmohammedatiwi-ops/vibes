import type { Metadata } from "next";
import { serverGet } from "@/lib/server";
import type { Province } from "@/lib/types";
import { NadeemChat, type NadeemConfig } from "./nadeem-chat";

export const metadata: Metadata = {
  title: "نديم — مخطّط مناسبتك",
  description: "أجب عن أسئلة بسيطة ويقترح عليك نديم أنسب المزارع والقاعات لمناسبتك.",
};

export default async function NadeemPage() {
  const [config, provinces] = await Promise.all([
    serverGet<NadeemConfig>("/api/nadeem/config", 30),
    serverGet<Province[]>("/api/provinces", 600),
  ]);
  return (
    <div className="container-x py-6 md:py-10">
      {config ? (
        <NadeemChat config={config} provinces={provinces ?? []} />
      ) : (
        <div className="card p-10 text-center text-ink-2">تعذر تحميل نديم — حاول بعد قليل.</div>
      )}
    </div>
  );
}
