-- ═══════════════════════════════════════════════════════════════════════════
--  الختمة الإدارية — مخطط Supabase للميزات الجديدة
--  User system · Khatma system · Stats · Gamification · Groups · Social
--  آمن لإعادة التشغيل (idempotent) — نفّذه في Supabase SQL Editor.
--  ملاحظة: مزوّدو الدخول (Google/Facebook/Apple) يُفعَّلون من لوحة Supabase Auth،
--  والإشعارات المحلية وتحميل الصوت (Offline) من جهة التطبيق.
-- ═══════════════════════════════════════════════════════════════════════════

create extension if not exists pgcrypto;   -- gen_random_uuid()

-- ───────────────────────────────────────────────────────────────────────────
-- 1) الملفات الشخصية + الإعدادات (تمتد من auth.users)
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id             uuid primary key references auth.users(id) on delete cascade,
  display_name   text,
  avatar_url     text,
  total_points   integer not null default 0,
  current_level  integer not null default 1,
  current_streak integer not null default 0,
  longest_streak integer not null default 0,
  last_active_date date,
  created_at     timestamptz not null default now()
);
-- إن كان جدول profiles موجوداً مسبقاً بأعمدة مختلفة، أضف الأعمدة الناقصة:
alter table public.profiles add column if not exists display_name     text;
alter table public.profiles add column if not exists avatar_url       text;
alter table public.profiles add column if not exists total_points     integer not null default 0;
alter table public.profiles add column if not exists current_level    integer not null default 1;
alter table public.profiles add column if not exists current_streak   integer not null default 0;
alter table public.profiles add column if not exists longest_streak   integer not null default 0;
alter table public.profiles add column if not exists last_active_date date;
alter table public.profiles add column if not exists created_at       timestamptz not null default now();

create table if not exists public.user_settings (
  user_id               uuid primary key references auth.users(id) on delete cascade,
  reminder_enabled      boolean not null default true,
  reminder_time         time    not null default '05:30',   -- وقت التذكير اليومي
  late_reminder_enabled boolean not null default true,       -- تذكير عند التأخّر
  late_reminder_time    time    not null default '21:00',
  theme                 text    not null default 'light',    -- light | dark | system
  locale                text    not null default 'ar',
  updated_at            timestamptz not null default now()
);

-- ───────────────────────────────────────────────────────────────────────────
-- 2) نظام الختمة الشخصية
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.khatmas (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  title        text,
  mode         text not null default 'custom' check (mode in ('idariya','custom')),
  total_days   integer not null default 21 check (total_days in (7,14,21,30)),
  start_date   date not null default current_date,
  status       text not null default 'active' check (status in ('active','completed','abandoned')),
  completed_at timestamptz,
  created_at   timestamptz not null default now()
);
-- للمثبّتين سابقاً: أضف العمود إن لم يوجد
alter table public.khatmas add column if not exists mode text not null default 'custom';
create index if not exists idx_khatmas_user on public.khatmas(user_id);
-- idariya = برنامج الختمة الإدارية الرسمي (٢١ يوماً، ٣ أحزاب/يوم عدا الجمعة حزبان)
-- custom  = مدة يحددها المستخدم مع توزيع متساوٍ للأحزاب

-- الأحزاب المقروءة داخل كل ختمة (صف لكل حزب مُنجَز)
create table if not exists public.khatma_reads (
  id         uuid primary key default gen_random_uuid(),
  khatma_id  uuid not null references public.khatmas(id) on delete cascade,
  hizb       integer not null check (hizb between 1 and 60),
  read_at    timestamptz not null default now(),
  unique (khatma_id, hizb)
);
create index if not exists idx_reads_khatma on public.khatma_reads(khatma_id);

-- ───────────────────────────────────────────────────────────────────────────
-- 3) التتبع والإحصائيات (سجل القراءة اليومي)
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.daily_activity (
  user_id       uuid not null references auth.users(id) on delete cascade,
  activity_date date not null default current_date,
  hizbs_read    integer not null default 0,
  primary key (user_id, activity_date)
);

-- ───────────────────────────────────────────────────────────────────────────
-- 4) Gamification: نقاط / إنجازات / مستويات
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.points_ledger (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  points     integer not null,
  reason     text not null,      -- hizb_read | khatma_completed | achievement | ...
  meta       jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_points_user on public.points_ledger(user_id);

create table if not exists public.achievements (
  code        text primary key,
  title       text not null,
  description text,
  icon        text,
  points      integer not null default 0,
  sort        integer not null default 0
);

create table if not exists public.user_achievements (
  user_id           uuid not null references auth.users(id) on delete cascade,
  achievement_code  text not null references public.achievements(code) on delete cascade,
  earned_at         timestamptz not null default now(),
  primary key (user_id, achievement_code)
);

-- كتالوج الإنجازات (يُحدَّث عند إعادة التشغيل)
insert into public.achievements(code,title,description,icon,points,sort) values
  ('first_hizb',    'أول حزب',        'قرأت أول حزب لك',                 '📖', 20,  1),
  ('first_khatma',  'أول ختمة',       'أكملت أول ختمة كاملة',            '🏆', 100, 2),
  ('streak_7',      'التزام أسبوع',   'واظبت على القراءة ٧ أيام متتالية', '🔥', 70,  3),
  ('streak_30',     'التزام شهر',     'واظبت على القراءة ٣٠ يوماً متتالية','🌟', 300, 4),
  ('khatma_7days',  'ختمة في أسبوع',  'أكملت ختمة مدّتها ٧ أيام',         '⚡', 150, 5),
  ('group_member',  'رفقة الخير',     'انضممت إلى مجموعة ختمة',           '🤝', 30,  6)
on conflict (code) do update
  set title=excluded.title, description=excluded.description,
      icon=excluded.icon, points=excluded.points, sort=excluded.sort;

-- ───────────────────────────────────────────────────────────────────────────
-- 5) الميزات الاجتماعية: مجموعات الختمة + الأصدقاء
-- ───────────────────────────────────────────────────────────────────────────
create or replace function public.gen_invite_code()
returns text language sql volatile as $$
  select upper(substr(md5(gen_random_uuid()::text), 1, 6));
$$;

create table if not exists public.groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  owner_id    uuid not null references auth.users(id) on delete cascade,
  invite_code text not null unique default public.gen_invite_code(),
  mode        text not null default 'custom' check (mode in ('idariya','custom')),
  total_days  integer not null default 21 check (total_days in (7,14,21,30)),
  start_date  date not null default current_date,
  status      text not null default 'active' check (status in ('active','completed','archived')),
  created_at  timestamptz not null default now()
);
alter table public.groups add column if not exists mode text not null default 'custom';
-- طور الانضمام: invite (يتغيّر الرمز بعد كل انضمام) | open (مفتوحة، رمز ثابت) | closed (مغلقة)
alter table public.groups add column if not exists join_mode text not null default 'invite';

create table if not exists public.group_members (
  group_id  uuid not null references public.groups(id) on delete cascade,
  user_id   uuid not null references auth.users(id) on delete cascade,
  role      text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index if not exists idx_group_members_user on public.group_members(user_id);
-- رتبة الاحتياطي (1..3) لعضوٍ بلا أحزاب مُسندة — يرث أحزاب من يغيب/يُحذف/يخرج
alter table public.group_members add column if not exists reserve_rank int;
create unique index if not exists uq_group_reserve_rank
  on public.group_members(group_id, reserve_rank) where reserve_rank is not null;

-- ختمة المجموعة تشاركية: كل حزب يُقرأ مرة واحدة يسجّلها أحد الأعضاء
create table if not exists public.group_reads (
  id        uuid primary key default gen_random_uuid(),
  group_id  uuid not null references public.groups(id) on delete cascade,
  hizb      integer not null check (hizb between 1 and 60),
  user_id   uuid not null references auth.users(id) on delete cascade,
  read_at   timestamptz not null default now(),
  unique (group_id, hizb)
);

create table if not exists public.friendships (
  user_id    uuid not null references auth.users(id) on delete cascade,  -- المُرسِل
  friend_id  uuid not null references auth.users(id) on delete cascade,  -- المُستقبِل
  status     text not null default 'pending' check (status in ('pending','accepted','blocked')),
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  check (user_id <> friend_id)
);

-- ───────────────────────────────────────────────────────────────────────────
-- 6) الدوال المنطقية (التوزيع / ورد اليوم / التقدّم / المستوى)
-- ───────────────────────────────────────────────────────────────────────────

