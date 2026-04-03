-- Set syllabus URLs by semester (pointing to relevant page in the combined PDF)

-- Semester 1 (BCA-1) -> page 10
with sem as (
  select id from public.semesters where code = 'BCA-1'
)
update public.subjects
set syllabus_url = 'https://snlznlwcwbqjilwrsgay.supabase.co/storage/v1/object/public/syllabus/bca_program_2025.pdf#page=10'
where semester_id = (select id from sem)
  and code like 'BCA %';

-- Semester 2 (BCA-2) -> page 41
with sem as (
  select id from public.semesters where code = 'BCA-2'
)
update public.subjects
set syllabus_url = 'https://snlznlwcwbqjilwrsgay.supabase.co/storage/v1/object/public/syllabus/bca_program_2025.pdf#page=41'
where semester_id = (select id from sem)
  and code like 'BCA %';
