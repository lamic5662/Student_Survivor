-- Past question papers: table + storage bucket policies
create table if not exists public.past_papers (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.subjects(id) on delete cascade,
  title text not null,
  year int,
  file_url text not null,
  created_at timestamptz not null default now()
);

insert into storage.buckets (id, name, public)
values ('past_papers', 'past_papers', true)
on conflict (id) do update set public = true;

drop policy if exists "past_papers_public_read" on storage.objects;
create policy "past_papers_public_read" on storage.objects
for select
using (bucket_id = 'past_papers');

drop policy if exists "past_papers_admin_insert" on storage.objects;
create policy "past_papers_admin_insert" on storage.objects
for insert
with check (bucket_id = 'past_papers' and public.is_admin());

drop policy if exists "past_papers_admin_update" on storage.objects;
create policy "past_papers_admin_update" on storage.objects
for update
using (bucket_id = 'past_papers' and public.is_admin());

drop policy if exists "past_papers_admin_delete" on storage.objects;
create policy "past_papers_admin_delete" on storage.objects
for delete
using (bucket_id = 'past_papers' and public.is_admin());

-- Allow admins to manage past paper rows
alter table public.past_papers enable row level security;

drop policy if exists "past_papers_public_read" on public.past_papers;
create policy "past_papers_public_read" on public.past_papers
for select
using (true);

drop policy if exists "past_papers_admin_insert" on public.past_papers;
create policy "past_papers_admin_insert" on public.past_papers
for insert
with check (public.is_admin());

drop policy if exists "past_papers_admin_update" on public.past_papers;
create policy "past_papers_admin_update" on public.past_papers
for update
using (public.is_admin());

drop policy if exists "past_papers_admin_delete" on public.past_papers;
create policy "past_papers_admin_delete" on public.past_papers
for delete
using (public.is_admin());
