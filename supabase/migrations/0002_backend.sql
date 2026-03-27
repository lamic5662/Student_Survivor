-- Backend workflow functions, triggers, and RPCs

create unique index if not exists weak_topics_user_topic_idx
  on public.weak_topics(user_id, topic);

create unique index if not exists recommendations_user_note_idx
  on public.recommendations(user_id, note_id)
  where note_id is not null;

create unique index if not exists recommendations_user_question_idx
  on public.recommendations(user_id, question_id)
  where question_id is not null;

-- Auto-create profile + stats on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;

  insert into public.user_stats (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

-- Update profile semester + subjects in one call
create or replace function public.set_user_subjects(
  p_semester_id uuid,
  p_subject_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not authenticated';
  end if;

  update public.profiles
  set semester_id = p_semester_id
  where id = v_user;

  delete from public.user_subjects
  where user_id = v_user;

  insert into public.user_subjects(user_id, subject_id)
  select v_user, s.id
  from public.subjects s
  where s.id = any(p_subject_ids)
    and s.semester_id = p_semester_id;
end;
$$;

-- Quiz workflow: start attempt
create or replace function public.start_quiz_attempt(
  p_quiz_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_total int;
  v_attempt_id uuid;
begin
  if v_user is null then
    raise exception 'not authenticated';
  end if;

  select question_count into v_total
  from public.quizzes
  where id = p_quiz_id;

  if v_total is null then
    raise exception 'quiz not found';
  end if;

  insert into public.quiz_attempts(user_id, quiz_id, score, total)
  values(v_user, p_quiz_id, 0, v_total)
  returning id into v_attempt_id;

  return v_attempt_id;
end;
$$;

-- Quiz workflow: finish attempt + answers
create or replace function public.finish_quiz_attempt(
  p_attempt_id uuid,
  p_score int,
  p_duration_seconds int,
  p_answers jsonb
)
returns table (passed boolean, xp_earned int, weak_topics text[])
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_total int;
  v_passed boolean;
  v_xp int;
  v_topics text[];
begin
  if v_user is null then
    raise exception 'not authenticated';
  end if;

  select total into v_total
  from public.quiz_attempts
  where id = p_attempt_id and user_id = v_user;

  if v_total is null then
    raise exception 'attempt not found';
  end if;

  v_passed := p_score >= (v_total * 0.6);
  v_xp := greatest(p_score * 10, 0);

  update public.quiz_attempts
  set score = p_score,
      total = v_total,
      xp_earned = v_xp,
      passed = v_passed,
      duration_seconds = p_duration_seconds,
      completed_at = now()
  where id = p_attempt_id;

  if p_answers is not null then
    insert into public.quiz_answers(
      attempt_id,
      quiz_question_id,
      selected_index,
      is_correct,
      response_time_ms
    )
    select
      p_attempt_id,
      (elem->>'quiz_question_id')::uuid,
      (elem->>'selected_index')::int,
      (elem->>'is_correct')::boolean,
      (elem->>'response_time_ms')::int
    from jsonb_array_elements(p_answers) as elem;
  end if;

  select array_agg(distinct q.topic)
  into v_topics
  from public.quiz_answers a
  join public.quiz_questions q on q.id = a.quiz_question_id
  where a.attempt_id = p_attempt_id
    and a.is_correct is false
    and q.topic is not null;

  if v_topics is not null then
    insert into public.weak_topics(user_id, topic, reason, severity, last_seen_at)
    select v_user, topic, 'Missed in latest quiz', 1, now()
    from unnest(v_topics) as topic
    on conflict (user_id, topic)
    do update set
      last_seen_at = excluded.last_seen_at,
      severity = least(public.weak_topics.severity + 1, 5),
      reason = excluded.reason;

    insert into public.recommendations(user_id, note_id, reason)
    select v_user, n.id, 'Recommended for weak topic: ' || topic
    from unnest(v_topics) as topic
    join public.notes n on n.title ilike '%' || topic || '%'
       or n.short_answer ilike '%' || topic || '%'
    on conflict do nothing;
  end if;

  insert into public.user_stats(user_id, xp, games_played, last_played_at)
  values(v_user, v_xp, 1, now())
  on conflict (user_id) do update
    set xp = public.user_stats.xp + excluded.xp,
        games_played = public.user_stats.games_played + excluded.games_played,
        last_played_at = excluded.last_played_at;

  return query select v_passed, v_xp, coalesce(v_topics, '{}');
end;
$$;

-- Search RPC (notes, questions, chapters, subjects)
create type public.search_result as (
  item_type text,
  item_id uuid,
  title text,
  snippet text,
  score real
);

create or replace function public.search_content(
  p_query text,
  p_limit int default 10
)
returns setof public.search_result
language sql
security definer
set search_path = public
as $$
with results as (
  select
    'note'::text as item_type,
    n.id as item_id,
    n.title,
    left(coalesce(n.short_answer, n.detailed_answer, ''), 160) as snippet,
    greatest(similarity(n.title, p_query), similarity(coalesce(n.short_answer, ''), p_query)) as score
  from public.notes n
  where n.title ilike '%' || p_query || '%'
     or n.short_answer ilike '%' || p_query || '%'

  union all
  select
    'question'::text,
    q.id,
    left(q.prompt, 120),
    q.prompt,
    similarity(q.prompt, p_query)
  from public.questions q
  where q.prompt ilike '%' || p_query || '%'

  union all
  select
    'chapter'::text,
    c.id,
    c.title,
    coalesce(c.summary, ''),
    similarity(c.title, p_query)
  from public.chapters c
  where c.title ilike '%' || p_query || '%'

  union all
  select
    'subject'::text,
    s.id,
    s.name,
    coalesce(s.description, ''),
    similarity(s.name, p_query)
  from public.subjects s
  where s.name ilike '%' || p_query || '%'
)
select * from results
order by score desc
limit p_limit;
$$;

grant execute on function public.set_user_subjects(uuid, uuid[]) to authenticated;
grant execute on function public.start_quiz_attempt(uuid) to authenticated;
grant execute on function public.finish_quiz_attempt(uuid, int, int, jsonb) to authenticated;
grant execute on function public.search_content(text, int) to anon, authenticated;