-- توزيع ٦٠ حزباً على عدد الأيام بأكبر قدر من التساوي، وإرجاع أحزاب يومٍ معيّن
create or replace function public.khatma_hizbs_for_day(p_total_days int, p_day int)
returns int[] language sql immutable as $$
  select case
    when p_day < 1 or p_day > p_total_days then array[]::int[]
    else array(
      select g from generate_series(
        floor((p_day - 1) * 60.0 / p_total_days)::int + 1,
        floor(p_day       * 60.0 / p_total_days)::int
      ) g
    )
  end;
$$;

-- خوارزمية الختمة الإدارية الرسمية (منقولة من khatma_calculator.dart)
-- نقطة الارتكاز: ١ يوليو ٢٠٢٦ = الأحزاب ١٩، ٢٠، ٢١ — ٣ أحزاب/يوم عدا الجمعة (حزبان)
create or replace function public.khatma_idariya_hizbs(p_date date)
returns int[] language plpgsql immutable as $$
declare
  anchor       date := date '2026-07-01';
  anchor_first int  := 19;
  per_cycle    int  := 60;
  per_week     int  := 20;   -- 6×3 + 1×2
  days         int  := p_date - anchor;
  full_weeks   int; remaining int; cnt int := 0; i int; d date; abs_days int;
  first        int; is_fri boolean;
begin
  if days > 0 then
    full_weeks := days / 7; remaining := days % 7;      -- قسمة صحيحة تقطع نحو الصفر
    cnt := full_weeks * per_week;
    for i in 0..remaining-1 loop
      d := anchor + (full_weeks*7 + i);
      cnt := cnt + case when extract(dow from d) = 5 then 2 else 3 end;  -- الجمعة = 5
    end loop;
  elsif days < 0 then
    abs_days := -days;
    full_weeks := abs_days / 7; remaining := abs_days % 7;
    cnt := -(full_weeks * per_week);
    for i in 0..remaining-1 loop
      d := anchor - (full_weeks*7 + i + 1);
      cnt := cnt - case when extract(dow from d) = 5 then 2 else 3 end;
    end loop;
  end if;

  first  := ((anchor_first - 1 + cnt) % per_cycle + per_cycle) % per_cycle + 1;  -- modulo موجب
  is_fri := extract(dow from p_date) = 5;
  if is_fri then
    return array[first, (first % per_cycle) + 1];
  else
    return array[first, (first % per_cycle) + 1, ((first + 1) % per_cycle) + 1];
  end if;
end; $$;

-- ورد اليوم لختمة معيّنة — يفرّق حسب الوضع (رسمي / مخصّص)
create or replace function public.khatma_today_hizbs(p_khatma uuid, p_today date default current_date)
returns int[] language plpgsql stable as $$
declare k record;
begin
  select mode, total_days, start_date into k from public.khatmas where id = p_khatma;
  if not found then return array[]::int[]; end if;
  if k.mode = 'idariya' then
    return public.khatma_idariya_hizbs(p_today);
  else
    return public.khatma_hizbs_for_day(k.total_days, (p_today - k.start_date)::int + 1);
  end if;
end; $$;

-- المستوى من مجموع النقاط: 0-99→1، 100-399→2، 400-899→3 ...
create or replace function public.level_for_points(p int)
returns int language sql immutable as $$
  select greatest(1, floor(sqrt(greatest(p,0)::numeric / 100)) + 1)::int;
$$;

-- منح إنجاز مع نقاطه (مرة واحدة)
create or replace function public.grant_achievement(p_user uuid, p_code text)
returns void language plpgsql security definer set search_path = public as $$
declare v_pts int;
begin
  insert into user_achievements(user_id, achievement_code)
  values (p_user, p_code) on conflict do nothing;
  if found then
    select points into v_pts from achievements where code = p_code;
    if coalesce(v_pts,0) > 0 then
      insert into points_ledger(user_id, points, reason, meta)
      values (p_user, v_pts, 'achievement', jsonb_build_object('code', p_code));
      update profiles
        set total_points = total_points + v_pts,
            current_level = level_for_points(total_points + v_pts)
      where id = p_user;
    end if;
  end if;
end; $$;

-- ───────────────────────────────────────────────────────────────────────────
-- 7) الدالة الرئيسية: تسجيل قراءة حزب (نقاط + streak + إنجازات + إكمال)
--     يستدعيها التطبيق: supabase.rpc('record_hizb_read', {p_khatma, p_hizb})
-- ───────────────────────────────────────────────────────────────────────────
create or replace function public.record_hizb_read(p_khatma uuid, p_hizb int)
returns json language plpgsql security definer set search_path = public as $$
declare
  v_user   uuid := auth.uid();
  v_owner  uuid;
  v_rows   int;
  v_new    boolean;
  v_count  int;
  v_today  date := current_date;
  v_last   date;
  v_streak int;
  v_long   int;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if p_hizb < 1 or p_hizb > 60 then raise exception 'invalid hizb'; end if;

  select user_id into v_owner from khatmas where id = p_khatma;
  if v_owner is null then raise exception 'khatma not found'; end if;
  if v_owner <> v_user then raise exception 'forbidden'; end if;

  insert into khatma_reads(khatma_id, hizb) values (p_khatma, p_hizb)
    on conflict (khatma_id, hizb) do nothing;
  get diagnostics v_rows = row_count;
  v_new := v_rows > 0;

  if v_new then
    -- سجل القراءة اليومي
    insert into daily_activity(user_id, activity_date, hizbs_read)
      values (v_user, v_today, 1)
      on conflict (user_id, activity_date)
      do update set hizbs_read = daily_activity.hizbs_read + 1;

    -- streak: يُحدَّث عند دخول يومٍ جديد فقط
    select last_active_date, current_streak, longest_streak
      into v_last, v_streak, v_long from profiles where id = v_user;
    if v_last is null or v_last < v_today then
      v_streak := case when v_last = v_today - 1 then coalesce(v_streak,0) + 1 else 1 end;
      v_long   := greatest(coalesce(v_long,0), v_streak);
      update profiles set last_active_date = v_today,
                          current_streak = v_streak, longest_streak = v_long
        where id = v_user;
    end if;

    -- النقاط (١٠ لكل حزب)
    insert into points_ledger(user_id, points, reason, meta)
      values (v_user, 10, 'hizb_read', jsonb_build_object('khatma', p_khatma, 'hizb', p_hizb));
    update profiles set total_points = total_points + 10,
                        current_level = level_for_points(total_points + 10)
      where id = v_user;

    perform public.grant_achievement(v_user, 'first_hizb');
    select current_streak into v_streak from profiles where id = v_user;
    if v_streak >= 7  then perform public.grant_achievement(v_user, 'streak_7');  end if;
    if v_streak >= 30 then perform public.grant_achievement(v_user, 'streak_30'); end if;
  end if;

  select count(*) into v_count from khatma_reads where khatma_id = p_khatma;

  -- إكمال الختمة
  if v_count >= 60 then
    update khatmas set status = 'completed', completed_at = now()
      where id = p_khatma and status <> 'completed';
    if found then
      insert into points_ledger(user_id, points, reason, meta)
        values (v_user, 100, 'khatma_completed', jsonb_build_object('khatma', p_khatma));
      update profiles set total_points = total_points + 100,
                          current_level = level_for_points(total_points + 100)
        where id = v_user;
      perform public.grant_achievement(v_user, 'first_khatma');
      if (select total_days from khatmas where id = p_khatma) = 7 then
        perform public.grant_achievement(v_user, 'khatma_7days');
      end if;
    end if;
  end if;

  return json_build_object(
    'hizbs_read', v_count,
    'percent', round(v_count * 100.0 / 60, 1),
    'newly_read', v_new,
    'completed', v_count >= 60
  );
