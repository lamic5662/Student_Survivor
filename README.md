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

## Run

```bash
flutter pub get
flutter run
```

## Notes

- All data is mocked in `lib/data/mock_data.dart`.
- Replace mock data with Supabase or API integration once backend is ready.
