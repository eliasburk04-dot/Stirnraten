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

## Premium In-App Purchase
- Setup und Launch-Details: `docs/premium_iap_setup.md`
- Produkt-ID wird per `--dart-define=IAP_PRODUCT_IDS=...` gesetzt.
- Optionale Server-Verifikation per `--dart-define=IAP_VERIFICATION_ENDPOINT=...`.

## Notes
This project is platform-neutral and does not require any Replit-specific configuration.
