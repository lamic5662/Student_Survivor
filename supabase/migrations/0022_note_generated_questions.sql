-- Generated questions from official notes (per note owner)
create table if not exists public.note_generated_questions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  note_id uuid not null references public.notes(id) on delete cascade,
  chapter_id uuid not null references public.chapters(id) on delete cascade,
  question text not null,
  answer text,
  created_at timestamptz not null default now()
);

create index if not exists note_generated_questions_user_idx
  on public.note_generated_questions(user_id);
create index if not exists note_generated_questions_note_idx
  on public.note_generated_questions(note_id);
create index if not exists note_generated_questions_chapter_idx
  on public.note_generated_questions(chapter_id);

alter table public.note_generated_questions enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'note_generated_questions'
      and policyname = 'note_generated_questions_owner_select'
  ) then
    execute 'create policy "note_generated_questions_owner_select" on public.note_generated_questions for select using (auth.uid() = user_id)';
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'note_generated_questions'
      and policyname = 'note_generated_questions_owner_insert'
  ) then
    execute 'create policy "note_generated_questions_owner_insert" on public.note_generated_questions for insert with check (auth.uid() = user_id)';
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'note_generated_questions'
      and policyname = 'note_generated_questions_owner_update'
  ) then
    execute 'create policy "note_generated_questions_owner_update" on public.note_generated_questions for update using (auth.uid() = user_id)';
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'note_generated_questions'
      and policyname = 'note_generated_questions_owner_delete'
  ) then
    execute 'create policy "note_generated_questions_owner_delete" on public.note_generated_questions for delete using (auth.uid() = user_id)';
  end if;
end $$;
