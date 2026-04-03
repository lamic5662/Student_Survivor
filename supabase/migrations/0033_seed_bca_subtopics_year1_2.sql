-- Seed subtopics for BCA Year 1/2 courses (from OCR)

-- BCA 103 subtopics
with subj as (
  select id from public.subjects where code = 'BCA 103' limit 1
), ch as (
  select id, sort_order from public.chapters where subject_id = (select id from subj)
)
insert into public.chapter_subtopics (chapter_id, title, summary, sort_order)
select ch.id, v.title, '', v.sort_order
from ch
join (values
  (1, 1, 'Analog and digital Signal'),
  (1, 2, 'Analog and digital System'),
  (1, 3, 'Number System Representation'),
  (1, 4, 'Binary Number System'),
  (1, 5, 'Octal Number System'),
  (1, 6, 'Decimal Number System'),
  (1, 7, 'Hexadecimal Number System'),
  (1, 8, 'Representation of signed numbers, FI loating point number'),
  (1, 9, 'Complement of Number Systems'),
  (1, 10, 'r’s complement'),
  (1, 11, 'r-1’s complement (with r as 2 or 10)'),
  (1, 12, 'Binary Arithmetic'),
  (1, 13, 'Representation of BCD, ASCI I, Excess 3, Gray Code, Error Detection Codes'),
  (2, 1, 'Basic Logic Gates: AND, OR and NOT'),
  (2, 2, 'Universal Logic Gates: NAND and NOR'),
  (2, 3, 'Extended/Derived Logic Gates: Ex-OR and Ex-NOR'),
  (2, 4, 'Boolean Algebra'),
  (2, 5, 'Postulates and Theorems'),
  (2, 6, 'Canonical Forms(SOP, POS)'),
  (2, 7, 'Simplification of Boolean Functions using laws'),
  (2, 8, 'Simplification of Logic Function using Karnaugh Map'),
  (2, 9, 'Analysis of SOP and POS expressions'),
  (2, 10, 'Simplification of up to 5 variable Boolean expression using Quine-McCluskey Minimization'),
  (3, 1, 'Implementation of Combinational Logic Function'),
  (3, 2, 'Half Adder and Full Adder'),
  (3, 3, 'Half Subtractor and Full Subiractor'),
  (3, 4, 'Encoders and Decoders'),
  (3, 5, 'Implementation of data processing circuits'),
  (3, 6, 'Multiplexers and Demuttiplexers'),
  (3, 7, 'Parallel Binary adder'),
  (3, 8, 'Magnitude comparator (2bit and 4 bit)'),
  (3, 9, 'Code Converters'),
  (3, 10, 'Parity Generator and checker'),
  (3, 11, 'Basic Concepts of Programmable Logic'),
  (3, 12, 'ROM'),
  (3, 13, 'PAL'),
  (3, 14, 'PLA'),
  (4, 1, 'Concept of Sate and State Diagram > z'),
  (4, 2, 'State Reduction technique <'),
  (4, 3, 'Triggering and its types ait os'),
  (4, 4, 'Latches and Flip-Flops (RS,D,T,JK, Master-Slave)'),
  (5, 1, 'Asynchronous and Synchronous Counter'),
  (5, 2, 'Ripple counter'),
  (5, 3, 'Ring counter'),
  (5, 4, 'Modulus 10 Counter'),
  (5, 5, 'Modulus counter (5,7,11)'),
  (5, 6, 'Synchronous Design of above counters'),
  (5, 7, 'Registers'),
  (5, 8, 'Serial in Parallel out register'),
  (5, 9, 'Serial in Serial out register'),
  (5, 10, 'Parallel in Parallel out register'),
  (5, 11, 'Parallel in Serial out register'),
  (5, 12, 'Bidirectional Shift Register')
) as v(unit_order, sort_order, title) on ch.sort_order = v.unit_order
where not exists (
  select 1 from public.chapter_subtopics cs where cs.chapter_id = ch.id and cs.title = v.title
);

