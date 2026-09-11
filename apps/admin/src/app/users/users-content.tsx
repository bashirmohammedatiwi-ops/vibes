"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { DataTable } from "@/components/ui/data-table";
import { ListRow } from "@/components/ui/list-row";
import { PageToolbar } from "@/components/ui/page-toolbar";
import { SkeletonList } from "@/components/ui/skeleton";
import { Alert } from "@/components/ui/alert";
import { Input, Select } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { useToast } from "@/components/ui/toast";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { EmptyState } from "@/components/empty-state";
import { HelpTip } from "@/components/help-tip";
import { PhoneActions } from "@/components/phone-actions";
import { PaginationBar } from "@/components/pagination-bar";
import { PageHeader } from "@/components/page-header";
import { PageShell } from "@/components/page-shell";
import { USER_ROLE_LABELS } from "@/lib/constants";
import { api, buildQuery, isAdmin } from "@/lib/api";
import { useCsvExport } from "@/lib/use-csv-export";
import type { Paginated, UserRecord } from "@/lib/types";
import { useDebouncedValue } from "@/hooks/use-debounced-value";
import { normalizeIraqiPhone } from "@/components/phone-actions";

export function UsersContent() {
  const searchParams = useSearchParams();
  const { toast } = useToast();
  const { exportCsv, exporting } = useCsvExport();
  const [data, setData] = useState<Paginated<UserRecord> | null>(null);
  const [q, setQ] = useState(() => searchParams.get("q") ?? "");
  const qDebounced = useDebouncedValue(q);
  const [role, setRole] = useState("");
  const [isActive, setIsActive] = useState("");
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [promote, setPromote] = useState<{ id: string; name: string; role: string } | null>(null);
  const [createOpen, setCreateOpen] = useState(false);
  const [newPhone, setNewPhone] = useState("");
  const [newName, setNewName] = useState("");
  const [newRole, setNewRole] = useState("CUSTOMER");
  const [creating, setCreating] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<{ id: string; name: string } | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const result = await api<Paginated<UserRecord>>(`/api/admin/users${buildQuery({ q: qDebounced, role, isActive, page, pageSize: 20 })}`);
      setData(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر التحميل");
    } finally {
      setLoading(false);
    }
  }, [qDebounced, role, isActive, page]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    const fromUrl = searchParams.get("q") ?? "";
    if (fromUrl) setQ(fromUrl);
  }, [searchParams]);

  async function toggleActive(user: UserRecord) {
    try {
      await api(`/api/admin/users/${user.id}`, {
        method: "PATCH",
        body: JSON.stringify({ isActive: !user.isActive }),
      });
      toast(user.isActive ? "تم التعطيل" : "تم التفعيل");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث", "error");
    }
  }

  const admin = isAdmin();

  async function deleteUser() {
    if (!deleteTarget) return;
    try {
      const res = await api<{ deleted: boolean; deactivated: boolean }>(
        `/api/admin/users/${deleteTarget.id}`,
        { method: "DELETE" },
      );
      toast(res.deleted ? "تم حذف المستخدم" : "تم تعطيل الحساب — له سجلات مرتبطة");
      setDeleteTarget(null);
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الحذف", "error");
    }
  }

  async function requestRoleChange(user: UserRecord, nextRole: string) {
    if (nextRole === "ADMIN" && user.role !== "ADMIN") {
      setPromote({ id: user.id, name: user.name ?? user.phone, role: nextRole });
      return;
    }
    await updateUserRole(user.id, nextRole);
  }

  async function updateUserRole(userId: string, nextRole: string) {
    if (!admin) return;
    try {
      await api(`/api/admin/users/${userId}`, {
        method: "PATCH",
        body: JSON.stringify({ role: nextRole }),
      });
      toast("تم تحديث الدور");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر التحديث", "error");
    }
  }

  async function createUser() {
    const phone = normalizeIraqiPhone(newPhone.trim());
    if (phone.length < 12) {
      toast("أدخل رقم هاتف عراقي صحيح — مثال 07XXXXXXXXX", "error");
      return;
    }
    setCreating(true);
    try {
      await api("/api/admin/users", {
        method: "POST",
        body: JSON.stringify({ phone, name: newName.trim() || undefined, role: newRole }),
      });
      toast("تم إنشاء المستخدم");
      setCreateOpen(false);
      setNewPhone("");
      setNewName("");
      setNewRole("CUSTOMER");
      await load();
    } catch (err) {
      toast(err instanceof Error ? err.message : "تعذر الإنشاء", "error");
    } finally {
      setCreating(false);
    }
  }

  return (
    <PageShell>
      <PageHeader
        title="المستخدمون"
        description="العملاء وفريق VIBES"
        eyebrow="VIBES Admin"
        action={
          admin ? (
            <>
              <Button size="sm" onClick={() => setCreateOpen(true)}>+ مستخدم جديد</Button>
              <Button variant="ghost" disabled={exporting} onClick={() => exportCsv(`/api/admin/reports/users/export${buildQuery({ q: qDebounced, role, isActive })}`, "users.csv")}>
                تصدير CSV
              </Button>
            </>
          ) : undefined
        }
      />

      <HelpTip>اضغط على اسم المستخدم لعرض التفاصيل — يمكن للمدير تغيير الدور أو تعطيل الحساب</HelpTip>

      <Card padded={false} className="overflow-hidden">
        <div className="border-b border-line p-4 sm:p-5">
          <PageToolbar className="mb-0">
            <Input className="max-w-sm flex-1" placeholder="بحث بالاسم أو الهاتف..." value={q} onChange={(e) => { setPage(1); setQ(e.target.value); }} />
            <Select value={role} onChange={(e) => { setPage(1); setRole(e.target.value); }} className="max-w-[160px]">
              <option value="">كل الأدوار</option>
              {Object.entries(USER_ROLE_LABELS).map(([k, v]) => (
                <option key={k} value={k}>{v}</option>
              ))}
            </Select>
            <Select value={isActive} onChange={(e) => { setPage(1); setIsActive(e.target.value); }} className="max-w-[140px]">
              <option value="">كل الحالات</option>
              <option value="true">نشط</option>
              <option value="false">معطّل</option>
            </Select>
            <Button variant="ghost" onClick={load}>تحديث</Button>
          </PageToolbar>
        </div>

        {error && <div className="mx-5 mt-4"><Alert variant="danger">{error}</Alert></div>}
        {loading && <div className="p-5"><SkeletonList count={5} /></div>}

        <div className="list-rows p-4 md:hidden">
          {(data?.items ?? []).map((user) => (
            <ListRow
              key={user.id}
              onClick={() => window.location.assign(`/users/${user.id}`)}
              title={<Link href={`/users/${user.id}`} className="text-accent">{user.name ?? user.phone}</Link>}
              subtitle={`${USER_ROLE_LABELS[user.role] ?? user.role} · ${user._count?.bookings ?? 0} حجز`}
              badge={<Badge variant={user.isActive ? "success" : "danger"}>{user.isActive ? "نشط" : "معطّل"}</Badge>}
              meta={<PhoneActions phone={user.phone} compact />}
              footer={
                <Link href={`/users/${user.id}`}>
                  <Button variant="ghost" className="px-2 py-1 text-xs">تفاصيل</Button>
                </Link>
              }
            />
          ))}
        </div>

        {!loading && (
          <DataTable
            columns={[
              {
                key: "name",
                header: "الاسم",
                cell: (user) => (
                  <Link href={`/users/${user.id}`} className="font-semibold text-accent hover:underline">
                    {user.name ?? user.phone}
                  </Link>
                ),
              },
              {
                key: "phone",
                header: "الهاتف",
                cell: (user) => (
                  <>
                    <div dir="ltr">{user.phone}</div>
                    <PhoneActions phone={user.phone} compact />
                  </>
                ),
              },
              {
                key: "role",
                header: "الدور",
                cell: (user) =>
                  admin ? (
                    <Select className="py-1 text-xs" value={user.role} onChange={(e) => requestRoleChange(user, e.target.value)}>
                      {Object.entries(USER_ROLE_LABELS).map(([k, v]) => (
                        <option key={k} value={k}>{v}</option>
                      ))}
                    </Select>
                  ) : (
                    USER_ROLE_LABELS[user.role] ?? user.role
                  ),
              },
              { key: "bookings", header: "الحجوزات", cell: (user) => user._count?.bookings ?? 0 },
              {
                key: "status",
                header: "الحالة",
                cell: (user) => <Badge variant={user.isActive ? "success" : "danger"}>{user.isActive ? "نشط" : "معطّل"}</Badge>,
              },
              {
                key: "actions",
                header: "إجراءات",
                cell: (user) => (
                  <div className="flex flex-wrap gap-1">
                    <Link href={`/users/${user.id}`}><Button variant="ghost" className="px-2 py-1 text-xs">تفاصيل</Button></Link>
                    {admin && (
                      <>
                        <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => toggleActive(user)}>
                          {user.isActive ? "تعطيل" : "تفعيل"}
                        </Button>
                        {user.role !== "ADMIN" && (
                          <Button
                            variant="danger"
                            className="px-2 py-1 text-xs"
                            onClick={() => setDeleteTarget({ id: user.id, name: user.name ?? user.phone })}
                          >
                            حذف
                          </Button>
                        )}
                      </>
                    )}
                  </div>
                ),
              },
            ]}
            rows={data?.items ?? []}
            rowKey={(user) => user.id}
            empty={!data?.items.length ? <EmptyState title="لا يوجد مستخدمون" description="جرّب تغيير معايير البحث" /> : undefined}
          />
        )}

        {data && (
          <div className="border-t border-line px-5 py-4">
            <PaginationBar page={page} totalPages={data.totalPages} total={data.total} label="مستخدم" onPage={setPage} />
          </div>
        )}
      </Card>

      <Modal open={createOpen} title="مستخدم جديد" onClose={() => setCreateOpen(false)}>
        <div className="space-y-3">
          <Input
            placeholder="رقم الهاتف — 07XXXXXXXXX"
            value={newPhone}
            onChange={(e) => setNewPhone(e.target.value)}
            onBlur={() => newPhone.trim() && setNewPhone(normalizeIraqiPhone(newPhone))}
            dir="ltr"
            inputMode="tel"
          />
          <Input placeholder="الاسم (اختياري)" value={newName} onChange={(e) => setNewName(e.target.value)} />
          <Select value={newRole} onChange={(e) => setNewRole(e.target.value)}>
            {Object.entries(USER_ROLE_LABELS).filter(([k]) => k !== "ADMIN").map(([k, v]) => (
              <option key={k} value={k}>{v}</option>
            ))}
          </Select>
          <div className="flex gap-2 pt-2">
            <Button disabled={creating} onClick={createUser}>إنشاء</Button>
            <Button variant="ghost" onClick={() => setCreateOpen(false)}>إلغاء</Button>
          </div>
        </div>
      </Modal>

      <ConfirmDialog
        open={!!promote}
        title="ترقية إلى مدير"
        message={`«${promote?.name}» سيصبح مديراً ويستطيع تغيير كل شيء في اللوحة. متأكد؟`}
        confirmLabel="نعم، ترقية"
        danger
        onConfirm={async () => {
          if (!promote) return;
          await updateUserRole(promote.id, promote.role);
          setPromote(null);
        }}
        onClose={() => setPromote(null)}
      />

      <ConfirmDialog
        open={!!deleteTarget}
        title="حذف المستخدم"
        message={`«${deleteTarget?.name}» — إن كان له حجوزات أو تقييمات سيُعطّل حسابه بدل حذفه للحفاظ على السجلات.`}
        confirmLabel="متابعة"
        danger
        onConfirm={deleteUser}
        onClose={() => setDeleteTarget(null)}
      />
    </PageShell>
  );
}
