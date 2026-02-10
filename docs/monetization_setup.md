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
- `sync-premium` (Premium-Flag serverseitig via RevenueCat)

Deploy:
```bash
supabase functions deploy generate-wordlist
supabase functions deploy sync-premium
```

## 3) Supabase Secrets setzen

### KI (bereits vorhanden)
```bash
supabase secrets set GROQ_API_KEY=...
```

### RevenueCat Premium Sync (serverseitig)
`sync-premium` validiert Premium ueber RevenueCat und schreibt `public.profiles.premium`.

Required:
```bash
supabase secrets set REVENUECAT_SECRET_API_KEY=...
```

Optional (wenn deine Product IDs nicht nur im Client gesetzt sind):
```bash
supabase secrets set IOS_IAP_PREMIUM_LIFETIME_PRODUCT_ID=...
supabase secrets set ANDROID_IAP_PREMIUM_LIFETIME_PRODUCT_ID=...
```

Optional (wenn du ein anderes Entitlement als "premium" nutzt):
```bash
supabase secrets set REVENUECAT_ENTITLEMENT_ID=premium
```

Hinweis:
- `SUPABASE_SERVICE_ROLE_KEY` ist in Edge Functions Runtime i.d.R. vorhanden.

## 4) Client ENV (DART_DEFINES)

Supabase + KI:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `AI_WORDLIST_ENDPOINT` (Supabase Function URL zu `generate-wordlist`)

IAP/RevenueCat:
- `IOS_IAP_PREMIUM_LIFETIME_PRODUCT_ID`
- `ANDROID_IAP_PREMIUM_LIFETIME_PRODUCT_ID`
- `REVENUECAT_API_KEY_IOS`
- `REVENUECAT_API_KEY_ANDROID`

Beispiel:
```bash
flutter run \\
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \\
  --dart-define=SUPABASE_ANON_KEY=... \\
  --dart-define=AI_WORDLIST_ENDPOINT=https://YOUR_PROJECT.supabase.co/functions/v1/generate-wordlist \\
  --dart-define=IOS_IAP_PREMIUM_LIFETIME_PRODUCT_ID=... \\
  --dart-define=ANDROID_IAP_PREMIUM_LIFETIME_PRODUCT_ID=... \\
  --dart-define=REVENUECAT_API_KEY_IOS=... \\
  --dart-define=REVENUECAT_API_KEY_ANDROID=...
```

