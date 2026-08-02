-- ═══════════════════════════════════════════════════════════════════════════
--  إشعارات Firebase (FCM) — الربط بين قاعدة البيانات ودالة Edge Function «notify»
--  يُشغَّل هذا الملف بعد:
--    1) نشر Edge Function: supabase functions deploy notify
--    2) ضبط الأسرار: FIREBASE_SERVICE_ACCOUNT / NOTIFY_SECRET
--    3) تفعيل امتداد pg_net (Database → Extensions → pg_net)
--  ثم عبّئ الصفين في app_secrets بعنوان الدالة والسرّ.
-- ═══════════════════════════════════════════════════════════════════════════

-- 0) رموز أجهزة المستخدمين (FCM tokens) — يملؤها التطبيق تلقائياً
create table if not exists public.device_tokens (
  token      text primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  platform   text,
  updated_at timestamptz not null default now()
);
create index if not exists idx_device_tokens_user on public.device_tokens(user_id);
alter table public.device_tokens enable row level security;
drop policy if exists dt_own on public.device_tokens;
create policy dt_own on public.device_tokens for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 1) جدول أسرار داخلي (لا يُقرأ إلا عبر دوال security definer)
create table if not exists public.app_secrets (key text primary key, value text);
alter table public.app_secrets enable row level security;  -- بلا سياسات = ممنوع لكل الأدوار

-- عبّئ هذين الصفين بقيمك:
--   notify_url    = https://<PROJECT_REF>.functions.supabase.co/notify
--   notify_secret = نفس قيمة NOTIFY_SECRET
-- insert into public.app_secrets(key, value) values
--   ('notify_url',   'https://YOUR_REF.functions.supabase.co/notify'),
--   ('notify_secret','YOUR_NOTIFY_SECRET')
-- on conflict (key) do update set value = excluded.value;

-- 2) مساعد الإرسال (fire-and-forget عبر pg_net)
create or replace function public.push_notify(p_users uuid[], p_title text, p_message text)
returns void language plpgsql security definer set search_path = public as $$
declare v_url text; v_secret text;
begin
  if p_users is null or array_length(p_users, 1) is null then return; end if;
  select value into v_url    from app_secrets where key = 'notify_url';
  select value into v_secret from app_secrets where key = 'notify_secret';
  if v_url is null or v_url = '' then return; end if;
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-notify-secret', coalesce(v_secret, '')),
    body := jsonb_build_object(
      'user_ids', to_jsonb(p_users),
      'title', p_title,
      'message', p_message)
  );
exception when others then
  -- لا نُفشل العملية الأساسية إن تعذّر الإشعار
  null;
end; $$;

create or replace function public.group_name(p_group uuid)
returns text language sql stable security definer set search_path = public as $$
  select name from groups where id = p_group;
$$;

