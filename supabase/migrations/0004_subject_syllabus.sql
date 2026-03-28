-- Add syllabus URLs per subject
alter table public.subjects
add column if not exists syllabus_url text;