-- BCA 106 subtopics
with subj as (
  select id from public.subjects where code = 'BCA 106' limit 1
), ch as (
  select id, sort_order from public.chapters where subject_id = (select id from subj)
)
insert into public.chapter_subtopics (chapter_id, title, summary, sort_order)
select ch.id, v.title, '', v.sort_order
from ch
join (values
  (1, 1, 'Introduction to Electronics & Safety NS E'),
  (1, 2, 'Active Components: Diodes, LEDs, Transistors, ICs'),
  (1, 3, 'Connectors, Switches, Relays, Buzzers, Crystals'),
  (1, 4, 'Reading Datasheets and Packaging Types'),
  (1, 5, 'Testing and Troubleshooting Components'),
  (2, 1, 'Overview of Network Devices'),
  (2, 2, 'Cabling & Connectors'),
  (2, 3, 'Testing and troubleshooting Common physical Issues'),
  (3, 1, 'Introduction to PC Hardware'),
  (3, 2, 'Preparing the Workbench & Safety'),
  (3, 3, 'System Unit Components :'),
  (3, 4, 'Storage Devices'),
  (3, 5, 'Input/Output Devices'),
  (3, 6, 'Understanding, role and Testing the Power Supply Unit (PSU)'),
  (3, 7, 'PSU Overview (ATX, Modular, SMPS)'),
  (3, 8, 'PSU Connectors and Their Purposes'),
  (3, 9, 'Voltage Standards (3.3V, 5V, 12V rails)'),
  (3, 10, 'Testing PSU with Multimeter'),
  (3, 11, 'Common PSU Failures'),
  (3, 12, 'Safety Tips for Handling PSUs'),
  (4, 1, 'Connecting PSU, Storage, and Cables'),
  (4, 2, 'BIOS/UEFI Configuration & POST Checks'),
  (4, 3, 'Troubleshooting Basics'),
  (4, 4, 'Installing Operating System (Optional)'),
  (4, 5, 'Troubleshooting & Diagnostics'),
  (4, 6, 'Final Practical Assessment'),
  (5, 1, 'Identification of Different Network devices, (Modem, NIC, Hub, Switch, Router, AP)'),
  (5, 2, 'Sharing'),
  (5, 3, 'Preventive Maintenance Tips'),
  (6, 1, 'IP Addressing, Subnetting'),
  (6, 2, 'Router & Switch Configuration'),
  (6, 3, 'Wireless Access Points (AP) & Extenders'),
  (6, 4, 'Network Design and Topologies'),
  (6, 5, 'Testing & Diagnostics'),
  (6, 6, 'Troubleshooting Common Issues'),
  (7, 1, 'Start with visual inspection: loose cables, damaged ports'),
  (7, 2, 'Use elimination method: test one part at a time'),
  (7, 3, 'Check for BIOS/UEF1 messages and beep codes'),
  (7, 4, 'Use ping, ipconfig/ifconfig, and network tester tools for network issues'),
  (7, 5, 'Follow a systematic approach: Identify > Test — Isolate > Fix > Verify'),
  (8, 1, 'Upgrade Planning & Compatibility Checks'),
  (8, 2, 'Memory (RAM) Upgrades'),
  (8, 3, 'Storage Upgrades'),
  (8, 4, 'Graphics Card (GPU) Upgrade (Desktop)'),
  (8, 5, 'CPU Upgrade Tips (Desktop)'),
  (8, 6, 'Cleaning Internal Components'),
  (8, 7, 'Thermal Paste Replacement (Advanced Task)'),
  (8, 8, 'Battery Care for Laptops'),
  (8, 9, 'BIOS/UEFI & Firmware Updates'),
  (8, 10, 'Cable Management & Airflow Optimization'),
  (8, 11, 'Health Monitoring & Diagnostics'),
  (9, 1, 'Hardware Identification and Handling: Label parts, explain function, use anti-static'),
  (9, 2, 'PC Assembly/Disassembly: Step-by-step guided practice using femo PCs'),
  (9, 3, 'Network Setup: Configure wired LAN, assign IPs, test with ping,'),
  (9, 4, 'Troubleshooting Simulations: Use POST card, interpret beep codes, fix connectivity'),
  (9, 5, 'Maintenance Tasks; Clean internal components, apply thermal paste, verify power')
) as v(unit_order, sort_order, title) on ch.sort_order = v.unit_order
where not exists (
  select 1 from public.chapter_subtopics cs where cs.chapter_id = ch.id and cs.title = v.title
);

