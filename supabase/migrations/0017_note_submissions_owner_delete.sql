-- Allow students to delete their own pending submissions
drop policy if exists "note_submissions_delete_owner" on public.note_submissions;
create policy "note_submissions_delete_owner" on public.note_submissions
for delete
using (auth.uid() = user_id and status = 'pending');
