# Student Survivor

Frontend MVP for the Student Survivor learning app. This build focuses on clean UI, MVP architecture, and mock data to represent all core features.

## Included Screens

- Authentication + onboarding (semester + subjects)
- Dashboard (progress, weak topics, recommendations)
- Subjects → chapters → notes/questions/quizzes
- AI study assistant chat UI
- Game hub, quiz flow, results with adaptive learning
- Study planner
- Search
- Progress tracking
- Syllabus
- Profile hub

## Architecture

MVP pattern with `Presenter` + `ViewModel` and `PresenterState` bridges:

- `lib/core/mvp/`
- `lib/features/<feature>/`
- `lib/data/mock_data.dart`

## Database

Supabase migration is ready at `supabase/migrations/0001_init.sql`.

## Backend Workflow

1. Run `supabase/migrations/0001_init.sql`
2. Run `supabase/migrations/0002_backend.sql`
3. Optional seed: `supabase/seed.sql`

Core RPCs:
- `set_user_subjects(semester_id, subject_ids[])`
- `start_quiz_attempt(quiz_id)`
- `finish_quiz_attempt(attempt_id, score, duration_seconds, answers_json)`
- `search_content(query, limit)`

## Run

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=YOUR_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Or create a `.env` (see `.env.example`) and run normally:

```bash
flutter run
```

## Notes

- All data is mocked in `lib/data/mock_data.dart`.
- Replace mock data with Supabase or API integration once backend is ready.