-- BCA 151 subtopics
with subj as (
  select id from public.subjects where code = 'BCA 151' limit 1
), ch as (
  select id, sort_order from public.chapters where subject_id = (select id from subj)
)
insert into public.chapter_subtopics (chapter_id, title, summary, sort_order)
select ch.id, v.title, '', v.sort_order
from ch
join (values
  (1, 1, 'Basic Concepts: Sets, elements, roster and set-builder notation, cardinality'),
  (1, 2, 'Set Relationships: ,'),
  (1, 3, 'Subsets Sy #'),
  (1, 4, 'Proper subsets — aw ng'),
  (1, 5, 'Universal set Leggo 8 aN'),
  (1, 6, 'Complement'),
  (1, 7, 'Disjoint sets'),
  (1, 8, 'Set Operations'),
  (1, 9, 'Union'),
  (1, 10, 'Intersection'),
  (1, 11, 'Difference'),
  (1, 12, 'Symmetric difference'),
  (1, 13, 'Venn Diagrams: Visual representation of set relationships and operations'),
  (1, 14, 'Cartesian Products: Ordered pairs, cross Product of two or more sets'),
  (1, 15, 'Power Sets: Definition and computation of power sets'),
  (1, 16, 'Applications: Use of sets in databases, computer programming, and decision structures'),
  (2, 1, 'Propasitions and Logical Operators: Definition of propositions, types (simple,'),
  (2, 2, 'Truth Tables: Constructing truth tables for expressions involving logical operators'),
  (2, 3, 'Tautologies, Contradictions, and Contingencies: Identifying always true/false/logical'),
  (2, 4, 'Logical Equivalence and Implications: Laws of logic (De Morgan''s, distributive,'),
  (2, 5, 'Predicate Logic and Quantifiers: Introduction to predicates, universal and existential'),
  (2, 6, 'Rules of Inference: Modus ponens, modus tollens, hypothetical syllogism, and others,'),
  (2, 7, 'Proof Methods: Direct, indirect, contradiction, contrapositive, and proof by cases'),
  (3, 1, 'Relations: Definition, Binary Relation, Representation, Domain, Range, Universal'),
  (3, 2, 'Properties of Binary Relations in a Set : Reflexive, Symmetric, Transitive, Anti'),
  (3, 3, 'Relation Matrix and Graph of a Relation; Partition and Covering of a Set, Equivalence'),
  (3, 4, 'Transitive Closure of a Relation R in Set X, examples from real-world scenarios'),
  (3, 5, 'Representation of Relations: Using matrices and directed graphs (digraphs)'),
  (3, 6, 'Equivalence and Partial Order Relations: Properties and examples, Simple or Linear'),
  (3, 7, 'Closures and Composition of Relations: Reflexive, symmetric, transitive closures'),
  (3, 8, 'Functions: Definition, domain, co-domain, range, examples'),
  (3, 9, 'Types of Functions: Injective (one-to-one), surjective (onto), bijective (one-to-one'),
  (3, 10, 'Inverse and Composition of Functions: Definitions and computations'),
  (3, 11, 'Applications: Use in programming, data mapping, and relational databases,'),
  (4, 1, '| Mathematical Reasoning: Basic structure of arguments, logical flow'),
  (4, 2, 'Mathematical Induction: Principle of induction, proof by induction, applications in series'),
  (4, 3, 'Strong Induction: Differences from regular induction, applications'),
  (4, 4, 'Recursive Definitions: Defining sequences and structures recursively'),
  (4, 5, 'Structural Induction: Proofs involving recursively defined structures like trees and lists'),
  (4, 6, 'Applications: Problem-solving and validation of algorithms'),
  (5, 1, 'Basic Counting Principles: Introduction to counting, rule of sum and rule of product with'),
  (5, 2, 'Permutations and Combinations: Concepts of ordered and unordered selections, factorial'),
  (5, 3, 'Pigeonhole Principle: Understanding the concept, simple and strong pigeonhole principle,'),
  (5, 4, 'Inclusion-Exclusion Principle: Set-based approach to solving overlapping sets, solving'),
  (6, 1, 'Graphs: Introduction, definition, examples; Nodes, edges, adjacent nodes, directed and'),
  (6, 2, 'Subgraphs: definition, examples; Converse (reversal or directional dual) of a digraph,'),
  (6, 3, 'Path: Definition, Paths of a given graph, length of path, examples; Simple path (edge'),
  (6, 4, 'Connectedness: Definition, weakly connected, strongly connected, unilaterally'),
  (6, 5, 'Matrix representation of graph: Definition, Adjacency matrix, boolean (or bit) matrix,'),
  (6, 6, 'Types of Graphs: Simple, multigraph, weighted, directed/undirected, complete, bipartite'),
  (6, 7, 'Graph Traversal: Breadth-First Search (BFS), Depth-First Search (DFS)'),
  (6, 8, 'Trees: Trees: Definition, branch nodes, leaf (terminal) nodes, root, examples;'),
  (6, 9, 'Different representations of a tree, examples; Binary tree, m-ary tree, Full (or complete)'),
  (6, 10, 'Converting any m-ary tree to a binary tree, examples;'),
  (6, 11, 'Representation of a binary tree: Linked-list; algorithms; Applications of List structures'),
  (6, 12, 'Tree Traversals: Inorder, preorder, postorder traversal techniques. ‘'),
  (7, 1, 'Binary Operations: Definition and examples of binary operations on sets'),
  (7, 2, 'Algebraic Systems: Semigroups, monoids, and groups - axioms and properties'),
  (7, 3, 'Group Theory Basics: Identity element, inverse, associativity, examples with integers and'),
  (7, 4, 'Boolean Algebra: Basic postulates and theorems, duality, Boolean functions'),
  (7, 5, 'Logie Circuits: Simplification of logic circuits using Boolean expressions'),
  (7, 6, 'Applications: Automata theory, logic design, cryptography')
) as v(unit_order, sort_order, title) on ch.sort_order = v.unit_order
where not exists (
  select 1 from public.chapter_subtopics cs where cs.chapter_id = ch.id and cs.title = v.title
);

