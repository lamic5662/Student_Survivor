-- Community Q&A (AI-verified questions + public answers)

create table if not exists public.community_questions (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.subjects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  question text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  ai_valid boolean not null default false,
  ai_reason text,
  admin_reason text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.community_answers (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.community_questions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  answer text not null,
  created_at timestamptz not null default now()
);

create index if not exists community_questions_subject_idx
  on public.community_questions(subject_id);
create index if not exists community_questions_status_idx
  on public.community_questions(status);
create index if not exists community_answers_question_idx
  on public.community_answers(question_id);

create trigger set_community_questions_updated_at
before update on public.community_questions
for each row
execute function public.set_updated_at();

alter table public.community_questions enable row level security;
alter table public.community_answers enable row level security;

drop policy if exists "community_questions_select" on public.community_questions;
create policy "community_questions_select" on public.community_questions
for select
using (
  status = 'approved'
  or user_id = auth.uid()
  or public.is_admin()
);

drop policy if exists "community_questions_insert" on public.community_questions;
create policy "community_questions_insert" on public.community_questions
for insert
with check (auth.uid() = user_id);

drop policy if exists "community_questions_update" on public.community_questions;
create policy "community_questions_update" on public.community_questions
for update
using (auth.uid() = user_id or public.is_admin());

drop policy if exists "community_questions_delete" on public.community_questions;
create policy "community_questions_delete" on public.community_questions
for delete
using (auth.uid() = user_id or public.is_admin());

drop policy if exists "community_answers_select" on public.community_answers;
create policy "community_answers_select" on public.community_answers
for select
using (
  exists (
    select 1 from public.community_questions q
    where q.id = question_id
      and (q.status = 'approved' or q.user_id = auth.uid() or public.is_admin())
  )
);

drop policy if exists "community_answers_insert" on public.community_answers;
create policy "community_answers_insert" on public.community_answers
for insert
with check (
  auth.uid() = user_id
  and exists (
    select 1 from public.community_questions q
    where q.id = question_id and q.status = 'approved'
  )
);

drop policy if exists "community_answers_update" on public.community_answers;
create policy "community_answers_update" on public.community_answers
for update
using (auth.uid() = user_id or public.is_admin());

drop policy if exists "community_answers_delete" on public.community_answers;
create policy "community_answers_delete" on public.community_answers
for delete
using (auth.uid() = user_id or public.is_admin());
