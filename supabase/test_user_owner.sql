-- ═══════════════════════════════════════════════════════════════
--  حساب تجريبي + تعيينه مالكاً لمجموعة محدّدة
--  المستخدم: hafed01dev@gmail.com / 123456
--  المجموعة: 02c9258a-b8be-4219-bc5b-e49c6b9cc136
-- ═══════════════════════════════════════════════════════════════
--
--  الطريقة المُوصى بها لإنشاء المستخدم:
--    Supabase Dashboard → Authentication → Users → Add user
--    Email: hafed01dev@gmail.com   Password: 123456
--    ✅ فعّل "Auto Confirm User"  (مهمّ حتى يستطيع الدخول فوراً)
--
--  ثم شغّل هذا السكربت في SQL Editor لتعيينه مالكاً.
-- ═══════════════════════════════════════════════════════════════

do $$
declare
  v_uid   uuid;
  v_group uuid := '02c9258a-b8be-4219-bc5b-e49c6b9cc136';
  v_old   uuid;
begin
  -- إيجاد معرّف المستخدم بالبريد
  select id into v_uid from auth.users where email = 'hafed01dev@gmail.com';
  if v_uid is null then
    raise exception 'المستخدم hafed01dev@gmail.com غير موجود — أنشئه أولاً من Dashboard (Auto Confirm).';
  end if;

  -- المالك السابق (لأرشفته أو إبقائه عضواً عادياً)
  select owner_id into v_old from public.groups where id = v_group;

  -- تعيينه مالكاً للمجموعة
  update public.groups set owner_id = v_uid where id = v_group;

  -- ضمان أنه عضو بدور "owner"
  insert into public.group_members(group_id, user_id, role)
  values (v_group, v_uid, 'owner')
  on conflict (group_id, user_id) do update set role = 'owner';

  -- تنزيل المالك السابق إلى عضو عادي (إن كان مختلفاً وما زال عضواً)
  if v_old is not null and v_old <> v_uid then
    update public.group_members set role = 'member'
    where group_id = v_group and user_id = v_old;
  end if;

  raise notice 'تم: % أصبح مالك المجموعة %', v_uid, v_group;
end $$;
