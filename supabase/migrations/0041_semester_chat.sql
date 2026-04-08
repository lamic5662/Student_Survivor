create table if not exists public.chat_rooms (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('public', 'group')),
  semester_id uuid not null references public.semesters(id) on delete cascade,
  name text not null,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists chat_rooms_public_semester_idx
  on public.chat_rooms(semester_id)
  where type = 'public';

create index if not exists chat_rooms_semester_idx
  on public.chat_rooms(semester_id);

create table if not exists public.chat_members (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.chat_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('member', 'admin')),
  joined_at timestamptz not null default now(),
  unique (room_id, user_id)
);

create index if not exists chat_members_room_idx
  on public.chat_members(room_id);

create index if not exists chat_members_user_idx
  on public.chat_members(user_id);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.chat_rooms(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_room_idx
  on public.chat_messages(room_id, created_at desc);

alter table public.chat_rooms enable row level security;
alter table public.chat_members enable row level security;
alter table public.chat_messages enable row level security;

create or replace function public.has_same_semester_id(semester_uuid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.semester_id = semester_uuid
  );
$$;

drop policy if exists "chat_rooms_select" on public.chat_rooms;
create policy "chat_rooms_select" on public.chat_rooms
for select
using (
  public.is_admin()
  or (type = 'public' and public.has_same_semester_id(semester_id))
  or exists (
    select 1 from public.chat_members m
    where m.room_id = id and m.user_id = auth.uid()
  )
);

drop policy if exists "chat_rooms_insert" on public.chat_rooms;
create policy "chat_rooms_insert" on public.chat_rooms
for insert
with check (
  auth.uid() = created_by
  and public.has_same_semester_id(semester_id)
);

drop policy if exists "chat_rooms_update" on public.chat_rooms;
create policy "chat_rooms_update" on public.chat_rooms
for update
using (public.is_admin() or created_by = auth.uid());

drop policy if exists "chat_rooms_delete" on public.chat_rooms;
create policy "chat_rooms_delete" on public.chat_rooms
for delete
using (public.is_admin() or created_by = auth.uid());

drop policy if exists "chat_members_select" on public.chat_members;
create policy "chat_members_select" on public.chat_members
for select
using (
  public.is_admin()
  or exists (
    select 1 from public.chat_members m
    where m.room_id = room_id and m.user_id = auth.uid()
  )
  or exists (
    select 1 from public.chat_rooms r
    where r.id = room_id
      and r.type = 'public'
      and public.has_same_semester_id(r.semester_id)
  )
);

drop policy if exists "chat_members_insert" on public.chat_members;
create policy "chat_members_insert" on public.chat_members
for insert
with check (
  (
    auth.uid() = user_id
    or exists (
      select 1 from public.chat_rooms r
      where r.id = room_id and r.created_by = auth.uid()
    )
  )
  and exists (
    select 1 from public.chat_rooms r
    join public.profiles p on p.id = user_id
    where r.id = room_id and p.semester_id = r.semester_id
  )
);

drop policy if exists "chat_members_delete" on public.chat_members;
create policy "chat_members_delete" on public.chat_members
for delete
using (
  public.is_admin()
  or user_id = auth.uid()
  or exists (
    select 1 from public.chat_rooms r
    where r.id = room_id and r.created_by = auth.uid()
  )
);

drop policy if exists "chat_messages_select" on public.chat_messages;
create policy "chat_messages_select" on public.chat_messages
for select
using (
  public.is_admin()
  or exists (
    select 1 from public.chat_rooms r
    where r.id = room_id
      and r.type = 'public'
      and public.has_same_semester_id(r.semester_id)
  )
  or exists (
    select 1 from public.chat_members m
    where m.room_id = room_id and m.user_id = auth.uid()
  )
);

drop policy if exists "chat_messages_insert" on public.chat_messages;
create policy "chat_messages_insert" on public.chat_messages
for insert
with check (
  auth.uid() = sender_id
  and (
    exists (
      select 1 from public.chat_rooms r
      where r.id = room_id
        and r.type = 'public'
        and public.has_same_semester_id(r.semester_id)
    )
    or exists (
      select 1 from public.chat_members m
      where m.room_id = room_id and m.user_id = auth.uid()
    )
  )
);

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
      where tgname = 'set_chat_rooms_updated_at'
    ) then
      execute 'create trigger set_chat_rooms_updated_at
        before update on public.chat_rooms
        for each row
        execute function public.set_updated_at()';
    end if;
  end if;
end $$;
