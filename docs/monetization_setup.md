# Monetization Setup (Free/Premium)

## Free vs Premium (verbindlich)

Free:
- Alle Kategorien & Modi spielbar
- Eigene Listen manuell erstellbar
- Max. 20 Wörter pro Liste
- KI-Listen: 3 Generierungen pro Tag (Europe/Berlin)
- Keine Werbung

Premium (Lifetime 4,99 EUR):
- Unbegrenzte KI-Generierungen
- Max. 100 Wörter pro Liste
- Keine Werbung

## 1) Supabase Migration ausführen

Zusätzlich zur bestehenden Wordlist-Migration:
- `supabase/migrations/20260210100000_monetization.sql`

Ausführen (CLI):
```bash
supabase db push
```

## 2) Edge Functions deployen

Diese Functions werden genutzt:
- `generate-wordlist` (Quota + Wordlimit serverseitig)
- `verify-premium` (Premium-Flag serverseitig via Store-Verification)

Deploy:
```bash
supabase functions deploy generate-wordlist
supabase functions deploy verify-premium
```

## 3) Supabase Secrets setzen

### KI (bereits vorhanden)
```bash
supabase secrets set GROQ_API_KEY=...
```

### Premium Verifikation (serverseitig)
`verify-premium` verifiziert den Lifetime-Kauf direkt mit Apple/Google und schreibt `public.profiles.premium`.

Required:
```bash
supabase secrets set SERVICE_ROLE_KEY=...
```

iOS (Receipt Verification, non-consumable):
```bash
# optional; fuer Subscriptions notwendig, fuer Non-Consumables meist nicht
supabase secrets set APPLE_VERIFY_RECEIPT_SHARED_SECRET=...
```

Android (Google Play Developer API):
```bash
supabase secrets set GOOGLE_PLAY_PACKAGE_NAME=com.dein.bundleid
supabase secrets set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
```

## 4) Client ENV (DART_DEFINES)

Supabase + KI:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `AI_WORDLIST_ENDPOINT` (Supabase Function URL zu `generate-wordlist`)

IAP (Store direkt):
- `IOS_IAP_PREMIUM_LIFETIME_PRODUCT_ID`
- `ANDROID_IAP_PREMIUM_LIFETIME_PRODUCT_ID`

Beispiel:
```bash
flutter run \\
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \\
  --dart-define=SUPABASE_ANON_KEY=... \\
  --dart-define=AI_WORDLIST_ENDPOINT=https://YOUR_PROJECT.supabase.co/functions/v1/generate-wordlist \\
  --dart-define=IOS_IAP_PREMIUM_LIFETIME_PRODUCT_ID=... \\
  --dart-define=ANDROID_IAP_PREMIUM_LIFETIME_PRODUCT_ID=...
```
