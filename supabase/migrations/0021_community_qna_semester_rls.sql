-- Restrict community Q&A visibility to same-semester students

create or replace function public.has_same_semester(subject_uuid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1
    from public.profiles p
    join public.subjects s on s.id = subject_uuid
    where p.id = auth.uid()
      and p.semester_id = s.semester_id
  );
$$;

drop policy if exists "community_questions_select" on public.community_questions;
create policy "community_questions_select" on public.community_questions
for select
using (
  (status = 'approved' and public.has_same_semester(subject_id))
  or user_id = auth.uid()
  or public.is_admin()
);

drop policy if exists "community_questions_insert" on public.community_questions;
create policy "community_questions_insert" on public.community_questions
for insert
with check (
  auth.uid() = user_id
  and public.has_same_semester(subject_id)
);

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
    select 1
    from public.community_questions q
    where q.id = question_id
      and q.status = 'approved'
      and public.has_same_semester(q.subject_id)
  )
  or public.is_admin()
);

drop policy if exists "community_answers_insert" on public.community_answers;
create policy "community_answers_insert" on public.community_answers
for insert
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.community_questions q
    where q.id = question_id
      and q.status = 'approved'
      and public.has_same_semester(q.subject_id)
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
