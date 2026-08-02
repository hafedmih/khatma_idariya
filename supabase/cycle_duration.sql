-- ═══════════════════════════════════════════════════════════════
--  مدة الدورة بالأيام والساعات — نضيف ختم زمني لنهاية الدورة
-- ═══════════════════════════════════════════════════════════════

-- 1) عمود وقت انتهاء الدورة (بدء الدورة = created_at الموجود مسبقاً)
alter table public.group_cycles
  add column if not exists ended_at timestamptz;

-- 2) مُشغِّل يضبط ended_at تلقائياً عند أرشفة الدورة
create or replace function public.set_cycle_ended_at()
returns trigger
language plpgsql as $$
begin
  if new.status = 'archived' and coalesce(old.status, '') <> 'archived'
     and new.ended_at is null then
    new.ended_at := now();
  end if;
  return new;
end $$;

drop trigger if exists trg_cycle_ended_at on public.group_cycles;
create trigger trg_cycle_ended_at
  before update on public.group_cycles
  for each row execute function public.set_cycle_ended_at();

-- 2ب) تعبئة رجعية: نهاية كل دورة مؤرشفة = وقت بدء الدورة التالية
update public.group_cycles c
set ended_at = nxt.created_at
from public.group_cycles nxt
where c.group_id = nxt.group_id
  and nxt.cycle_no = c.cycle_no + 1
  and c.status = 'archived'
  and c.ended_at is null;

-- 3) الأرشيف يُرجع أوقات البداية والنهاية لحساب المدة
--    (نحذف الدالة أولاً لأن نوع الإرجاع تغيّر — بإضافة أعمدة)
drop function if exists public.group_archived_cycles(uuid);
create or replace function public.group_archived_cycles(p_group uuid)
returns table(id uuid, cycle_no int, start_date date, end_date date,
              hizbs_read int, members int,
              created_at timestamptz, ended_at timestamptz)
language sql stable security definer set search_path = public as $$
  select c.id, c.cycle_no, c.start_date, c.end_date,
    (select count(*) from cycle_snapshot_read r where r.cycle_id = c.id)::int,
    (select count(*) from cycle_snapshot_member m where m.cycle_id = c.id)::int,
    c.created_at, c.ended_at
  from group_cycles c
  where c.group_id = p_group and c.status = 'archived'
    and public.is_group_member(p_group, auth.uid())
  order by c.cycle_no desc;
$$;
grant execute on function public.group_archived_cycles(uuid) to authenticated;