-- BCA 152 subtopics
with subj as (
  select id from public.subjects where code = 'BCA 152' limit 1
), ch as (
  select id, sort_order from public.chapters where subject_id = (select id from subj)
)
insert into public.chapter_subtopics (chapter_id, title, summary, sort_order)
select ch.id, v.title, '', v.sort_order
from ch
join (values
  (2, 1, 'Functional Block Diagram, Pin Configuration, Description of each'),
  (2, 2, '8085 Instruction Set'),
  (2, 3, 'Basic Assembly Language Programming using 8085 Instruction Sets'),
  (3, 1, 'Logical black diagram and components, Bus interface unit and'),
  (5, 1, 'Hardwired vs micro program CU, Control Memory, Address'),
  (6, 1, 'Introduction, General Register Organization, Stack Organization,'),
  (6, 2, 'RISC and CISC architecture'),
  (9, 1, 'Arithmetic Pipeline, Pipeline for Floating-point Addition and')
) as v(unit_order, sort_order, title) on ch.sort_order = v.unit_order
where not exists (
  select 1 from public.chapter_subtopics cs where cs.chapter_id = ch.id and cs.title = v.title
);

-- BCA 153 subtopics
with subj as (
  select id from public.subjects where code = 'BCA 153' limit 1
), ch as (
  select id, sort_order from public.chapters where subject_id = (select id from subj)
)
insert into public.chapter_subtopics (chapter_id, title, summary, sort_order)
select ch.id, v.title, '', v.sort_order
from ch
join (values
  (1, 1, 'Java Architecture: JVM, JDK. and JRE ! Ri ‘'),
  (1, 2, 'Procedural-oriented Vs. Object-oriented Programming'),
  (1, 3, 'Setting up java environment and IDE in Local machine'),
  (1, 4, 'Sample java programs'),
  (1, 5, 'Compiling and running java program'),
  (1, 6, 'Command-line arguments'),
  (1, 7, 'Scanner class for input'),
  (1, 8, 'Handling common errors'),
  (2, 1, 'Writing comments and its type'),
  (2, 2, 'Java token: keywords, identifier, literal, operators and separators'),
  (2, 3, 'Data types: primitive and user-defined data type'),
  (2, 4, 'Variable declaration and assignment, expression'),
  (2, 5, 'Control statements: selection statements, looping statement and jump statements'),
  (2, 6, 'Arrays: single dimension array, multi-dimensional array ( Rectangular and Jagged)'),
  (2, 7, 'Type conversion and casting'),
  (2, 8, 'Garbage Collection'),
  (2, 9, 'String: creation, concatenation, comparison, modification, changing case and searching'),
  (2, 10, 'String Buffer Class'),
  (3, 1, 'Defining class, adding method to class, creating object and calling function/method'),
  (3, 2, 'Abstraction and Encapsulation'),
  (3, 3, 'Constrictors and its type (Default, Parameterized and copy)'),
  (3, 4, '‘this’ keyword'),
  (3, 5, 'Static fields and methods'),
  (3, 6, 'More onmethod: passing by value, by reference'),
  (3, 7, 'Recursion'),
  (3, 8, 'Nested and inner class'),
  (3, 9, 'Variable length arguments'),
  (3, 10, 'Package: Defining and importing package'),
  (4, 1, 'Inheritance basics a : piss ¥ £ WX'),
  (4, 2, 'Inheritance Type( Single-level, Multi-level, Multiple and Hierarchical)'),
  (4, 3, '‘super’ keyword'),
  (4, 4, 'Polymorphism: Method overloading and method overriding'),
  (4, 5, 'Object class'),
  (4, 6, '‘final’ keyword'),
  (4, 7, 'Abstract class and methods'),
  (4, 8, 'Access control (private, protected, default and public)'),
  (4, 9, 'Interface: Defining, implementing and applying interface'),
  (5, 1, 'Basic exceptions, proper use of exceptions'),
  (5, 2, 'Exception hierarchy'),
  (5, 3, 'Exception handling keywords: try, catch, throw, throws and finally'),
  (5, 4, 'Java''s built-in exceptions'),
  (5, 5, 'User-defined exceptions'),
  (5, 6, 'Multithreading basics'),
  (5, 7, 'Thread class and Runnable interface'),
  (5, 8, 'Thread priorities'),
  (5, 9, 'Thread synchronization and inter-thread communication'),
  (6, 1, 'Console and File 1/0'),
  (6, 2, 'Reading and writing file using byte stream'),
  (6, 3, 'Reading and writing file using character stream'),
  (6, 4, 'Serialization and deserialization'),
  (6, 5, 'RandomAccessFile class'),
  (7, 1, 'Wrapper class and associate methods %'),
  (7, 2, 'Java collection framework po ( é'),
  (7, 3, 'List, Set, Map interface as'),
  (7, 4, 'ArrayList, LinkedList, HashSet, HashMap and TreeSet Class yee'),
  (7, 5, 'Accessing collections: Iterator/comparator a'),
  (7, 6, 'Defining generic class and methods'),
  (7, 7, 'Using wildcard arguments'),
  (7, 8, 'Generic interface and generic hierarchy'),
  (7, 9, 'Some generic restrictions'),
  (8, 1, 'Design pattern: singleton, factory, observer pattern'),
  (8, 2, 'Lambda expression'),
  (8, 3, 'Stream API: Introduction'),
  (8, 4, 'Optional class'),
  (8, 5, 'Method references')
) as v(unit_order, sort_order, title) on ch.sort_order = v.unit_order
where not exists (
  select 1 from public.chapter_subtopics cs where cs.chapter_id = ch.id and cs.title = v.title
);

