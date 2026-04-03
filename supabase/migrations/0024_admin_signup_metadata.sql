-- Auto-mark admin profiles when admin signup metadata is set

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_admin boolean := coalesce(
    (new.raw_user_meta_data->>'admin_signup')::boolean,
    false
  );
begin
  insert into public.profiles (id, email, is_admin)
  values (new.id, new.email, v_is_admin)
  on conflict (id) do nothing;

  insert into public.user_stats (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;
