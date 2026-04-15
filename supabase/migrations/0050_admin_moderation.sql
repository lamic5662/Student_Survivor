alter table public.profiles
  add column if not exists is_blocked boolean not null default false,
  add column if not exists blocked_reason text,
  add column if not exists blocked_at timestamptz,
  add column if not exists blocked_by uuid references auth.users(id) on delete set null;

create index if not exists profiles_is_blocked_idx
  on public.profiles(is_blocked);

drop policy if exists "profiles_update_admin" on public.profiles;
create policy "profiles_update_admin" on public.profiles
for update
using (public.is_admin());

create table if not exists public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid,
  target_type text not null check (
    target_type in (
      'note',
      'question',
      'note_submission',
      'community_question',
      'community_answer',
      'chat_message',
      'user_note'
    )
  ),
  target_id text not null,
  target_owner_id uuid,
  target_title text,
  target_preview text,
  reason text not null,
  details text,
  status text not null default 'pending' check (
    status in ('pending', 'reviewed', 'resolved', 'dismissed')
  ),
  reviewed_by uuid,
  review_note text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

create index if not exists content_reports_status_idx
  on public.content_reports(status, created_at desc);

create index if not exists content_reports_target_idx
  on public.content_reports(target_type, target_id);

create index if not exists content_reports_reporter_idx
  on public.content_reports(reporter_id);

alter table public.content_reports enable row level security;

drop policy if exists "content_reports_select" on public.content_reports;
create policy "content_reports_select" on public.content_reports
for select
using (public.is_admin() or reporter_id = auth.uid());

drop policy if exists "content_reports_insert" on public.content_reports;
create policy "content_reports_insert" on public.content_reports
for insert
with check (reporter_id = auth.uid());

drop policy if exists "content_reports_update_admin" on public.content_reports;
create policy "content_reports_update_admin" on public.content_reports
for update
using (public.is_admin());

drop policy if exists "content_reports_delete_admin" on public.content_reports;
create policy "content_reports_delete_admin" on public.content_reports
for delete
using (public.is_admin());

create table if not exists public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null,
  action_type text not null,
  target_type text,
  target_id text,
  target_user_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists admin_audit_log_created_at_idx
  on public.admin_audit_log(created_at desc);

create index if not exists admin_audit_log_actor_idx
  on public.admin_audit_log(actor_id);

alter table public.admin_audit_log enable row level security;

drop policy if exists "admin_audit_log_select_admin" on public.admin_audit_log;
create policy "admin_audit_log_select_admin" on public.admin_audit_log
for select
using (public.is_admin());

drop policy if exists "admin_audit_log_insert_admin" on public.admin_audit_log;
create policy "admin_audit_log_insert_admin" on public.admin_audit_log
for insert
with check (public.is_admin() and actor_id = auth.uid());

drop policy if exists "activity_log_select_admin" on public.user_activity_log;
create policy "activity_log_select_admin" on public.user_activity_log
for select
using (public.is_admin());

create or replace function public.log_admin_action(
  p_action_type text,
  p_target_type text default null,
  p_target_id text default null,
  p_target_user_id uuid default null,
  p_details jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden';
  end if;

  insert into public.admin_audit_log (
    actor_id,
    action_type,
    target_type,
    target_id,
    target_user_id,
    details
  )
  values (
    auth.uid(),
    p_action_type,
    p_target_type,
    p_target_id,
    p_target_user_id,
    coalesce(p_details, '{}'::jsonb)
  );
end;
$$;

create or replace function public.admin_delete_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden';
  end if;

  if p_user_id is null then
    raise exception 'user_id_required';
  end if;

  if auth.uid() = p_user_id then
    raise exception 'cannot_delete_self';
  end if;

  perform public.log_admin_action(
    'user_deleted',
    'profile',
    p_user_id::text,
    p_user_id,
    jsonb_build_object('deleted_by', auth.uid())
  );

  delete from auth.users
  where id = p_user_id;
end;
$$;

grant execute on function public.log_admin_action(text, text, text, uuid, jsonb)
  to authenticated;

grant execute on function public.admin_delete_user(uuid)
  to authenticated;
