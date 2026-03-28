-- Add room code for invite-based battle quiz
alter table public.battle_rooms
add column if not exists room_code text;

create unique index if not exists battle_rooms_room_code_key
on public.battle_rooms(room_code);
