-- Update subtopics for BCA 102 (C Programming) with detailed syllabus points

with subj as (
  select id
  from public.subjects
  where code = 'BCA 102'
  limit 1
),
ch as (
  select id, title
  from public.chapters
  where subject_id = (select id from subj)
)
delete from public.chapter_subtopics
where chapter_id in (select id from ch);

with subj as (
  select id
  from public.subjects
  where code = 'BCA 102'
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
    ('Unit 1: Introduction to C Programming', 1, 'Evolution of programming languages', ''),
    ('Unit 1: Introduction to C Programming', 2, 'History, characteristics and applications of C', ''),
    ('Unit 1: Introduction to C Programming', 3, 'Structure of a C program', ''),
    ('Unit 1: Introduction to C Programming', 4, 'Compilation and execution process', ''),
    ('Unit 1: Introduction to C Programming', 5, 'C tokens: keywords, identifiers, constants, string literals, operators', ''),
    ('Unit 1: Introduction to C Programming', 6, 'Variables: declaration, initialization, scope, lifetime', ''),
    ('Unit 1: Introduction to C Programming', 7, 'Data types: basic, derived, user-defined', ''),
    ('Unit 1: Introduction to C Programming', 8, 'Type casting: implicit and explicit conversion', ''),
    ('Unit 1: Introduction to C Programming', 9, 'Operators & expressions: arithmetic, relational, logical, bitwise, assignment, inc/dec, ternary, sizeof, comma, address-of, dereference; precedence', ''),

    -- Unit 2
    ('Unit 2: Input/Output and Control Structures', 1, 'Formatted I/O: printf() and scanf()', ''),
    ('Unit 2: Input/Output and Control Structures', 2, 'Unformatted I/O: getchar(), putchar(), getch(), getche(), putch()', ''),
    ('Unit 2: Input/Output and Control Structures', 3, 'Decision statements: if, if-else, nested if-else, else-if ladder', ''),
    ('Unit 2: Input/Output and Control Structures', 4, 'switch statement and conditional operator', ''),
    ('Unit 2: Input/Output and Control Structures', 5, 'Loops: while, do-while, for, nested loops', ''),
    ('Unit 2: Input/Output and Control Structures', 6, 'Jump statements: break, continue, goto', ''),

    -- Unit 3
    ('Unit 3: Functions, Arrays and Strings', 1, 'Functions: definition, declaration/prototype, advantages, function call', ''),
    ('Unit 3: Functions, Arrays and Strings', 2, 'Types of functions: library vs user-defined', ''),
    ('Unit 3: Functions, Arrays and Strings', 3, 'Function arguments: call by value, call by reference', ''),
    ('Unit 3: Functions, Arrays and Strings', 4, 'Recursion: concepts and examples', ''),
    ('Unit 3: Functions, Arrays and Strings', 5, 'Arrays: declaration, initialization, accessing elements', ''),
    ('Unit 3: Functions, Arrays and Strings', 6, 'One-dimensional arrays: processing and examples', ''),
    ('Unit 3: Functions, Arrays and Strings', 7, 'Two-dimensional arrays: matrix operations', ''),
    ('Unit 3: Functions, Arrays and Strings', 8, 'Multi-dimensional arrays', ''),
    ('Unit 3: Functions, Arrays and Strings', 9, 'Arrays and functions', ''),
    ('Unit 3: Functions, Arrays and Strings', 10, 'Strings: declaration, initialization', ''),
    ('Unit 3: Functions, Arrays and Strings', 11, 'String I/O: gets(), puts()', ''),
    ('Unit 3: Functions, Arrays and Strings', 12, 'String handling: strlen, strrev, strcpy, strupr, strlwr, strcmp, strcat', ''),
    ('Unit 3: Functions, Arrays and Strings', 13, 'Array of strings', ''),

    -- Unit 4
    ('Unit 4: Structures, Unions, and Enumerations', 1, 'Structures: defining and declaring', ''),
    ('Unit 4: Structures, Unions, and Enumerations', 2, 'Passing structures to functions', ''),
    ('Unit 4: Structures, Unions, and Enumerations', 3, 'Unions and comparison with structures', ''),
    ('Unit 4: Structures, Unions, and Enumerations', 4, 'Enumerations (enum) and typedef', ''),

    -- Unit 5
    ('Unit 5: Pointers and Memory Management', 1, 'Pointer declaration, initialization, dereferencing', ''),
    ('Unit 5: Pointers and Memory Management', 2, 'Pointer arithmetic', ''),
    ('Unit 5: Pointers and Memory Management', 3, 'Pointers with arrays, strings, functions, structures', ''),
    ('Unit 5: Pointers and Memory Management', 4, 'Dynamic memory allocation: malloc, calloc, realloc, free', ''),
    ('Unit 5: Pointers and Memory Management', 5, 'DMA with structures', ''),
    ('Unit 5: Pointers and Memory Management', 6, 'Dangling pointers and memory leaks', ''),

    -- Unit 6
    ('Unit 6: File Handling, Command-Line, and Graphics', 1, 'File concepts: text vs binary, open/close/read/write', ''),
    ('Unit 6: File Handling, Command-Line, and Graphics', 2, 'File modes and standard I/O: fgetc, fputc, fgets, fputs, fprintf, fscanf, fread, fwrite', ''),
    ('Unit 6: File Handling, Command-Line, and Graphics', 3, 'Random access: fseek, ftell, rewind; error handling', ''),
    ('Unit 6: File Handling, Command-Line, and Graphics', 4, 'Command-line arguments: argc/argv', ''),
    ('Unit 6: File Handling, Command-Line, and Graphics', 5, 'Graphics basics: modes, primitives, colors, text, simple animation', ''),

    -- Laboratory Works
    ('Laboratory Works', 1, 'Fundamental programming constructs', ''),
    ('Laboratory Works', 2, 'Control flow mechanisms', ''),
    ('Laboratory Works', 3, 'Functions and modularity', ''),
    ('Laboratory Works', 4, 'Array and string manipulation', ''),
    ('Laboratory Works', 5, 'Pointers and dynamic memory', ''),
    ('Laboratory Works', 6, 'Structured data types', ''),
    ('Laboratory Works', 7, 'File operations', ''),
    ('Laboratory Works', 8, 'Command-line interaction', ''),
    ('Laboratory Works', 9, 'Basic graphics programming', '')
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
