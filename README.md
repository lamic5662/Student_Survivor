# Student Survivor

Flutter app for the Student Survivor learning platform. Includes Supabase-backed data, AI study tools, games, and progress tracking.

## Features

- Authentication + onboarding (semester + subjects)
- Dashboard (progress, weak topics, recommendations)
- Subjects → chapters → notes/questions/quizzes
- AI notes (chapter + subject), saved user notes
- AI study assistant chat + AI personal coach
- Games: flashcards, battle quiz, study survivor
- Programming World (learning tracks + practice links)
- Free Books hub (OpenStax, Open Textbook Library, LibreTexts)
- Note attachment reader with word meanings + generated Q/A (owner-only)
- BCA notices feed (TU official page parsing)
- Quiz flow + results with review
- Study planner (AI + manual tasks)
- Community Q&A (AI-verified questions + public answers)
- Offline notes cache (Hive) + offline AI note drafts
- Search
- Progress tracking
- Syllabus & past papers
- Profile hub

## Architecture

MVP pattern with `Presenter` + `ViewModel` and `PresenterState` bridges:

- `lib/core/mvp/`
- `lib/features/<feature>/`
Data layer uses Supabase services in `lib/data/` with MVP presenters per feature.

## Database

Supabase migrations live in `supabase/migrations/`.
Latest additions:
- `0020_community_qna.sql` (Community Q&A tables + RLS)
- `0021_community_qna_semester_rls.sql` (same-semester visibility)
- `0022_note_generated_questions.sql` (note-generated Q/A, owner-only)

## Backend Workflow (Supabase)

1. Apply migrations in order (see `supabase/migrations/`)
2. Optional seed: `supabase/seed.sql`

Core RPCs:
- `set_user_subjects(semester_id, subject_ids[])`
- `start_quiz_attempt(quiz_id)`
- `finish_quiz_attempt(attempt_id, score, duration_seconds, answers_json)`
- `search_content(query, limit)`

Edge Functions:
- `ai-chat` (AI tutor)
- `ai-generate` (AI notes / quizzes / flashcards / definitions)

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

## Offline Notes Cache

Notes and AI-generated drafts are cached with Hive. First open notes online to seed the cache.
After that, notes and AI drafts are available offline.

## AI Modes

Configure in `.env`:

```env
AI_MODE=backend   # backend | ollama | lmstudio | free
```

Recommended architecture:
- **Production:** Flutter → Supabase Edge Functions → Ollama
- **Development:** LM Studio (local) for fast testing

Provider config:

```env
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_MODEL=llama3

LMSTUDIO_BASE_URL=http://127.0.0.1:1234/v1
LMSTUDIO_MODEL=google/gemma-3-4b
LMSTUDIO_API_KEY=
```

## Local Dev (Backend + Ollama)

1. Start Supabase:
```bash
supabase start
```

2. Serve Edge Functions locally:
```bash
supabase functions serve ai-generate --no-verify-jwt
```

3. Set local function env in `supabase/functions/.env`:
```env
AI_PROVIDER=ollama
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_MODEL=llama3
```

## Notes

- Supabase local users are separate from production users.
