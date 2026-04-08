create table if not exists public.revision_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_key text not null,
  item_type text not null check (item_type in ('topic', 'chapter', 'note', 'question')),
  subject_id uuid references public.subjects(id) on delete set null,
  chapter_id uuid references public.chapters(id) on delete set null,
  note_id uuid references public.notes(id) on delete set null,
  question_id uuid references public.questions(id) on delete set null,
  title text not null,
  detail text,
  priority int not null default 2,
  due_at timestamptz not null default now(),
  interval_days int not null default 1,
  ease_factor numeric(3,2) not null default 2.20,
  success_count int not null default 0,
  last_reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists revision_items_user_key_idx
  on public.revision_items(user_id, item_key);

create index if not exists revision_items_user_due_idx
  on public.revision_items(user_id, due_at);

alter table public.revision_items enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'revision_items'
      and policyname = 'revision_items_select_own'
  ) then
    execute 'create policy "revision_items_select_own" on public.revision_items for select using (auth.uid() = user_id)';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'revision_items'
      and policyname = 'revision_items_insert_own'
  ) then
    execute 'create policy "revision_items_insert_own" on public.revision_items for insert with check (auth.uid() = user_id)';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'revision_items'
      and policyname = 'revision_items_update_own'
  ) then
    execute 'create policy "revision_items_update_own" on public.revision_items for update using (auth.uid() = user_id)';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'revision_items'
      and policyname = 'revision_items_delete_own'
  ) then
    execute 'create policy "revision_items_delete_own" on public.revision_items for delete using (auth.uid() = user_id)';
  end if;
end $$;

do $$
begin
  if exists (
    select 1
    from pg_proc
    where proname = 'set_updated_at'
  ) then
    if not exists (
      select 1
      from pg_trigger
      where tgname = 'set_revision_items_updated_at'
    ) then
      execute 'create trigger set_revision_items_updated_at
        before update on public.revision_items
        for each row
        execute function public.set_updated_at()';
    end if;
  end if;
end $$;
