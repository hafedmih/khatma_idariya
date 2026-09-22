-- ═══════════════════════════════════════════════════════════════
--  إضافة أعضاء إلى مجموعة ختمة (دور: member)
--
--  نفّذه في: Supabase Dashboard > SQL Editor > New query
--  (محرّر SQL يعمل بصلاحية service_role فيتجاوز RLS؛ الإدخال المباشر
--   من التطبيق ممنوع لأن الانضمام يمرّ عبر الدالة join_group).
--
--  آمنٌ لإعادة التنفيذ: on conflict do nothing، ولا يُنقص أحداً.
-- ═══════════════════════════════════════════════════════════════

do $$
declare
  v_group  uuid   := 'cc45d966-1f88-4739-900b-afe702c2b3c7';
  v_users  uuid[] := array[
    '297f7a86-e244-40cd-bd28-a44ae471ca2e',
    '425911d7-8b22-43ba-a715-12983c0e30b8',
    '4419b097-5abd-4234-871d-848bf42c0800',
    '443d44f5-fb68-4b97-9109-b25550038b96',
    '6c7c605e-c2d2-4518-9aa9-b4b210e8d223',
    '82ec0988-5406-4d2c-92ec-146705496b12',
    'b42d5be6-7900-49d4-b41d-b32e24aa11c4',
    'b5fa1a4f-2295-4db3-96a7-fd67e9bdeaa3'
  ];
  v_uid    uuid;
  v_before int;
  v_after  int;
  v_skip   int := 0;
begin
  -- 1) تحقّق من وجود المجموعة قبل أي إدخال
  if not exists (select 1 from public.groups where id = v_group) then
    raise exception 'المجموعة % غير موجودة', v_group;
  end if;

  select count(*) into v_before
    from public.group_members where group_id = v_group;

  -- 2) أضِف كل مستخدم موجود فعلاً في auth.users
  foreach v_uid in array v_users loop
    if not exists (select 1 from auth.users where id = v_uid) then
      raise notice 'تجاهُل: المستخدم % غير موجود في auth.users', v_uid;
      v_skip := v_skip + 1;
      continue;
    end if;

    insert into public.group_members(group_id, user_id, role)
    values (v_group, v_uid, 'member')
    on conflict (group_id, user_id) do nothing;

    -- نفس ما تفعله الدالة join_group: وسام «رفقة الخير»
    perform public.grant_achievement(v_uid, 'group_member');
  end loop;

  select count(*) into v_after
    from public.group_members where group_id = v_group;

  raise notice 'الأعضاء: % ← %   (تم تجاهُل % معرّفاً)', v_before, v_after, v_skip;

  if v_after < 10 then
    raise notice 'تنبيه: النصاب 10 أعضاء. ينقص % عضواً لبدء الدورة.', 10 - v_after;
  else
    raise notice 'النصاب مكتمل — يمكن بدء الدورة من التطبيق.';
  end if;
end $$;

-- ═══════════════════════════════════════════════════════════════
--  تحقّق: قائمة أعضاء المجموعة بعد التنفيذ
-- ═══════════════════════════════════════════════════════════════
select gm.role,
       coalesce(nullif(p.display_name,''), u.email, gm.user_id::text) as member,
       gm.reserve_rank,
       gm.joined_at
from public.group_members gm
left join public.profiles  p on p.id = gm.user_id
left join auth.users       u on u.id = gm.user_id
where gm.group_id = 'cc45d966-1f88-4739-900b-afe702c2b3c7'
order by (gm.role = 'owner') desc, gm.joined_at;
