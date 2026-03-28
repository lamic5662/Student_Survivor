-- Seed data for Student Survivor (BCA Semesters)

-- Cleanup old BCA curriculum data (also removes dependent user progress via cascades)
delete from public.subjects
where semester_id in (
  select id from public.semesters where code like 'BCA-%'
);

-- Remove orphaned user data created by the cleanup
delete from public.study_tasks where subject_id is null;
delete from public.weak_topics where chapter_id is null;
delete from public.recommendations where note_id is null and question_id is null;

insert into public.semesters (name, code, sort_order)
values
  ('BCA Semester 1', 'BCA-1', 1),
  ('BCA Semester 2', 'BCA-2', 2),
  ('BCA Semester 3', 'BCA-3', 3),
  ('BCA Semester 4', 'BCA-4', 4),
  ('BCA Semester 5', 'BCA-5', 5),
  ('BCA Semester 6', 'BCA-6', 6),
  ('BCA Semester 7', 'BCA-7', 7),
  ('BCA Semester 8', 'BCA-8', 8)
on conflict (code)
do update set name = excluded.name, sort_order = excluded.sort_order;

-- Subjects for all semesters
insert into public.subjects (
  semester_id,
  name,
  code,
  description,
  accent_color,
  sort_order,
  syllabus_url
)
select
  s.id,
  v.name,
  v.code,
  v.description,
  v.accent_color,
  v.sort_order,
  v.syllabus_url
