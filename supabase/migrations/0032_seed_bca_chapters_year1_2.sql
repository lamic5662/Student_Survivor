-- Seed chapters for BCA 103-106 (Semester 1) and BCA 151-156 (Semester 2)

-- Semester 1 subjects
with sem as (
  select id
  from public.semesters
  where code = 'BCA-1'
)
-- BCA 103 Digital Logic
insert into public.chapters (subject_id, title, summary, sort_order)
select s.id, v.title, v.summary, v.sort_order
from public.subjects s
join sem on s.semester_id = sem.id
cross join (values
  (1, 'Unit 1: Digital Design Fundamentals and Number System', 'Analog vs digital systems and number systems.'),
  (2, 'Unit 2: Boolean Algebra and Its Simplification', 'Logic gates, Boolean laws, and K-Map minimization.'),
  (3, 'Unit 3: Combinational Logic Design', 'Adders, subtractors, encoders/decoders, and multiplexers.'),
  (4, 'Unit 4: Sequential Logic Design', 'State machines, flip-flops, and timing.'),
  (5, 'Unit 5: Counters and Registers', 'Counters, shift registers, and register operations.'),
  (6, 'Laboratory Works', 'Practical digital logic exercises and implementations.')
) as v(sort_order, title, summary)
where s.code = 'BCA 103'
  and not exists (
    select 1 from public.chapters c
    where c.subject_id = s.id and c.title = v.title
  );

-- BCA 104 Mathematics I
with sem as (
  select id
  from public.semesters
  where code = 'BCA-1'
)
insert into public.chapters (subject_id, title, summary, sort_order)
select s.id, v.title, v.summary, v.sort_order
from public.subjects s
join sem on s.semester_id = sem.id
cross join (values
  (1, 'Unit 1: Logic, Relations, Functions, and Graphs', 'Logic basics, real numbers, relations, functions, and graphs.'),
  (2, 'Unit 2: Sequence and Series', 'Arithmetic, geometric, and harmonic sequences and series.'),
  (3, 'Unit 3: Matrices and Determinants', 'Matrix algebra, determinants, and linear transformations.'),
  (4, 'Unit 4: Analytical Geometry', 'Conic sections and polar/Cartesian equations.'),
  (5, 'Unit 5: Vector and Vector Space', 'Vectors, vector operations, and vector spaces.'),
  (6, 'Unit 6: Permutations and Combinations', 'Counting principles and combinatorics.'),
  (7, 'Laboratory Works', 'Numerical problem solving with Python/MATLAB/Mathematica.')
) as v(sort_order, title, summary)
where s.code = 'BCA 104'
  and not exists (
    select 1 from public.chapters c
    where c.subject_id = s.id and c.title = v.title
  );

-- BCA 105 Professional Communication and Ethics
with sem as (
  select id
  from public.semesters
  where code = 'BCA-1'
)
insert into public.chapters (subject_id, title, summary, sort_order)
select s.id, v.title, v.summary, v.sort_order
from public.subjects s
join sem on s.semester_id = sem.id
cross join (values
  (1, 'Unit 1: Foundation of Professional Communication', 'Language fundamentals and communication process.'),
  (2, 'Unit 2: Oral Communication', 'Presentations, meetings, and professional dialogue.'),
  (3, 'Unit 3: Writing Professionally', 'Emails, memos, letters, and resumes.'),
  (4, 'Unit 4: Interpersonal and Group Communication', 'Team communication and leadership skills.'),
  (5, 'Unit 5: Digital Communication', 'Online professionalism and digital communication.'),
  (6, 'Unit 6: Professional Ethics', 'Ethics in computing and professional practice.')
) as v(sort_order, title, summary)
where s.code = 'BCA 105'
  and not exists (
    select 1 from public.chapters c
    where c.subject_id = s.id and c.title = v.title
  );

