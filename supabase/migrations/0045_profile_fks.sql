do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'chat_members_user_profile_fkey'
  ) then
    execute 'alter table public.chat_members
      add constraint chat_members_user_profile_fkey
      foreign key (user_id)
      references public.profiles(id)
      on delete cascade
      not valid';
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'note_submissions_user_profile_fkey'
  ) then
    execute 'alter table public.note_submissions
      add constraint note_submissions_user_profile_fkey
      foreign key (user_id)
      references public.profiles(id)
      on delete cascade
      not valid';
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'community_questions_user_profile_fkey'
  ) then
    execute 'alter table public.community_questions
      add constraint community_questions_user_profile_fkey
      foreign key (user_id)
      references public.profiles(id)
      on delete cascade
      not valid';
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'community_answers_user_profile_fkey'
  ) then
    execute 'alter table public.community_answers
      add constraint community_answers_user_profile_fkey
      foreign key (user_id)
      references public.profiles(id)
      on delete cascade
      not valid';
  end if;
end $$;
