-- Note submission attachments
alter table public.note_submissions
add column if not exists file_url text;

insert into storage.buckets (id, name, public)
values ('note_submissions', 'note_submissions', true)
on conflict (id) do update set public = true;

drop policy if exists "note_submissions_files_select" on storage.objects;
create policy "note_submissions_files_select" on storage.objects
for select
using (bucket_id = 'note_submissions');

drop policy if exists "note_submissions_files_insert" on storage.objects;
create policy "note_submissions_files_insert" on storage.objects
for insert
with check (bucket_id = 'note_submissions' and auth.role() = 'authenticated');

drop policy if exists "note_submissions_files_update" on storage.objects;
create policy "note_submissions_files_update" on storage.objects
for update
using (
  bucket_id = 'note_submissions'
  and (owner = auth.uid() or public.is_admin())
);

drop policy if exists "note_submissions_files_delete" on storage.objects;
create policy "note_submissions_files_delete" on storage.objects
for delete
using (
  bucket_id = 'note_submissions'
  and (owner = auth.uid() or public.is_admin())
);
