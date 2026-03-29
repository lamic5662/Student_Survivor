-- Allow users to delete their own AI messages via conversation ownership.
create policy "ai_messages_delete_own" on public.ai_messages
for delete
using (
  exists (
    select 1 from public.ai_conversations ac
    where ac.id = conversation_id and ac.user_id = auth.uid()
  )
);
