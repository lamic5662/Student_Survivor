-- Remove unused file_path column (file system export removed)
alter table public.user_notes
drop column if exists file_path;
