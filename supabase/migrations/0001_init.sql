-- Student Survivor core schema

create extension if not exists "pgcrypto";
create extension if not exists "pg_trgm";

create type public.quiz_type as enum ('mcq', 'time', 'level');
create type public.quiz_difficulty as enum ('easy', 'medium', 'hard');
create type public.question_kind as enum ('important', 'past', 'practice');

create table public.semesters (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text not null unique,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  semester_id uuid not null references public.semesters(id) on delete cascade,
  name text not null,
  code text not null,
  description text,
  accent_color text,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (semester_id, code)
);

create table public.chapters (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.subjects(id) on delete cascade,
  title text not null,
  summary text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table public.notes (
  id uuid primary key default gen_random_uuid(),
  chapter_id uuid not null references public.chapters(id) on delete cascade,
  title text not null,
  short_answer text,
  detailed_answer text,
  tags text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  chapter_id uuid not null references public.chapters(id) on delete cascade,
  prompt text not null,
  marks int not null default 5,
  kind public.question_kind not null default 'important',
  year int,
  created_at timestamptz not null default now()
);

create table public.quizzes (
  id uuid primary key default gen_random_uuid(),
  chapter_id uuid not null references public.chapters(id) on delete cascade,
  title text not null,
  quiz_type public.quiz_type not null default 'mcq',
  difficulty public.quiz_difficulty not null default 'easy',
  duration_minutes int not null default 10,
  question_count int not null default 10,
  created_at timestamptz not null default now()
);

create table public.quiz_questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  prompt text not null,
  options jsonb not null,
  correct_index int,
  explanation text,
  topic text,
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  phone text,
  semester_id uuid references public.semesters(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_subjects (
  user_id uuid not null references auth.users(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, subject_id)
);

create table public.user_chapter_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  chapter_id uuid not null references public.chapters(id) on delete cascade,
  completion_percent numeric(5,2) not null default 0,
  last_activity_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, chapter_id)
);

create table public.quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  score int not null,
  total int not null,
  xp_earned int not null default 0,
  passed boolean not null default false,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  duration_seconds int,
  created_at timestamptz not null default now()
);

create table public.quiz_answers (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.quiz_attempts(id) on delete cascade,
  quiz_question_id uuid references public.quiz_questions(id),
  selected_index int,
  is_correct boolean,
  response_time_ms int,
  created_at timestamptz not null default now()
);

create table public.weak_topics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  chapter_id uuid references public.chapters(id) on delete set null,
  topic text not null,
  reason text,
  severity int not null default 1,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table public.recommendations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  note_id uuid references public.notes(id) on delete set null,
  question_id uuid references public.questions(id) on delete set null,
  reason text,
  created_at timestamptz not null default now()
);

create table public.study_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  start_date date,
  end_date date,
  created_at timestamptz not null default now()
);

