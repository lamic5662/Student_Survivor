create table if not exists public.teacher_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  subject_name text not null,
  topic text not null,
  level text,
  style text,
  lesson_title text not null,
  lesson_objective text,
  lesson_introduction text,
  lesson_main_points text[] not null default '{}',
  lesson_example text,
  lesson_summary text,
  homework_tasks text[] not null default '{}',
  homework_target text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists teacher_sessions_user_idx
  on public.teacher_sessions (user_id, created_at desc);

create table if not exists public.teacher_questions (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.teacher_sessions(id) on delete cascade,
  type text not null,
  prompt text not null,
  options text[] not null default '{}',
  answer_index int,
  answer text,
  position int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists teacher_questions_session_idx
  on public.teacher_questions (session_id, position);

create table if not exists public.teacher_answers (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.teacher_sessions(id) on delete cascade,
  question_id uuid references public.teacher_questions(id) on delete set null,
  user_id uuid not null references auth.users(id) on delete cascade,
  answer text not null,
  score int,
  verdict text,
  feedback text,
  improved_answer text,
  created_at timestamptz not null default now()
);

create index if not exists teacher_answers_session_idx
  on public.teacher_answers (session_id, created_at desc);

create index if not exists teacher_answers_user_idx
  on public.teacher_answers (user_id, created_at desc);

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
      where tgname = 'set_teacher_sessions_updated_at'
    ) then
      execute 'create trigger set_teacher_sessions_updated_at
        before update on public.teacher_sessions
        for each row
        execute function public.set_updated_at()';
    end if;
  end if;
end $$;

alter table public.teacher_sessions enable row level security;
alter table public.teacher_questions enable row level security;
alter table public.teacher_answers enable row level security;

drop policy if exists "teacher_sessions_select" on public.teacher_sessions;
create policy "teacher_sessions_select" on public.teacher_sessions
for select
using (auth.uid() = user_id or public.is_admin());

drop policy if exists "teacher_sessions_insert" on public.teacher_sessions;
create policy "teacher_sessions_insert" on public.teacher_sessions
for insert
with check (auth.uid() = user_id);

drop policy if exists "teacher_sessions_update" on public.teacher_sessions;
create policy "teacher_sessions_update" on public.teacher_sessions
for update
using (auth.uid() = user_id or public.is_admin());

drop policy if exists "teacher_sessions_delete" on public.teacher_sessions;
create policy "teacher_sessions_delete" on public.teacher_sessions
for delete
using (auth.uid() = user_id or public.is_admin());

drop policy if exists "teacher_questions_select" on public.teacher_questions;
create policy "teacher_questions_select" on public.teacher_questions
for select
using (
  public.is_admin()
  or exists (
    select 1
    from public.teacher_sessions s
    where s.id = session_id and s.user_id = auth.uid()
  )
);

drop policy if exists "teacher_questions_insert" on public.teacher_questions;
create policy "teacher_questions_insert" on public.teacher_questions
for insert
with check (
  exists (
    select 1
    from public.teacher_sessions s
    where s.id = session_id and s.user_id = auth.uid()
  )
);

drop policy if exists "teacher_questions_update" on public.teacher_questions;
create policy "teacher_questions_update" on public.teacher_questions
for update
using (
  public.is_admin()
  or exists (
    select 1
    from public.teacher_sessions s
    where s.id = session_id and s.user_id = auth.uid()
  )
);

drop policy if exists "teacher_questions_delete" on public.teacher_questions;
create policy "teacher_questions_delete" on public.teacher_questions
for delete
using (
  public.is_admin()
  or exists (
    select 1
    from public.teacher_sessions s
    where s.id = session_id and s.user_id = auth.uid()
  )
);

drop policy if exists "teacher_answers_select" on public.teacher_answers;
create policy "teacher_answers_select" on public.teacher_answers
for select
using (auth.uid() = user_id or public.is_admin());

drop policy if exists "teacher_answers_insert" on public.teacher_answers;
create policy "teacher_answers_insert" on public.teacher_answers
for insert
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.teacher_sessions s
    where s.id = session_id and s.user_id = auth.uid()
  )
);

drop policy if exists "teacher_answers_update" on public.teacher_answers;
create policy "teacher_answers_update" on public.teacher_answers
for update
using (auth.uid() = user_id or public.is_admin());

drop policy if exists "teacher_answers_delete" on public.teacher_answers;
create policy "teacher_answers_delete" on public.teacher_answers
for delete
using (auth.uid() = user_id or public.is_admin());