-- 3) الحدث #1: اكتمال النصاب (10 أعضاء) — داخل join_group
create or replace function public.join_group(p_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_new text; rows int; v_cap int; v_mode text; v_count int;
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
    select max_per_member into v_cap
      from group_cycles where group_id = v_id and status = 'active' limit 1;
    if v_cap is not null and v_cap > 0 then
      insert into group_hizb_assignment(group_id, hizb, user_id)
        select v_id, h, auth.uid()
        from generate_series(1, 60) as h
        where not exists (select 1 from group_hizb_assignment a where a.group_id = v_id and a.hizb = h)
        order by h limit v_cap on conflict do nothing;
    end if;
    if v_mode = 'invite' then
      loop
        v_new := public.gen_invite_code();
        exit when not exists (select 1 from groups where invite_code = v_new);
      end loop;
      update groups set invite_code = v_new where id = v_id;
    end if;
    -- إشعار اكتمال النصاب
    select count(*) into v_count from group_members where group_id = v_id;
    if v_count = 10 then
      perform public.push_notify(
        (select array_agg(user_id) from group_members where group_id = v_id),
        'اكتملت المجموعة 🎉',
        'اكتمل نصاب مجموعة «' || public.group_name(v_id) || '» بعشرة أعضاء. يمكن الآن بدء الختمة.');
    end if;
  end if;
  return v_id;
end; $$;

-- 4) الحدث #4: إسناد أحزاب جديدة — إشعار لكل عضو تغيّر نصيبه بعد التوزيع التلقائي
--    (p_notify = false عند استدعائها من بدء الدورة لتفادي التكرار)
drop function if exists public.auto_distribute_group(uuid, int);
create or replace function public.auto_distribute_group(p_group uuid, p_max int default null, p_notify boolean default true)
returns void language plpgsql security definer set search_path = public as $$
declare v_owner uuid; v_members uuid[]; n int; h int; cap int; total int; v_no int; v_off int; b int; midx int; m record;
begin
  select owner_id into v_owner from groups where id = p_group;
  if v_owner is null then raise exception 'group not found'; end if;
  if v_owner <> auth.uid() then raise exception 'forbidden'; end if;
  if exists (select 1 from group_reads where group_id = p_group) then
    raise exception 'distribution locked: reads exist';
  end if;
  select array_agg(user_id order by joined_at, user_id) into v_members
    from group_members where group_id = p_group;
  n := coalesce(array_length(v_members, 1), 0);
  if n = 0 then return; end if;
  cap := coalesce(p_max,
    (select max_per_member from group_cycles where group_id = p_group and status = 'active' limit 1),
    ceil(60.0 / n)::int);
  if cap < 1 then cap := 1; end if;
  select cycle_no into v_no from group_cycles where group_id = p_group and status = 'active' limit 1;
  v_off := coalesce(v_no, 1) - 1;
  delete from group_hizb_assignment where group_id = p_group;
  total := least(n * cap, 60);
  for h in 1..total loop
    b := ((h - 1) / cap) + 1;
    midx := ((b - 1 - v_off) % n + n) % n + 1;
    insert into group_hizb_assignment(group_id, hizb, user_id)
      values (p_group, h, v_members[midx]);
  end loop;
  update group_members gm set reserve_rank = null
    where gm.group_id = p_group and gm.reserve_rank is not null
      and exists (select 1 from group_hizb_assignment a where a.group_id = p_group and a.user_id = gm.user_id);
  perform public.compact_group_reserves(p_group);
  -- إشعار كل عضو بعدد أحزابه الجديدة
  if p_notify then
    for m in
      select user_id, count(*) c from group_hizb_assignment where group_id = p_group group by user_id
    loop
      perform public.push_notify(array[m.user_id],
        'أُسندت إليك أحزاب جديدة 📖',
        'لديك ' || m.c || ' أحزاب في مجموعة «' || public.group_name(p_group) || '».');
    end loop;
  end if;
end; $$;
grant execute on function public.auto_distribute_group(uuid, int, boolean) to authenticated;

-- 5) الحدث #2: بدء دورة جديدة — إشعار كل الأعضاء (بلا إشعار توزيع منفصل)
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
  select count(*) into v_count from group_members where group_id = p_group;
  if v_count < 10 then raise exception 'quorum not met: at least 10 members required'; end if;
  select id, cycle_no into v_cur, v_no from group_cycles where group_id = p_group and status = 'active' limit 1;
  if v_cur is not null then
    insert into cycle_snapshot_member(cycle_id, user_id, display_name)
      select v_cur, gm.user_id,
        coalesce(nullif(p.display_name,''), nullif(u.raw_user_meta_data->>'full_name',''),
                 nullif(u.raw_user_meta_data->>'name',''), nullif(p.full_name,''), 'عضو')
      from group_members gm join profiles p on p.id = gm.user_id join auth.users u on u.id = gm.user_id
      where gm.group_id = p_group on conflict do nothing;
    insert into cycle_snapshot_assignment(cycle_id, hizb, user_id)
      select v_cur, hizb, user_id from group_hizb_assignment where group_id = p_group on conflict do nothing;
    insert into cycle_snapshot_read(cycle_id, hizb, user_id)
      select v_cur, hizb, user_id from group_reads where group_id = p_group on conflict do nothing;
    update group_cycles set status = 'archived', end_date = p_start where id = v_cur;
    delete from group_reads where group_id = p_group;
  end if;
  v_newmax := coalesce(p_max, (select max_per_member from group_cycles where id = v_cur));
  insert into group_cycles(group_id, cycle_no, start_date, end_date, status, max_per_member)
    values (p_group, coalesce(v_no, 0) + 1, p_start, p_end, 'active', v_newmax)
    returning id into new_id;
  if p_mode <> 'keep' or v_cur is null then
    perform public.auto_distribute_group(p_group, v_newmax, false);
  end if;
  -- إشعار بدء الدورة لكل الأعضاء
  perform public.push_notify(
    (select array_agg(user_id) from group_members where group_id = p_group),
    'بدأت دورة جديدة 🔄',
    'بدأت الدورة ' || (coalesce(v_no,0)+1) || ' في مجموعة «' || public.group_name(p_group) || '». تفقّد نصيبك من الأحزاب.');
  return new_id;
