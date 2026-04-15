create or replace view public.admin_activity_feed as
select
  l.id,
  l.user_id,
  coalesce(p.full_name, 'Student') as user_name,
  coalesce(p.email, '') as user_email,
  l.activity_type,
  l.source,
  l.points,
  l.subject_id,
  coalesce(s.name, '') as subject_name,
  l.chapter_id,
  coalesce(c.title, '') as chapter_title,
  l.metadata,
  l.created_at,
  trim(
    both ' ' from concat_ws(
      ' ',
      coalesce(p.full_name, ''),
      coalesce(p.email, ''),
      coalesce(l.activity_type, ''),
      coalesce(l.source, ''),
      coalesce(s.name, ''),
      coalesce(c.title, ''),
      coalesce(l.metadata::text, '')
    )
  ) as search_text
from public.user_activity_log l
left join public.profiles p on p.id = l.user_id
left join public.subjects s on s.id = l.subject_id
left join public.chapters c on c.id = l.chapter_id;

grant select on public.admin_activity_feed to authenticated;

create or replace view public.admin_audit_feed as
select
  a.id,
  a.actor_id,
  coalesce(p.full_name, 'Admin') as actor_name,
  coalesce(p.email, '') as actor_email,
  a.action_type,
  a.target_type,
  a.target_id,
  a.target_user_id,
  a.details,
  a.created_at,
  trim(
    both ' ' from concat_ws(
      ' ',
      coalesce(p.full_name, ''),
      coalesce(p.email, ''),
      coalesce(a.action_type, ''),
      coalesce(a.target_type, ''),
      coalesce(a.target_id, ''),
      coalesce(a.details::text, '')
    )
  ) as search_text
from public.admin_audit_log a
left join public.profiles p on p.id = a.actor_id;

grant select on public.admin_audit_feed to authenticated;
