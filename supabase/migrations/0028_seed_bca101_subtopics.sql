-- Seed subtopics for BCA 101 (Computer Fundamentals and Applications)

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
),
ch as (
  select id, title
  from public.chapters
  where subject_id = (select id from subj)
),
data as (
  select * from (values
    -- Unit 1
    ('Unit 1: Introduction to Computer', 1, 'Definition & Characteristics', 'Definition, characteristics of computer.'),
    ('Unit 1: Introduction to Computer', 2, 'Anatomy of Computer', 'Basic anatomy and components overview.'),
    ('Unit 1: Introduction to Computer', 3, 'Types of Computers', 'Size, principle, brand, and purpose.'),
    ('Unit 1: Introduction to Computer', 4, 'History & Generations', 'Computer history and generations.'),
    ('Unit 1: Introduction to Computer', 5, 'Applications', 'Applications of computers in various fields.'),

    -- Unit 2
    ('Unit 2: Computer Hardware', 1, 'Organization & Architecture', 'Basic computer organization and architecture.'),
    ('Unit 2: Computer Hardware', 2, 'System Components', 'Hardware, software, user, data, and procedures.'),
    ('Unit 2: Computer Hardware', 3, 'CPU Components', 'ALU, CU, and registers.'),
    ('Unit 2: Computer Hardware', 4, 'Memory & Hierarchy', 'Primary vs secondary memory, hierarchy.'),
    ('Unit 2: Computer Hardware', 5, 'Motherboard & Parts', 'Slots, ports, interface, processor, chips.'),
    ('Unit 2: Computer Hardware', 6, 'BIOS/CMOS/SMPS', 'BIOS, CMOS, SMPS, microprocessor chips.'),

    -- Unit 3
    ('Unit 3: Computer Software', 1, 'Software Basics', 'Software and program introduction.'),
    ('Unit 3: Computer Software', 2, 'Types of Software', 'System vs application software.'),
    ('Unit 3: Computer Software', 3, 'Operating Systems', 'Functions and types of OS.'),
    ('Unit 3: Computer Software', 4, 'Utilities & Security', 'Utility software, virus, antivirus.'),
    ('Unit 3: Computer Software', 5, 'Programming Languages', 'Language types and translators.'),

    -- Unit 4
    ('Unit 4: Database Management System', 1, 'Data/Database/DBMS', 'Introduction to data, database, DBMS.'),
    ('Unit 4: Database Management System', 2, 'DBMS Architecture', 'Database system architecture.'),
    ('Unit 4: Database Management System', 3, 'Database Models', 'Models and applications.'),
    ('Unit 4: Database Management System', 4, 'SQL vs NoSQL', 'Relational vs NoSQL concepts.'),
    ('Unit 4: Database Management System', 5, 'Data Warehousing', 'Intro to data warehousing.'),
    ('Unit 4: Database Management System', 6, 'Data Mining & Big Data', 'Mining and big data concepts.'),

    -- Unit 5
    ('Unit 5: Computer Network and Internet', 1, 'Network Basics', 'Network, intranet, internet.'),
    ('Unit 5: Computer Network and Internet', 2, 'Types & Topologies', 'Network types and LAN topologies.'),
    ('Unit 5: Computer Network and Internet', 3, 'Media & Devices', 'Transmission media and devices.'),
    ('Unit 5: Computer Network and Internet', 4, 'Data Communication', 'Transmission modes and basics.'),
    ('Unit 5: Computer Network and Internet', 5, 'OSI & Protocols', 'OSI reference model and protocols.'),
    ('Unit 5: Computer Network and Internet', 6, 'Web Concepts', 'WWW, URL, DNS, client-server.'),

    -- Unit 6
    ('Unit 6: Computer Security', 1, 'Threats & Attacks', 'Security threats and attacks.'),
    ('Unit 6: Computer Security', 2, 'Malware', 'Malicious software and virus types.'),
    ('Unit 6: Computer Security', 3, 'Security Mechanisms', 'Cryptography and digital signatures.'),
    ('Unit 6: Computer Security', 4, 'Protection Systems', 'Firewall, authentication, IDS.'),
    ('Unit 6: Computer Security', 5, 'Awareness & Policy', 'Security awareness and policy.'),

    -- Unit 7
    ('Unit 7: Contemporary Technology', 1, 'AI & Applications', 'AI basics and applications.'),
    ('Unit 7: Contemporary Technology', 2, 'ML & Neural Networks', 'Basic ML and neural network concepts.'),
    ('Unit 7: Contemporary Technology', 3, 'Blockchain & Bitcoin', 'Blockchain technology and bitcoin.'),
    ('Unit 7: Contemporary Technology', 4, 'IoT & Cloud', 'IoT and cloud computing uses.'),
    ('Unit 7: Contemporary Technology', 5, 'VR/AR', 'Virtual and augmented reality.'),

    -- Laboratory Works
    ('Laboratory Works', 1, 'Office Automation', 'Overview of office automation tools.'),
    ('Laboratory Works', 2, 'Word Processing Basics', 'Typing, editing, formatting, margins, printing.'),
    ('Laboratory Works', 3, 'Word Processing Tables', 'Create and format tables, large docs.'),
    ('Laboratory Works', 4, 'Spreadsheet Basics', 'Sheet concepts, addressing, basics.'),
    ('Laboratory Works', 5, 'Spreadsheet Functions', 'Formulas, logic, invoices, charts.'),
    ('Laboratory Works', 6, 'Presentation', 'Slides, master slides, formatting.'),
    ('Laboratory Works', 7, 'DOS Commands', 'Internal and external commands.'),
    ('Laboratory Works', 8, 'GUI OS & Files', 'GUI features, files/folders, control panel.'),
    ('Laboratory Works', 9, 'Internet Basics', 'WWW, browsing, search engines.'),
    ('Laboratory Works', 10, 'AI Tools Usage', 'Using AI tools for study/work.')
  ) as v(chapter_title, sort_order, title, summary)
)
insert into public.chapter_subtopics (chapter_id, title, summary, sort_order)
select c.id, d.title, d.summary, d.sort_order
from data d
join ch c on c.title = d.chapter_title
where not exists (
  select 1 from public.chapter_subtopics cs
  where cs.chapter_id = c.id and cs.title = d.title
);
