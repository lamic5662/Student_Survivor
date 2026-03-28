-- Admin support: profiles.is_admin + RLS policies for content authoring

alter table public.profiles
add column if not exists is_admin boolean not null default false;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.profiles p
    where p.id = auth.uid() and p.is_admin = true
  );
$$;

-- Allow admins to manage curriculum content
drop policy if exists "semesters_admin_insert" on public.semesters;
create policy "semesters_admin_insert" on public.semesters
for insert
with check (public.is_admin());

drop policy if exists "semesters_admin_update" on public.semesters;
create policy "semesters_admin_update" on public.semesters
for update
using (public.is_admin());

drop policy if exists "semesters_admin_delete" on public.semesters;
create policy "semesters_admin_delete" on public.semesters
for delete
using (public.is_admin());

drop policy if exists "subjects_admin_insert" on public.subjects;
create policy "subjects_admin_insert" on public.subjects
for insert
with check (public.is_admin());

drop policy if exists "subjects_admin_update" on public.subjects;
create policy "subjects_admin_update" on public.subjects
for update
using (public.is_admin());

drop policy if exists "subjects_admin_delete" on public.subjects;
create policy "subjects_admin_delete" on public.subjects
for delete
using (public.is_admin());

drop policy if exists "chapters_admin_insert" on public.chapters;
create policy "chapters_admin_insert" on public.chapters
for insert
with check (public.is_admin());

drop policy if exists "chapters_admin_update" on public.chapters;
create policy "chapters_admin_update" on public.chapters
for update
using (public.is_admin());

drop policy if exists "chapters_admin_delete" on public.chapters;
create policy "chapters_admin_delete" on public.chapters
for delete
using (public.is_admin());

drop policy if exists "notes_admin_insert" on public.notes;
create policy "notes_admin_insert" on public.notes
for insert
with check (public.is_admin());

drop policy if exists "notes_admin_update" on public.notes;
create policy "notes_admin_update" on public.notes
for update
using (public.is_admin());

drop policy if exists "notes_admin_delete" on public.notes;
create policy "notes_admin_delete" on public.notes
for delete
using (public.is_admin());

drop policy if exists "questions_admin_insert" on public.questions;
create policy "questions_admin_insert" on public.questions
for insert
with check (public.is_admin());

drop policy if exists "questions_admin_update" on public.questions;
create policy "questions_admin_update" on public.questions
for update
using (public.is_admin());

drop policy if exists "questions_admin_delete" on public.questions;
create policy "questions_admin_delete" on public.questions
for delete
using (public.is_admin());

drop policy if exists "quizzes_admin_insert" on public.quizzes;
create policy "quizzes_admin_insert" on public.quizzes
for insert
with check (public.is_admin());

drop policy if exists "quizzes_admin_update" on public.quizzes;
create policy "quizzes_admin_update" on public.quizzes
for update
using (public.is_admin());

drop policy if exists "quizzes_admin_delete" on public.quizzes;
create policy "quizzes_admin_delete" on public.quizzes
for delete
using (public.is_admin());

drop policy if exists "quiz_questions_admin_insert" on public.quiz_questions;
create policy "quiz_questions_admin_insert" on public.quiz_questions
for insert
with check (public.is_admin());

drop policy if exists "quiz_questions_admin_update" on public.quiz_questions;
create policy "quiz_questions_admin_update" on public.quiz_questions
for update
using (public.is_admin());

drop policy if exists "quiz_questions_admin_delete" on public.quiz_questions;
create policy "quiz_questions_admin_delete" on public.quiz_questions
for delete
using (public.is_admin());
