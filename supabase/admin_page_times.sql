-- ═══════════════════════════════════════════════════════════════
--  المشرفون (واحد أو أكثر) + تأمين أوقات صفحات الأحزاب
--
--  ⚠️ يُصلح هذا الملف ثغرةً أمنية: كانت سياسة «admin_write» على
--     hizb_links و hizb_page_times تسمح لأيّ مستخدم مسجَّل الدخول
--     بتعديل أوقات الصفحات لكل الأحزاب عالمياً.
--
--  نفّذه كاملاً في: Supabase Dashboard > SQL Editor > New query.
--  آمنٌ لإعادة التنفيذ (idempotent).
-- ═══════════════════════════════════════════════════════════════

-- ── 1) جدول المشرفين ──────────────────────────────────────────
create table if not exists public.app_admins (
  email      text primary key,
  note       text,
  created_at timestamptz not null default now()
);

alter table public.app_admins enable row level security;

-- لا سياسة SELECT هنا مطلقاً: لا يستطيع أي مستخدم قراءة قائمة
-- المشرفين. الدالة is_admin() أدناه security definer فتتجاوز RLS.

insert into public.app_admins(email, note)
values ('hafedmih89@gmail.com', 'المشرف الأول')
on conflict (email) do nothing;

-- ── 2) دالة التحقّق من المشرف ─────────────────────────────────
-- تقرأ البريد من auth.users بمعرّف الجلسة، لا من الـ JWT، حتى لا
-- يتأثّر التحقّق برمزٍ قديم بعد تغيير البريد.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from auth.users u
    join public.app_admins a on lower(a.email) = lower(u.email)
    where u.id = auth.uid()
  );
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- ── 3) أعمدة تتبّع: من عدّل ومتى ──────────────────────────────
alter table public.hizb_page_times
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists updated_by uuid references auth.users(id);

create or replace function public.stamp_page_times()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end; $$;

drop trigger if exists trg_page_times_stamp on public.hizb_page_times;
create trigger trg_page_times_stamp
  before insert or update on public.hizb_page_times
  for each row execute function public.stamp_page_times();

-- ── 4) إصلاح RLS ──────────────────────────────────────────────
-- القراءة تبقى عامة (التطبيق يعمل دون تسجيل دخول)،
-- والكتابة تُقصَر على المشرفين.

drop policy if exists "admin_write" on public.hizb_page_times;
create policy "admin_write" on public.hizb_page_times
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "admin_write" on public.hizb_links;
create policy "admin_write" on public.hizb_links
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ═══════════════════════════════════════════════════════════════
--  إضافة مشرف جديد لاحقاً (نفّذ هذا السطر وحده):
--    insert into public.app_admins(email, note)
--    values ('someone@example.com', 'الوصف')
--    on conflict (email) do nothing;
--
--  إزالة مشرف:
--    delete from public.app_admins where email = 'someone@example.com';
--
--  التحقّق من عمل الدالة (نفّذه وأنت مسجَّل الدخول بحساب المشرف):
--    select public.is_admin();
-- ═══════════════════════════════════════════════════════════════