end; $$;
grant execute on function public.start_new_cycle(uuid, date, date, int, text) to authenticated;

-- 6) الحدث #4 (يدوي): إسناد حزب لعضو — إشعاره
create or replace function public.set_hizb_assignment(p_group uuid, p_hizb int, p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_owner uuid;
begin
  select owner_id into v_owner from groups where id = p_group;
  if v_owner is null then raise exception 'group not found'; end if;
  if v_owner <> auth.uid() then raise exception 'forbidden'; end if;
  if p_hizb < 1 or p_hizb > 60 then raise exception 'invalid hizb'; end if;
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
    update group_members set reserve_rank = null
      where group_id = p_group and user_id = p_user and reserve_rank is not null;
    perform public.compact_group_reserves(p_group);
    perform public.push_notify(array[p_user],
      'أُسند إليك حزب جديد 📖',
      'الحزب ' || p_hizb || ' في مجموعة «' || public.group_name(p_group) || '».');
  end if;
end; $$;

-- 7) الحدث #4 (احتياطي): ترقية احتياطي — إشعاره بأحزابه الجديدة
create or replace function public.free_hizbs_to_reserve(p_group uuid, p_user uuid)
returns int language plpgsql security definer set search_path = public as $$
declare v_hizbs int[]; v_res uuid; v_rank int; v_n int;
begin
  select array_agg(a.hizb) into v_hizbs from group_hizb_assignment a
    where a.group_id = p_group and a.user_id = p_user
      and not exists (select 1 from group_reads r where r.group_id = p_group and r.hizb = a.hizb);
  delete from group_hizb_assignment a
    where a.group_id = p_group and a.user_id = p_user
      and not exists (select 1 from group_reads r where r.group_id = p_group and r.hizb = a.hizb);
  v_n := coalesce(array_length(v_hizbs,1),0);
  if v_n = 0 then return 0; end if;
  select user_id, reserve_rank into v_res, v_rank from group_members
    where group_id = p_group and reserve_rank is not null order by reserve_rank limit 1;
  if v_res is null then return v_n; end if;
  insert into group_hizb_assignment(group_id, hizb, user_id)
    select p_group, h, v_res from unnest(v_hizbs) as h
    on conflict (group_id, hizb) do update set user_id = excluded.user_id;
  update group_members set reserve_rank = null where group_id = p_group and user_id = v_res;
  update group_members set reserve_rank = reserve_rank - 1
    where group_id = p_group and reserve_rank is not null and reserve_rank > v_rank;
  perform public.push_notify(array[v_res],
    'أُسندت إليك أحزاب جديدة 📥',
    'أصبحتَ ضمن التوزيع في مجموعة «' || public.group_name(p_group) || '» (' || v_n || ' أحزاب).');
  return v_n;
end; $$;

-- 8) الحدث #3: الدورة قاربت النهاية — إشعار المتأخرين فقط
create or replace function public.set_cycle_near_end(p_group uuid, p_value boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_owner uuid; v_late uuid[];
begin
  select owner_id into v_owner from groups where id = p_group;
  if v_owner is null then raise exception 'group not found'; end if;
  if v_owner <> auth.uid() then raise exception 'forbidden'; end if;
  update group_cycles set near_end = p_value where group_id = p_group and status = 'active';
  if p_value then
    -- المتأخرون = لهم أحزاب مُسندة غير مقروءة
    select array_agg(distinct a.user_id) into v_late
    from group_hizb_assignment a
    where a.group_id = p_group
      and not exists (select 1 from group_reads r where r.group_id = p_group and r.hizb = a.hizb);
    perform public.push_notify(v_late,
      'الدورة تقارب نهايتها ⏳',
      'لم تُكمل قراءة نصيبك في مجموعة «' || public.group_name(p_group) || '». سارِع بإتمامه.');
  end if;
end; $$;
grant execute on function public.set_cycle_near_end(uuid, boolean) to authenticated;