create table public.study_tasks (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.study_plans(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  title text not null,
  due_date date,
  is_done boolean not null default false,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations(id) on delete cascade,
  role text not null check (role in ('user', 'assistant', 'system')),
  content text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.user_stats (
  user_id uuid primary key references auth.users(id) on delete cascade,
  xp int not null default 0,
  games_played int not null default 0,
  streak_days int not null default 0,
  last_played_at timestamptz
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_notes_updated_at
before update on public.notes
for each row
execute function public.set_updated_at();

create trigger set_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

create trigger set_progress_updated_at
before update on public.user_chapter_progress
for each row
execute function public.set_updated_at();

create trigger set_ai_conversations_updated_at
before update on public.ai_conversations
for each row
execute function public.set_updated_at();

-- Search indexes (fuzzy match)
create index notes_title_trgm_idx on public.notes using gin (title gin_trgm_ops);
create index notes_short_answer_trgm_idx on public.notes using gin (short_answer gin_trgm_ops);
create index questions_prompt_trgm_idx on public.questions using gin (prompt gin_trgm_ops);
create index chapters_title_trgm_idx on public.chapters using gin (title gin_trgm_ops);
create index subjects_name_trgm_idx on public.subjects using gin (name gin_trgm_ops);

-- Enable RLS
alter table public.semesters enable row level security;
alter table public.subjects enable row level security;
alter table public.chapters enable row level security;
alter table public.notes enable row level security;
alter table public.questions enable row level security;
alter table public.quizzes enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.profiles enable row level security;
alter table public.user_subjects enable row level security;
alter table public.user_chapter_progress enable row level security;
alter table public.quiz_attempts enable row level security;
alter table public.quiz_answers enable row level security;
alter table public.weak_topics enable row level security;
alter table public.recommendations enable row level security;
alter table public.study_plans enable row level security;
alter table public.study_tasks enable row level security;
alter table public.ai_conversations enable row level security;
alter table public.ai_messages enable row level security;
alter table public.user_stats enable row level security;

-- Public read policies for curriculum content
create policy "semesters_public_read" on public.semesters
for select
using (true);

create policy "subjects_public_read" on public.subjects
for select
using (true);

create policy "chapters_public_read" on public.chapters
for select
using (true);

create policy "notes_public_read" on public.notes
for select
using (true);

create policy "questions_public_read" on public.questions
for select
using (true);

create policy "quizzes_public_read" on public.quizzes
for select
using (true);

create policy "quiz_questions_public_read" on public.quiz_questions
for select
using (true);

-- Profiles
create policy "profiles_select_own" on public.profiles
for select
using (auth.uid() = id);

create policy "profiles_insert_own" on public.profiles
for insert
with check (auth.uid() = id);

create policy "profiles_update_own" on public.profiles
for update
using (auth.uid() = id);

-- User subjects
create policy "user_subjects_select_own" on public.user_subjects
for select
using (auth.uid() = user_id);

create policy "user_subjects_insert_own" on public.user_subjects
for insert
with check (auth.uid() = user_id);

create policy "user_subjects_delete_own" on public.user_subjects
for delete
using (auth.uid() = user_id);

-- Progress
create policy "progress_select_own" on public.user_chapter_progress
for select
using (auth.uid() = user_id);

create policy "progress_upsert_own" on public.user_chapter_progress
for insert
with check (auth.uid() = user_id);

create policy "progress_update_own" on public.user_chapter_progress
for update
using (auth.uid() = user_id);

-- Quiz attempts
create policy "quiz_attempts_select_own" on public.quiz_attempts
for select
using (auth.uid() = user_id);

create policy "quiz_attempts_insert_own" on public.quiz_attempts
for insert
with check (auth.uid() = user_id);

-- Quiz answers (bound to attempt user)
create policy "quiz_answers_select_own" on public.quiz_answers
for select
using (
  exists (
    select 1 from public.quiz_attempts qa
    where qa.id = attempt_id and qa.user_id = auth.uid()
  )
);

create policy "quiz_answers_insert_own" on public.quiz_answers
for insert
with check (
  exists (
    select 1 from public.quiz_attempts qa
    where qa.id = attempt_id and qa.user_id = auth.uid()
  )
);

-- Weak topics
create policy "weak_topics_select_own" on public.weak_topics
for select
using (auth.uid() = user_id);

create policy "weak_topics_upsert_own" on public.weak_topics
for insert
with check (auth.uid() = user_id);

create policy "weak_topics_update_own" on public.weak_topics
for update
using (auth.uid() = user_id);

-- Recommendations
create policy "recommendations_select_own" on public.recommendations
for select
using (auth.uid() = user_id);

create policy "recommendations_insert_own" on public.recommendations
for insert
with check (auth.uid() = user_id);

-- Study plans
create policy "study_plans_select_own" on public.study_plans
for select
using (auth.uid() = user_id);

create policy "study_plans_insert_own" on public.study_plans
for insert
with check (auth.uid() = user_id);

create policy "study_plans_update_own" on public.study_plans
for update
using (auth.uid() = user_id);

create policy "study_plans_delete_own" on public.study_plans
for delete
using (auth.uid() = user_id);

-- Study tasks via plan ownership
create policy "study_tasks_select_own" on public.study_tasks
for select
using (
  exists (
    select 1 from public.study_plans sp
    where sp.id = plan_id and sp.user_id = auth.uid()
  )
);

create policy "study_tasks_insert_own" on public.study_tasks
for insert
with check (
  exists (
    select 1 from public.study_plans sp
    where sp.id = plan_id and sp.user_id = auth.uid()
  )
);

create policy "study_tasks_update_own" on public.study_tasks
for update
using (
  exists (
    select 1 from public.study_plans sp
    where sp.id = plan_id and sp.user_id = auth.uid()
  )
);

create policy "study_tasks_delete_own" on public.study_tasks
for delete
using (
  exists (
    select 1 from public.study_plans sp
    where sp.id = plan_id and sp.user_id = auth.uid()
  )
);

-- AI conversations
create policy "ai_conversations_select_own" on public.ai_conversations
for select
using (auth.uid() = user_id);

create policy "ai_conversations_insert_own" on public.ai_conversations
for insert
with check (auth.uid() = user_id);

create policy "ai_conversations_update_own" on public.ai_conversations
for update
using (auth.uid() = user_id);

create policy "ai_conversations_delete_own" on public.ai_conversations
for delete
using (auth.uid() = user_id);

-- AI messages via conversation ownership
create policy "ai_messages_select_own" on public.ai_messages
for select
using (
  exists (
    select 1 from public.ai_conversations ac
    where ac.id = conversation_id and ac.user_id = auth.uid()
  )
);

create policy "ai_messages_insert_own" on public.ai_messages
for insert
with check (
  exists (
    select 1 from public.ai_conversations ac
    where ac.id = conversation_id and ac.user_id = auth.uid()
  )
);

-- User stats
create policy "user_stats_select_own" on public.user_stats
for select
using (auth.uid() = user_id);

create policy "user_stats_upsert_own" on public.user_stats
for insert
with check (auth.uid() = user_id);

create policy "user_stats_update_own" on public.user_stats
for update
using (auth.uid() = user_id);