from public.semesters s
join (
  values
    ('BCA-1','Computer Fundamentals & Applications','BCA1-CFA','Computer basics, hardware, software, and networking fundamentals.','#2563EB',1,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-1','Programming in C','BCA1-C','Programming fundamentals using C.','#16A34A',2,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-1','Digital Logic','BCA1-DL','Number systems, Boolean algebra, and circuits.','#F97316',3,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-1','Mathematics I','BCA1-MATH1','Foundational mathematics for computing.','#9333EA',4,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-1','Professional Communication & Ethics','BCA1-PCE','Communication skills and ethics in IT.','#0EA5E9',5,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-1','Hardware Workshop','BCA1-HW','Hands-on PC assembly, installation, and troubleshooting.','#0F766E',6,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-2','Discrete Structure','BCA2-DS','Logic, sets, relations, graphs, and combinatorics.','#2563EB',1,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-2','Mathematics II','BCA2-MATH2','Matrices, differential equations, and probability.','#16A34A',2,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-2','Microprocessor & Architecture','BCA2-MPA','8085 architecture, instruction set, memory, and I/O.','#F97316',3,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-2','OOP in Java','BCA2-JAVA','Object-oriented programming using Java.','#9333EA',4,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-2','UI/UX Design','BCA2-UIUX','Design principles, wireframing, and prototyping.','#0EA5E9',5,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-2','Principles of Management','BCA2-POM','Management basics, planning, organizing, and leadership.','#0F766E',6,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-3','Data Structures & Algorithms','BCA3-DSA','Core data structures and algorithms.','#2563EB',1,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-3','Database Management System','BCA3-DBMS','Database concepts, SQL, normalization, and transactions.','#16A34A',2,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-3','Web Technology I','BCA3-WEB1','HTML, CSS, and JavaScript fundamentals.','#F97316',3,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-3','System Analysis & Design','BCA3-SAD','SDLC and system modeling.','#9333EA',4,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-3','Probability & Statistics','BCA3-STAT','Probability and statistical methods.','#0EA5E9',5,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-3','Applied Economics','BCA3-AE','Economic concepts for IT.','#0F766E',6,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-4','Operating System','BCA4-OS','Processes, scheduling, memory, and OS concepts.','#2563EB',1,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-4','Software Engineering','BCA4-SE','SDLC models, design, and testing.','#16A34A',2,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-4','Python Programming','BCA4-PY','Python fundamentals, functions, and OOP.','#F97316',3,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-4','Numerical Methods','BCA4-NM','Error analysis and numerical computation.','#9333EA',4,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-4','Web Technology II','BCA4-WEB2','Backend development and web security.','#0EA5E9',5,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-4','Project I','BCA4-PROJ1','Semester project work.','#0F766E',6,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-5','Computer Network','BCA5-CN','OSI, TCP/IP, routing, and network devices.','#2563EB',1,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-5','Artificial Intelligence','BCA5-AI','AI basics, search, and ML intro.','#16A34A',2,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-5','Advanced Java','BCA5-AJAVA','Servlets, JSP, and JDBC.','#F97316',3,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-5','MIS & E-Business','BCA5-MIS','MIS concepts, e-commerce, and ERP.','#9333EA',4,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-5','Society & Technology','BCA5-ST','Technology impact and social issues.','#0EA5E9',5,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-5','Project II','BCA5-PROJ2','Project II.','#0F766E',6,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-6','Mobile Programming','BCA6-MOBILE','Android/Flutter app development.','#2563EB',1,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-6','Distributed System','BCA6-DS','Distributed computing concepts.','#16A34A',2,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-6','Cryptography & Network Security','BCA6-CNS','Security fundamentals and cryptography.','#F97316',3,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-6','Computer Graphics & Animation','BCA6-CGA','Graphics and animation basics.','#9333EA',4,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-6','Technical Writing','BCA6-TW','Documentation and report writing.','#0EA5E9',5,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-6','Project III','BCA6-PROJ3','Project III.','#0F766E',6,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-7','Cyber Security & Ethical Hacking','BCA7-CSEH','Security threats and ethical hacking.','#2563EB',1,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-7','Software Project Management','BCA7-SPM','Planning, scheduling, and risk management.','#16A34A',2,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-7','Financial Accounting','BCA7-FA','Accounting principles and statements.','#F97316',3,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-7','Elective I','BCA7-EL1','Choose one elective course.','#9333EA',4,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-7','Elective II','BCA7-EL2','Choose one elective course.','#0EA5E9',5,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-7','Project IV','BCA7-PROJ4','Project IV.','#0F766E',6,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-8','Cloud Computing','BCA8-CC','Cloud services and virtualization.','#2563EB',1,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-8','Elective III','BCA8-EL3','Choose one elective course.','#16A34A',2,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-8','Elective IV','BCA8-EL4','Choose one elective course.','#F97316',3,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf'),
    ('BCA-8','Internship','BCA8-INTERN','Industry internship and report.','#9333EA',4,'https://portal.tu.edu.np/downloads/2025_11_27_15_22_42.pdf')
) as v(semester_code, name, code, description, accent_color, sort_order, syllabus_url)
  on v.semester_code = s.code
on conflict (semester_id, code)
do update set
  name = excluded.name,
  description = excluded.description,
  accent_color = excluded.accent_color,
  sort_order = excluded.sort_order,
  syllabus_url = excluded.syllabus_url;

-- Chapters for all subjects
with chapters_data(subject_code, title, sort_order) as (
  values
    ('BCA1-CFA','Computer Introduction & History',1),
    ('BCA1-CFA','Hardware Components',2),
    ('BCA1-CFA','Software Types',3),
    ('BCA1-CFA','Operating System',4),
    ('BCA1-CFA','Office Applications',5),
    ('BCA1-CFA','Internet & Networking Basics',6),
    ('BCA1-C','Basics of Programming',1),
    ('BCA1-C','Data Types & Operators',2),
    ('BCA1-C','Control Structures',3),
    ('BCA1-C','Functions',4),
    ('BCA1-C','Arrays & Strings',5),
    ('BCA1-C','Pointers',6),
    ('BCA1-C','File Handling',7),
    ('BCA1-DL','Number Systems',1),
    ('BCA1-DL','Boolean Algebra',2),
    ('BCA1-DL','Logic Gates',3),
    ('BCA1-DL','Combinational Circuits',4),
    ('BCA1-DL','Sequential Circuits',5),
    ('BCA1-MATH1','Set Theory',1),
    ('BCA1-MATH1','Functions',2),
    ('BCA1-MATH1','Algebra',3),
    ('BCA1-MATH1','Trigonometry',4),
    ('BCA1-MATH1','Limits',5),
    ('BCA1-PCE','Communication Process',1),
    ('BCA1-PCE','Technical Writing',2),
    ('BCA1-PCE','Report Writing',3),
    ('BCA1-PCE','Ethics in IT',4),
    ('BCA1-PCE','Professional Skills',5),
    ('BCA1-HW','PC Assembly',1),
    ('BCA1-HW','Installation',2),
    ('BCA1-HW','Troubleshooting',3),
    ('BCA2-DS','Logic & Proof',1),
    ('BCA2-DS','Sets & Relations',2),
    ('BCA2-DS','Functions',3),
    ('BCA2-DS','Graph Theory',4),
    ('BCA2-DS','Combinatorics',5),
    ('BCA2-MATH2','Matrices',1),
    ('BCA2-MATH2','Differential Equations',2),
    ('BCA2-MATH2','Probability Basics',3),
    ('BCA2-MPA','8085 Architecture',1),
    ('BCA2-MPA','Instruction Set',2),
    ('BCA2-MPA','Memory System',3),
    ('BCA2-MPA','I/O Interface',4),
    ('BCA2-JAVA','Java Basics',1),
    ('BCA2-JAVA','Classes & Objects',2),
    ('BCA2-JAVA','Inheritance',3),
    ('BCA2-JAVA','Polymorphism',4),
    ('BCA2-JAVA','Exception Handling',5),
    ('BCA2-JAVA','GUI',6),
    ('BCA2-UIUX','Design Principles',1),
    ('BCA2-UIUX','Wireframing',2),
    ('BCA2-UIUX','Prototyping',3),
    ('BCA2-UIUX','User Experience',4),
    ('BCA2-POM','Management Basics',1),
    ('BCA2-POM','Planning',2),
    ('BCA2-POM','Organizing',3),
    ('BCA2-POM','Leadership',4),
    ('BCA2-POM','Decision Making',5),
    ('BCA3-DSA','Arrays & Linked List',1),
    ('BCA3-DSA','Stack & Queue',2),
    ('BCA3-DSA','Trees',3),
    ('BCA3-DSA','Graphs',4),
    ('BCA3-DSA','Sorting',5),
    ('BCA3-DSA','Searching',6),
    ('BCA3-DBMS','DB Concepts',1),
    ('BCA3-DBMS','ER Diagram',2),
    ('BCA3-DBMS','Relational Model',3),
    ('BCA3-DBMS','SQL',4),
    ('BCA3-DBMS','Normalization',5),
    ('BCA3-DBMS','Transactions',6),
    ('BCA3-WEB1','HTML',1),
    ('BCA3-WEB1','CSS',2),
    ('BCA3-WEB1','JavaScript Basics',3),
    ('BCA3-SAD','SDLC',1),
    ('BCA3-SAD','Requirement Analysis',2),
    ('BCA3-SAD','Design Models',3),
    ('BCA3-STAT','Probability',1),
    ('BCA3-STAT','Distribution',2),
    ('BCA3-STAT','Hypothesis Testing',3),
    ('BCA3-AE','Demand & Supply',1),
    ('BCA3-AE','Market Structure',2),
    ('BCA3-AE','National Income',3),
    ('BCA4-OS','OS Basics',1),
    ('BCA4-OS','Process Management',2),
    ('BCA4-OS','Scheduling',3),
    ('BCA4-OS','Deadlock',4),
    ('BCA4-OS','Memory Management',5),
    ('BCA4-SE','SDLC Models',1),
    ('BCA4-SE','Requirement Engineering',2),
    ('BCA4-SE','Design',3),
    ('BCA4-SE','Testing',4),
    ('BCA4-PY','Python Basics',1),
    ('BCA4-PY','Functions',2),
    ('BCA4-PY','OOP in Python',3),
    ('BCA4-PY','File Handling',4),
    ('BCA4-NM','Error Analysis',1),
    ('BCA4-NM','Root Finding',2),
    ('BCA4-NM','Interpolation',3),
    ('BCA4-WEB2','PHP / Backend',1),
    ('BCA4-WEB2','Database Integration',2),
    ('BCA4-WEB2','Web Security',3),
    ('BCA4-PROJ1','Proposal',1),
    ('BCA4-PROJ1','Design',2),
    ('BCA4-PROJ1','Implementation',3),
    ('BCA5-CN','OSI Model',1),
    ('BCA5-CN','TCP/IP',2),
    ('BCA5-CN','Routing',3),
    ('BCA5-CN','Network Devices',4),
    ('BCA5-AI','AI Basics',1),
    ('BCA5-AI','Search Algorithms',2),
    ('BCA5-AI','Knowledge Representation',3),
    ('BCA5-AI','Machine Learning Intro',4),
    ('BCA5-AJAVA','Servlet',1),
    ('BCA5-AJAVA','JSP',2),
    ('BCA5-AJAVA','JDBC',3),
    ('BCA5-MIS','MIS Concepts',1),
    ('BCA5-MIS','E-Commerce',2),
    ('BCA5-MIS','ERP',3),
    ('BCA5-ST','Technology Impact',1),
    ('BCA5-ST','Social Issues',2),
    ('BCA5-PROJ2','Project II',1),
    ('BCA6-MOBILE','Android / Flutter Basics',1),
    ('BCA6-MOBILE','UI Design',2),
    ('BCA6-MOBILE','Activity Lifecycle',3),
    ('BCA6-MOBILE','API Integration',4),
    ('BCA6-MOBILE','Deployment',5),
    ('BCA6-DS','Concepts',1),
    ('BCA6-DS','Communication',2),
    ('BCA6-DS','Synchronization',3),
    ('BCA6-DS','Fault Tolerance',4),
    ('BCA6-CNS','Encryption',1),
    ('BCA6-CNS','Cryptography Techniques',2),
    ('BCA6-CNS','Network Security',3),
    ('BCA6-CGA','2D/3D Graphics',1),
    ('BCA6-CGA','Transformations',2),
    ('BCA6-CGA','Animation',3),
    ('BCA6-TW','Documentation',1),
    ('BCA6-TW','Reports',2),
    ('BCA6-TW','Proposal Writing',3),
    ('BCA6-PROJ3','Project III',1),
    ('BCA7-CSEH','Security Threats',1),
    ('BCA7-CSEH','Penetration Testing',2),
    ('BCA7-CSEH','Ethical Hacking',3),
    ('BCA7-SPM','Planning',1),
    ('BCA7-SPM','Scheduling',2),
    ('BCA7-SPM','Risk Management',3),
    ('BCA7-FA','Accounting Basics',1),
    ('BCA7-FA','Financial Statements',2),
    ('BCA7-EL1','Data Mining',1),
    ('BCA7-EL1','Machine Learning',2),
    ('BCA7-EL1','Big Data Analytics',3),
    ('BCA7-EL1','Internet of Things (IoT)',4),
    ('BCA7-EL1','Blockchain Technology',5),
    ('BCA7-EL1','Information Security',6),
    ('BCA7-EL1','Advanced Database',7),
    ('BCA7-EL1','Human Computer Interaction (HCI)',8),
    ('BCA7-EL1','Image Processing',9),
    ('BCA7-EL1','Natural Language Processing (NLP)',10),
    ('BCA7-EL1','Robotics',11),
    ('BCA7-EL1','Software Testing & QA (Advanced)',12),
    ('BCA7-EL2','Data Mining',1),
    ('BCA7-EL2','Machine Learning',2),
    ('BCA7-EL2','Big Data Analytics',3),
    ('BCA7-EL2','Internet of Things (IoT)',4),
    ('BCA7-EL2','Blockchain Technology',5),
    ('BCA7-EL2','Information Security',6),
    ('BCA7-EL2','Advanced Database',7),
    ('BCA7-EL2','Human Computer Interaction (HCI)',8),
    ('BCA7-EL2','Image Processing',9),
    ('BCA7-EL2','Natural Language Processing (NLP)',10),
    ('BCA7-EL2','Robotics',11),
    ('BCA7-EL2','Software Testing & QA (Advanced)',12),
    ('BCA7-PROJ4','Project IV',1),
    ('BCA8-CC','Cloud Basics',1),
    ('BCA8-CC','Virtualization',2),
    ('BCA8-CC','AWS',3),
    ('BCA8-EL3','Data Mining',1),
    ('BCA8-EL3','Machine Learning',2),
    ('BCA8-EL3','Big Data Analytics',3),
    ('BCA8-EL3','Internet of Things (IoT)',4),
    ('BCA8-EL3','Blockchain Technology',5),
    ('BCA8-EL3','Information Security',6),
    ('BCA8-EL3','Advanced Database',7),
    ('BCA8-EL3','Human Computer Interaction (HCI)',8),
    ('BCA8-EL3','Image Processing',9),
    ('BCA8-EL3','Natural Language Processing (NLP)',10),
    ('BCA8-EL3','Robotics',11),
    ('BCA8-EL3','Software Testing & QA (Advanced)',12),
    ('BCA8-EL4','Data Mining',1),
    ('BCA8-EL4','Machine Learning',2),
    ('BCA8-EL4','Big Data Analytics',3),
    ('BCA8-EL4','Internet of Things (IoT)',4),
    ('BCA8-EL4','Blockchain Technology',5),
    ('BCA8-EL4','Information Security',6),
    ('BCA8-EL4','Advanced Database',7),
    ('BCA8-EL4','Human Computer Interaction (HCI)',8),
    ('BCA8-EL4','Image Processing',9),
    ('BCA8-EL4','Natural Language Processing (NLP)',10),
    ('BCA8-EL4','Robotics',11),
    ('BCA8-EL4','Software Testing & QA (Advanced)',12),
    ('BCA8-INTERN','Industry Work',1),
    ('BCA8-INTERN','Report Writing',2)
)
insert into public.chapters (subject_id, title, summary, sort_order)
select sub.id, c.title, c.title, c.sort_order
from public.subjects sub
join chapters_data c on c.subject_code = sub.code
where not exists (
  select 1 from public.chapters ch
  where ch.subject_id = sub.id and ch.title = c.title
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
where s.code = 'BCA5-CN' and c.title = 'OSI Model'
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
where s.code = 'BCA5-CN' and c.title = 'TCP/IP'
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
where s.code = 'BCA5-CN' and c.title = 'OSI Model'
  and not exists (
    select 1 from public.questions q
    where q.chapter_id = c.id and q.prompt = 'Explain the OSI model with functions of each layer.'
  );

-- Quizzes
insert into public.quizzes (chapter_id, title, quiz_type, difficulty, duration_minutes, question_count)
select c.id, 'OSI Rapid MCQ', 'mcq', 'easy', 10, 10
from public.chapters c
join public.subjects s on s.id = c.subject_id
where s.code = 'BCA5-CN' and c.title = 'OSI Model'
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
  select 1 from public.quizzes q where q.chapter_id = c.id
);
