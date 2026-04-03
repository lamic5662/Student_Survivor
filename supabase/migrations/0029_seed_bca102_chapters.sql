-- Seed chapters for BCA 102 (C Programming)

with sem as (
  select id
  from public.semesters
  where code = 'BCA-1'
),
subj as (
  select s.id
  from public.subjects s
  join sem on s.semester_id = sem.id
  where s.code = 'BCA 102'
  limit 1
)
insert into public.chapters (subject_id, title, summary, sort_order)
select subj.id, v.title, v.summary, v.sort_order
from subj
cross join (values
  (1, 'Unit 1: Introduction to C Programming', 'Evolution, structure, tokens, variables, data types, operators.'),
  (2, 'Unit 2: Input/Output and Control Structures', 'I/O functions, decisions, loops, and jump statements.'),
  (3, 'Unit 3: Functions, Arrays and Strings', 'Functions, recursion, arrays, and string handling.'),
  (4, 'Unit 4: Structures, Unions, and Enumerations', 'Structured data types and typedef.'),
  (5, 'Unit 5: Pointers and Memory Management', 'Pointers, DMA, and memory safety.'),
  (6, 'Unit 6: File Handling, Command-Line, and Graphics', 'Files, CLI args, and basic graphics.'),
  (7, 'Laboratory Works', 'Practical exercises for C programming concepts.')
) as v(sort_order, title, summary)
where not exists (
  select 1 from public.chapters c
  where c.subject_id = subj.id and c.title = v.title
);
