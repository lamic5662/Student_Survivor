-- Ensure every chapter has at least one quiz (AI Quick Quiz)
insert into public.quizzes (
  chapter_id,
  title,
  quiz_type,
  difficulty,
  duration_minutes,
  question_count
)
select
  c.id,
  'AI Quick Quiz',
  'mcq',
  'easy',
  10,
  10
from public.chapters c
where not exists (
  select 1
  from public.quizzes q
  where q.chapter_id = c.id
);
