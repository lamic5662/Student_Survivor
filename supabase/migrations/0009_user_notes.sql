-- User saved notes (including AI-generated notes)
create table if not exists public.user_notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  chapter_id uuid not null references public.chapters(id) on delete cascade,
  title text not null,
  short_answer text,
  detailed_answer text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgname = 'set_user_notes_updated_at'
      and tgrelid = 'public.user_notes'::regclass
  ) then
    create trigger set_user_notes_updated_at
    before update on public.user_notes
    for each row
    execute function public.set_updated_at();
  end if;
end $$;

alter table public.user_notes enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_notes'
      and policyname = 'user_notes_owner_select'
  ) then
    execute 'create policy "user_notes_owner_select" on public.user_notes for select using (auth.uid() = user_id)';
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_notes'
      and policyname = 'user_notes_owner_insert'
  ) then
    execute 'create policy "user_notes_owner_insert" on public.user_notes for insert with check (auth.uid() = user_id)';
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_notes'
      and policyname = 'user_notes_owner_update'
  ) then
    execute 'create policy "user_notes_owner_update" on public.user_notes for update using (auth.uid() = user_id)';
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_notes'
      and policyname = 'user_notes_owner_delete'
  ) then
    execute 'create policy "user_notes_owner_delete" on public.user_notes for delete using (auth.uid() = user_id)';
  end if;
end $$;
