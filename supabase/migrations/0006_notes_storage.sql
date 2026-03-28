-- Notes attachments: file_url column + storage bucket policies
alter table public.notes
add column if not exists file_url text;

insert into storage.buckets (id, name, public)
values ('notes', 'notes', true)
on conflict (id) do update set public = true;

drop policy if exists "notes_public_read" on storage.objects;
create policy "notes_public_read" on storage.objects
for select
using (bucket_id = 'notes');

drop policy if exists "notes_admin_insert" on storage.objects;
create policy "notes_admin_insert" on storage.objects
for insert
with check (bucket_id = 'notes' and public.is_admin());

drop policy if exists "notes_admin_update" on storage.objects;
create policy "notes_admin_update" on storage.objects
for update
using (bucket_id = 'notes' and public.is_admin());

drop policy if exists "notes_admin_delete" on storage.objects;
create policy "notes_admin_delete" on storage.objects
for delete
using (bucket_id = 'notes' and public.is_admin());
