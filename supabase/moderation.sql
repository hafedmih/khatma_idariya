-- ═══════════════════════════════════════════════════════════════
--  الإشراف على المحتوى من المستخدمين (متطلّب مراجعة App Store — Guideline 1.2)
--  البلاغات + حظر المستخدمين
-- ═══════════════════════════════════════════════════════════════

-- ── جدول البلاغات ──
create table if not exists public.member_reports (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid        references public.groups(id) on delete cascade,
  reporter_id  uuid        not null references auth.users(id) on delete cascade,
  reported_id  uuid        not null references auth.users(id) on delete cascade,
  reason       text        not null,
  status       text        not null default 'pending',  -- pending | reviewed | dismissed
  created_at   timestamptz not null default now()
);

alter table public.member_reports enable row level security;

-- المبلِّغ يرى بلاغاته فقط
drop policy if exists member_reports_select_own on public.member_reports;
create policy member_reports_select_own on public.member_reports
  for select using (reporter_id = auth.uid());

-- ── جدول الحظر ──
create table if not exists public.user_blocks (
  blocker_id  uuid        not null references auth.users(id) on delete cascade,
  blocked_id  uuid        not null references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

alter table public.user_blocks enable row level security;

drop policy if exists user_blocks_select_own on public.user_blocks;
create policy user_blocks_select_own on public.user_blocks
  for select using (blocker_id = auth.uid());

-- ═══════════════════════════════════════════════════════════════
--  دوال RPC
-- ═══════════════════════════════════════════════════════════════

-- الإبلاغ عن عضو
create or replace function public.report_member(
  p_group uuid, p_reported uuid, p_reason text
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_reported = auth.uid() then
    raise exception 'cannot report yourself';
  end if;
  insert into public.member_reports(group_id, reporter_id, reported_id, reason)
  values (p_group, auth.uid(), p_reported, coalesce(nullif(trim(p_reason), ''), 'غير محدد'));
end;
$$;

-- حظر مستخدم
create or replace function public.block_user(p_blocked uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_blocked = auth.uid() then
    raise exception 'cannot block yourself';
  end if;
  insert into public.user_blocks(blocker_id, blocked_id)
  values (auth.uid(), p_blocked)
  on conflict do nothing;
end;
$$;

-- رفع الحظر
create or replace function public.unblock_user(p_blocked uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from public.user_blocks
  where blocker_id = auth.uid() and blocked_id = p_blocked;
end;
$$;

-- قائمة المحظورين من طرف المستخدم الحالي (مع الاسم والصورة)
create or replace function public.my_blocked_users()
returns table(blocked_id uuid, display_name text, avatar_url text, created_at timestamptz)
language sql security definer set search_path = public as $$
  select b.blocked_id, p.display_name, p.avatar_url, b.created_at
  from public.user_blocks b
  left join public.profiles p on p.id = b.blocked_id
  where b.blocker_id = auth.uid()
  order by b.created_at desc;
$$;

grant execute on function public.report_member(uuid, uuid, text) to authenticated;
grant execute on function public.block_user(uuid)   to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;
grant execute on function public.my_blocked_users() to authenticated;
