create table if not exists public.exam_best_scores (
  user_id uuid not null references auth.users(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  best_score numeric(5,4) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, subject_id)
);

alter table public.exam_best_scores enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'exam_best_scores'
      and policyname = 'exam_best_scores_select_own'
  ) then
    execute 'create policy "exam_best_scores_select_own" on public.exam_best_scores for select using (auth.uid() = user_id)';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'exam_best_scores'
      and policyname = 'exam_best_scores_upsert_own'
  ) then
    execute 'create policy "exam_best_scores_upsert_own" on public.exam_best_scores for insert with check (auth.uid() = user_id)';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'exam_best_scores'
      and policyname = 'exam_best_scores_update_own'
  ) then
    execute 'create policy "exam_best_scores_update_own" on public.exam_best_scores for update using (auth.uid() = user_id)';
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
      where tgname = 'set_exam_best_scores_updated_at'
    ) then
      execute 'create trigger set_exam_best_scores_updated_at
        before update on public.exam_best_scores
        for each row
        execute function public.set_updated_at()';
    end if;
  end if;
end $$;
