-- Seed data for Student Survivor (BCA Semester 5)

insert into public.semesters (name, code, sort_order)
values ('BCA Semester 5', 'BCA-5', 5)
on conflict (code)
do update set name = excluded.name, sort_order = excluded.sort_order;

insert into public.subjects (semester_id, name, code, description, accent_color, sort_order)
select s.id, 'Computer Networking', 'CS-305', 'OSI, TCP/IP, routing, congestion', '#2563EB', 1
from public.semesters s
where s.code = 'BCA-5'
on conflict (semester_id, code)
do update set
  name = excluded.name,
  description = excluded.description,
  accent_color = excluded.accent_color,
  sort_order = excluded.sort_order;

insert into public.subjects (semester_id, name, code, description, accent_color, sort_order)
select s.id, 'Database Management System', 'CS-306', 'ER model, SQL, normalization', '#16A34A', 2
from public.semesters s
where s.code = 'BCA-5'
on conflict (semester_id, code)
do update set
  name = excluded.name,
  description = excluded.description,
  accent_color = excluded.accent_color,
  sort_order = excluded.sort_order;

-- Chapters
insert into public.chapters (subject_id, title, summary, sort_order)
select sub.id, 'OSI & TCP/IP Models', 'Layers and protocols', 1
from public.subjects sub
where sub.code = 'CS-305'
  and not exists (
    select 1 from public.chapters c
    where c.subject_id = sub.id and c.title = 'OSI & TCP/IP Models'
  );

insert into public.chapters (subject_id, title, summary, sort_order)
select sub.id, 'Routing & Switching', 'Routing basics and devices', 2
from public.subjects sub
where sub.code = 'CS-305'
  and not exists (
    select 1 from public.chapters c
    where c.subject_id = sub.id and c.title = 'Routing & Switching'
  );

insert into public.chapters (subject_id, title, summary, sort_order)
select sub.id, 'Relational Model', 'Keys, relations, constraints', 1
from public.subjects sub
where sub.code = 'CS-306'
  and not exists (
    select 1 from public.chapters c
    where c.subject_id = sub.id and c.title = 'Relational Model'
  );

-- Notes
insert into public.notes (chapter_id, title, short_answer, detailed_answer, tags)
select c.id,
  'OSI Layers Overview',
  'OSI has 7 layers: Physical, Data Link, Network, Transport, Session, Presentation, Application.',
  'The OSI model divides communication into seven layers. Each layer provides services to the layer above.',
  array['osi', 'layers']
from public.chapters c
join public.subjects s on s.id = c.subject_id
where s.code = 'CS-305' and c.title = 'OSI & TCP/IP Models'
  and not exists (
    select 1 from public.notes n
    where n.chapter_id = c.id and n.title = 'OSI Layers Overview'
  );

insert into public.notes (chapter_id, title, short_answer, detailed_answer, tags)
select c.id,
  'TCP vs UDP',
  'TCP is reliable and connection-oriented; UDP is faster and connectionless.',
  'TCP ensures ordered delivery with acknowledgements. UDP sends datagrams without guarantees.',
  array['tcp', 'udp']
from public.chapters c
join public.subjects s on s.id = c.subject_id
where s.code = 'CS-305' and c.title = 'OSI & TCP/IP Models'
  and not exists (
    select 1 from public.notes n
    where n.chapter_id = c.id and n.title = 'TCP vs UDP'
  );

-- Questions
insert into public.questions (chapter_id, prompt, marks, kind)
select c.id,
  'Explain the OSI model with functions of each layer.',
  10,
  'important'
from public.chapters c
join public.subjects s on s.id = c.subject_id
where s.code = 'CS-305' and c.title = 'OSI & TCP/IP Models'
  and not exists (
    select 1 from public.questions q
    where q.chapter_id = c.id and q.prompt = 'Explain the OSI model with functions of each layer.'
  );

-- Quizzes
insert into public.quizzes (chapter_id, title, quiz_type, difficulty, duration_minutes, question_count)
select c.id, 'OSI Rapid MCQ', 'mcq', 'easy', 10, 10
from public.chapters c
join public.subjects s on s.id = c.subject_id
where s.code = 'CS-305' and c.title = 'OSI & TCP/IP Models'
  and not exists (
    select 1 from public.quizzes q
    where q.chapter_id = c.id and q.title = 'OSI Rapid MCQ'
  );

insert into public.quiz_questions (quiz_id, prompt, options, correct_index, explanation, topic)
select q.id,
  'Which OSI layer handles routing?',
  '["Transport", "Network", "Session", "Presentation"]'::jsonb,
  1,
  'The Network layer is responsible for routing packets.',
  'OSI Layers'
from public.quizzes q
where q.title = 'OSI Rapid MCQ'
  and not exists (
    select 1 from public.quiz_questions qq
    where qq.quiz_id = q.id and qq.prompt = 'Which OSI layer handles routing?'
  );
