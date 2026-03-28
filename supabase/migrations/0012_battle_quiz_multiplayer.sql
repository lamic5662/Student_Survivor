-- Multiplayer battle quiz tables
create table if not exists public.battle_rooms (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.subjects(id) on delete cascade,
  chapter_id uuid not null references public.chapters(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  status text not null default 'waiting',
  target_score int not null default 10,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgname = 'set_battle_rooms_updated_at'
      and tgrelid = 'public.battle_rooms'::regclass
  ) then
    create trigger set_battle_rooms_updated_at
    before update on public.battle_rooms
    for each row
    execute function public.set_updated_at();
  end if;
end $$;

create table if not exists public.battle_players (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.battle_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  score int not null default 0,
  joined_at timestamptz not null default now(),
  unique (room_id, user_id)
);

create table if not exists public.battle_questions (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.battle_rooms(id) on delete cascade,
  prompt text not null,
  options jsonb not null,
  correct_index int not null,
  explanation text,
  difficulty text,
  order_index int not null
);

create table if not exists public.battle_answers (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.battle_rooms(id) on delete cascade,
  question_id uuid not null references public.battle_questions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  selected_index int not null,
  is_correct boolean not null,
  created_at timestamptz not null default now(),
  unique (question_id, user_id)
);

alter table public.battle_rooms enable row level security;
alter table public.battle_players enable row level security;
alter table public.battle_questions enable row level security;
alter table public.battle_answers enable row level security;

create policy "battle_rooms_select" on public.battle_rooms
for select
using (
  exists (
    select 1 from public.battle_players bp
    where bp.room_id = id and bp.user_id = auth.uid()
  )
);

create policy "battle_rooms_insert" on public.battle_rooms
for insert
with check (auth.uid() = created_by);

create policy "battle_rooms_update" on public.battle_rooms
for update
using (
  exists (
    select 1 from public.battle_players bp
    where bp.room_id = id and bp.user_id = auth.uid()
  )
);

create policy "battle_players_select" on public.battle_players
for select
using (
  exists (
    select 1 from public.battle_players bp
    where bp.room_id = room_id and bp.user_id = auth.uid()
  )
);

create policy "battle_players_insert" on public.battle_players
for insert
with check (auth.uid() = user_id);

create policy "battle_players_update" on public.battle_players
for update
using (auth.uid() = user_id);

create policy "battle_questions_select" on public.battle_questions
for select
using (
  exists (
    select 1 from public.battle_players bp
    where bp.room_id = room_id and bp.user_id = auth.uid()
  )
);

create policy "battle_questions_insert" on public.battle_questions
for insert
with check (
  exists (
    select 1 from public.battle_rooms r
    where r.id = room_id and r.created_by = auth.uid()
  )
);

create policy "battle_answers_select" on public.battle_answers
for select
using (
  exists (
    select 1 from public.battle_players bp
    where bp.room_id = room_id and bp.user_id = auth.uid()
  )
);

create policy "battle_answers_insert" on public.battle_answers
for insert
with check (
  auth.uid() = user_id
  and exists (
    select 1 from public.battle_players bp
    where bp.room_id = room_id and bp.user_id = auth.uid()
  )
);