end; $$;

-- إلغاء تسجيل حزب (في حال الخطأ)
create or replace function public.unrecord_hizb_read(p_khatma uuid, p_hizb int)
returns void language plpgsql security definer set search_path = public as $$
begin
  if (select user_id from khatmas where id = p_khatma) <> auth.uid() then
    raise exception 'forbidden';
  end if;
  delete from khatma_reads where khatma_id = p_khatma and hizb = p_hizb;
end; $$;

-- ───────────────────────────────────────────────────────────────────────────
-- 8) دوال المجموعات (انضمام / تسجيل حزب جماعي)
-- ───────────────────────────────────────────────────────────────────────────
create or replace function public.is_group_member(p_group uuid, p_user uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from group_members where group_id = p_group and user_id = p_user);
$$;

create or replace function public.create_group(
  p_name text, p_mode text default 'custom',
  p_total_days int default 21, p_start date default current_date)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  -- منع إنشاء مجموعة جديدة إذا كان لدى المستخدم مجموعة غير مكتملة (أقل من 10 أعضاء)
  if exists (
    select 1 from groups g
    where g.owner_id = auth.uid()
      and (select count(*) from group_members m where m.group_id = g.id) < 10
  ) then
    raise exception 'incomplete group exists: complete your current group (10 members) first';
  end if;
  -- المجموعة الجديدة مفتوحة للجميع افتراضياً (رمز ثابت، عدة أشخاص ينضمون)
  insert into groups(name, owner_id, mode, total_days, start_date, join_mode)
    values (p_name, auth.uid(), p_mode, p_total_days, p_start, 'open') returning id into v_id;
  insert into group_members(group_id, user_id, role) values (v_id, auth.uid(), 'owner');
  return v_id;
end; $$;

-- أحزاب اليوم لعضوٍ معيّن في المجموعة: تُوزَّع أحزاب اليوم على الأعضاء بالتناوب،
-- فتُكمل المجموعةُ ختمةً كاملة (٦٠ حزباً) خلال المدة، ويرى كلُّ عضوٍ نصيبه اليوم.
create or replace function public.group_member_today_hizbs(
  p_group uuid, p_user uuid, p_today date default current_date)
returns int[] language plpgsql stable set search_path = public as $$
declare
  g record; n int; m int; day_index int; pool int[]; res int[] := '{}'; i int;
begin
  select mode, total_days, start_date into g from groups where id = p_group;
  if not found then return '{}'; end if;

  select count(*) into n from group_members where group_id = p_group;
  select idx into m from (
    select user_id, (row_number() over (order by joined_at, user_id) - 1)::int as idx
    from group_members where group_id = p_group
  ) t where t.user_id = p_user;
  if m is null or coalesce(n,0) = 0 then return '{}'; end if;

  if g.mode = 'idariya' then
    pool := public.khatma_idariya_hizbs(p_today);
  else
    day_index := (p_today - g.start_date)::int + 1;
    pool := public.khatma_hizbs_for_day(g.total_days, day_index);
  end if;

  for i in 1..coalesce(array_length(pool,1),0) loop
    if ((i - 1) % n) = m then res := res || pool[i]; end if;
  end loop;
  return res;
end; $$;

-- توزيع اليوم لكل أعضاء المجموعة (يُظهر لكل عضوٍ حزبه اليوم + مستواه وتتابعه)
drop function if exists public.group_today_assignments(uuid, date);
drop function if exists public.group_today_assignments(uuid, date);
create or replace function public.group_today_assignments(p_group uuid, p_today date default current_date)
returns table(user_id uuid, display_name text, avatar_url text, hizbs int[], level int, streak int, reserve_rank int)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_group_member(p_group, auth.uid()) then raise exception 'not a member'; end if;
  return query
    select gm.user_id,
           coalesce(
             nullif(p.display_name, ''),
             nullif(u.raw_user_meta_data->>'full_name', ''),
             nullif(u.raw_user_meta_data->>'name', ''),
             nullif(p.full_name, ''),
             'عضو'
           ) as display_name,
           coalesce(nullif(p.avatar_url, ''),
                    u.raw_user_meta_data->>'avatar_url',
                    u.raw_user_meta_data->>'picture') as avatar_url,
           public.group_member_today_hizbs(p_group, gm.user_id, p_today),
           coalesce(p.current_level, 1),
           coalesce(p.current_streak, 0),
           gm.reserve_rank
    from group_members gm
    join profiles p on p.id = gm.user_id
    join auth.users u on u.id = gm.user_id
    where gm.group_id = p_group
    order by gm.joined_at, gm.user_id;
end; $$;

-- تحرير أحزاب عضو مغادر: تُسند أولاً إلى الاحتياطي الأول (ثم يُرقّى ويُقلَّص الباقي)،
-- وإن لم يوجد احتياطي تبقى في المجمّع (غير مسندة).
create or replace function public.free_hizbs_to_reserve(p_group uuid, p_user uuid)
returns int language plpgsql security definer set search_path = public as $$
declare v_hizbs int[]; v_res uuid; v_rank int; v_n int;
begin
  -- الأحزاب غير المقروءة المسندة للعضو
  select array_agg(a.hizb) into v_hizbs
    from group_hizb_assignment a
    where a.group_id = p_group and a.user_id = p_user
      and not exists (select 1 from group_reads r where r.group_id = p_group and r.hizb = a.hizb);
  delete from group_hizb_assignment a
    where a.group_id = p_group and a.user_id = p_user
      and not exists (select 1 from group_reads r where r.group_id = p_group and r.hizb = a.hizb);
  v_n := coalesce(array_length(v_hizbs, 1), 0);
  if v_n = 0 then return 0; end if;

  -- الاحتياطي الأول (أقل رتبة)
  select user_id, reserve_rank into v_res, v_rank
    from group_members where group_id = p_group and reserve_rank is not null
    order by reserve_rank limit 1;

  if v_res is null then
    return v_n;  -- لا احتياطي: تبقى في المجمّع
  end if;

  -- أسند كل الأحزاب المحرّرة للاحتياطي
  insert into group_hizb_assignment(group_id, hizb, user_id)
    select p_group, h, v_res from unnest(v_hizbs) as h
    on conflict (group_id, hizb) do update set user_id = excluded.user_id;
  -- رُفعت عنه صفة الاحتياطي + تقليص رتب الأعلى (2→1، 3→2 ... والأخيرة تشغر)
  update group_members set reserve_rank = null where group_id = p_group and user_id = v_res;
  update group_members set reserve_rank = reserve_rank - 1
    where group_id = p_group and reserve_rank is not null and reserve_rank > v_rank;
  return v_n;
end; $$;

-- المؤسس: تعيين/إلغاء رتبة احتياطي لعضو بلا أحزاب (p_rank = null للإلغاء)
create or replace function public.set_group_reserve(p_group uuid, p_user uuid, p_rank int)
returns void language plpgsql security definer set search_path = public as $$
declare v_owner uuid;
begin
  select owner_id into v_owner from groups where id = p_group;
  if v_owner is null then raise exception 'group not found'; end if;
  if v_owner <> auth.uid() then raise exception 'forbidden'; end if;
  if not public.is_group_member(p_group, p_user) then raise exception 'not a member'; end if;
  if p_rank is not null then
    if p_rank < 1 or p_rank > 3 then raise exception 'invalid rank'; end if;
    if exists (select 1 from group_hizb_assignment a where a.group_id = p_group and a.user_id = p_user) then
      raise exception 'reserve must have no assigned hizbs';
    end if;
    -- حرّر الرتبة إن كانت مشغولة بعضو آخر
    update group_members set reserve_rank = null where group_id = p_group and reserve_rank = p_rank;
  end if;
  update group_members set reserve_rank = p_rank where group_id = p_group and user_id = p_user;
