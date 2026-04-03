-- Link syllabus PDF for all BCA subjects

update public.subjects
set syllabus_url = 'https://snlznlwcwbqjilwrsgay.supabase.co/storage/v1/object/public/syllabus/bca_program_2025.pdf'
where code like 'BCA %';
