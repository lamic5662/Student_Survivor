-- Fix RLS recursion for battle matchmaking

create or replace function public.is_battle_room_member(
  p_room uuid,
  p_user uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.battle_players
    where room_id = p_room and user_id = p_user
  );
$$;

create or replace function public.is_battle_room_waiting(p_room uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.battle_rooms
    where id = p_room and status = 'waiting'
  );
$$;

drop policy if exists "battle_rooms_select" on public.battle_rooms;
drop policy if exists "battle_rooms_select_waiting" on public.battle_rooms;
drop policy if exists "battle_rooms_insert" on public.battle_rooms;
drop policy if exists "battle_rooms_update" on public.battle_rooms;

create policy "battle_rooms_select" on public.battle_rooms
for select
using (
  status = 'waiting'
  or created_by = auth.uid()
  or public.is_battle_room_member(id, auth.uid())
);

create policy "battle_rooms_insert" on public.battle_rooms
for insert
with check (auth.uid() = created_by);

create policy "battle_rooms_update" on public.battle_rooms
for update
using (public.is_battle_room_member(id, auth.uid()));

drop policy if exists "battle_players_select" on public.battle_players;
drop policy if exists "battle_players_select_waiting" on public.battle_players;
drop policy if exists "battle_players_insert" on public.battle_players;
drop policy if exists "battle_players_update" on public.battle_players;

create policy "battle_players_select" on public.battle_players
for select
using (
  auth.uid() = user_id
  or public.is_battle_room_waiting(room_id)
  or public.is_battle_room_member(room_id, auth.uid())
);

create policy "battle_players_insert" on public.battle_players
for insert
with check (auth.uid() = user_id);

create policy "battle_players_update" on public.battle_players
for update
using (auth.uid() = user_id);

drop policy if exists "battle_questions_select" on public.battle_questions;
drop policy if exists "battle_questions_insert" on public.battle_questions;

create policy "battle_questions_select" on public.battle_questions
for select
using (public.is_battle_room_member(room_id, auth.uid()));

create policy "battle_questions_insert" on public.battle_questions
for insert
with check (
  exists (
    select 1 from public.battle_rooms r
    where r.id = room_id and r.created_by = auth.uid()
  )
);

drop policy if exists "battle_answers_select" on public.battle_answers;
drop policy if exists "battle_answers_insert" on public.battle_answers;

create policy "battle_answers_select" on public.battle_answers
for select
using (public.is_battle_room_member(room_id, auth.uid()));

create policy "battle_answers_insert" on public.battle_answers
for insert
with check (
  auth.uid() = user_id
  and public.is_battle_room_member(room_id, auth.uid())
);