end; $$;
grant execute on function public.set_group_reserve(uuid, uuid, int) to authenticated;

-- حذف عضو من المجموعة (للمالك فقط) — أحزابه تنتقل للاحتياطي أولاً
create or replace function public.remove_group_member(p_group uuid, p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_owner uuid;
begin
  select owner_id into v_owner from groups where id = p_group;
  if v_owner is null then raise exception 'group not found'; end if;
  if v_owner <> auth.uid() then raise exception 'forbidden'; end if;
  if p_user = v_owner then raise exception 'cannot remove owner'; end if;
  perform public.free_hizbs_to_reserve(p_group, p_user);
  delete from group_members where group_id = p_group and user_id = p_user;
end; $$;
grant execute on function public.remove_group_member(uuid, uuid) to authenticated;

-- خروج العضو من المجموعة — أحزابه تنتقل للاحتياطي أولاً
create or replace function public.leave_group(p_group uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_owner uuid;
begin
  select owner_id into v_owner from groups where id = p_group;
  if v_owner = auth.uid() then raise exception 'owner cannot leave; delete the group instead'; end if;
  perform public.free_hizbs_to_reserve(p_group, auth.uid());
  delete from group_members where group_id = p_group and user_id = auth.uid();
end; $$;
grant execute on function public.leave_group(uuid) to authenticated;

create or replace function public.join_group(p_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_new text; rows int; v_cap int; v_mode text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select id, join_mode into v_id, v_mode from groups where invite_code = upper(trim(p_code));
  if v_id is null then raise exception 'invalid invite code'; end if;
  if v_mode = 'closed' then raise exception 'group closed'; end if;
  insert into group_members(group_id, user_id) values (v_id, auth.uid())
    on conflict do nothing;
  get diagnostics rows = row_count;
  if rows > 0 then
    perform public.grant_achievement(auth.uid(), 'group_member');
    -- إسناد أحزاب للعضو الجديد من المجمّع (غير المسندة) حسب الحد الأقصى للدورة النشطة
    select max_per_member into v_cap
      from group_cycles where group_id = v_id and status = 'active' limit 1;
    if v_cap is not null and v_cap > 0 then
      insert into group_hizb_assignment(group_id, hizb, user_id)
        select v_id, h, auth.uid()
        from generate_series(1, 60) as h
        where not exists (select 1 from group_hizb_assignment a where a.group_id = v_id and a.hizb = h)
        order by h
        limit v_cap
        on conflict do nothing;
    end if;
    -- في طور «بدعوة» فقط: توليد رمز جديد ليبطُل الرمز السابق. أما «مفتوحة» فالرمز ثابت.
    if v_mode = 'invite' then
      loop
        v_new := public.gen_invite_code();
        exit when not exists (select 1 from groups where invite_code = v_new);
      end loop;
      update groups set invite_code = v_new where id = v_id;
    end if;
  end if;
  return v_id;
end; $$;

-- المؤسس: تغيير طور الانضمام (invite | open | closed)
create or replace function public.set_group_join_mode(p_group uuid, p_mode text)
returns void language plpgsql security definer set search_path = public as $$
declare v_owner uuid;
begin
  select owner_id into v_owner from groups where id = p_group;
  if v_owner is null then raise exception 'group not found'; end if;
  if v_owner <> auth.uid() then raise exception 'forbidden'; end if;
  if p_mode not in ('open','closed','invite') then raise exception 'invalid mode'; end if;
  update groups set join_mode = p_mode where id = p_group;
end; $$;
grant execute on function public.set_group_join_mode(uuid, text) to authenticated;

create or replace function public.record_group_hizb_read(p_group uuid, p_hizb int)
returns json language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_rows int; v_count int;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if not public.is_group_member(p_group, v_user) then raise exception 'not a member'; end if;
  if p_hizb < 1 or p_hizb > 60 then raise exception 'invalid hizb'; end if;

  insert into group_reads(group_id, hizb, user_id) values (p_group, p_hizb, v_user)
    on conflict (group_id, hizb) do nothing;
  get diagnostics v_rows = row_count;
  if v_rows > 0 then
    insert into points_ledger(user_id, points, reason, meta)
      values (v_user, 10, 'group_hizb_read', jsonb_build_object('group', p_group, 'hizb', p_hizb));
    update profiles set total_points = total_points + 10,
                        current_level = level_for_points(total_points + 10)
      where id = v_user;
  end if;

  select count(*) into v_count from group_reads where group_id = p_group;
  if v_count >= 60 then
    update groups set status = 'completed' where id = p_group and status <> 'completed';
  end if;
  return json_build_object('hizbs_read', v_count, 'percent', round(v_count*100.0/60,1));
end; $$;

-- ───────────────────────────────────────────────────────────────────────────
-- 9) الإنشاء التلقائي للملف الشخصي عند التسجيل
-- ───────────────────────────────────────────────────────────────────────────
-- ملاحظة: جدول profiles مشترك مع تطبيق آخر ويتطلب phone و full_name (NOT NULL).
-- لذا نملأ الحقول المطلوبة، ونجعل المُشغِّل لا يُفشل التسجيل أبداً (exception → return new).
-- الاسم مخصّص (khatma_) تفادياً للتصادم مع أي مُشغِّل قائم باسم handle_new_user.
create or replace function public.khatma_handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_name text := coalesce(
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'name',
    nullif(split_part(coalesce(new.email,''), '@', 1), ''),
    'مستخدم');
begin
  insert into public.profiles (id, phone, full_name, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.phone, 'u_' || replace(new.id::text, '-', '')),  -- بديل فريد (phone مطلوب وفريد)
    v_name, v_name,
    new.raw_user_meta_data->>'avatar_url'
  ) on conflict (id) do nothing;
  insert into public.user_settings (user_id) values (new.id) on conflict do nothing;
  return new;
exception when others then
  return new;  -- لا تُعطّل التسجيل مهما حدث
end; $$;

drop trigger if exists on_auth_user_created_khatma on auth.users;
create trigger on_auth_user_created_khatma
  after insert on auth.users
  for each row execute function public.khatma_handle_new_user();

-- ───────────────────────────────────────────────────────────────────────────
-- 10) المشاهدات (Views) — للتقدّم والإحصائيات
-- ───────────────────────────────────────────────────────────────────────────
create or replace view public.v_khatma_progress
  with (security_invoker = true) as
select k.id as khatma_id, k.user_id, k.title, k.total_days, k.start_date, k.status,
       count(r.hizb) as hizbs_read,
       round(count(r.hizb) * 100.0 / 60, 1) as percent,
       greatest(1, (current_date - k.start_date)::int + 1) as day_index
from public.khatmas k
left join public.khatma_reads r on r.khatma_id = k.id
group by k.id;

create or replace view public.v_user_stats
  with (security_invoker = true) as
select p.id as user_id, p.display_name, p.total_points, p.current_level,
       p.current_streak, p.longest_streak,
       (select count(*) from public.khatmas k where k.user_id = p.id and k.status = 'completed') as completed_khatmas,
       (select count(*) from public.daily_activity d where d.user_id = p.id) as active_days,
       (select coalesce(sum(d.hizbs_read),0) from public.daily_activity d where d.user_id = p.id) as total_hizbs_read
from public.profiles p;

-- ملاحظة: نستخدم استعلامات فرعية مستقلة لتفادي الضرب التصالبي
-- (join بين group_members و group_reads كان يضاعف عدد الأحزاب المقروءة × عدد الأعضاء)
create or replace view public.v_group_progress
  with (security_invoker = true) as
