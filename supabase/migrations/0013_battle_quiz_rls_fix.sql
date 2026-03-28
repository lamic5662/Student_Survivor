-- Allow matchmaking to see waiting rooms and player counts
do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'battle_rooms'
      and policyname = 'battle_rooms_select_waiting'
  ) then
    execute 'create policy "battle_rooms_select_waiting" on public.battle_rooms for select using (status = ''waiting'')';
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'battle_players'
      and policyname = 'battle_players_select_waiting'
  ) then
    execute 'create policy "battle_players_select_waiting" on public.battle_players for select using (exists (select 1 from public.battle_rooms r where r.id = room_id and r.status = ''waiting''))';
  end if;
end $$;
