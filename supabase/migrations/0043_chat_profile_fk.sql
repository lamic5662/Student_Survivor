do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'chat_messages_sender_profile_fkey'
  ) then
    execute 'alter table public.chat_messages
      add constraint chat_messages_sender_profile_fkey
      foreign key (sender_id)
      references public.profiles(id)
      on delete cascade';
  end if;
end $$;