-- BCA 154 subtopics
with subj as (
  select id from public.subjects where code = 'BCA 154' limit 1
), ch as (
  select id, sort_order from public.chapters where subject_id = (select id from subj)
)
insert into public.chapter_subtopics (chapter_id, title, summary, sort_order)
select ch.id, v.title, '', v.sort_order
from ch
join (values
  (1, 1, 'Definition of limit including epsilon-delta condition, right and left hand limit, and its'),
  (1, 2, 'Algebraic properties of limit'),
  (1, 3, 'Definition and conditions of continuity and discontinuity'),
  (1, 4, 'Continuity of algebraic, Trigonometric, and exponential Functions, examples, and'),
  (2, 1, 'Definition and geometrical meaning of derivatives,'),
  (2, 2, 'Rules of derivatives (sum, product, power, chain, and quotient rule),'),
  (2, 3, 'Derivatives of inverse circular, hyperbolic functions and implicit functions,'),
  (2, 4, 'Higher order derivatives,'),
  (2, 5, 'Relation between derivative and continuity'),
  (2, 6, 'Definition and examples of partial derivatives'),
  (3, 1, 'Increasing and decreasing functions,'),
  (3, 2, 'Equation of tangents and normals using first derivatives,'),
  (3, 3, 'L'' Hospital''s rule,'),
  (3, 4, 'Angle between two lines,'),
  (3, 5, 'Maxima and minima, absolute maxima and minima, concavity, stationary points and'),
  (3, 6, 'Statement and geometrical interpretation of Rolle''s theorem, Cauchy Mean-value'),
  (3, 7, 'Taylor''s theorem, Maclaurin theorem (without proof) and its use in expansion of some'),
  (3, 8, 'Applications of derivatives in Economics,'),
  (3, 9, 'Rate measures'),
  (3, 10, 'Differential equations of first order and first degree,'),
  (4, 1, 'Definition and geometrical meaning of integration,'),
  (4, 2, 'Basic integration formulas for algebraic, trigonometric, exponential, and logarithmic'),
  (4, 3, 'Improper integral,'),
  (4, 4, 'Definite integral in terms of Riemann sum, and fundamental theorem of integral calculus'),
  (4, 5, 'Applications of definite integral (Area under curve, area between curves, Quadrature &'),
  (5, 1, 'Definition, order, and degree of differential equations,'),
  (5, 2, 'Reducible to linear form,'),
  (5, 3, 'Partial differential equations with some basic examples'),
  (6, 1, 'Linear programming problems,'),
  (6, 2, 'Linear inequalities in two variables and their graphical solutions,'),
  (6, 3, 'Simplex Method (up to 3 variables), Duality problems'),
  (6, 4, 'Matrix inversion method,'),
  (6, 5, 'Gauss Elimination, Gauss-Seidel method,'),
  (6, 6, 'Bisection method and Newton-Raphson Method for non-linear equations')
) as v(unit_order, sort_order, title) on ch.sort_order = v.unit_order
where not exists (
  select 1 from public.chapter_subtopics cs where cs.chapter_id = ch.id and cs.title = v.title
);

