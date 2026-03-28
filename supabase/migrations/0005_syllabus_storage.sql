-- Storage bucket + policies for syllabus PDFs
insert into storage.buckets (id, name, public)
values ('syllabus', 'syllabus', true)
on conflict (id) do update set public = true;

drop policy if exists "syllabus_public_read" on storage.objects;
create policy "syllabus_public_read" on storage.objects
for select
using (bucket_id = 'syllabus');

drop policy if exists "syllabus_admin_insert" on storage.objects;
create policy "syllabus_admin_insert" on storage.objects
for insert
with check (bucket_id = 'syllabus' and public.is_admin());

drop policy if exists "syllabus_admin_update" on storage.objects;
create policy "syllabus_admin_update" on storage.objects
for update
using (bucket_id = 'syllabus' and public.is_admin());

drop policy if exists "syllabus_admin_delete" on storage.objects;
create policy "syllabus_admin_delete" on storage.objects
for delete
using (bucket_id = 'syllabus' and public.is_admin());
