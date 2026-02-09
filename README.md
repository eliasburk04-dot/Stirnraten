# Stirnraten

Flutter party guessing game (Stirnraten).

## Requirements
- Flutter SDK (stable channel)
- Dart (included with Flutter)

## Setup
```powershell
flutter pub get
```

## Run (local)
```powershell
flutter run
```

## Run (web)
```powershell
flutter run -d chrome
```

## Build (web)
```powershell
flutter build web
```
Output: `build/web`

## Tests
```powershell
flutter test
```

## Deploy (Vercel)
```powershell
flutter build web
vercel deploy --prebuilt
```

## Eigene Wörter
- Eigene Wortlisten werden lokal auf dem Gerät gespeichert (kein Account nötig).
- Mehrere Listen möglich, vollständig bearbeitbar (erstellen, ändern, löschen).
- Funktioniert offline auf Web und iOS.

## App-Modell
- Die App wird aktuell vollständig kostenlos veröffentlicht.
- Es gibt keine In-App-Käufe oder Paywall.

## KI-Wörterlisten
- Setup und Supabase-Migration: `docs/ai_wordlist_setup.md`
- Supabase SQL: `docs/supabase/migrations/20260209_wordlists_ai.sql`
- Supabase Auth-Session (Apple Login) wird für Cloud-Listen verwendet.

## Notes
This project is platform-neutral and does not require any Replit-specific configuration.
