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
- Free: voll spielbar (alle Kategorien/Modi), eigene Listen, KI-Limits (3/Tag), max. 20 Wörter pro Liste.
- Premium (Lifetime): unbegrenzte KI, max. 100 Wörter pro Liste.
- Keine Werbung.

## KI-Wörterlisten
- Setup und Supabase-Migration: `docs/ai_wordlist_setup.md`
- Supabase SQL (CLI Migration): `supabase/migrations/20260209170000_wordlists_ai.sql`
- Supabase Auth: Anonymous (kein Login im UI).

## Monetization
- Setup: `docs/monetization_setup.md`
- Manuelle Tests: `docs/monetization_manual_test_checklist.md`

## Notes
This project is platform-neutral and does not require any Replit-specific configuration.