-- BCA 155 subtopics
with subj as (
  select id from public.subjects where code = 'BCA 155' limit 1
), ch as (
  select id, sort_order from public.chapters where subject_id = (select id from subj)
)
insert into public.chapter_subtopics (chapter_id, title, summary, sort_order)
select ch.id, v.title, '', v.sort_order
from ch
join (values
  (1, 1, 'Tasks of UX designer and UI designer'),
  (1, 2, 'Core discipline of UX: User research, content strategy, Information Architecture,'),
  (1, 3, 'User interfaces: CLI, GUI, VUI, Menu-driven, NLP based'),
  (1, 4, 'Properties of good UX/UI design'),
  (1, 5, 'UX/UI tools: Figma, Adobe XD, Sketch'),
  (2, 1, 'UX design process and user center design, Mindmap'),
  (2, 2, 'Ideation techniques: using Mood boards, Brainstorming and sketching'),
  (2, 3, 'Graphical and web user interfaces'),
  (2, 4, 'Interaction styles: Command line, Menu selection, Form fill in, Direct manipulation,'),
  (2, 5, 'Principles of UI design'),
  (2, 6, 'Graphical user interface'),
  (2, 7, 'UI design process'),
  (2, 8, 'Human considerations in interface and screen design'),
  (2, 9, 'Technological considerations in interface design'),
  (3, 1, 'System menus and functions of menus'),
  (3, 2, 'Formatting of menus: Consistency, display, presentation, organization, complexity, item'),
  (3, 3, 'Types of menus: Menu bar, pull down menu, cascading menu, popup menu, tear off menu,'),
  (3, 4, 'Selection of Windows and its components, window presentation styles: Tiled windows,'),
  (3, 5, 'Types of windows: Primary, secondary windows, dialog boxes'),
  (3, 6, 'Screen based controls: Operable controfs (Buttons, toolbars), Text entry/Read-only'),
  (3, 7, 'Other operable controls: slider, tabs, date picker, tree view, scroll bars'),
  (3, 8, 'Selecting the proper controls'),
  (3, 9, 'Creating meaningful graphics, icons and images'),
  (5, 1, 'Page layout, Color scheme and font selection, typography, screen size and responsive'),
  (5, 2, 'Visual hierarchy principles: Alignment, Color, Contrast, Proximity, Size, Texture, Time'),
  (5, 3, 'Navigation: Global navigation, utility navigation, Associative and Inline Navigation'),
  (5, 4, 'Navigational models: Hub and spoke, fully connected, multilevel or tree, stepwise'),
  (6, 1, 'Wireframes and mock-ups'),
  (6, 2, 'Prototyping: Low fidelity and high fidelity prototyping, interactive prototyping'),
  (6, 3, 'UX storyboarding, mockups'),
  (6, 4, 'Software prototyping'),
  (6, 5, 'Transition and animation to prototypes'),
  (6, 6, 'Creating a simple clickable prototype'),
  (7, 1, 'Formative and summative evaluation oe'),
  (7, 2, 'Usability testing: Moderated vs Unmoderated'),
  (7, 3, 'Analyzing test results and gathering insights'),
  (7, 4, 'Evaluation through expert analysis and user participation, iterative evaluation and'),
  (7, 5, 'DECIDE evaluation framework, heuristic evaluation'),
  (7, 6, 'Task analysis and performance metrics'),
  (8, 1, 'Command and contro! vs Conversational Ul'),
  (8, 2, 'Personas, Avatars, Actors and Video games'),
  (8, 3, 'Speech recognition technology and Dialog management'),
  (8, 4, 'Designing for Wearable Devices')
) as v(unit_order, sort_order, title) on ch.sort_order = v.unit_order
where not exists (
  select 1 from public.chapter_subtopics cs where cs.chapter_id = ch.id and cs.title = v.title
);

