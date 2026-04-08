create or replace function public.is_room_member(room_uuid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists(
    select 1
    from public.chat_members m
    where m.room_id = room_uuid
      and m.user_id = auth.uid()
  );
$$;

drop policy if exists "chat_rooms_select" on public.chat_rooms;
create policy "chat_rooms_select" on public.chat_rooms
for select
using (
  public.is_admin()
  or (type = 'public' and public.has_same_semester_id(semester_id))
  or public.is_room_member(id)
);

drop policy if exists "chat_members_select" on public.chat_members;
create policy "chat_members_select" on public.chat_members
for select
using (
  public.is_admin()
  or public.is_room_member(room_id)
  or exists (
    select 1 from public.chat_rooms r
    where r.id = room_id
      and r.type = 'public'
      and public.has_same_semester_id(r.semester_id)
  )
);

drop policy if exists "chat_messages_select" on public.chat_messages;
create policy "chat_messages_select" on public.chat_messages
for select
using (
  public.is_admin()
  or public.is_room_member(room_id)
  or exists (
    select 1 from public.chat_rooms r
    where r.id = room_id
      and r.type = 'public'
      and public.has_same_semester_id(r.semester_id)
  )
);

drop policy if exists "chat_messages_insert" on public.chat_messages;
create policy "chat_messages_insert" on public.chat_messages
for insert
with check (
  auth.uid() = sender_id
  and (
    public.is_room_member(room_id)
    or exists (
      select 1 from public.chat_rooms r
      where r.id = room_id
        and r.type = 'public'
        and public.has_same_semester_id(r.semester_id)
    )
  )
);
