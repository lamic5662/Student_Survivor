-- Add file path to user notes for saved AI note files
alter table public.user_notes
add column if not exists file_path text;