-- BCA 156 subtopics
with subj as (
  select id from public.subjects where code = 'BCA 156' limit 1
), ch as (
  select id, sort_order from public.chapters where subject_id = (select id from subj)
)
insert into public.chapter_subtopics (chapter_id, title, summary, sort_order)
select ch.id, v.title, '', v.sort_order
from ch
join (values
  (1, 1, 'Concept and meaning of management'),
  (1, 2, 'Forms of business'),
  (1, 3, 'Types of managers'),
  (1, 4, 'Basic managerial roles'),
  (1, 5, 'Managerial skills'),
  (1, 6, 'Integrated management framework'),
  (1, 7, 'Managing ethics and diversity'),
  (1, 8, 'Social responsibilities and organizations'),
  (1, 9, 'Role of IT in management'),
  (2, 1, 'Concept of planning'),
  (2, 2, 'Planning process'),
  (2, 3, 'Types of plan'),
  (2, 4, 'Organizational goals'),
  (2, 5, 'Organizational planning'),
  (2, 6, 'SWOT analysis oat an'),
  (2, 7, 'Nature and process of decision-making BY &'),
  (2, 8, 'Use of IT in planning and decision-making . a'),
  (3, 1, 'Elements of organizing'),
  (3, 2, 'Job design, job description and job specification'),
  (3, 3, 'Authority distribution'),
  (3, 4, 'Forms of organizational design'),
  (4, 1, 'Nature of leadership'),
  (4, 2, 'Generic approaches to leadership'),
  (4, 3, 'Situational approaches to leadership'),
  (4, 4, 'Managing team in the time of crisis'),
  (4, 5, 'Leadership challenges in IT based organization')
) as v(unit_order, sort_order, title) on ch.sort_order = v.unit_order
where not exists (
  select 1 from public.chapter_subtopics cs where cs.chapter_id = ch.id and cs.title = v.title
);

-- BCA 104 subtopics
with subj as (
  select id from public.subjects where code = 'BCA 104' limit 1
), ch as (
  select id, sort_order from public.chapters where subject_id = (select id from subj)
)
insert into public.chapter_subtopics (chapter_id, title, summary, sort_order)
select ch.id, v.title, '', v.sort_order
from ch
join (values
  (1, 1, 'Real number system,'),
  (1, 2, 'Field and ordered axioms of real numbers,'),
  (1, 3, 'Intervals, rational and irrational numbers, ’ ='),
  (1, 4, 'Absolute value, and its properties, complex numbers and their properties,'),
  (1, 5, 'Ordered pairs, Cartesian product, relation, equivalence relation,'),
  (1, 6, 'Graphs of different types of functions,'),
  (2, 1, 'Sequence and Series (Arithmetic, Geometric and Harmonic) and their properties,'),
  (2, 2, 'Means (AM, GM, and HM), and theorems to show the relation among them,'),
  (2, 3, 'nth term and sum of arithmetic series, & finite and infinite geometric series,'),
  (2, 4, 'Arithmatico-geometric series'),
  (3, 1, 'Definitions and types of matrices, algebra of matrices,'),
  (3, 2, 'Determinants, transpose, minors, and cofactors of matrices,'),
  (3, 3, 'Properties of determinants (without proof), singular, non-singular, adjoint, and inverse of'),
  (3, 4, 'Rank of a matrix,'),
  (3, 5, 'Linear and orthogonal transformation, composite transformation, and its applications to'),
  (3, 6, 'Characteristic equations, Eigenvalues and Eigenvectors'),
  (4, 1, 'Standard equations of circle, parabola, ellipse, hyperbola and their graphs'),
  (4, 2, 'Polar equations of the circle, ellipse, parabola and hyperbola'),
  (5, 1, 'Definition of vector and scalar, magnitude and distance and unit vector,'),
  (5, 2, 'Operations on vectors (addition, subtraction, scalar multiplication)'),
  (5, 3, 'Scalar product and vector product of two and three vectors with their geometrical'),
  (5, 4, 'Vector space, subspace,'),
  (5, 5, 'Linear combination, linear dependence and independence,'),
  (5, 6, 'Scalar product, norm and orthogonality'),
  (6, 1, 'Basic counting principle'),
  (6, 2, 'Deduction method for the formulas for permutations and combinations'),
  (6, 3, 'Relation between permutations and combinations')
) as v(unit_order, sort_order, title) on ch.sort_order = v.unit_order
where not exists (
  select 1 from public.chapter_subtopics cs where cs.chapter_id = ch.id and cs.title = v.title
);