select g.id as group_id, g.name, g.total_days, g.start_date, g.status,
       (select count(*) from public.group_members gm where gm.group_id = g.id) as members,
       (select count(*) from public.group_reads gr where gr.group_id = g.id) as hizbs_read,
       round((select count(*) from public.group_reads gr where gr.group_id = g.id) * 100.0 / 60, 1) as percent
from public.groups g;

-- ───────────────────────────────────────────────────────────────────────────
-- 11) تأمين الصفوف (Row Level Security) + السياسات
-- ───────────────────────────────────────────────────────────────────────────
alter table public.profiles          enable row level security;
alter table public.user_settings     enable row level security;
alter table public.khatmas           enable row level security;
alter table public.khatma_reads      enable row level security;
alter table public.daily_activity    enable row level security;
alter table public.points_ledger     enable row level security;
alter table public.achievements      enable row level security;
alter table public.user_achievements enable row level security;
alter table public.groups            enable row level security;
alter table public.group_members     enable row level security;
alter table public.group_reads       enable row level security;
alter table public.friendships       enable row level security;

-- profiles: قراءة عامة (لعرض أسماء المشاركين)، تعديل الذات فقط
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated using (true);
drop policy if exists profiles_upsert on public.profiles;
create policy profiles_upsert on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- user_settings: الذات فقط
drop policy if exists settings_all on public.user_settings;
create policy settings_all on public.user_settings for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- khatmas: الذات فقط
drop policy if exists khatmas_all on public.khatmas;
create policy khatmas_all on public.khatmas for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- khatma_reads: عبر ملكية الختمة
drop policy if exists reads_select on public.khatma_reads;
create policy reads_select on public.khatma_reads for select to authenticated
  using (exists (select 1 from public.khatmas k where k.id = khatma_id and k.user_id = auth.uid()));
drop policy if exists reads_write on public.khatma_reads;
create policy reads_write on public.khatma_reads for all to authenticated
  using (exists (select 1 from public.khatmas k where k.id = khatma_id and k.user_id = auth.uid()))
  with check (exists (select 1 from public.khatmas k where k.id = khatma_id and k.user_id = auth.uid()));

-- daily_activity / points / user_achievements: قراءة الذات (الكتابة عبر الدوال)
drop policy if exists activity_select on public.daily_activity;
create policy activity_select on public.daily_activity for select to authenticated using (user_id = auth.uid());
drop policy if exists points_select on public.points_ledger;
create policy points_select on public.points_ledger for select to authenticated using (user_id = auth.uid());
drop policy if exists ua_select on public.user_achievements;
create policy ua_select on public.user_achievements for select to authenticated using (user_id = auth.uid());

-- achievements: كتالوج عام للقراءة
drop policy if exists ach_read on public.achievements;
create policy ach_read on public.achievements for select to authenticated using (true);

-- groups: يراها الأعضاء؛ الإنشاء للجميع؛ التعديل/الحذف للمالك
drop policy if exists groups_select on public.groups;
create policy groups_select on public.groups for select to authenticated
  using (owner_id = auth.uid() or public.is_group_member(id, auth.uid()));
drop policy if exists groups_insert on public.groups;
create policy groups_insert on public.groups for insert to authenticated with check (owner_id = auth.uid());
drop policy if exists groups_update on public.groups;
create policy groups_update on public.groups for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
drop policy if exists groups_delete on public.groups;
create policy groups_delete on public.groups for delete to authenticated using (owner_id = auth.uid());

-- group_members: يراها الأعضاء؛ يمكن للعضو مغادرة نفسه
drop policy if exists gm_select on public.group_members;
create policy gm_select on public.group_members for select to authenticated
  using (public.is_group_member(group_id, auth.uid()));
drop policy if exists gm_leave on public.group_members;
create policy gm_leave on public.group_members for delete to authenticated using (user_id = auth.uid());

-- group_reads: يراها الأعضاء (الكتابة عبر الدالة)
drop policy if exists gr_select on public.group_reads;
create policy gr_select on public.group_reads for select to authenticated
  using (public.is_group_member(group_id, auth.uid()));

-- friendships: يراها ويديرها طرفاها
drop policy if exists fr_select on public.friendships;
create policy fr_select on public.friendships for select to authenticated
  using (user_id = auth.uid() or friend_id = auth.uid());
drop policy if exists fr_insert on public.friendships;
create policy fr_insert on public.friendships for insert to authenticated with check (user_id = auth.uid());
drop policy if exists fr_update on public.friendships;
create policy fr_update on public.friendships for update to authenticated
  using (user_id = auth.uid() or friend_id = auth.uid())
  with check (user_id = auth.uid() or friend_id = auth.uid());
drop policy if exists fr_delete on public.friendships;
create policy fr_delete on public.friendships for delete to authenticated
  using (user_id = auth.uid() or friend_id = auth.uid());

-- ───────────────────────────────────────────────────────────────────────────
-- 12) حذف الحساب وكل بياناته (زر "حذف الحساب" داخل التطبيق)
-- ───────────────────────────────────────────────────────────────────────────
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public, auth as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not authenticated'; end if;
  delete from public.khatma_reads where khatma_id in (select id from public.khatmas where user_id = uid);
  delete from public.khatmas           where user_id = uid;
  delete from public.daily_activity    where user_id = uid;
  delete from public.points_ledger     where user_id = uid;
  delete from public.user_achievements where user_id = uid;
  delete from public.group_reads       where user_id = uid;
  delete from public.group_members     where user_id = uid;
  delete from public.groups            where owner_id = uid;
  delete from public.friendships       where user_id = uid or friend_id = uid;
  delete from public.user_settings     where user_id = uid;
  delete from public.profiles          where id = uid;
  delete from auth.users where id = uid;   -- حساب المصادقة (Google/Facebook/Apple)
end; $$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- ───────────────────────────────────────────────────────────────────────────
-- 13) سجل الورد اليومي (الختمة الإدارية) + التتابع + عدد المشاركين اليوم
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.wird_log (
  user_id    uuid not null references auth.users(id) on delete cascade,
  log_date   date not null default current_date,
  item       text not null,              -- 'hizb:NN' أو 'kahf'
  created_at timestamptz not null default now(),
  primary key (user_id, log_date, item)
);
create index if not exists idx_wird_date on public.wird_log(log_date);

alter table public.wird_log enable row level security;
drop policy if exists wird_own on public.wird_log;
create policy wird_own on public.wird_log for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- تسجيل قراءة عنصر الورد (حزب أو الكهف) — يحدّث التتابع والنقاط
create or replace function public.record_wird(p_item text, p_date date default current_date)
returns json language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); rows int; first_today boolean;
        v_last date; v_streak int; v_long int;
begin
  if uid is null then raise exception 'not authenticated'; end if;
  insert into wird_log(user_id, log_date, item) values (uid, p_date, p_item)
    on conflict do nothing;
  get diagnostics rows = row_count;
  if rows > 0 then
    select count(*) = 1 into first_today from wird_log where user_id = uid and log_date = p_date;
    insert into daily_activity(user_id, activity_date, hizbs_read) values (uid, p_date, 1)
      on conflict (user_id, activity_date) do update set hizbs_read = daily_activity.hizbs_read + 1;
    if first_today then
      select last_active_date, current_streak, longest_streak into v_last, v_streak, v_long
        from profiles where id = uid;
      if v_last is null or v_last < p_date then
        v_streak := case when v_last = p_date - 1 then coalesce(v_streak,0) + 1 else 1 end;
        v_long   := greatest(coalesce(v_long,0), v_streak);
        update profiles set last_active_date = p_date, current_streak = v_streak, longest_streak = v_long
          where id = uid;
      end if;
    end if;
    insert into points_ledger(user_id, points, reason, meta)
      values (uid, 10, 'wird', jsonb_build_object('item', p_item, 'date', p_date));
    update profiles set total_points = total_points + 10,
                        current_level = level_for_points(total_points + 10) where id = uid;
    perform public.grant_achievement(uid, 'first_hizb');
    select current_streak into v_streak from profiles where id = uid;
    if v_streak >= 7  then perform public.grant_achievement(uid, 'streak_7');  end if;
    if v_streak >= 30 then perform public.grant_achievement(uid, 'streak_30'); end if;
  end if;
  return json_build_object('ok', true);
