-- Seed questions from subtopics for BCA Year 1/2 courses

with target_subjects as (
  select id
  from public.subjects
  where code in (
    'BCA 103','BCA 104','BCA 105','BCA 106',
    'BCA 151','BCA 152','BCA 153','BCA 154','BCA 155','BCA 156'
  )
), target_chapters as (
  select c.id, c.title
  from public.chapters c
  join target_subjects s on c.subject_id = s.id
  where c.title not ilike '%Laboratory%'
)
insert into public.questions (chapter_id, prompt, marks, kind)
select tc.id,
       'Explain: ' || cs.title,
       5,
       'important'
from public.chapter_subtopics cs
join target_chapters tc on tc.id = cs.chapter_id
where not exists (
  select 1 from public.questions q
  where q.chapter_id = tc.id and q.prompt = 'Explain: ' || cs.title
);
