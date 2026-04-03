-- Seed chapters for BCA 101 (Semester 1)

with sem as (
  select id
  from public.semesters
  where code = 'BCA-1'
),
subj as (
  select s.id
  from public.subjects s
  join sem on s.semester_id = sem.id
  where s.code = 'BCA 101'
  limit 1
)
insert into public.chapters (subject_id, title, summary, sort_order)
select subj.id, v.title, v.summary, v.sort_order
from subj
cross join (values
  (1, 'Unit 1: Introduction to Computer', 'Definition, characteristics, anatomy, types, history, applications.'),
  (2, 'Unit 2: Computer Hardware', 'Organization, components, CPU, memory, motherboard, BIOS/CMOS/SMPS.'),
  (3, 'Unit 3: Computer Software', 'Software types, OS, utilities, virus/antivirus, translators.'),
  (4, 'Unit 4: Database Management System', 'Data/DB/DBMS, architecture, models, SQL/NoSQL, warehousing, mining.'),
  (5, 'Unit 5: Computer Network and Internet', 'Network types, media, devices, OSI, web/URL/DNS, client-server.'),
  (6, 'Unit 6: Computer Security', 'Threats, malware, cryptography, firewall, IDS, security policy.'),
  (7, 'Unit 7: Contemporary Technology', 'AI/ML, blockchain, IoT, cloud, VR/AR.'),
  (8, 'Laboratory Works', 'Office tools, word processor, spreadsheet, presentation, DOS, GUI, internet, AI tools.')
) as v(sort_order, title, summary)
where not exists (
  select 1 from public.chapters c
  where c.subject_id = subj.id and c.title = v.title
);