-- BCA 106 Hardware Workshop
with sem as (
  select id
  from public.semesters
  where code = 'BCA-1'
)
insert into public.chapters (subject_id, title, summary, sort_order)
select s.id, v.title, v.summary, v.sort_order
from public.subjects s
join sem on s.semester_id = sem.id
cross join (values
  (1, 'Unit 1: Introduction to Hardware (Electronic Components)', 'Electronics basics and component identification.'),
  (2, 'Unit 2: Introduction of Networking Components', 'Network devices, cabling, and connectors.'),
  (3, 'Unit 3: Desktop and Laptop Hardware Identification and Handling', 'System components and safe handling.'),
  (4, 'Unit 4: PC and Laptop Assembly', 'Assembly, BIOS setup, and troubleshooting.'),
  (5, 'Unit 5: Basic Network Device and Deployment', 'Device setup and basic sharing.'),
  (6, 'Unit 6: Basic Networking Configuration', 'IP addressing and device configuration.'),
  (7, 'Unit 7: Problem Solving Techniques', 'Systematic troubleshooting and diagnostics.'),
  (8, 'Unit 8: Maintenance and Upgrade', 'Preventive maintenance and upgrades.'),
  (9, 'Unit 9: Final Practical Assessment', 'Hands-on assessment tasks.')
) as v(sort_order, title, summary)
where s.code = 'BCA 106'
  and not exists (
    select 1 from public.chapters c
    where c.subject_id = s.id and c.title = v.title
  );

-- Semester 2 subjects
with sem as (
  select id
  from public.semesters
  where code = 'BCA-2'
)
-- BCA 151 Discrete Structure
insert into public.chapters (subject_id, title, summary, sort_order)
select s.id, v.title, v.summary, v.sort_order
from public.subjects s
join sem on s.semester_id = sem.id
cross join (values
  (1, 'Unit 1: Set Theory', 'Sets, operations, and set identities.'),
  (2, 'Unit 2: Logic and Propositional Calculus', 'Logic operators and truth tables.'),
  (3, 'Unit 3: Relations and Functions', 'Relations, matrices, and function properties.'),
  (4, 'Unit 4: Mathematical Reasoning and Proof Techniques', 'Proof strategies and reasoning.'),
  (5, 'Unit 5: Combinatorics and Counting Principles', 'Counting, permutations, and combinations.'),
  (6, 'Unit 6: Graph Theory and Trees', 'Graphs, trees, and traversals.'),
  (7, 'Unit 7: Algebraic Structures', 'Algebraic structures and Boolean algebra.'),
  (8, 'Laboratory Works', 'Practical tasks using tools like Python/Graphviz.')
) as v(sort_order, title, summary)
where s.code = 'BCA 151'
  and not exists (
    select 1 from public.chapters c
    where c.subject_id = s.id and c.title = v.title
  );

-- BCA 152 Microprocessor and Computer Architecture
with sem as (
  select id
  from public.semesters
  where code = 'BCA-2'
)
insert into public.chapters (subject_id, title, summary, sort_order)
select s.id, v.title, v.summary, v.sort_order
from public.subjects s
join sem on s.semester_id = sem.id
cross join (values
  (1, 'Unit 1: Introduction to Microprocessor', 'Microprocessor basics and system buses.'),
  (2, 'Unit 2: 8085 Microprocessor', 'Architecture, instruction set, and programming.'),
  (3, 'Unit 3: 8086 Microprocessor', 'Architecture and segmentation.'),
  (4, 'Unit 4: Basic Computer Architecture and Design', 'Registers, buses, and instruction cycle.'),
  (5, 'Unit 5: Microprogrammed Control Unit', 'Microinstructions and control memory.'),
  (6, 'Unit 6: Central Processing Unit', 'Register organization and instruction formats.'),
  (7, 'Unit 7: Computer Arithmetic', 'Signed arithmetic and multiplication.'),
  (8, 'Unit 8: Input/Output and Memory Organization', 'I/O interfaces, DMA, and memory hierarchy.'),
  (9, 'Unit 9: Pipelining', 'Pipelining concepts and speed-up.')
) as v(sort_order, title, summary)
where s.code = 'BCA 152'
  and not exists (
    select 1 from public.chapters c
    where c.subject_id = s.id and c.title = v.title
  );

