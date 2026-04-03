-- Chapter subtopics

create table if not exists public.chapter_subtopics (
  id uuid primary key default gen_random_uuid(),
  chapter_id uuid not null references public.chapters(id) on delete cascade,
  title text not null,
  summary text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.chapter_subtopics enable row level security;

create policy "chapter_subtopics_public_read" on public.chapter_subtopics
for select
using (true);

create policy "chapter_subtopics_admin_insert" on public.chapter_subtopics
for insert
with check (public.is_admin());

create policy "chapter_subtopics_admin_update" on public.chapter_subtopics
for update
using (public.is_admin());

create policy "chapter_subtopics_admin_delete" on public.chapter_subtopics
for delete
using (public.is_admin());