end; $$;

create or replace function public.unrecord_wird(p_item text, p_date date default current_date)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from wird_log where user_id = auth.uid() and log_date = p_date and item = p_item;
end; $$;

create or replace function public.wird_today(p_date date default current_date)
returns setof text language sql security definer set search_path = public stable as $$
  select item from wird_log where user_id = auth.uid() and log_date = p_date;
$$;

-- عدد المشاركين اليوم (عام — يظهر في الرئيسية دون تسجيل دخول)
-- عدد المشاركين اليوم: كل من قرأ حزباً اليوم — في ختمة الإدارة (wird_log)
-- أو في أي ختمة من ختمات المجموعات (group_reads) — بلا تكرار
create or replace function public.todays_participants(p_date date default current_date)
returns int language sql security definer set search_path = public stable as $$
  select count(*)::int from (
    select user_id from wird_log    where log_date = p_date
    union
    select user_id from group_reads where read_at::date = p_date
  ) u;
$$;

-- المشاركون اليوم مفصّلين: ختمة الإدارة (idara) والمجموعات (groups)
create or replace function public.todays_participants_split(p_date date default current_date)
returns json language sql security definer set search_path = public stable as $$
  select json_build_object(
    'idara',  (select count(distinct user_id)::int from wird_log    where log_date = p_date),
    'groups', (select count(distinct user_id)::int from group_reads where read_at::date = p_date)
  );
$$;

revoke all on function public.record_wird(text, date)   from public;
revoke all on function public.unrecord_wird(text, date) from public;
grant execute on function public.record_wird(text, date)      to authenticated;
grant execute on function public.unrecord_wird(text, date)    to authenticated;
grant execute on function public.wird_today(date)             to authenticated;
grant execute on function public.todays_participants(date)    to anon, authenticated;

-- عدد المشاركين في ختمة الإدارة لكل فترة [start,end] — يُمرَّر مصفوفة فترات
-- p_ranges = [["2026-06-11","2026-07-01"], ...] ويُرجع [عدد, ...]
create or replace function public.khatma_period_participants(p_ranges jsonb)
returns int[] language plpgsql stable security definer set search_path = public as $$
declare r jsonb; res int[] := '{}'; c int;
begin
  for r in select * from jsonb_array_elements(p_ranges) loop
    select count(distinct user_id) into c from wird_log
      where log_date >= (r->>0)::date and log_date <= (r->>1)::date;
    res := array_append(res, c);
  end loop;
  return res;
end; $$;
grant execute on function public.khatma_period_participants(jsonb) to anon, authenticated;
grant execute on function public.todays_participants_split(date) to anon, authenticated;

-- ───────────────────────────────────────────────────────────────────────────
-- 14) توليد رمز دعوة جديد للمجموعة (للمالك فقط) — فريد لا يتصادم مع مجموعة أخرى
-- ───────────────────────────────────────────────────────────────────────────
create or replace function public.regenerate_group_code(p_group uuid)
returns text language plpgsql security definer set search_path = public as $$
declare v_owner uuid; v_code text;
begin
  select owner_id into v_owner from groups where id = p_group;
  if v_owner is null then raise exception 'group not found'; end if;
  if v_owner <> auth.uid() then raise exception 'forbidden'; end if;
  loop
    v_code := public.gen_invite_code();
    exit when not exists (select 1 from groups where invite_code = v_code);
  end loop;
  update groups set invite_code = v_code where id = p_group;
  return v_code;
end; $$;
grant execute on function public.regenerate_group_code(uuid) to authenticated;

-- ───────────────────────────────────────────────────────────────────────────
-- 15) توزيع الأحزاب بين الأعضاء (تعيين دائم لكل حزب لعضو) — يديره المؤسس
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.group_hizb_assignment (
  group_id uuid not null references public.groups(id) on delete cascade,
  hizb     int  not null check (hizb between 1 and 60),
  user_id  uuid not null references auth.users(id) on delete cascade,
  primary key (group_id, hizb)
);
create index if not exists idx_gha_group on public.group_hizb_assignment(group_id);

alter table public.group_hizb_assignment enable row level security;
drop policy if exists gha_select on public.group_hizb_assignment;
create policy gha_select on public.group_hizb_assignment for select to authenticated
  using (public.is_group_member(group_id, auth.uid()));

