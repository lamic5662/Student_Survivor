# Admin App Run

This project includes a separate Admin app entrypoint.

## Required credentials
Set these in `.env` (same as the main app):

```
SUPABASE_URL=YOUR_URL
SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

## Run admin app
```
flutter run -t lib/admin_main.dart
```

If you want a dedicated admin config file (for example `.env.admin`),
tell me and I’ll wire it in.
