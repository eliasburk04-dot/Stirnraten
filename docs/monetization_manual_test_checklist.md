# Monetization Manuelle Test-Checkliste

## Free
1. KI: 4. Versuch am selben Tag (Europe/Berlin) -> Paywall erscheint.
2. KI: Output > 20 -> serverseitig auf 20 gekuerzt (Client zeigt 20 in Vorschau).
3. Manuell: > 20 Woerter speichern -> Paywall erscheint, Speichern blockiert.

## Premium
1. Premium kaufen -> UI zeigt sofort Premium aktiv.
2. Restore purchases -> Premium aktiv.
3. KI: unbegrenzt -> keine Paywall.
4. KI: Output > 100 -> serverseitig auf 100 gekuerzt.
5. Manuell: > 100 speichern -> blockiert (Premium bleibt aktiv).

## Sync / Backend
1. Nach Premium Kauf: `sync-premium` setzt `public.profiles.premium=true` (Edge Function).
2. `generate-wordlist`: Quota wird serverseitig ueber `consume_ai_generation` gezaehlt.