-- المؤسس: يُسند حزباً لعضو، أو (p_user = null) يعيده إلى المجمّع (pool)
-- إعادة ترقيم رتب الاحتياطي إلى 1،2،3 بلا فجوات (بعد إزالة أحدهم)
create or replace function public.compact_group_reserves(p_group uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  with ranked as (
    select user_id, row_number() over (order by reserve_rank) as rn
    from group_members where group_id = p_group and reserve_rank is not null
  )
  update group_members gm set reserve_rank = r.rn
  from ranked r
  where gm.group_id = p_group and gm.user_id = r.user_id and gm.reserve_rank <> r.rn;
end; $$;

create or replace function public.set_hizb_assignment(p_group uuid, p_hizb int, p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_owner uuid;
begin
  select owner_id into v_owner from groups where id = p_group;
  if v_owner is null then raise exception 'group not found'; end if;
  if v_owner <> auth.uid() then raise exception 'forbidden'; end if;
  if p_hizb < 1 or p_hizb > 60 then raise exception 'invalid hizb'; end if;
  -- يُمنع تغيير إسناد حزب تمت قراءته فقط (يبقى التوزيع اليدوي متاحاً لغير المقروء والمجمّع)
  if exists (select 1 from group_reads where group_id = p_group and hizb = p_hizb) then
    raise exception 'hizb already read';
  end if;
  if p_user is null then
    delete from group_hizb_assignment where group_id = p_group and hizb = p_hizb;
  else
    if not public.is_group_member(p_group, p_user) then raise exception 'not a member'; end if;
    insert into group_hizb_assignment(group_id, hizb, user_id)
      values (p_group, p_hizb, p_user)
      on conflict (group_id, hizb) do update set user_id = excluded.user_id;
    -- إسناد حزب لعضو كان احتياطياً يُلغي صفة الاحتياطي عنه، ثم نُعيد ترقيم الباقين
    update group_members set reserve_rank = null
      where group_id = p_group and user_id = p_user and reserve_rank is not null;
    perform public.compact_group_reserves(p_group);
  end if;
end; $$;
grant execute on function public.set_hizb_assignment(uuid, int, uuid) to authenticated;

-- العضو يُسند لنفسه حزباً غير مُسند (غير مقروء) بحد أقصى للدورة (أو 6)
create or replace function public.self_assign_hizb(p_group uuid, p_hizb int)
returns void language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_cap int; v_count int;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if not public.is_group_member(p_group, v_uid) then raise exception 'not a member'; end if;
  if p_hizb < 1 or p_hizb > 60 then raise exception 'invalid hizb'; end if;
  if exists (select 1 from group_hizb_assignment where group_id = p_group and hizb = p_hizb) then
    raise exception 'hizb already assigned';
  end if;
  if exists (select 1 from group_reads where group_id = p_group and hizb = p_hizb) then
    raise exception 'hizb already read';
  end if;
  v_cap := coalesce((select max_per_member from group_cycles where group_id = p_group and status = 'active' limit 1), 6);
  select count(*) into v_count from group_hizb_assignment where group_id = p_group and user_id = v_uid;
  if v_count >= v_cap then raise exception 'max reached'; end if;
  insert into group_hizb_assignment(group_id, hizb, user_id) values (p_group, p_hizb, v_uid);
  update group_members set reserve_rank = null where group_id = p_group and user_id = v_uid and reserve_rank is not null;
  perform public.compact_group_reserves(p_group);
end; $$;
grant execute on function public.self_assign_hizb(uuid, int) to authenticated;

-- ── تنبيهات المؤسس للأعضاء المتأخرين (حد أقصى 3 لكل عضو في الدورة) ──
create table if not exists public.group_reminders (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references public.groups(id) on delete cascade,
  cycle_id   uuid not null references public.group_cycles(id) on delete cascade,
  to_user    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists idx_group_reminders on public.group_reminders(group_id, cycle_id, to_user);
alter table public.group_reminders enable row level security;
drop policy if exists gr_sel on public.group_reminders;
create policy gr_sel on public.group_reminders for select to authenticated
  using (public.is_group_member(group_id, auth.uid()));

-- المؤسس يرسل تنبيهاً لعضو بإتمام قراءته (حد 3 لكل عضو في الدورة) + إشعار — يُرجع العدد الجديد
create or replace function public.remind_member(p_group uuid, p_user uuid)
returns int language plpgsql security definer set search_path = public as $$
declare v_owner uuid; v_cycle uuid; v_count int;
begin
  select owner_id into v_owner from groups where id = p_group;
  if v_owner is null then raise exception 'group not found'; end if;
  if v_owner <> auth.uid() then raise exception 'forbidden'; end if;
  if not public.is_group_member(p_group, p_user) then raise exception 'not a member'; end if;
  select id into v_cycle from group_cycles where group_id = p_group and status = 'active' limit 1;
  if v_cycle is null then raise exception 'no active cycle'; end if;
  select count(*) into v_count from group_reminders where cycle_id = v_cycle and to_user = p_user;
  if v_count >= 3 then raise exception 'reminder limit reached'; end if;
  insert into group_reminders(group_id, cycle_id, to_user) values (p_group, v_cycle, p_user);
  perform public.push_notify(array[p_user],
    'تذكير من مؤسس المجموعة ⏰',
    'يرجى إتمام قراءة أحزابك المسندة إليك في مجموعة «' || public.group_name(p_group) || '».');
  return v_count + 1;
end; $$;
grant execute on function public.remind_member(uuid, uuid) to authenticated;

-- تنبيهات عضو في الدورة الحالية (للعرض بالتاريخ والوقت)
create or replace function public.member_reminders(p_group uuid, p_user uuid)
returns setof timestamptz language sql stable security definer set search_path = public as $$
  select gr.created_at from group_reminders gr
  join group_cycles c on c.id = gr.cycle_id and c.status = 'active'
  where gr.group_id = p_group and gr.to_user = p_user
    and public.is_group_member(p_group, auth.uid())
  order by gr.created_at desc;
$$;
grant execute on function public.member_reminders(uuid, uuid) to authenticated;

-- المؤسس: تحديد عضو كغائب — أحزابه غير المقروءة تنتقل للاحتياطي أولاً، وإلا للمجمّع
create or replace function public.mark_member_absent(p_group uuid, p_user uuid)
returns int language plpgsql security definer set search_path = public as $$
declare v_owner uuid; v_freed int;
begin
  select owner_id into v_owner from groups where id = p_group;
  if v_owner is null then raise exception 'group not found'; end if;
  if v_owner <> auth.uid() then raise exception 'forbidden'; end if;
  v_freed := public.free_hizbs_to_reserve(p_group, p_user);
  return v_freed;
end; $$;
grant execute on function public.mark_member_absent(uuid, uuid) to authenticated;

-- المؤسس: توزيع تلقائي بكتل متسلسلة، بحد أقصى cap حزباً لكل عضو.
--   • الحد الأقصى: المعامل، وإلا المخزّن في الدورة النشطة، وإلا توزيع الكل بالتساوي.
--   • ما يتبقّى (إن كان n*cap < 60) يبقى في المجمّع للأعضاء الجدد أو التوزيع اليدوي.
--   • تدوير حسب رقم الدورة: كل عضو ينتقل للكتلة التالية في الدورة الجديدة.
create or replace function public.auto_distribute_group(p_group uuid, p_max int default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_owner uuid; v_members uuid[]; n int; h int; cap int; total int; v_no int; v_off int; b int; midx int;
begin
  select owner_id into v_owner from groups where id = p_group;
  if v_owner is null then raise exception 'group not found'; end if;
  if v_owner <> auth.uid() then raise exception 'forbidden'; end if;
  -- قفل التوزيع بعد قراءة أي حزب في الدورة الحالية
  if exists (select 1 from group_reads where group_id = p_group) then
    raise exception 'distribution locked: reads exist';
  end if;
  select array_agg(user_id order by joined_at, user_id) into v_members
    from group_members where group_id = p_group;
  n := coalesce(array_length(v_members, 1), 0);
  if n = 0 then return; end if;
  cap := coalesce(
    p_max,
    (select max_per_member from group_cycles where group_id = p_group and status = 'active' limit 1),
    ceil(60.0 / n)::int
  );
  if cap < 1 then cap := 1; end if;
  select cycle_no into v_no from group_cycles where group_id = p_group and status = 'active' limit 1;
  v_off := coalesce(v_no, 1) - 1;  -- إزاحة التدوير = رقم الدورة - 1
  delete from group_hizb_assignment where group_id = p_group;
  total := least(n * cap, 60);
  -- كتل متسلسلة بحجم cap مع تدوير الأعضاء حسب الدورة
  for h in 1..total loop
    b := ((h - 1) / cap) + 1;                       -- رقم الكتلة (1..)
    midx := ((b - 1 - v_off) % n + n) % n + 1;      -- العضو بعد التدوير
    insert into group_hizb_assignment(group_id, hizb, user_id)
      values (p_group, h, v_members[midx]);
  end loop;
  -- من حصل على أحزاب يفقد صفة الاحتياطي، ثم نُعيد ترقيم الباقين
  update group_members gm set reserve_rank = null
    where gm.group_id = p_group and gm.reserve_rank is not null
      and exists (select 1 from group_hizb_assignment a where a.group_id = p_group and a.user_id = gm.user_id);
  perform public.compact_group_reserves(p_group);
end; $$;
grant execute on function public.auto_distribute_group(uuid, int) to authenticated;

-- خريطة التوزيع (يراها كل الأعضاء): حزب → عضو
create or replace function public.group_assignments_map(p_group uuid)
returns table(hizb int, user_id uuid) language sql stable security definer set search_path = public as $$
  select a.hizb, a.user_id
  from group_hizb_assignment a
  where a.group_id = p_group and public.is_group_member(p_group, auth.uid());
$$;
grant execute on function public.group_assignments_map(uuid) to authenticated;

-- ───────────────────────────────────────────────────────────────────────────
-- 16) دورات الختمة للمجموعة + الأرشيف
--   • الدورة النشطة = بيانات المجموعة الحالية (group_hizb_assignment / group_reads)
--   • بدء دورة جديدة يؤرشف الحالية (لقطة) ويدوّر الأحزاب ويصفّر القراءات
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.group_cycles (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references public.groups(id) on delete cascade,
  cycle_no   int  not null default 1,
  start_date date not null default current_date,
  end_date   date,
  status     text not null default 'active' check (status in ('active','archived')),
  created_at timestamptz not null default now()
);
create index if not exists idx_cycles_group on public.group_cycles(group_id);
create unique index if not exists uq_active_cycle on public.group_cycles(group_id) where status = 'active';
-- الحد الأقصى للأحزاب لكل عضو في التوزيع التلقائي (null = توزيع الكل بالتساوي)
alter table public.group_cycles add column if not exists max_per_member int;
-- الدورة قاربت النهاية: بعدها يُعتبر من لم يقرأ متأخراً
alter table public.group_cycles add column if not exists near_end boolean not null default false;
alter table public.group_cycles enable row level security;
drop policy if exists cycles_select on public.group_cycles;
create policy cycles_select on public.group_cycles for select to authenticated
  using (public.is_group_member(group_id, auth.uid()));

-- لقطات الأرشيف (تبقى حتى بعد خروج الأعضاء)
create table if not exists public.cycle_snapshot_member (
  cycle_id uuid references public.group_cycles(id) on delete cascade,
  user_id  uuid, display_name text, primary key (cycle_id, user_id));
create table if not exists public.cycle_snapshot_assignment (
  cycle_id uuid references public.group_cycles(id) on delete cascade,
  hizb int, user_id uuid, primary key (cycle_id, hizb));
create table if not exists public.cycle_snapshot_read (
  cycle_id uuid references public.group_cycles(id) on delete cascade,
  hizb int, user_id uuid, primary key (cycle_id, hizb));
alter table public.cycle_snapshot_member     enable row level security;
alter table public.cycle_snapshot_assignment enable row level security;
alter table public.cycle_snapshot_read       enable row level security;
drop policy if exists snap_m_sel on public.cycle_snapshot_member;
create policy snap_m_sel on public.cycle_snapshot_member for select to authenticated
  using (exists (select 1 from group_cycles c where c.id = cycle_id and public.is_group_member(c.group_id, auth.uid())));
drop policy if exists snap_a_sel on public.cycle_snapshot_assignment;
create policy snap_a_sel on public.cycle_snapshot_assignment for select to authenticated
  using (exists (select 1 from group_cycles c where c.id = cycle_id and public.is_group_member(c.group_id, auth.uid())));
drop policy if exists snap_r_sel on public.cycle_snapshot_read;
create policy snap_r_sel on public.cycle_snapshot_read for select to authenticated
  using (exists (select 1 from group_cycles c where c.id = cycle_id and public.is_group_member(c.group_id, auth.uid())));

-- ضمان وجود دورة نشطة (تُنشأ من تاريخ بداية المجموعة إن لزم)
create or replace function public.ensure_active_cycle(p_group uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_start date;
begin
  select id into v_id from group_cycles where group_id = p_group and status = 'active' limit 1;
  if v_id is null then
    select start_date into v_start from groups where id = p_group;
    insert into group_cycles(group_id, cycle_no, start_date, status)
      values (p_group, 1, coalesce(v_start, current_date), 'active') returning id into v_id;
  end if;
  return v_id;
end; $$;
grant execute on function public.ensure_active_cycle(uuid) to authenticated;

-- معلومات الدورة النشطة (لا تُنشئ دورة تلقائياً — تُرجع صفراً إن لم تبدأ الدورة بعد)
drop function if exists public.group_active_cycle(uuid);
create or replace function public.group_active_cycle(p_group uuid)
returns table(id uuid, cycle_no int, start_date date, end_date date, max_per_member int, near_end boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_group_member(p_group, auth.uid()) then raise exception 'not a member'; end if;
  return query select c.id, c.cycle_no, c.start_date, c.end_date, c.max_per_member, c.near_end
    from group_cycles c where c.group_id = p_group and c.status = 'active' limit 1;
end; $$;
grant execute on function public.group_active_cycle(uuid) to authenticated;

-- المؤسس: اعتبار الدورة قاربت النهاية (أو إلغاء ذلك)
create or replace function public.set_cycle_near_end(p_group uuid, p_value boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_owner uuid;
begin
  select owner_id into v_owner from groups where id = p_group;
  if v_owner is null then raise exception 'group not found'; end if;
  if v_owner <> auth.uid() then raise exception 'forbidden'; end if;
  update group_cycles set near_end = p_value where group_id = p_group and status = 'active';
end; $$;
grant execute on function public.set_cycle_near_end(uuid, boolean) to authenticated;

-- بدء دورة جديدة (للمؤسس): تؤرشف الحالية ثم تُنشئ دورة جديدة.
--   p_mode = 'rotate' → توزيع كامل بالحد الأقصى مع تدوير الأعضاء (الافتراضي).
--   p_mode = 'keep'   → الحفاظ على نفس توزيع الدورة السابقة (بلا إعادة توزيع).
drop function if exists public.start_new_cycle(uuid, date, date);
drop function if exists public.start_new_cycle(uuid, date, date, int);
create or replace function public.start_new_cycle(
  p_group uuid, p_start date default current_date, p_end date default null,
  p_max int default null, p_mode text default 'rotate')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_owner uuid; v_cur uuid; v_no int; new_id uuid; v_newmax int; v_count int;
begin
  select owner_id into v_owner from groups where id = p_group;
  if v_owner is null then raise exception 'group not found'; end if;
  if v_owner <> auth.uid() then raise exception 'forbidden'; end if;

  -- نصاب بدء الدورة: 10 أعضاء على الأقل
  select count(*) into v_count from group_members where group_id = p_group;
  if v_count < 10 then raise exception 'quorum not met: at least 10 members required'; end if;

  -- الدورة النشطة الحالية إن وُجدت (لا تُنشأ تلقائياً)
  select id, cycle_no into v_cur, v_no
    from group_cycles where group_id = p_group and status = 'active' limit 1;

  -- أرشفة الدورة الحالية (إن وُجدت) قبل بدء الجديدة
  if v_cur is not null then
    insert into cycle_snapshot_member(cycle_id, user_id, display_name)
      select v_cur, gm.user_id,
        coalesce(nullif(p.display_name,''), nullif(u.raw_user_meta_data->>'full_name',''),
                 nullif(u.raw_user_meta_data->>'name',''), nullif(p.full_name,''), 'عضو')
      from group_members gm join profiles p on p.id = gm.user_id join auth.users u on u.id = gm.user_id
      where gm.group_id = p_group
      on conflict do nothing;
    insert into cycle_snapshot_assignment(cycle_id, hizb, user_id)
      select v_cur, hizb, user_id from group_hizb_assignment where group_id = p_group on conflict do nothing;
    insert into cycle_snapshot_read(cycle_id, hizb, user_id)
      select v_cur, hizb, user_id from group_reads where group_id = p_group on conflict do nothing;
    -- تاريخ نهاية الدورة الحالية = تاريخ بداية الدورة المقبلة
    update group_cycles set status = 'archived', end_date = p_start where id = v_cur;
    delete from group_reads where group_id = p_group;
  end if;

  -- الدورة الجديدة (تحمل الحد الأقصى الجديد أو الموروث من السابقة)
  v_newmax := coalesce(p_max, (select max_per_member from group_cycles where id = v_cur));
  insert into group_cycles(group_id, cycle_no, start_date, end_date, status, max_per_member)
    values (p_group, coalesce(v_no, 0) + 1, p_start, p_end, 'active', v_newmax)
    returning id into new_id;

  -- 'rotate' أو الدورة الأولى → توزيع كامل بالحد الأقصى مع التدوير.
  -- 'keep' في دورة لاحقة → نُبقي التوزيع الحالي كما هو (لا إعادة توزيع).
  if p_mode <> 'keep' or v_cur is null then
    perform public.auto_distribute_group(p_group, v_newmax);
  end if;
  return new_id;
end; $$;
grant execute on function public.start_new_cycle(uuid, date, date, int, text) to authenticated;

-- قائمة الدورات المؤرشفة (ملخّص)
create or replace function public.group_archived_cycles(p_group uuid)
returns table(id uuid, cycle_no int, start_date date, end_date date, hizbs_read int, members int)
language sql stable security definer set search_path = public as $$
  select c.id, c.cycle_no, c.start_date, c.end_date,
    (select count(*) from cycle_snapshot_read r where r.cycle_id = c.id)::int,
    (select count(*) from cycle_snapshot_member m where m.cycle_id = c.id)::int
  from group_cycles c
  where c.group_id = p_group and c.status = 'archived'
    and public.is_group_member(p_group, auth.uid())
  order by c.cycle_no desc;
$$;
grant execute on function public.group_archived_cycles(uuid) to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
--  انتهى المخطط.
-- ═══════════════════════════════════════════════════════════════════════════