-- BCA 105 subtopics
with subj as (
  select id from public.subjects where code = 'BCA 105' limit 1
), ch as (
  select id, sort_order from public.chapters where subject_id = (select id from subj)
)
insert into public.chapter_subtopics (chapter_id, title, summary, sort_order)
select ch.id, v.title, '', v.sort_order
from ch
join (values
  (1, 1, 'A Brief History of Professional Communication'),
  (1, 2, 'Principles of Professional Communication'),
  (1, 3, 'The Communication Process'),
  (1, 4, 'Nonverbal Communication in the Workplace'),
  (1, 5, 'Barriers to Effective Communication'),
  (1, 6, 'Vocabulary and Grammar'),
  (1, 7, 'Commonly Confusing Words'),
  (1, 8, 'Use of Tenses'),
  (1, 9, 'Readings:'),
  (1, 10, '“The Letter” by Dhumketu'),
  (2, 1, 'Telephone Conversation'),
  (2, 2, 'Public Speaking and Presentation Skills'),
  (2, 3, 'Meeting, agendas and minutes'),
  (2, 4, 'Elevator Pitches'),
  (2, 5, 'Interviewing and Professional Dialogue'),
  (2, 6, 'Vocabulary and Grammar'),
  (2, 7, 'Professional Idioms'),
  (2, 8, 'Reported Speech'),
  (2, 9, 'Readings:'),
  (2, 10, '“Death by PowerPoint” by Angela R. Garber'),
  (2, 11, '“Our world on fire needs you” by Maria Ressa'),
  (3, 1, 'Rules of Professional Writing'),
  (3, 2, 'Text Messages, Emails, and Memos'),
  (3, 3, 'Notice Writing %'),
  (3, 4, 'Informal and Formal Letters / + ='),
  (3, 5, 'Résumés and Cover Letters at'),
  (3, 6, 'Vocabulary and Grammar'),
  (3, 7, 'Business Vocabulary and Its Uses'),
  (3, 8, 'Active and Passive Voice'),
  (3, 9, 'Readings:'),
  (3, 10, '“Gateman’s Gift” by R. K. Narayan'),
  (3, 11, '“My School” by Rabindranath Tagore'),
  (4, 1, 'Interpersonal Communication in the Workplace'),
  (4, 2, 'Listening Environment in the Workplace'),
  (4, 3, 'Intercultural Communication'),
  (4, 4, 'Effective Communication in Teams'),
  (4, 5, 'Leadership and Communication'),
  (4, 6, 'Vocabulary and Grammar'),
  (4, 7, 'Polite Words in Communication'),
  (4, 8, 'Making Requests and Offers'),
  (4, 9, 'Conditional Sentences'),
  (4, 10, 'Readings:'),
  (4, 11, '“Computer and the Pursuit of Happiness” by David Gelempter'),
  (4, 12, '“The Collapse of the Family and the Community” by Yuval Noah Harari'),
  (5, 1, 'Virtual Etiquette/Netiquette'),
  (5, 2, 'Online Professionalism'),
  (5, 3, 'Communicating via Social Media and Collaborative Tools'),
  (5, 4, 'Plagiarism and Online Plagiarism'),
  (5, 5, 'Visuals in Communication (Maps, Tables, Charts, Infographics, Icon, Photograph,'),
  (5, 6, 'Vocabulary and Grammar'),
  (5, 7, 'Social Media Vocabulary and Its Uses'),
  (5, 8, 'Preposition of Time, Place and Direction'),
  (5, 9, 'Readings a é'),
  (5, 10, '“Cat Pictures Please” by Naomi Kritzer'),
  (5, 11, '“ChatGPT May Be Eroding Critical Thinking Skills” by Andrew R. Chow'),
  (6, 1, 'Professional Codes of Ethics'),
  (6, 2, 'Responsibilities of IT Professionals'),
  (6, 3, 'Ethical Decision-Making in IT'),
  (6, 4, 'Whistle-Blowing and Professional Integrity'),
  (6, 5, 'Workplace Ethical Challenges in IT'),
  (6, 6, 'Vocabulary and Grammar'),
  (6, 7, 'Ethical Vocabulary'),
  (6, 8, 'Concord (Subject Verb Agreement)'),
  (6, 9, 'Readings'),
  (6, 10, '“The Necklace” by Guy de Maupassant'),
  (6, 11, '“The Digital Citizen” by Lugi Ceccarini')
) as v(unit_order, sort_order, title) on ch.sort_order = v.unit_order
where not exists (
  select 1 from public.chapter_subtopics cs where cs.chapter_id = ch.id and cs.title = v.title
);
