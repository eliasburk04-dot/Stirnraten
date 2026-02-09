# KI-Wörterlisten Setup (Production Ready)

## 1) Supabase Migration ausführen

CLI-Migration liegt in:
- `supabase/migrations/20260209170000_wordlists_ai.sql`

Manuell im SQL Editor:
- Inhalt aus `supabase/migrations/20260209170000_wordlists_ai.sql` ausführen.

CLI-Push:
```bash
supabase db push
```

## 2) Supabase Anonymous Auth aktivieren (kein Nutzer-Login im UI)

In Supabase:
- `Authentication -> Providers -> Anonymous` aktivieren.
- Kein Apple Provider nötig.
- Kein Redirect-Setup nötig.
- Die App erstellt beim Öffnen automatisch eine anonyme Session.

## 3) Laufzeit-Konfiguration per `--dart-define`

Für Produktion:
- Supabase URL + Anon Key
- KI-Endpoint (dein Proxy/Edge Function)
- Kein Groq-Key in der App

```bash
flutter run \
  --dart-define=AI_WORDLIST_ENDPOINT=https://YOUR_PROJECT.supabase.co/functions/v1/generate-wordlist \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

Hinweis:
- Supabase wird beim App-Start automatisch initialisiert (`lib/services/supabase_bootstrap.dart`).
- Cloud-Sync nutzt automatisch eine anonyme Supabase-Session (`signInAnonymously`).
- `SUPABASE_USER_ID` + `SUPABASE_ACCESS_TOKEN` werden nur noch als lokaler Dev-Fallback unterstützt.
- `APP_TOKEN` ist nur Dev-Placeholder. Für App-Store-Release entfernen und nur Server-to-Server nutzen.

## 4) Auth-Verhalten in der App

- Es ist kein Konto nötig.
- Die App meldet Spieler automatisch anonym an.
- Danach werden Cloud-Listen pro User geladen/gespeichert.

## 5) Wo kommt der Groq API Key hin?

Nicht in die App.

Empfohlen:
- Groq Key als Secret im Backend (Supabase Edge Function Secret `GROQ_API_KEY`).
- App ruft nur `AI_WORDLIST_ENDPOINT` auf.
- Backend ruft Groq auf und gibt nur validiertes JSON zurück.

Groq Secret setzen (CLI):
```bash
supabase secrets set --project-ref YOUR_PROJECT_REF GROQ_API_KEY=YOUR_GROQ_KEY
```

Optional:
```bash
supabase secrets set --project-ref YOUR_PROJECT_REF GROQ_MODEL=llama-3.1-70b-versatile GROQ_TEMPERATURE=0.4
```

## 6) Sicherheits-Hinweis

- Keine Secrets in Git einchecken.
- Für CI/CD: Werte als Secret Environment Variables hinterlegen und in Build-Command als `--dart-define` injizieren.

## 7) Supabase CLI einmalig verbinden

Voraussetzung:
- `supabase` CLI ist installiert.

Einmalig ausführen:
```bash
cd /path/to/Stirnraten
SUPABASE_ACCESS_TOKEN=... \
SUPABASE_PROJECT_REF=... \
SUPABASE_DB_PASSWORD=... \
SUPABASE_PUSH=1 \
./scripts/supabase_cli_connect.sh
```

Danach kann ich Migrationen direkt übernehmen (`supabase db push`, `supabase migration ...`).
