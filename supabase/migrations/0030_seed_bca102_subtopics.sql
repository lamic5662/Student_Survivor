-- Seed subtopics for BCA 102 (C Programming)

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
),
ch as (
  select id, title
  from public.chapters
  where subject_id = (select id from subj)
),
data as (
  select * from (values
    -- Unit 1
    ('Unit 1: Introduction to C Programming', 1, 'Evolution of Programming Languages', 'Overview of programming language evolution.'),
    ('Unit 1: Introduction to C Programming', 2, 'History & Applications of C', 'History, characteristics, and applications of C.'),
    ('Unit 1: Introduction to C Programming', 3, 'Structure of a C Program', 'Basic structure of a C program.'),
    ('Unit 1: Introduction to C Programming', 4, 'Compilation & Execution', 'Compilation and execution process.'),
    ('Unit 1: Introduction to C Programming', 5, 'C Tokens', 'Keywords, identifiers, constants, string literals, operators.'),
    ('Unit 1: Introduction to C Programming', 6, 'Variables', 'Declaration, initialization, scope, lifetime.'),
    ('Unit 1: Introduction to C Programming', 7, 'Data Types', 'Basic, derived, and user-defined data types.'),
    ('Unit 1: Introduction to C Programming', 8, 'Type Casting', 'Implicit and explicit conversions.'),
    ('Unit 1: Introduction to C Programming', 9, 'Operators & Expressions', 'Arithmetic, relational, logical, bitwise, assignment, inc/dec, ternary, special ops; precedence.'),

    -- Unit 2
    ('Unit 2: Input/Output and Control Structures', 1, 'Formatted I/O', 'printf and scanf.'),
    ('Unit 2: Input/Output and Control Structures', 2, 'Unformatted I/O', 'getchar, putchar, getch, getche, putch.'),
    ('Unit 2: Input/Output and Control Structures', 3, 'Decision Statements', 'if, if-else, nested, else-if ladder, switch, conditional operator.'),
    ('Unit 2: Input/Output and Control Structures', 4, 'Looping Statements', 'while, do-while, for, nested loops.'),
    ('Unit 2: Input/Output and Control Structures', 5, 'Jump Statements', 'break, continue, goto.'),

    -- Unit 3
    ('Unit 3: Functions, Arrays and Strings', 1, 'Function Basics', 'Definition, declaration/prototype, advantages.'),
    ('Unit 3: Functions, Arrays and Strings', 2, 'Function Call & Types', 'Function call, library vs user-defined.'),
    ('Unit 3: Functions, Arrays and Strings', 3, 'Arguments & Recursion', 'Call by value/reference; recursion.'),
    ('Unit 3: Functions, Arrays and Strings', 4, 'Arrays', 'Declaration, initialization, 1D, 2D, multi-dimensional, arrays with functions.'),
    ('Unit 3: Functions, Arrays and Strings', 5, 'Strings', 'String I/O, handling functions, array of strings.'),

    -- Unit 4
    ('Unit 4: Structures, Unions, and Enumerations', 1, 'Structures', 'Defining/declaring structures, passing to functions.'),
    ('Unit 4: Structures, Unions, and Enumerations', 2, 'Unions', 'Defining unions and comparison with structures.'),
    ('Unit 4: Structures, Unions, and Enumerations', 3, 'Enums & typedef', 'Enumerations and typedef implementation.'),

    -- Unit 5
    ('Unit 5: Pointers and Memory Management', 1, 'Pointer Basics', 'Declaration, initialization, dereferencing.'),
    ('Unit 5: Pointers and Memory Management', 2, 'Pointer Arithmetic', 'Arithmetic and addressing.'),
    ('Unit 5: Pointers and Memory Management', 3, 'Pointers with Data Types', 'Arrays, strings, functions, structures.'),
    ('Unit 5: Pointers and Memory Management', 4, 'Dynamic Memory Allocation', 'malloc, calloc, realloc, free.'),
    ('Unit 5: Pointers and Memory Management', 5, 'DMA with Structures', 'Dynamic memory with structures.'),
    ('Unit 5: Pointers and Memory Management', 6, 'Memory Safety', 'Dangling pointers and memory leaks.'),

    -- Unit 6
    ('Unit 6: File Handling, Command-Line, and Graphics', 1, 'File Concepts & Operations', 'Text vs binary, open/close/read/write.'),
    ('Unit 6: File Handling, Command-Line, and Graphics', 2, 'File Modes & I/O', 'fgetc, fputc, fgets, fputs, fprintf, fscanf, fread, fwrite.'),
    ('Unit 6: File Handling, Command-Line, and Graphics', 3, 'Random Access & Errors', 'fseek, ftell, rewind, error handling.'),
    ('Unit 6: File Handling, Command-Line, and Graphics', 4, 'Command-Line Arguments', 'argc/argv and usage.'),
    ('Unit 6: File Handling, Command-Line, and Graphics', 5, 'Graphics Basics', 'Modes, primitives, colors, text, simple animation.'),

    -- Laboratory Works
    ('Laboratory Works', 1, 'C IDE & Tooling', 'IDE setup, compile/run process, debugging.'),
    ('Laboratory Works', 2, 'Fundamentals Practice', 'Basic I/O, arithmetic, operators, type conversion.'),
    ('Laboratory Works', 3, 'Control Flow', 'if/switch and loop practice; break/continue/goto.'),
    ('Laboratory Works', 4, 'Functions & Modularity', 'User-defined functions, recursion, call by value/reference.'),
    ('Laboratory Works', 5, 'Arrays & Strings', 'Searching, sorting, matrices, string operations.'),
    ('Laboratory Works', 6, 'Pointers & DMA', 'Pointers with arrays/strings, malloc/calloc/realloc/free.'),
    ('Laboratory Works', 7, 'Structured Types', 'Structures, unions, enums.'),
    ('Laboratory Works', 8, 'File Operations', 'Text/binary files, formatted I/O, random access.'),
    ('Laboratory Works', 9, 'Command-Line & Graphics', 'Args handling and basic graphics demos.')
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
