drop policy if exists "profiles_select_same_semester" on public.profiles;
create policy "profiles_select_same_semester" on public.profiles
for select
using (
  public.is_admin()
  or auth.uid() = id
  or public.has_same_semester_id(semester_id)
);
