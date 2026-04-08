create table if not exists public.colleges (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists colleges_active_idx
  on public.colleges (is_active);

do $$
begin
  if exists (
    select 1
    from pg_proc
    where proname = 'set_updated_at'
  ) then
    if not exists (
      select 1
      from pg_trigger
      where tgname = 'set_colleges_updated_at'
    ) then
      execute 'create trigger set_colleges_updated_at
        before update on public.colleges
        for each row
        execute function public.set_updated_at()';
    end if;
  end if;
end $$;

alter table public.colleges enable row level security;

drop policy if exists "colleges_select" on public.colleges;
create policy "colleges_select" on public.colleges
for select
using (true);

drop policy if exists "colleges_insert" on public.colleges;
create policy "colleges_insert" on public.colleges
for insert
with check (public.is_admin());

drop policy if exists "colleges_update" on public.colleges;
create policy "colleges_update" on public.colleges
for update
using (public.is_admin());

drop policy if exists "colleges_delete" on public.colleges;
create policy "colleges_delete" on public.colleges
for delete
using (public.is_admin());

insert into public.colleges (name)
values
  ('Amrit Science Campus (ASCOL)'),
  ('Patan Multiple Campus'),
  ('St. Xavier''s College, Maitighar'),
  ('Prime College'),
  ('Kathmandu BernHardt College'),
  ('KIST College & SS'),
  ('National College of Computer Studies (NCCS)'),
  ('Texas College of Management & IT'),
  ('Kantipur City College'),
  ('Kathmandu Model College (KMC)'),
  ('Softwarica College of IT'),
  ('NCIT'),
  ('Lalitpur Engineering College'),
  ('Everest College'),
  ('Orchid International College')
on conflict (name) do nothing;
