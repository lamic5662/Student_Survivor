-- Student note submissions for admin approval
create table if not exists public.note_submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  chapter_id uuid not null references public.chapters(id) on delete cascade,
  title text not null,
  short_answer text,
  detailed_answer text,
  tags text[] default '{}'::text[],
  status text not null default 'pending',
  admin_feedback text,
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint note_submissions_status_check
    check (status in ('pending', 'approved', 'rejected'))
);

create index if not exists note_submissions_status_idx
  on public.note_submissions (status);
create index if not exists note_submissions_chapter_idx
  on public.note_submissions (chapter_id);
create index if not exists note_submissions_user_idx
  on public.note_submissions (user_id);

do $$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgname = 'set_note_submissions_updated_at'
      and tgrelid = 'public.note_submissions'::regclass
  ) then
    create trigger set_note_submissions_updated_at
    before update on public.note_submissions
    for each row
    execute function public.set_updated_at();
  end if;
end $$;

alter table public.note_submissions enable row level security;

drop policy if exists "note_submissions_select" on public.note_submissions;
create policy "note_submissions_select" on public.note_submissions
for select
using (auth.uid() = user_id or public.is_admin());

drop policy if exists "note_submissions_insert" on public.note_submissions;
create policy "note_submissions_insert" on public.note_submissions
for insert
with check (auth.uid() = user_id);

drop policy if exists "note_submissions_update" on public.note_submissions;
create policy "note_submissions_update" on public.note_submissions
for update
using (public.is_admin());

drop policy if exists "note_submissions_delete" on public.note_submissions;
create policy "note_submissions_delete" on public.note_submissions
for delete
using (public.is_admin());