-- BCA 153 OOP in Java
with sem as (
  select id
  from public.semesters
  where code = 'BCA-2'
)
insert into public.chapters (subject_id, title, summary, sort_order)
select s.id, v.title, v.summary, v.sort_order
from public.subjects s
join sem on s.semester_id = sem.id
cross join (values
  (1, 'Unit 1: Introduction to Java and OOP Concepts', 'Java basics and OOP principles.'),
  (2, 'Unit 2: Basic Java Programming', 'Syntax, data types, control flow, and arrays.'),
  (3, 'Unit 3: Class and Objects in Java', 'Classes, constructors, and methods.'),
  (4, 'Unit 4: Inheritance and Polymorphism', 'Inheritance, interfaces, and abstraction.'),
  (5, 'Unit 5: Exception Handling and Multithreading', 'Exceptions and threading basics.'),
  (6, 'Unit 6: File Handling in Java', 'Streams, files, and serialization.'),
  (7, 'Unit 7: Collections and Generics', 'Collections framework and generics.'),
  (8, 'Unit 8: Advanced OOP Concepts in Java', 'Design patterns, lambdas, streams.')
) as v(sort_order, title, summary)
where s.code = 'BCA 153'
  and not exists (
    select 1 from public.chapters c
    where c.subject_id = s.id and c.title = v.title
  );

-- BCA 154 Mathematics II
with sem as (
  select id
  from public.semesters
  where code = 'BCA-2'
)
insert into public.chapters (subject_id, title, summary, sort_order)
select s.id, v.title, v.summary, v.sort_order
from public.subjects s
join sem on s.semester_id = sem.id
cross join (values
  (1, 'Unit 1: Limit and Continuity', 'Limits, continuity, and related properties.'),
  (2, 'Unit 2: Derivatives', 'Derivative definitions and rules.'),
  (3, 'Unit 3: Applications of Derivatives', 'Maxima/minima, tangents, and applications.'),
  (4, 'Unit 4: Anti-derivative and Its Applications', 'Integration and its applications.'),
  (5, 'Unit 5: Differential Equations', 'ODE/PDE basics and methods.'),
  (6, 'Unit 6: Computational Methods', 'Numerical and optimization methods.')
) as v(sort_order, title, summary)
where s.code = 'BCA 154'
  and not exists (
    select 1 from public.chapters c
    where c.subject_id = s.id and c.title = v.title
  );

-- BCA 155 UX/UI Design
with sem as (
  select id
  from public.semesters
  where code = 'BCA-2'
)
insert into public.chapters (subject_id, title, summary, sort_order)
select s.id, v.title, v.summary, v.sort_order
from public.subjects s
join sem on s.semester_id = sem.id
cross join (values
  (1, 'Unit 1: Introduction', 'UX/UI fundamentals, principles, and tools.'),
  (2, 'Unit 2: User Interaction Design', 'Research, personas, and ideation.'),
  (3, 'Unit 3: User Interface Design', 'UI principles and interaction styles.'),
  (4, 'Unit 4: UI Components', 'Menus, windows, and controls.'),
  (5, 'Unit 5: UI Design Considerations', 'Layout, typography, and navigation.'),
  (6, 'Unit 6: Wireframing and Prototyping', 'Wireframes, mockups, and prototyping.'),
  (7, 'Unit 7: Design Evaluations', 'Evaluation methods and usability testing.'),
  (8, 'Unit 8: Advanced Techniques', 'VUI, NLP, and advanced interface ideas.'),
  (9, 'Laboratory Works', 'Hands-on design tasks with tools like Figma.')
) as v(sort_order, title, summary)
where s.code = 'BCA 155'
  and not exists (
    select 1 from public.chapters c
    where c.subject_id = s.id and c.title = v.title
  );

-- BCA 156 Principles of Management
with sem as (
  select id
  from public.semesters
  where code = 'BCA-2'
)
insert into public.chapters (subject_id, title, summary, sort_order)
select s.id, v.title, v.summary, v.sort_order
from public.subjects s
join sem on s.semester_id = sem.id
cross join (values
  (1, 'Unit 1: Introduction to Management', 'Concepts, functions, and managerial roles.'),
  (2, 'Unit 2: Planning and Decision Making', 'Planning process and decision tools.'),
  (3, 'Unit 3: Organizing', 'Organization structure and design.'),
  (4, 'Unit 4: Leading', 'Leadership approaches and team management.')
) as v(sort_order, title, summary)
where s.code = 'BCA 156'
  and not exists (
    select 1 from public.chapters c
    where c.subject_id = s.id and c.title = v.title
  );
