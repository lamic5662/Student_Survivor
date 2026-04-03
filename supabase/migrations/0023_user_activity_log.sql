create table if not exists public.user_activity_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_type text not null,
  source text,
  points int not null default 0,
  subject_id uuid references public.subjects(id) on delete set null,
  chapter_id uuid references public.chapters(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists user_activity_log_user_idx
  on public.user_activity_log(user_id);

create index if not exists user_activity_log_type_idx
  on public.user_activity_log(activity_type);

create index if not exists user_activity_log_created_at_idx
  on public.user_activity_log(created_at desc);

create index if not exists user_activity_log_subject_idx
  on public.user_activity_log(subject_id);

create index if not exists user_activity_log_chapter_idx
  on public.user_activity_log(chapter_id);

alter table public.user_activity_log enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_activity_log'
      and policyname = 'activity_log_select_own'
  ) then
    execute 'create policy "activity_log_select_own" on public.user_activity_log for select using (auth.uid() = user_id)';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_activity_log'
      and policyname = 'activity_log_insert_own'
  ) then
    execute 'create policy "activity_log_insert_own" on public.user_activity_log for insert with check (auth.uid() = user_id)';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_activity_log'
      and policyname = 'activity_log_delete_own'
  ) then
    execute 'create policy "activity_log_delete_own" on public.user_activity_log for delete using (auth.uid() = user_id)';
  end if;
end $$;
